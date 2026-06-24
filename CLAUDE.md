# To-Bar-Do — project context for AI agents

A minimal, native macOS **menu bar to-do app**. The goal is a tiny, dependency-
free, low-learning-curve utility that the owner uses on an M4 Air and M1 Air and
shares on GitHub. This file is the handoff: what exists, why it's built this way,
and what's left.

## Owner & intent

- Owner / licensor: **Muhammad Jibran Mughal**.
- Priorities, in order: **minimalism**, **low system footprint**, **no setup
  friction**. Resist adding features or dependencies that work against these.
- Target machines: Apple Silicon (M1, M4). Build is **arm64**, **macOS 15+**.

## Tech & key decisions

- **SwiftUI + AppKit**, no third-party dependencies. Pure Apple frameworks.
- **Menu bar built in AppKit** (`NSStatusItem` + `NSPopover`), *not* SwiftUI's
  `MenuBarExtra`. Reason: `MenuBarExtra` cannot be opened programmatically, and
  we need a hotkey / URL to open the dropdown. See `AppDelegate.swift`.
- **Main window** is also AppKit-managed (`NSWindow` + `NSHostingController` in
  `AppDelegate.showMainWindow()`), so the app never auto-shows a window at
  launch. `ToBarDoApp.swift` only declares a `Settings` scene as a placeholder
  (a SwiftUI `App` requires at least one `Scene`).
- **Menu-bar-only**: `LSUIElement = true` in `Info.plist` → no Dock icon, not in
  ⌘-Tab. This was an explicit owner choice.
- **Storage**: plain JSON at `~/Library/Application Support/To-Bar-Do/tasks.json`
  via `TaskStore` (an `@MainActor ObservableObject`). JSON was chosen over
  SwiftData deliberately — fewer moving parts, transparent, easy to read. Every
  mutation rewrites the whole file atomically (fine for a personal list).
- **URL scheme** `tobardo://` (registered in `Info.plist`):
  - `tobardo://open` (or `menu` / `tasks`) → show the menu bar popover
  - `tobardo://window` → open the main window
  Handled in `AppDelegate.application(_:open:)`.
- **Code signing**: ad-hoc (`CODE_SIGN_IDENTITY = "-"`, Manual style, no team) so
  anyone can build & run without an Apple Developer account.
- **Xcode project**: uses file-system-synchronized groups (objectVersion 77), so
  source files are auto-included by referencing the folder — no per-file entries
  in `project.pbxproj`. `Info.plist` is excluded from the Copy Resources phase
  via a `PBXFileSystemSynchronizedBuildFileExceptionSet`.
- **Model type is named `TodoTask`**, not `Task`, to avoid colliding with Swift
  Concurrency's `Task`.

## Layout

```
ToBarDo/ToBarDo/
├── ToBarDoApp.swift          # @main App; Settings placeholder + AppDelegate adaptor
├── AppDelegate.swift         # status item, popover, main window, tobardo:// URLs, hotkey
├── HotKeyManager.swift       # Carbon RegisterEventHotKey wrapper (global ⌥⌘T)
├── Info.plist                # LSUIElement + CFBundleURLTypes (tobardo)
├── Models/Task.swift         # TodoTask (Codable, Identifiable; isDone, completedAt, url)
├── Store/TaskStore.swift     # tasks + archive JSON; add/toggle/delete/purge/move/auto-archive
└── Views/
    ├── MenuBarView.swift     # dropdown UI (takes an openMainWindow closure)
    ├── MainView.swift        # full window UI (reorder, Archive + Options buttons)
    ├── ArchiveView.swift     # archive/history view; permanent delete + clear
    ├── OptionsView.swift     # options popover: auto-archive delay, hotkey display
    ├── PopoverKeyMonitor.swift # popover keyboard event monitor
    └── TaskRow.swift         # shared row: toggle, double-click-to-edit, context menu
```

## Build / run

See `BUILD.md`. TL;DR: needs full Xcode 16+ on macOS 15+; `open
ToBarDo/ToBarDo.xcodeproj` then ⌘R, or `xcodebuild ... build`. From a shell
where `xcode-select` points at Command Line Tools, prefix builds with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

## Status (done)

- Quick-add, tap-to-complete, hover/menu-to-delete; double-click a row to edit;
  drag-to-reorder in the main window; empty states.
