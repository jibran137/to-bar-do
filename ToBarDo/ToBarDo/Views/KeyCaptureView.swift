import AppKit
import SwiftUI

/// An invisible AppKit view that reliably captures key events inside an
/// `NSPopover`, where SwiftUI's `.onKeyPress` focus handling is flaky.
///
/// It makes itself first responder every time it's shown (the popover reuses
/// its content view across opens, so this re-grabs focus on each open) and
/// forwards key-downs to `onKeyDown`. Return `true` to swallow the event.
struct KeyCaptureView: NSViewRepresentable {
    var onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? KeyView)?.onKeyDown = onKeyDown
    }

    final class KeyView: NSView {
        var onKeyDown: ((NSEvent) -> Bool)?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            // Defer until the popover window is ready, then take focus so the
            // list responds to the keyboard immediately on open.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.window?.makeFirstResponder(self)
            }
        }

        override func keyDown(with event: NSEvent) {
            if onKeyDown?(event) == true { return }
            super.keyDown(with: event)
        }
    }
}
