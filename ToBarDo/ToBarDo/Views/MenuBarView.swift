import SwiftUI

/// The compact view shown when you click the menu bar icon.
struct MenuBarView: View {
    @EnvironmentObject private var store: TaskStore
    /// Called when the user taps "Open To-Bar-Do"; injected by the AppDelegate.
    var openMainWindow: () -> Void = {}
    @State private var newTitle = ""

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
                            TaskRow(task: task)
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
    }

    private var isEmpty: Bool {
        newTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func add() {
        store.add(title: newTitle)
        newTitle = ""
    }
}