- Menu bar dropdown + full window, sharing one `TaskStore`.
- **Archive**: a second JSON file (`archive.json`) keeps every task ever added.
  Normal delete is *soft* (drops from the active list, kept in the archive);
  the archive view permanently `purge`s (behind a confirm with "don't ask
  again") and can `clearArchive` the purely-historical items. Shows a
  "completed" tally and a "Completed N ago" caption per row.
- **Auto-archive**: completed tasks linger on the active list for a configurable
  delay (Never / Immediately / 1h / 1d / 3d / 1w / custom days), then drop to the
  archive. Driven by `TodoTask.completedAt`; settings persist in `UserDefaults`
  (`autoArchiveDelay`, `autoArchiveCustomDays`). Swept on launch, on toggle, on
  setting change, and via a 60s timer.
- **Global hotkey** ⌥⌘T (Carbon `RegisterEventHotKey`, no Accessibility perm) to
  toggle the popover. Fixed for now; shown in Options.
- **App icon**: generated into `AppIcon.appiconset` (checklist glyph on a blue
  gradient tile) by `scripts/generate-appicon.swift` — rerun it to restyle.
- `tobardo://` URL scheme (`open`/`window`/`add`); verified cold/warm launch.
- Git repo on `main`, pushed to GitHub remote `origin`
  (`github.com/jibran137/to-bar-do`).
- License: **MIT + Commons Clause** (free to use/modify/share, no resale).

## Bugs already fixed (don't reintroduce)

- **Cold-launch crash**: on launch via URL, macOS delivers
  `application(_:open:)` *before* `applicationDidFinishLaunching`, so the status
  item was nil and `showPopover()` force-unwrapped it. Fixed by buffering URLs in
  `pendingURLs` and replaying them after setup (`didFinishLaunching` flag).
- `TaskStore` is `@MainActor`; `AppDelegate` must be `@MainActor` too or its
  `let store = TaskStore()` initializer won't compile.
- `Info.plist` was being copied into Resources by the synchronized group — fixed
  with a membership exception.

## Known limitations / gotchas

- **Notch**: on notched Macs with a crowded menu bar, macOS can tuck the status
  icon under the notch, making it hard to click. The ⌥⌘T hotkey / URL scheme
  sidesteps this. Apps cannot control their menu bar slot.
- **No sync**: each Mac has its own `tasks.json` / `archive.json`. No sync
  between machines.
- **Hotkey is fixed at ⌥⌘T** — not yet user-configurable (no recorder UI).
- **`@Published` + `didSet` recursion**: never reassign a `@Published` property
  inside its own `didSet` (e.g. clamping) — the wrapper makes it a computed
  accessor, so the assignment re-fires `didSet` and stack-overflows. Clamp at the
  read site / input bounds instead. (Crashed `customDays`; now fixed.)

## Roadmap / what we could do next

Roughly ordered, easy → involved. Keep the minimalism bar high.

*Done since v1:* app icon, built-in global hotkey (⌥⌘T), drag-to-reorder,
archive/history, auto-archive of completed tasks.

1. **Configurable hotkey recorder** — let the user rebind ⌥⌘T. Needs a small
   key-capture field (a focused `NSView`/`NSTextField` subclass reading
   `keyDown`), persist keyCode+modifiers, re-`register` on the existing
   `HotKeyManager`. No third-party dep required.
2. **Notch fallback** — if the status-item button is hidden, have `tobardo://open`
   fall back to the window or a centered panel. (Offered to owner, not yet done.)
3. **Launch at login** — `SMAppService.mainApp` (macOS 13+); add to Options.
4. **Due dates / priorities** — explicitly deferred; add only on demand.
5. **iCloud / cross-Mac sync** — biggest change; would alter the storage layer
   (and now the archive file too).
6. **Distribution** — GitHub push + Releases; for a download that runs without
   Gatekeeper warnings, notarize a signed build (requires Apple Developer
   account, ~$99/yr). Building from source needs none of this.
7. **Universal binary** — only if Intel Mac support is ever wanted (currently
   arm64-only by choice).

## Conventions

- Commits: **Conventional Commits** (`feat:`, `fix:`, `docs:`, …).
- Keep dependencies at **zero** unless there's a strong reason.
