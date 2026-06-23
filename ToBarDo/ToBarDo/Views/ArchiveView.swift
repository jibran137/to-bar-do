import SwiftUI
import AppKit

/// The history of every task ever added, reached from a button in the main
/// window. Tasks land here when added and stay even after they're removed from
/// the active list — so the count of completed items only grows.
///
/// This is the one place tasks are *permanently* deleted. Each permanent delete
/// asks for confirmation first, with a "Don't ask me again" option that's
/// remembered across launches.
struct ArchiveView: View {
    @EnvironmentObject private var store: TaskStore
    /// Returns to the active list. Injected by `MainView`.
    var onBack: () -> Void = {}

    /// Persisted preference: when true, permanent deletes skip the confirmation.
    private static let skipConfirmKey = "skipArchiveDeleteConfirm"

    var body: some View {
        VStack(spacing: 0) {
            // Header with a back button.
            HStack {
                Button(action: onBack) {
                    Label("List", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                Spacer()
                Text("Archive")
                    .font(.headline)
                Spacer()
                Button(action: confirmClear) {
                    Text("Clear")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(!hasClearable)
                .help("Remove completed/removed tasks from the archive")
            }
            .padding()

            Divider()

            // Running tally.
            HStack {
                Text("\(store.completedCount) of \(store.archive.count) completed")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            if store.archive.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Nothing archived yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Every task you add is kept here, even after you remove it from your list.")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                Spacer()
            } else {
                List {
                    ForEach(store.archive) { task in
                        TaskRow(task: task, onDelete: confirmDelete, showsCompletion: true)
                            .listRowInsets(EdgeInsets())
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 360, minHeight: 420)
    }

    /// Permanently removes a task, asking first unless the user has opted out.
    private func confirmDelete(_ task: TodoTask) {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Self.skipConfirmKey) {
            store.purge(task)
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Permanently delete “\(task.title)”?"
        alert.informativeText = "This removes it from the archive for good. This can’t be undone."
        alert.addButton(withTitle: "Delete")   // .alertFirstButtonReturn
        alert.addButton(withTitle: "Cancel")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don’t ask me again"

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if alert.suppressionButton?.state == .on {
            defaults.set(true, forKey: Self.skipConfirmKey)
        }
        store.purge(task)
    }

    /// Whether there's any purely-historical item to clear (i.e. anything in the
    /// archive that's no longer on the active list).
    private var hasClearable: Bool {
        let activeIDs = Set(store.tasks.map(\.id))
        return store.archive.contains { !activeIDs.contains($0.id) }
    }

    /// Clears the archive of completed/removed items, after confirming.
    private func confirmClear() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Clear the archive?"
        alert.informativeText = "This permanently removes every completed or deleted task from the archive. Tasks still on your list stay. This can’t be undone."
        alert.addButton(withTitle: "Clear")   // .alertFirstButtonReturn
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        store.clearArchive()
    }
}
