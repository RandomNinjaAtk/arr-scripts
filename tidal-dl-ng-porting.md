## What changes at a glance

`tidal-dl` (from yaronzz/Tidal-Media-Downloader) is basically:

* Interactive TUI (“Show interactive interface”) when you run `tidal-dl` with no args
* A few top-level flags, mainly:

  * `-l <url>` to download a link
  * `-g` for a simple GUI
  * `-h` for help ([GitHub][1])

`tidal-dl-ng` flips that into a modern “subcommand” CLI:

* `tidal-dl-ng <command> ...` (or the shorter alias `tdn`)
* Commands include `login`, `logout`, `cfg`, `dl`, `dl_fav`, `gui` ([PyPI][2])

So the “port” is mostly: flags and interactive menus become explicit subcommands, and settings move to a different config location/format.

---

## Setup and installation differences

### Python versions

* `tidal-dl` docs/readme just show `pip3 install tidal-dl --upgrade` and works across typical Python 3 installs. ([GitHub][1])
* `tidal-dl-ng` is stricter: it requires Python `>=3.12, <3.14` on PyPI. ([PyPI][2])

If you have automation scripts or a server, this is the first breaking change: you may need to upgrade the runtime.

### Install/upgrade

* Old:

  * `pip3 install tidal-dl --upgrade` ([GitHub][1])
* New:

  * `pip install --upgrade tidal-dl-ng`
  * GUI extra: `pip install --upgrade "tidal-dl-ng[gui]"` ([PyPI][2])

---

## CLI porting guide (command mapping)

### Downloading a URL

* Old:

  * `tidal-dl -l "<tidal url>"`
  * Or open the interactive interface (`tidal-dl`) and paste the URL. ([GitHub][1])
* New:

  * `tidal-dl-ng dl <tidal url>`
  * Or `tdn dl <tidal url>` ([PyPI][2])

### Favorites / collections

* Old:

  * Typically done via interactive UI flows (menus). ([YaornzZ][3])
* New:

  * `tidal-dl-ng dl_fav tracks|artists|albums|videos` ([PyPI][2])

### Login/logout

* Old:

  * Interactive prompt for credentials (and it persists a token file). ([YaornzZ][3])
* New:

  * `tidal-dl-ng login`
  * `tidal-dl-ng logout` ([PyPI][2])

### Configuring settings

* Old:

  * You typically run `tidal-dl`, then use the “set config file” menu (documented as option 2) to set download path, audio quality, video quality, cover saving, naming rules, etc. ([YaornzZ][3])
* New:

  * `tidal-dl-ng cfg` to list settings
  * `tidal-dl-ng cfg <key>` to print one value
  * `tidal-dl-ng cfg <key> <value>` to set it ([PyPI][2])

This is the biggest “feel” change: instead of an in-app menu, you configure via `cfg` subcommand (and/or by editing the config file directly).

---

## Configuration file differences (format + location)

### `tidal-dl` config files

Common files you’ll see:

* `~/.tidal-dl.json` (settings)
* `~/.tidal-dl.token.json` (auth token)

This layout is explicitly referenced by tooling that wraps `tidal-dl` (for persistence in containers). ([GitHub][4])
And users commonly locate it in their home directory on Windows as `.tidal-dl.json`. ([GitHub][5])

### `tidal-dl-ng` config files

`tidal-dl-ng` uses a JSON config (commonly named `config.json`) with keys like these (real-world example from an issue):

* `download_base_path`
* `quality_audio` (example: `HI_RES_LOSSLESS`)
* `quality_video` (example: `"1080"`)
* Multiple output format templates:

  * `format_album`, `format_track`, `format_playlist`, `format_mix`, `format_video`
* ffmpeg integration:

  * `path_binary_ffmpeg`
  * `extract_flac`
* Metadata/cover/lyrics toggles, concurrency, delay settings, etc. ([GitHub][6])

Location-wise, a common (and very practical) reference is Docker bind mounts mapping the config directory to:

* `/root/.config/tidal_dl_ng`
* and placing `config.json` inside it ([hub.docker.com][7])

On Windows, one issue discussion notes that a “normal” run stores the config in the user profile folder (not beside a portable executable). ([GitHub][8])

### Key takeaway

* You generally cannot “drop in” `.tidal-dl.json` and expect `tidal-dl-ng` to read it.
* Treat this as a settings migration: recreate equivalent settings in `tidal-dl-ng` via `cfg` or by editing its `config.json`.

---

## Step-by-step migration checklist

### 1) Install `tidal-dl-ng` in a clean place

* Make sure you’re on Python 3.12+ first. ([PyPI][2])
* Install:

  * `pip install --upgrade tidal-dl-ng` ([PyPI][2])

Negative bit: if you have older systems (NAS boxes, old distros, older macOS Python environments), Python 3.12 can be the blocker. Plan for that early.

### 2) Do a fresh login (don’t try to reuse old token files)

* Run: `tidal-dl-ng login` ([PyPI][2])

In practice, `tidal-dl`’s `.tidal-dl.token.json` and `tidal-dl-ng`’s credentials are not interchangeable, so expect to authenticate again.

### 3) Recreate your core settings in `tidal-dl-ng`

Start with:

* `tidal-dl-ng cfg` (to list everything) ([PyPI][2])

Then set the big ones first:

* Download directory

  * `download_base_path` (exists in real configs) ([GitHub][6])
* Audio quality

  * `quality_audio` (example value: `HI_RES_LOSSLESS`) ([GitHub][6])
* Video quality

  * `quality_video` (example: `"1080"`) ([GitHub][6])
