# gh-media

Upload an animated WebP or video from the terminal and copy ready-to-paste
Markdown for GitHub issues, pull requests, and discussions.

GitHub caps direct image and video attachments. This script uploads media to a
release asset in your own public repository instead. Release assets stay out of
Git history, so a collection of recordings does not make every clone larger.

```console
$ gh-media settings-bug.webp "Settings panel flickering"
Uploaded:
  20260819T094432Z-settings-bug-902780a352.webp
Copied Markdown to the clipboard:
![Settings panel flickering](https://github.com/you/media/releases/download/attachments/20260819T094432Z-settings-bug-902780a352.webp)

Delete the uploaded asset with:
gh release delete-asset attachments 20260819T094432Z-settings-bug-902780a352.webp --repo you/media --yes
```

GitHub renders the resulting URL as an inline animated WebP.

For MP4, MOV, and WebM input, the script creates a full-length animated WebP
preview. It uploads the preview and original video, then links the preview to
the full-quality video:

```md
[![Settings panel flickering](PREVIEW_URL)](VIDEO_URL)

[Download the full video](VIDEO_URL)
```

## Requirements

- [GitHub CLI](https://cli.github.com/) authenticated with `gh auth login`
- `zsh`
- `file`, `sed`, `mktemp`, and either `sha256sum` or `shasum`
- `ffmpeg` for video uploads
- `wl-copy`, `xclip`, or `pbcopy` if you want automatic clipboard copying

The upload still succeeds when no supported clipboard command is installed.
The script prints the Markdown so you can copy it manually.

## Set up your own repository

This repository is a GitHub template. The following commands create a public
copy named `media`, create the release used for uploads, and install the script:

```zsh
gh auth login
gh repo create media --public --template D3SOX/media --clone
cd media
gh release create attachments \
  --title "Issue attachments" \
  --notes "Media embedded in GitHub issues, pull requests, and discussions."

mkdir -p "$HOME/.local/bin"
install -m 755 bin/gh-media "$HOME/.local/bin/gh-media"
```

Make sure `~/.local/bin` is in your `PATH`. For zsh, add this to `~/.zshrc` if
needed:

```zsh
path=("$HOME/.local/bin" $path)
```

The script uses the account currently authenticated in `gh` and assumes the
repository is named `media`.

GitHub allows at most 1,000 assets in one release. When the configured release
does not have enough room for an upload, the script creates numbered releases
such as `attachments-2` and `attachments-3`. A video and its preview stay
together in the same release.

If you use a different repository name, add its full name to `~/.zshrc`:

```zsh
export GH_MEDIA_REPO="your-name/github-media"
```

You can also change the release tag. The default is `attachments`:

```zsh
export GH_MEDIA_RELEASE="uploads"
```

The repository must be public if people without access to your account need to
see embedded images.

## Usage

Pass a WebP or supported video and, optionally, useful alt text:

```zsh
gh-media animation.webp
gh-media animation.webp "The menu closes after selecting an item"
gh-media recording.mp4 "The settings panel flickers after saving"
```

Supported input formats are WebP, MP4, MOV, and WebM. Without the second
argument, the filename becomes the alt text.

For a WebP, the script:

1. Confirms that the file is a WebP.
2. Gives the upload a timestamped name with a short content hash.
3. Uploads it to the configured release.
4. Copies the inline-image Markdown to your clipboard.

For a video, the script also creates and uploads a full-length animated WebP
preview at 10 FPS with a maximum width of 800 pixels. The preview has no audio.
The copied Markdown displays the preview inline and links it to the original
video.

After every upload, the command prints the exact `gh release delete-asset`
commands needed to remove everything it created.

The original file is never changed.

## Manage uploads

Uploaded files appear under the repository's `attachments` release and any
numbered continuation releases. You can inspect the first release from the
terminal:

```zsh
repo="${GH_MEDIA_REPO:-$(gh api user --jq .login)/media}"
release="${GH_MEDIA_RELEASE:-attachments}"
gh release view "$release" --repo "$repo"
```

The upload command prints cleanup commands such as:

```zsh
gh release delete-asset attachments FILE.webp --repo your-name/media --yes
```

Video uploads print one command for the original video and another for its WebP
preview. Deleting an asset breaks every issue or comment that embeds its URL.

## Privacy and limits

Every uploaded file is public. Check recordings for tokens, email addresses,
private repository names, and personal information before uploading them.

Full-length animated WebPs can be much larger than their source videos and load
as soon as someone opens the issue. The original video keeps its full quality
and audio, but GitHub downloads it instead of displaying an inline player.

This works around the limits for media attached through the issue composer.
The script starts another release when it reaches GitHub's 1,000-assets-per-
release limit, but repository usage limits still apply. See GitHub's
documentation on
[attaching files](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/attaching-files)
and [linking to release assets](https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases).

## License

[MIT](LICENSE)
