import AppKit
import SwiftUI
import Combine
import Carbon.HIToolbox

/// Owns the menu bar status item, its popover, and the main window.
///
/// We manage these in AppKit (rather than SwiftUI's `MenuBarExtra`) so the
/// dropdown can be opened *programmatically* — e.g. from a Raycast hotkey via
/// the `tobardo://` URL scheme — which `MenuBarExtra` does not allow.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = TaskStore()

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var mainWindow: NSWindow?

    /// Built-in global shortcut to toggle the popover from anywhere, so the app
    /// doesn't depend on Raycast/Alfred. See `HotKeyManager`.
    private let hotKey = HotKeyManager()
    /// The user's chosen shortcut (default ⌥⌘T). Injected into the window's
    /// SwiftUI environment so Options can rebind it; we re-register on change.
    let hotKeyStore = HotKeyStore()
    private var cancellables = Set<AnyCancellable>()

    /// On a cold launch via the URL scheme, macOS can deliver
    /// `application(_:open:)` *before* `applicationDidFinishLaunching`, when the
    /// status item doesn't exist yet. We buffer those URLs and replay them once
    /// setup is complete.
    private var didFinishLaunching = false
    private var pendingURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Popover that hosts the SwiftUI menu bar view.
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(openMainWindow: { [weak self] in self?.showMainWindow() })
                .environmentObject(store)
        )

        // The menu bar item itself.
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "To-Bar-Do")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        statusItem = item

        // Global shortcut toggles the popover from any app. Registered from the
        // user's stored combo, and re-registered whenever they rebind it.
        hotKey.onPress = { [weak self] in self?.togglePopover(nil) }
        registerHotKey()
        hotKeyStore.$keyCode.combineLatest(hotKeyStore.$modifiers)
            .dropFirst()   // skip the initial value we just registered
            .sink { [weak self] code, mods in
                self?.hotKey.register(keyCode: code, modifiers: mods)
            }
            .store(in: &cancellables)

        didFinishLaunching = true
        let buffered = pendingURLs
        pendingURLs = []
        buffered.forEach(handle)
    }

    // MARK: - Popover

    @objc func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = statusItem?.button, !popover.isShown else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    // MARK: - Main window

    /// Registers the current shortcut from `hotKeyStore`.
    private func registerHotKey() {
        hotKey.register(keyCode: hotKeyStore.keyCode, modifiers: hotKeyStore.modifiers)
    }

    func showMainWindow() {
        if mainWindow == nil {
            let hosting = NSHostingController(
                rootView: MainView()
                    .environmentObject(store)
                    .environmentObject(hotKeyStore)
            )
            let window = EscClosableWindow(contentViewController: hosting)
            window.title = "To-Bar-Do"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 380, height: 480))
            window.center()
            window.isReleasedWhenClosed = false
            mainWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - URL scheme (tobardo://)

    func application(_ application: NSApplication, open urls: [URL]) {
        guard didFinishLaunching else {
            pendingURLs.append(contentsOf: urls)
            return
        }
        urls.forEach(handle)
    }

    private func handle(_ url: URL) {
        switch url.host?.lowercased() {
        case "window":
            showMainWindow()
        case "add":
            addTask(from: url)
        default: // open / menu / tasks / nil → show the menu bar dropdown
            showPopover()
        }
    }

    /// `tobardo://add?title=…` (or `text=`) — append a task without showing any
    /// UI, so it works cleanly from a shell: `open "tobardo://add?title=Buy%20milk"`.
    private func addTask(from url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let title = components?.queryItems?
            .first { $0.name == "title" || $0.name == "text" }?.value ?? ""
        store.add(title: title) // store.add trims and ignores empty input
    }
}

// MARK: - Popover lifecycle

extension AppDelegate: NSPopoverDelegate {
    /// The popover reuses one persistent SwiftUI tree, so per-row edit/selection
    /// state would otherwise survive a close. Broadcast a reset before each show
    /// so the dropdown opens clean (no stuck inline-edit cursor, no stale highlight).
    func popoverWillShow(_ notification: Notification) {
        NotificationCenter.default.post(name: .toBarDoPopoverWillShow, object: nil)
    }
}

extension Notification.Name {
    /// Posted just before the menu bar popover is shown.
    static let toBarDoPopoverWillShow = Notification.Name("ToBarDoPopoverWillShow")
}

/// Main window that closes on the Esc key. AppKit routes Esc to
/// `cancelOperation(_:)` up the responder chain; the window is the last link,
/// so overriding it here gives us Esc-to-close without touching the SwiftUI view.
private final class EscClosableWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        close()
    }
}
