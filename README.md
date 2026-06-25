# To-Bar-Do

A minimal to-do list that lives in your macOS menu bar — with a proper app window when you want it.

No accounts, no sync, no clutter. Click the menu bar icon, type a task, hit return. That's the whole learning curve.

![To-Bar-Do demo](docs/demo.gif)

- **Native & lightweight** — pure SwiftUI, no Electron, no dependencies. Idles around ~30–50 MB RAM and ~0% CPU.
- **Menu bar first** — add, check off, reorder, and delete tasks straight from the dropdown.
- **Global hotkey** — press **⌥⌘T** to open the dropdown from any app. No Raycast or extra setup required.
- **Full window when you need it** — one click opens a roomier view, drag to reorder, double-click to edit.
- **Archive & history** — completed tasks move to an archive (kept until you delete them there), with a running "completed" count. Optionally auto-archive a task a set time after you finish it.
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

## Global hotkey

Press **⌥⌘T** anywhere to toggle the menu bar dropdown. It's built in (via
Carbon's `RegisterEventHotKey`), so it needs **no Accessibility permission and
no third-party launcher** — handy when a crowded menu bar tucks the icon under
the notch. The shortcut is shown in the app's **Options** popover. It's
currently fixed at ⌥⌘T.

## Shortcuts & URL scheme

To-Bar-Do also registers a `tobardo://` URL scheme so you can drive it from a
script, another app, or a custom hotkey (e.g. Raycast or Alfred):

| URL | Action |
| --- | --- |
| `tobardo://open` | Open the menu bar dropdown (the popover) |
| `tobardo://window` | Open the full app window |
| `tobardo://add?title=<text>` | Append a task silently (no window shown) |

These work even when the app isn't already running — firing the URL launches it.

### Add a task from the command line (or Claude)

Because `tobardo://add` is registered system-wide, you can add tasks from any
script, terminal, or AI assistant — no need to open the app first:

```sh
open "tobardo://add?title=Buy%20milk"
```

The `title` must be percent-encoded. The repo ships a helper that handles the
encoding for you (and reads from stdin if you give it no arguments):

```sh
scripts/tobardo-add "Call the dentist tomorrow"
echo "Reply to Sam" | scripts/tobardo-add
```

The task is appended silently and persisted to `tasks.json`; the app
cold-launches if it isn't running. This makes it easy to wire up to **Claude
Code** or any agent — e.g. add a note to your global instructions so that
whenever you say "remind me to…", Claude runs `open "tobardo://add?title=…"`
and the task lands in your list.

### Raycast hotkey

1. Open Raycast → run **Create Quicklink**.
2. **Link:** `tobardo://open` (or `tobardo://window`), **Name:** `To-Bar-Do`.
3. Save, then in Raycast Settings → **Extensions**, find the Quicklink and assign
   a **Hotkey** (e.g. ⌥Space).

## Where are my tasks stored?

```
~/Library/Application Support/To-Bar-Do/tasks.json     # your active list
~/Library/Application Support/To-Bar-Do/archive.json   # full history (the archive)
```

Two human-readable JSON files. `tasks.json` is the list you see; `archive.json`
keeps every task ever added so the archive and "completed" count survive removing
a task from the list. Delete them to start fresh; back them up to keep your data.

## Project layout

```
ToBarDo/ToBarDo/
├── ToBarDoApp.swift           # App entry (menu-bar-only; delegates to AppDelegate)
├── AppDelegate.swift          # Status item, popover, main window, tobardo:// URLs, hotkey
├── HotKeyManager.swift        # Carbon global hotkey (⌥⌘T)
├── Info.plist                 # LSUIElement (no Dock) + URL scheme registration
├── Models/Task.swift          # The TodoTask model (Codable)
├── Store/TaskStore.swift      # Active list + archive; load/save; auto-archive logic
└── Views/
    ├── MenuBarView.swift      # The menu bar dropdown
    ├── MainView.swift         # The full app window (reorder + Archive/Options)
    ├── ArchiveView.swift      # The archive/history view
    ├── OptionsView.swift      # Options popover (auto-archive delay, hotkey)
    ├── PopoverKeyMonitor.swift# Keyboard handling for the popover
    └── TaskRow.swift          # A single task row (shared)
```

## Roadmap

Kept intentionally tiny. Done since v1: app icon, built-in global hotkey,
drag-to-reorder, archive/history, and auto-archive of completed tasks. Possible
future additions: a configurable hotkey recorder, launch-at-login, due dates,
and iCloud sync.

## License

[MIT with the Commons Clause](LICENSE) — free to use, modify, and share
(including at work), but you may **not sell** it or offer a paid product/service
whose value comes substantially from it. This makes it *source-available* rather
than OSI "open source."
