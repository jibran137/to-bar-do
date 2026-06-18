import SwiftUI

/// The compact view shown when you click the menu bar icon.
///
/// Keyboard-driven (the primary path is opening this via a Raycast hotkey):
/// ↑/↓ move a highlight through the list, Return toggles the highlighted task
/// done, typing (incl. space) appends to its title, Backspace trims the last
/// character, and Shift+Delete (or the forward-Delete key, fn+Delete) removes
/// the task.
struct MenuBarView: View {
    @EnvironmentObject private var store: TaskStore
    /// Called when the user taps "Open To-Bar-Do"; injected by the AppDelegate.
    var openMainWindow: () -> Void = {}
    @State private var newTitle = ""
    /// The keyboard-highlighted task, tracked by id so it survives reordering.
    @State private var selectedID: TodoTask.ID?
    @FocusState private var listFocused: Bool

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
        .focusable()
        .focusEffectDisabled()
        .focused($listFocused)
        .onKeyPress(action: handleKey)
        .onAppear {
            if selectedID == nil { selectedID = store.tasks.first?.id }
            // Defer so the list (not the add field) holds focus when the
            // popover opens, making ↑/↓ work immediately.
            DispatchQueue.main.async { listFocused = true }
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

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard !store.tasks.isEmpty else { return .ignored }
        if selectedTask == nil { selectedID = store.tasks.first?.id }

        switch press.key {
        case .upArrow:
            move(-1); return .handled
        case .downArrow:
            move(1); return .handled
        case .return:
            if let task = selectedTask { store.toggle(task) }
            return .handled
        case .deleteForward:           // fn+Delete → remove the whole task
            deleteSelected(); return .handled
        case .delete:
            if press.modifiers.contains(.shift) {
                deleteSelected()       // Shift+Delete → remove the whole task
            } else if let task = selectedTask, !task.title.isEmpty {
                store.updateTitle(task, to: String(task.title.dropLast())) // Backspace → trim
            }
            return .handled
        default:
            // Type-to-append: printable characters (incl. space) extend the
            // highlighted task. Ignore anything carrying ⌘/⌃ so shortcuts work.
            guard press.modifiers.isDisjoint(with: [.command, .control]) else {
                return .ignored
            }
            let chars = press.characters
            guard !chars.isEmpty,
                  chars.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7F }) else {
                return .ignored
            }
            if let task = selectedTask {
                store.updateTitle(task, to: task.title + chars)
            }
            return .handled
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
