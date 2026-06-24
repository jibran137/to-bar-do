import SwiftUI
import AppKit

/// A single task row, shared by the menu bar dropdown and the main window.
/// Tap the circle to toggle done; tap the link icon (when a task has a URL) to
/// open it; right-click (Control-click) for edit / link / delete actions.
struct TaskRow: View {
    @EnvironmentObject private var store: TaskStore
    let task: TodoTask
    /// Highlighted by keyboard navigation (menu bar popover only).
    var isSelected: Bool = false
    /// Max lines for the title; `nil` wraps fully (used by the main window).
    /// The compact popover caps this and relies on the hover tooltip for the rest.
    var titleLineLimit: Int? = nil
    /// Called when the row is clicked, so the popover can move its keyboard
    /// highlight to the clicked task. No-op in the main window.
    var onSelect: () -> Void = {}
    /// Whether a single tap selects this row. Only the popover wants this; the
    /// main window leaves it off so the tap gesture doesn't swallow List's
    /// drag-to-reorder.
    var isSelectable: Bool = false
    /// Overrides the destructive "Delete" action. Defaults to a soft delete
    /// (removes from the active list, keeps the archive copy). The archive view
    /// passes a permanent-delete handler that confirms first.
    var onDelete: ((TodoTask) -> Void)? = nil
    /// Shows a "Completed …" caption under the title (used by the archive).
    var showsCompletion: Bool = false

    @State private var editingField: EditField?
    @State private var draft = ""
    @FocusState private var editFocused: Bool

    private enum EditField { case title, url }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                onSelect()
                store.toggle(task)
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isDone ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)

            if let field = editingField {
                TextField(field == .url ? "https://…" : "Task", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($editFocused)
                    .onSubmit(commitEdit)
                    .onExitCommand(perform: cancelEdit)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(task.title)
                        .strikethrough(task.isDone)
                        .foregroundStyle(task.isDone ? .secondary : .primary)
                        .lineLimit(titleLineLimit)
                        .help(task.title)
                    if showsCompletion, let when = completedCaption {
                        Text(when)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 4)

            if editingField == nil, let link = openableURL {
                Button {
                    NSWorkspace.shared.open(link)
                } label: {
                    Image(systemName: "link")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(task.url ?? "Open link")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        .contentShape(Rectangle())
        // Double-click anywhere on the row to edit its title inline.
        .onTapGesture(count: 2) {
            if editingField == nil { startEdit(.title) }
        }
        // Fires alongside the row's buttons without the recognition lag of a
        // plain .onTapGesture, so selection lands as soon as you click. Popover
        // only — in the main window it would intercept List's reorder drag.
        .simultaneousGesture(TapGesture().onEnded { onSelect() }, including: isSelectable ? .all : .subviews)
        .contextMenu {
            Button("Edit title…") { startEdit(.title) }
            if task.url == nil {
                Button("Add link…") { startEdit(.url) }
            } else {
                Button("Edit link…") { startEdit(.url) }
                Button("Remove link") { store.updateURL(task, to: nil) }
            }
            Divider()
            Button("Delete", role: .destructive) { (onDelete ?? { store.delete($0) })(task) }
        }
    }

    /// "Completed 3 days ago" for a done task, or "Not completed" otherwise.
    private var completedCaption: String? {
        guard task.isDone else { return "Not completed" }
        guard let date = task.completedAt else { return "Completed" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Completed " + formatter.localizedString(for: date, relativeTo: Date())
    }

    /// The task's link as an openable URL, defaulting a missing scheme to https.
    private var openableURL: URL? {
        guard let raw = task.url?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        if let url = URL(string: raw), url.scheme != nil { return url }
        return URL(string: "https://" + raw)
    }

    // MARK: - Inline editing

    private func startEdit(_ field: EditField) {
        draft = field == .url ? (task.url ?? "") : task.title
        editingField = field
        DispatchQueue.main.async { editFocused = true }
    }

    private func commitEdit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        switch editingField {
        case .title:
            if !trimmed.isEmpty { store.updateTitle(task, to: trimmed) }
        case .url:
            store.updateURL(task, to: trimmed)   // blank clears the link
        case nil:
            break
        }
        editingField = nil
    }

    private func cancelEdit() {
        editingField = nil
    }
}
