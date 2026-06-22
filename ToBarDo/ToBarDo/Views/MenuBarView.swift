import AppKit
import SwiftUI

/// The compact view shown when you click the menu bar icon.
///
/// Keyboard-driven (the primary path is opening this via a Raycast hotkey):
/// ↑/↓ move a highlight through the list, Return toggles the highlighted task
/// done, typing (incl. space) appends to its title, Backspace trims the last
/// character, and Shift+Delete (or the forward-Delete key, fn+Delete) removes
/// the task. Keys are captured by `KeyCaptureView` because SwiftUI's
/// `.onKeyPress` focus is unreliable inside an `NSPopover`.
struct MenuBarView: View {
    @EnvironmentObject private var store: TaskStore
    /// Called when the user taps "Open To-Bar-Do"; injected by the AppDelegate.
    var openMainWindow: () -> Void = {}
    @State private var newTitle = ""
    /// The keyboard-highlighted task, tracked by id so it survives reordering.
    @State private var selectedID: TodoTask.ID?

    var body: some View {
        VStack(spacing: 0) {
            // Quick add
            HStack(spacing: 6) {
                TextField("Add a task…", text: $newTitle)
                    .textFieldStyle(.plain)
                    .onSubmit(add)
                Button(action: add) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .disabled(isEmpty)
            }
            .padding(10)

            Divider()

            // Task list
            if store.tasks.isEmpty {
                Text("No tasks — add one above")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.tasks) { task in
                            TaskRow(task: task, isSelected: task.id == selectedID)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 280)
            }

            Divider()

            // Footer
            HStack {
                Button("Open To-Bar-Do") {
                    openMainWindow()
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .buttonStyle(.plain)
            .font(.callout)
            .padding(10)
        }
        .frame(width: 300)
        // Invisible key catcher; grabs first responder whenever the popover opens.
        .background(KeyCaptureView(onKeyDown: handleKey).frame(width: 0, height: 0))
        .onAppear {
            if selectedID == nil { selectedID = store.tasks.first?.id }
        }
    }

    private var isEmpty: Bool {
        newTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func add() {
        store.add(title: newTitle)
        newTitle = ""
    }

    // MARK: - Keyboard navigation

    private var selectedTask: TodoTask? {
        guard let id = selectedID else { return nil }
        return store.tasks.first { $0.id == id }
    }

    /// Handles a raw key-down from `KeyCaptureView`. Returns true if consumed.
    private func handleKey(_ event: NSEvent) -> Bool {
        guard !store.tasks.isEmpty else { return false }
        if selectedTask == nil { selectedID = store.tasks.first?.id }

        // Let ⌘/⌃ shortcuts (Quit, etc.) pass through untouched.
        let mods = event.modifierFlags
        if mods.contains(.command) || mods.contains(.control) { return false }

        switch event.keyCode {
        case 126:                       // ↑
            move(-1); return true
        case 125:                       // ↓
            move(1); return true
        case 36, 76:                    // Return / keypad Enter
            if let task = selectedTask { store.toggle(task) }
            return true
        case 117:                       // forward Delete (fn+Delete) → remove task
            deleteSelected(); return true
        case 51:                        // Backspace
            if mods.contains(.shift) {
                deleteSelected()        // Shift+Delete → remove task
            } else if let task = selectedTask, !task.title.isEmpty {
                store.updateTitle(task, to: String(task.title.dropLast())) // trim
            }
            return true
        default:
            // Type-to-append: printable characters (incl. space) extend the title.
            guard let chars = event.characters, !chars.isEmpty,
                  chars.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7F }) else {
                return false
            }
            if let task = selectedTask { store.updateTitle(task, to: task.title + chars) }
            return true
        }
    }

    private func move(_ delta: Int) {
        guard let id = selectedID,
              let idx = store.tasks.firstIndex(where: { $0.id == id }) else {
            selectedID = store.tasks.first?.id
            return
        }
        let next = min(max(idx + delta, 0), store.tasks.count - 1)
        selectedID = store.tasks[next].id
    }

    private func deleteSelected() {
        guard let id = selectedID,
              let idx = store.tasks.firstIndex(where: { $0.id == id }) else { return }
        store.delete(store.tasks[idx])
        // Keep a neighbouring task highlighted so navigation continues.
        selectedID = store.tasks.isEmpty
            ? nil
            : store.tasks[min(idx, store.tasks.count - 1)].id
    }
}
