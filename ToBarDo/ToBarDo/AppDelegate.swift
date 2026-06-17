import AppKit
import SwiftUI

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

    /// On a cold launch via the URL scheme, macOS can deliver
    /// `application(_:open:)` *before* `applicationDidFinishLaunching`, when the
    /// status item doesn't exist yet. We buffer those URLs and replay them once
    /// setup is complete.
    private var didFinishLaunching = false
    private var pendingURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Popover that hosts the SwiftUI menu bar view.
        popover.behavior = .transient
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

    func showMainWindow() {
        if mainWindow == nil {
            let hosting = NSHostingController(rootView: MainView().environmentObject(store))
            let window = NSWindow(contentViewController: hosting)
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
        default: // open / menu / tasks / nil → show the menu bar dropdown
            showPopover()
        }
    }
}
