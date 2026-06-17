# To-Bar-Do

A minimal to-do list that lives in your macOS menu bar — with a proper app window when you want it.

No accounts, no sync, no clutter. Click the menu bar icon, type a task, hit return. That's the whole learning curve.

- **Native & lightweight** — pure SwiftUI, no Electron, no dependencies. Idles around ~30–50 MB RAM and ~0% CPU.
- **Menu bar first** — add, check off, and delete tasks straight from the dropdown.
- **Full window when you need it** — one click opens a roomier view of the same list.
- **Local & private** — tasks are stored in a plain JSON file on your Mac. Nothing leaves the machine.
- **Universal Apple Silicon** — one build runs on M1, M2, M3, M4… (macOS 15 Sequoia or later).

## Requirements

- macOS 15 (Sequoia) or later
- Xcode 16 or later (to build from source)

## Build & run

Open the project in Xcode and press **Run** (⌘R):

```
open ToBarDo/ToBarDo.xcodeproj
```

Or build from the command line:

```sh
cd ToBarDo
xcodebuild -project ToBarDo.xcodeproj -scheme ToBarDo -configuration Release build
```

The app runs as a menu bar item (no Dock icon). Look for the **checklist** icon in your menu bar after launching.

> **First time using Xcode on this machine?** Run `sudo xcodebuild -runFirstLaunch` once to finish Xcode's component install, otherwise command-line builds may fail to load required plug-ins.

## Shortcuts & URL scheme

To-Bar-Do registers a `tobardo://` URL scheme so you can open it from a hotkey
(e.g. Raycast or Alfred), a script, or another app:

| URL | Action |
| --- | --- |
| `tobardo://open` | Open the menu bar dropdown (the popover) |
| `tobardo://window` | Open the full app window |

These work even when the app isn't already running — firing the URL launches it.

### Raycast hotkey

1. Open Raycast → run **Create Quicklink**.
2. **Link:** `tobardo://open` (or `tobardo://window`), **Name:** `To-Bar-Do`.
3. Save, then in Raycast Settings → **Extensions**, find the Quicklink and assign
   a **Hotkey** (e.g. ⌥Space).

## Where are my tasks stored?

```
~/Library/Application Support/To-Bar-Do/tasks.json
```

A human-readable JSON file. Delete it to start fresh; back it up to keep your list.

## Project layout

```
ToBarDo/ToBarDo/
├── ToBarDoApp.swift      # App entry (menu-bar-only; delegates to AppDelegate)
├── AppDelegate.swift     # Status item, popover, main window, tobardo:// URLs
├── Info.plist            # LSUIElement (no Dock) + URL scheme registration
├── Models/Task.swift     # The TodoTask model (Codable)
├── Store/TaskStore.swift # Loads/saves tasks to JSON
└── Views/
    ├── MenuBarView.swift # The menu bar dropdown
    ├── MainView.swift    # The full app window
    └── TaskRow.swift     # A single task row (shared)
```

## Roadmap

Kept intentionally tiny for v1. Possible future additions: reordering, due dates, launch-at-login, clear-completed, and an app icon.

## License

[MIT with the Commons Clause](LICENSE) — free to use, modify, and share
(including at work), but you may **not sell** it or offer a paid product/service
whose value comes substantially from it. This makes it *source-available* rather
than OSI "open source."
