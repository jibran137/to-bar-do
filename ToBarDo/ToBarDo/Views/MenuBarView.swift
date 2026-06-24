import AppKit
import SwiftUI

/// The compact view shown when you click the menu bar icon.
///
/// Keyboard navigation: ↑/↓ move a highlight through the list, Return toggles
/// the highlighted task done, and Shift+Delete (or the forward-Delete key,
/// fn+Delete) removes it. Typing always goes to the quick-add field — to rename
/// a task, double-click it or use the right-click menu. Keys are captured by a
/// local monitor because SwiftUI's `.onKeyPress` focus is unreliable inside an
/// `NSPopover`.
struct MenuBarView: View {
    @EnvironmentObject private var store: TaskStore
    /// Called when the user taps "Open To-Bar-Do"; injected by the AppDelegate.
    var openMainWindow: () -> Void = {}
    @State private var newTitle = ""
    /// The keyboard-highlighted task, tracked by id so it survives reordering.
    @State private var selectedID: TodoTask.ID?
    /// Routes popover key events to `handleKey` without relying on first responder.
    @StateObject private var keys = PopoverKeyMonitor()

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
                            TaskRow(
                                task: task,
                                isSelected: task.id == selectedID,
                                titleLineLimit: 3,
                                onSelect: { selectedID = task.id },
                                isSelectable: true
                            )
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
                if store.lastDeleted != nil {
                    Button("Undo") { store.undoLastDelete() }
                        .help("Restore the last deleted task")
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
        // Resolve the popover window so the key monitor only reacts to it.
        .background(WindowReader { keys.window = $0 }.frame(width: 0, height: 0))
        .onAppear {
            if selectedID == nil { selectedID = store.tasks.first?.id }
            keys.handler = handleKey
            keys.start()
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

    /// Handles a popover key-down. `editing` is true when a text field (the
    /// quick-add field or an inline editor) has focus — in that case only the
    /// arrow keys are taken for navigation; everything else stays in the field
    /// so typing renames nothing and lands in the field you're in.
    /// Returns true if the key was consumed.
    private func handleKey(_ event: NSEvent, editing: Bool) -> Bool {
        guard !store.tasks.isEmpty else { return false }
        if selectedTask == nil { selectedID = store.tasks.first?.id }

        // Let ⌘/⌃ shortcuts (Quit, etc.) pass through untouched.
        let mods = event.modifierFlags
        if mods.contains(.command) || mods.contains(.control) { return false }

        switch event.keyCode {
        case 126:                       // ↑ — always navigates
            move(-1); return true
        case 125:                       // ↓ — always navigates
            move(1); return true
        case 36, 76:                    // Return / keypad Enter
            // While typing a new task, let the quick-add field submit instead.
            if editing && !isEmpty { return false }
            if let task = selectedTask { store.toggle(task) }
            return true
        case 117:                       // forward Delete (fn+Delete) → remove task
            if editing { return false }
            deleteSelected(); return true
        case 51:                        // Shift+Backspace → remove the selected task
            if editing { return false }  // plain Backspace edits the focused field
            if mods.contains(.shift) { deleteSelected(); return true }
            return false
        default:
            // Everything else (including typing) belongs to the focused field —
            // to rename a task, double-click it or use the right-click menu.
            return false
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