* Naming/organization templates

  * `format_album`, `format_track`, `format_playlist`, `format_mix`, `format_video` ([GitHub][6])

Mapping tip (conceptual):

* `tidal-dl` “Download path” -> `download_base_path`
* `tidal-dl` “Audio quality (Master/HiFi/High/Normal)” -> `quality_audio` (new values differ, for example `HI_RES_LOSSLESS`) ([YaornzZ][3])
* `tidal-dl` “Video quality 1080/720/…” -> `quality_video` ([YaornzZ][3])

Negative bit: naming templates are not 1:1. `tidal-dl` has its own set of tags (documented as “Possible Tags”). `tidal-dl-ng` uses different placeholder names like `{album_artist}`, `{track_title}`, etc. ([GitHub][1])
So you’ll likely need to redesign your folder layout strings, not merely copy them.

### 4) If you relied on FLAC extraction or video processing, set ffmpeg explicitly

`tidal-dl-ng` is very explicit about ffmpeg path/config, and many problems trace back to it. You’ll see settings like:

* `path_binary_ffmpeg`
* `extract_flac` ([GitHub][6])

Negative bit: this is one of the most common failure modes. If ffmpeg is missing or the path is wrong, you’ll get partial functionality (downloads may work, but processing/extraction won’t).

### 5) Update scripts and aliases

If you had scripts like:

* `tidal-dl -l "$url"`

Port them to:

* `tdn dl "$url"` ([PyPI][2])

If you used the interactive “paste URL” workflow, the closest equivalent is still CLI, but it’s command-first now (`dl`, `dl_fav`, etc.).

---

## “Gotchas” you should expect

* Runtime requirement jump: Python 3.12+ is non-negotiable on current releases. ([PyPI][2])
* Config migration is manual: old `.tidal-dl.json` isn’t the same format, and `tidal-dl-ng` config keys/templates differ. ([GitHub][4])
* ffmpeg path issues are common, and can silently degrade your output (no extraction, no post-processing) unless you set `path_binary_ffmpeg` correctly. ([hub.docker.com][7])
* Portability: on Windows especially, “portable folder” expectations can clash with config going into the user profile directory. ([GitHub][8])

---

[1]: https://github.com/yaronzz/Tidal-Media-Downloader "GitHub - yaronzz/Tidal-Media-Downloader: Download 'TIDAL' Music On Windows/Linux/MacOs (PYTHON/C#)"
[2]: https://pypi.org/project/tidal-dl-ng/ "tidal-dl-ng · PyPI"
[3]: https://doc.yaronzz.com/post/tidal_dl_installation/ "Tidal-Media-Downloader Installation Documentation | YaornzZ"
[4]: https://github.com/rgnet1/tidal-dl?utm_source=chatgpt.com "rgnet1/tidal-dl: Web UI wrapper for ..."
[5]: https://github.com/yaronzz/Tidal-Media-Downloader/issues/1037?utm_source=chatgpt.com "[QUESTION]: Where can I find my settings for tidal-dl? #1037"
[6]: https://github.com/exislow/tidal-dl-ng/issues/387?utm_source=chatgpt.com "Config Module Not Found · Issue #387 · exislow/tidal-dl-ng"
[7]: https://hub.docker.com/r/nillivanilli0815/tidal-dl-ng-web?utm_source=chatgpt.com "nillivanilli0815/tidal-dl-ng-web - Docker Image"
[8]: https://github.com/exislow/tidal-dl-ng/issues/634?utm_source=chatgpt.com "GUI glitches · Issue #634 · exislow/tidal-dl-ng"

---

Since `tidal-dl` is still broken and `tidal-dl-ng` works, port the audio downloading script to it.

Fixes #391, #374, #289, and maybe more.

## Changes

- Mostly just find/replace `tidal-dl` calls for `tidal-dl-ng`.
- Moved TIDAL config/auth state under `/config/extended/tidal_dl_ng` via `XDG_CONFIG_HOME` and ensured directories exist.
- Mapped audio quality settings to `tidal-dl-ng` enums and set `download_base_path`/`quality_audio` through `tidal-dl-ng cfg`.
- Updated the bundled TIDAL config to `tidal-dl-ng` format and switched setup to install `tidal-dl-ng`.

## Breaks

The port does require some changes to work.

- The `Audio` service must be updated, of course.
  - This could be fixed by checking file hashes in the setup script.
- The `tidal-dl.json` file contents are changed. This could be worked around with a rename if desired. If so, the URL in the setup script will break.

## Testing

I haven't tested every possible configuration, but it seems to work with lossless/master for the quality. I've tested artists with a mix of lossless and "Max" with no issues. I also started it on my server, and it is having some upstream issues with existing files. 

When testing, I mostly just followed the existing setup directions and then copied over the new Audio service (including renaming) and the new tidal config file.

## Potential Issues

For context, since Lidarr started having issues from the MusicBrainz change, I've mostly been doing things manually. Then `tidal-dl` broke, and I tried fixing it, then gave up after realizing I was basically rewriting the thing. So, I moved to using `tidal-dl-ng`. 

However, since I started using it, there has apparently been some kind of take-down on the original repo. The PyPi package is still up and working, for now, but the GitHub repo is gone.

For reference, here's the PyPi package: https://pypi.org/project/tidal-dl-ng/
But the GitHub repo is a 404: https://github.com/exislow/tidal-dl-ng

If that's an issue, several forks exist that could be used. I haven't found one on PyPi yet, but they could just be installed from GitHub directly like this:
```bash
uv pip install --system --upgrade --no-cache-dir --break-system-packages "git+https://github.com/FunWarry/tidal-dl-ng-For-DJ.git@main"
```