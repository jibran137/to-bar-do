import SwiftUI

/// The full window opened from the menu bar.
struct MainView: View {
    @EnvironmentObject private var store: TaskStore
    @State private var newTitle = ""
    @State private var showingArchive = false
    @State private var showingOptions = false

    var body: some View {
        if showingArchive {
            ArchiveView(onBack: { showingArchive = false })
        } else {
            activeList
        }
    }

    private var activeList: some View {
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
                    .onMove { store.move(fromOffsets: $0, toOffset: $1) }
                }
                .listStyle(.inset)
            }

            Divider()

            // Footer: jump to the archive (full history) + running done tally.
            HStack {
                Button {
                    showingArchive = true
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
                .buttonStyle(.plain)
                if store.lastDeleted != nil {
                    Button {
                        store.undoLastDelete()
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("z", modifiers: .command)
                    .help("Undo delete (⌘Z)")
                }
                Spacer()
                if store.completedCount > 0 {
                    Text("\(store.completedCount) completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    showingOptions = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .help("Options")
                .popover(isPresented: $showingOptions, arrowEdge: .bottom) {
                    OptionsView().environmentObject(store)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
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
