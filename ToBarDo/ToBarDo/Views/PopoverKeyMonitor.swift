import SwiftUI
import AppKit

/// Watches key-down (and left-mouse-down) events for the popover window and
/// routes them to handlers for arrow-key navigation and click-to-select.
///
/// This replaces the older first-responder approach, which broke as soon as a
/// click moved focus to a button or text field. A local event monitor doesn't
/// depend on first responder, so navigation keeps working after clicks — and it
/// deliberately ignores keys while a text field is being edited (so the quick-
/// add field and inline title/link editing type normally).
///
/// The mouse-down monitor exists because SwiftUI's tap gesture has recognition
/// lag (it must wait out the double-click window before a single tap fires).
/// Handling the click in AppKit on mouse-*down* moves the highlight instantly,
/// and the event is always passed through so buttons and double-click editing
/// still work.
@MainActor
final class PopoverKeyMonitor: ObservableObject {
    /// The popover window whose events we handle (set by `WindowReader`).
    weak var window: NSWindow?
    /// Given the event and whether a text field is focused, returns true if the
    /// key was consumed for navigation. The handler decides which keys to take
    /// while editing (e.g. arrows always navigate; typing stays in the field).
    var handler: ((NSEvent, Bool) -> Bool)?
    /// Called on left mouse-down with the click point in the popover content's
    /// top-left coordinate space (matching SwiftUI's `.global`). Selection is a
    /// side effect; the event always proceeds to the view underneath.
    var mouseDownHandler: ((CGPoint) -> Void)?

    private var keyMonitor: Any?
    private var mouseMonitor: Any?

    func start() {
        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return MainActor.assumeIsolated {
                    guard let win = self.window, event.window === win else { return event }
                    // The field editor (quick-add / inline edit) is an NSText subclass.
                    let editing = win.firstResponder is NSText
                    return (self.handler?(event, editing) ?? false) ? nil : event
                }
            }
        }
        if mouseMonitor == nil {
            mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                guard let self else { return event }
                return MainActor.assumeIsolated {
                    guard let win = self.window, event.window === win else { return event }
                    // If a field is being edited and the click lands outside it,
                    // end editing so it commits (SwiftUI sees focus leave the
                    // field). The field editor is a shared NSText subclass.
                    if let editor = win.firstResponder as? NSText {
                        let fieldFrame = editor.convert(editor.bounds, to: nil)
                        if !fieldFrame.contains(event.locationInWindow) {
                            win.makeFirstResponder(nil)
                        }
                    }
                    // Map the click into SwiftUI's `.global` space — the hosting
                    // view's flipped, top-left coordinates. The popover's own
                    // contentView is its chrome (arrow + padding), so we must
                    // convert against the hosting view, not the window.
                    if let host = self.hostingView(in: win) {
                        let p = host.convert(event.locationInWindow, from: nil)
                        let point = host.isFlipped
                            ? p
                            : CGPoint(x: p.x, y: host.bounds.height - p.y)
                        self.mouseDownHandler?(point)
                    }
                    return event
                }
            }
        }
    }

    /// Finds the SwiftUI `NSHostingView` inside the window. SwiftUI's `.global`
    /// coordinate space is anchored to this view, so clicks must be converted
    /// against it (not the popover's chrome contentView).
    private func hostingView(in window: NSWindow) -> NSView? {
        func search(_ view: NSView) -> NSView? {
            if String(describing: type(of: view)).hasPrefix("NSHostingView") { return view }
            for sub in view.subviews {
                if let found = search(sub) { return found }
            }
            return nil
        }
        guard let root = window.contentView else { return nil }
        return search(root)
    }
}

/// Reports the hosting `NSWindow` back via `onResolve`, updating whenever the
/// view is attached to or removed from a window (e.g. each popover open/close).
struct WindowReader: NSViewRepresentable {
    var onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView { ReaderView(onResolve: onResolve) }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ReaderView)?.onResolve = onResolve
    }

    final class ReaderView: NSView {
        var onResolve: (NSWindow?) -> Void

        init(onResolve: @escaping (NSWindow?) -> Void) {
            self.onResolve = onResolve
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onResolve(window)
        }
    }
}
