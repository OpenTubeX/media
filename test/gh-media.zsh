#!/usr/bin/env zsh

emulate -L zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

mock_gh() {
  local command="$1"
  shift

  if [[ "$command" == api ]]; then
    local endpoint="$1"

    if [[ "$endpoint" == repos/*/releases/tags/* ]]; then
      local tag="${endpoint##*/}"
      [[ -f "$GH_MEDIA_TEST_STATE/releases/$tag" ]] || return 1
      print -r -- "$tag"
      return
    fi

    if [[ "$endpoint" == repos/*/releases/*/assets\?per_page=100 ]]; then
      local release_id="${endpoint##*/releases/}"
      release_id="${release_id%%/*}"
      while IFS= read -r page_count; do
        print -r -- "$page_count"
      done < "$GH_MEDIA_TEST_STATE/releases/$release_id"
      return
    fi
  fi

  if [[ "$command" == release && "$1" == create ]]; then
    local tag="$2"
    print -r -- 0 > "$GH_MEDIA_TEST_STATE/releases/$tag"
    print -r -- "create $tag" >> "$GH_MEDIA_TEST_STATE/log"
    return
  fi

  if [[ "$command" == release && "$1" == upload ]]; then
    print -r -- "upload $2 ${(j: :)${@:3}}" >> "$GH_MEDIA_TEST_STATE/log"
    return
  fi

  print -u2 -- "unexpected gh call: $command $*"
  return 1
}

case "${0:t}" in
  gh)
    mock_gh "$@"
    exit
    ;;
  file)
    case "${@: -1}" in
      *.webp) print -r -- image/webp ;;
      *.mp4) print -r -- video/mp4 ;;
      *) print -r -- application/octet-stream ;;
    esac
    exit
    ;;
  ffmpeg)
    print -rn -- preview > "${@: -1}"
    exit
    ;;
  wl-copy)
    while IFS= read -r _; do
    done
    exit
    ;;
esac

readonly repo_dir="${0:A:h:h}"
readonly test_dir="$(mktemp -d "${TMPDIR:-/tmp}/gh-media-test.XXXXXXXX")"
trap 'rm -rf -- "$test_dir"' EXIT

readonly mock_bin="$test_dir/bin"
mkdir -p "$mock_bin" "$test_dir/state/releases"
for command in gh file ffmpeg wl-copy; do
  ln -s "$0" "$mock_bin/$command"
done

export PATH="$mock_bin:/usr/bin:/bin"
export GH_MEDIA_REPO="owner/media"
export GH_MEDIA_TEST_STATE="$test_dir/state"

print -rn -- image > "$test_dir/image.webp"
print -rn -- video > "$test_dir/video.mp4"

reset_state() {
  rm -f -- "$GH_MEDIA_TEST_STATE/releases/"*(N) "$GH_MEDIA_TEST_STATE/log"
}

set_release_pages() {
  local tag="$1"
  shift
  print -l -- "$@" > "$GH_MEDIA_TEST_STATE/releases/$tag"
}

assert_log_line() {
  local expected="$1"
  if ! grep -q -E -- "$expected" "$GH_MEDIA_TEST_STATE/log"; then
    print -u2 -- "Expected log line matching: $expected"
    print -u2 -- "Actual log:"
    sed 's/^/  /' "$GH_MEDIA_TEST_STATE/log" >&2
    return 1
  fi
}

reset_state
set_release_pages attachments 999
"$repo_dir/bin/gh-media" "$test_dir/image.webp" >/dev/null
assert_log_line '^upload attachments '
if grep -q '^create ' "$GH_MEDIA_TEST_STATE/log"; then
  print -u2 -- "An image should fit in the last slot"
  exit 1
fi

reset_state
set_release_pages attachments 100 100 100 100 100 100 100 100 100 100
"$repo_dir/bin/gh-media" "$test_dir/image.webp" >/dev/null
assert_log_line '^create attachments-2$'
assert_log_line '^upload attachments-2 '

reset_state
set_release_pages attachments 999
"$repo_dir/bin/gh-media" "$test_dir/video.mp4" >/dev/null
assert_log_line '^create attachments-2$'
assert_log_line '^upload attachments-2 '

reset_state
set_release_pages attachments 1000
set_release_pages attachments-2 1000
set_release_pages attachments-3 12
"$repo_dir/bin/gh-media" "$test_dir/image.webp" >/dev/null
assert_log_line '^upload attachments-3 '
if grep -q '^create ' "$GH_MEDIA_TEST_STATE/log"; then
  print -u2 -- "An existing continuation release should be reused"
  exit 1
fi

print -r -- "All gh-media tests passed."
