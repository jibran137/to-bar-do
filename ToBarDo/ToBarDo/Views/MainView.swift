import SwiftUI

/// The full window opened from the menu bar.
struct MainView: View {
    @EnvironmentObject private var store: TaskStore
    @State private var newTitle = ""

    var body: some View {
        VStack(spacing: 0) {
            // Add row
            HStack(spacing: 8) {
                TextField("Add a task…", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button("Add", action: add)
                    .disabled(isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            if store.tasks.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No tasks yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Add your first task above.")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                List {
                    ForEach(store.tasks) { task in
                        TaskRow(task: task)
                            .listRowInsets(EdgeInsets())
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 360, minHeight: 420)
    }

    private var isEmpty: Bool {
        newTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func add() {
        store.add(title: newTitle)
        newTitle = ""
    }
}
