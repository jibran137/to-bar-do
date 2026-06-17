import Foundation
import Combine

/// Owns the list of tasks and persists them to a small JSON file in
/// `~/Library/Application Support/To-Bar-Do/tasks.json`.
///
/// Deliberately tiny: no database, no dependencies. Every mutation writes
/// the whole list back to disk atomically — for a personal to-do list this
/// is more than fast enough and keeps the storage format human-readable.
@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [TodoTask] = []

    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("To-Bar-Do", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("tasks.json")
        load()
    }

    // MARK: - Mutations

    func add(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tasks.insert(TodoTask(title: trimmed), at: 0)
        save()
    }

    func toggle(_ task: TodoTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isDone.toggle()
        save()
    }

    func delete(_ task: TodoTask) {
        tasks.removeAll { $0.id == task.id }
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([TodoTask].self, from: data) else { return }
        tasks = decoded
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(tasks) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
