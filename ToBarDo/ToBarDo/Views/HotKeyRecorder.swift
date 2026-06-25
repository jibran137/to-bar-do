import SwiftUI
import AppKit
import Carbon.HIToolbox

/// A small control for viewing and rebinding the global shortcut. Shows the
/// current combo; click to record, then press a new one. Esc cancels recording;
/// a reset button restores the built-in ⌥⌘T.
struct HotKeyRecorder: View {
    @EnvironmentObject private var hotKeys: HotKeyStore
    @State private var recording = false

    var body: some View {
        HStack(spacing: 6) {
            if recording {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Color.accentColor, lineWidth: 1.5)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.accentColor.opacity(0.08)))
                    Text("Press keys…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    // Invisible first responder that captures the key combo.
                    KeyCaptureView(
                        onCapture: { code, mods in
                            hotKeys.update(keyCode: code, modifiers: mods)
                            recording = false
                        },
                        onCancel: { recording = false }
                    )
                }
                .frame(width: 110, height: 24)
            } else {
                Button {
                    recording = true
                } label: {
                    Text(hotKeys.displayString)
                        .font(.callout.monospaced())
                        .frame(minWidth: 70)
                }
                .help("Click, then press a new shortcut")

                if !hotKeys.isDefault {
                    Button {
                        hotKeys.reset()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Reset to ⌥⌘T")
                }
            }
        }
    }
}

/// Hosts an `NSView` that grabs keyboard focus and reports the first modified
/// key combo the user presses. A bare key (no modifier) is rejected with a beep,
/// since a global shortcut needs at least one modifier to be usable.
private struct KeyCaptureView: NSViewRepresentable {
    var onCapture: (UInt32, UInt32) -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.onCapture = onCapture
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: CaptureView, context: Context) {
        nsView.onCapture = onCapture
        nsView.onCancel = onCancel
        // Grab focus once the view is in a window, so keyDown reaches us.
        DispatchQueue.main.async { nsView.window?.makeFirstResponder(nsView) }
    }

    final class CaptureView: NSView {
        var onCapture: ((UInt32, UInt32) -> Void)?
        var onCancel: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }

        override func keyDown(with event: NSEvent) {
            let activeMods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Esc on its own cancels recording.
            if Int(event.keyCode) == kVK_Escape && activeMods.isEmpty {
                onCancel?()
                return
            }
            let mask = HotKeyFormatter.carbonModifiers(from: event.modifierFlags)
            guard mask != 0 else {
                NSSound.beep()   // a global shortcut needs a modifier
                return
            }
            onCapture?(UInt32(event.keyCode), mask)
        }
    }
}
