# Paneless

A Lightshot-style screenshot tool for the macOS menu bar. Press **⇧⌘9**, drag over anything on your screen, mark it up, and copy or save it.

**Website:** [mattsheehandev.github.io/paneless](https://mattsheehandev.github.io/paneless/), with a live demo you can try in the browser.

- Drag out an area, click a window to capture just that window, or click the desktop for the whole screen
- Resize and move the selection with handles and see its size in pixels
- Pen, line, arrow, rectangle, highlighter, text, and emoji stamps, in twelve colors
- Drag any mark to move it after you place it, double-click text to edit it, and ⌘Z to undo
- Copy to the clipboard (⌘C or Return) or save as PNG or JPEG (⌘S) at full Retina resolution
- Works on every display, with an option to launch at login

## Install

**[Download Paneless.zip](https://github.com/MattSheehanDev/paneless/releases/latest/download/Paneless.zip)** (macOS 14 or later, Apple Silicon)

1. Unzip it and move **Paneless.app** to your Applications folder.
2. Open it. macOS blocks it the first time because the app isn't notarized.
3. Go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to Paneless.
4. Allow Paneless under **Privacy & Security → Screen & System Audio Recording**, then reopen it.

Or skip steps 2–3 from Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/Paneless.app && open /Applications/Paneless.app
```

All versions are on the [Releases page](https://github.com/MattSheehanDev/paneless/releases).

## Shortcuts

| Shortcut | Action |
| --- | --- |
| ⇧⌘9 | Start a capture from anywhere |
| ⌘C or Return | Copy to the clipboard and close |
| ⌘S | Save as PNG or JPEG |
| ⌘Z | Undo the last mark or move |
| Esc or right-click | Cancel the capture |
| Scroll | Change the line width or text size |
| ⌘, | Settings, like the default save folder |

## Build from source

Requires a Swift 5.10+ toolchain. The Xcode Command Line Tools are enough; full Xcode isn't required.

```bash
make install   # build, copy to ~/Applications, and launch
make run       # build build/Paneless.app and launch it
make test      # run the test suite
make clean     # remove build output
make package VERSION=1.2.0   # build build/Paneless.zip locally
make release VERSION=1.2.0   # tag v1.2.0 and push it, which triggers the release build
```

Local builds are signed with a self-signed "Paneless Local Signing" certificate that `scripts/create-signing-identity.sh` creates the first time. macOS ties the Screen Recording permission to the app's signature, so a stable certificate means you grant it once instead of after every rebuild. Set `SIGN_IDENTITY=-` to sign ad-hoc instead.

Use `make test` rather than plain `swift test`: with only the Command Line Tools installed, SwiftPM intermittently fails to load the Swift Testing macro plugin, and `scripts/test.sh` passes its path explicitly.

## Releasing

Run `make release VERSION=1.2.0` from a clean `main`. It runs the tests, then tags `v1.2.0` and pushes the tag. Pushing a `v*` tag triggers the [Release workflow](.github/workflows/release.yml) on GitHub Actions, which tests again, builds `Paneless.zip`, and publishes a GitHub release with it attached. The download link above always gets the newest release.

You can also run the workflow manually from the Actions tab. It tests and packages the app as a downloadable workflow artifact without publishing a release.

Release builds are ad-hoc signed, so after updating, macOS may ask for the Screen Recording permission again.

## Project layout

```
Sources/Paneless/        app entry point
Sources/PanelessKit/     capture, overlay, annotations, toolbars, export, settings
Tests/PanelessKitTests/  Swift Testing suite
Resources/Info.plist     bundle metadata (menu bar agent, arm64)
scripts/                 build, install, test, package, and release scripts
docs/                    GitHub Pages site
.github/workflows/       release workflow
```
