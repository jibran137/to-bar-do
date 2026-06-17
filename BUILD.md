# Building To-Bar-Do

A native macOS menu bar app. No external dependencies — just Apple's tools.

## Requirements

- **macOS 15 (Sequoia) or later**
- **Full Xcode 16+** (the Xcode app, *not* only the Command Line Tools)
- Apple Silicon Mac (the build is arm64)
- **No Apple Developer account needed** — the project uses ad-hoc signing
  ("Sign to Run Locally").

## Easiest: build & run in Xcode

```sh
open ToBarDo/ToBarDo.xcodeproj
```

Press **⌘R**. The app has no Dock icon — look for the **checklist** icon in your
menu bar.

## Command line

```sh
cd ToBarDo
xcodebuild -project ToBarDo.xcodeproj -scheme ToBarDo -configuration Release build
```

The built app lands in (relative to `ToBarDo/`):

```
build/Build/Products/Release/ToBarDo.app
```

> Run it with `open build/Build/Products/Release/ToBarDo.app`.

## First time using Xcode on a machine?

If `xcodebuild` errors with "requires Xcode" or fails to load a plug-in, the
toolchain isn't pointed at Xcode or its one-time setup hasn't run:

```sh
sudo xcode-select -s /Applications/Xcode.app
sudo xcodebuild -runFirstLaunch
```

(You can also build via `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild ...` without changing the system-wide selection.)

## Moving it to another Mac

AirDrop the **`to-bar-do` source folder** (not the built `.app`) and rebuild on
the other machine. Rebuilding produces a locally-signed app that runs without
Gatekeeper warnings. AirDropping the prebuilt `.app` triggers a quarantine
prompt ("unidentified developer") that you'd have to bypass with right-click →
Open.

## Quick checks

```sh
# Is the tobardo:// URL scheme registered to this app?
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -dump | grep -i tobardo

# Open the dropdown / window from the command line
open "tobardo://open"
open "tobardo://window"
```
