import SwiftUI
import AppKit

/// Watches key-down events for the popover window and routes them to a handler
/// for arrow-key navigation / type-to-append.
///
/// This replaces the older first-responder approach, which broke as soon as a
/// click moved focus to a button or text field. A local event monitor doesn't
/// depend on first responder, so navigation keeps working after clicks — and it
/// deliberately ignores keys while a text field is being edited (so the quick-
/// add field and inline title/link editing type normally).
@MainActor
final class PopoverKeyMonitor: ObservableObject {
    /// The popover window whose key events we handle (set by `WindowReader`).
    weak var window: NSWindow?
    /// Given the event and whether a text field is focused, returns true if the
    /// key was consumed for navigation. The handler decides which keys to take
    /// while editing (e.g. arrows always navigate; typing stays in the field).
    var handler: ((NSEvent, Bool) -> Bool)?

    private var monitor: Any?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return MainActor.assumeIsolated {
                guard let win = self.window, event.window === win else { return event }
                // The field editor (quick-add / inline edit) is an NSText subclass.
                let editing = win.firstResponder is NSText
                return (self.handler?(event, editing) ?? false) ? nil : event
            }
        }
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
