import SwiftUI

/// A single task row, shared by the menu bar dropdown and the main window.
/// Tap the circle to toggle done; the trash button appears on hover.
struct TaskRow: View {
    @EnvironmentObject private var store: TaskStore
    let task: TodoTask
    /// Highlighted by keyboard navigation (menu bar popover only).
    var isSelected: Bool = false
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                store.toggle(task)
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isDone ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)

            Text(task.title)
                .strikethrough(task.isDone)
                .foregroundStyle(task.isDone ? .secondary : .primary)
                .lineLimit(2)

            Spacer(minLength: 4)

            if hovering {
                Button {
                    store.delete(task)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete task")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}
