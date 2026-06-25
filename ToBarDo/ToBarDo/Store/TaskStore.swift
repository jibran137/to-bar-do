import Foundation
import Combine

/// How long a completed task stays on the active list before it's automatically
/// moved to the archive. The raw value is what we persist in `UserDefaults`.
enum AutoArchiveDelay: String, CaseIterable, Identifiable {
    case never
    case immediately
    case afterHour
    case afterDay
    case afterThreeDays
    case afterWeek
    case custom

    var id: String { rawValue }

    /// Fixed delay (seconds) for the preset cases. `nil` for `.never` (don't
    /// archive) and for `.custom`, where the store supplies the day count.
    var interval: TimeInterval? {
        switch self {
        case .never, .custom: return nil
        case .immediately:    return 0
        case .afterHour:      return 3600
        case .afterDay:       return 86_400
        case .afterThreeDays: return 3 * 86_400
        case .afterWeek:      return 7 * 86_400
        }
    }

    var label: String {
        switch self {
        case .never:          return "Never"
        case .immediately:    return "Immediately"
        case .afterHour:      return "After 1 hour"
        case .afterDay:       return "After 1 day"
        case .afterThreeDays: return "After 3 days"
        case .afterWeek:      return "After 1 week"
        case .custom:         return "Custom…"
        }
    }
}

/// Owns the list of tasks and persists them to small JSON files in
/// `~/Library/Application Support/To-Bar-Do/`.
///
/// Two files, both human-readable:
/// - `tasks.json` — the active list the app loads and shows.
/// - `archive.json` — every task ever added, kept as a running history so you
///   can see how many you've completed. Removing a task from the active list
///   (the menu bar or the main window) leaves its archive copy intact; the
///   archive is only pruned by an explicit permanent delete in the archive view.
///
/// Deliberately tiny: no database, no dependencies. Every mutation writes the
/// whole list(s) back to disk atomically — for a personal to-do list this is
/// more than fast enough and keeps the storage format transparent.
@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [TodoTask] = []
    /// The full history of every task ever added. A superset of `tasks`:
    /// active tasks live in both lists (sharing an `id`), soft-deleted ones
    /// remain here only.
    @Published private(set) var archive: [TodoTask] = []

    /// The most recent soft delete, kept so it can be undone. Holds the task and
    /// the position it was removed from; `nil` when there's nothing to undo.
    @Published private(set) var lastDeleted: DeletedTask?

    /// A soft-deleted task plus where it sat in the active list, for undo.
    struct DeletedTask: Equatable {
        let task: TodoTask
        let index: Int
    }

    /// How long completed tasks linger on the active list before auto-archiving.
    /// Persisted to `UserDefaults`; changing it re-runs the sweep immediately.
    @Published var autoArchiveDelay: AutoArchiveDelay {
        didSet {
            defaults.set(autoArchiveDelay.rawValue, forKey: Self.delayKey)
            archiveCompletedIfDue()
        }
    }

    /// Number of days used when `autoArchiveDelay == .custom`. The UI keeps this
    /// in 1...365; never reassign it from this `didSet` (that re-triggers the
    /// observer through the `@Published` wrapper and recurses).
    @Published var customDays: Int {
        didSet {
            defaults.set(customDays, forKey: Self.customDaysKey)
            archiveCompletedIfDue()
        }
    }

    private static let delayKey = "autoArchiveDelay"
    private static let customDaysKey = "autoArchiveCustomDays"

    /// Where settings persist. Injectable so tests can use a throwaway suite
    /// instead of clobbering the user's real defaults.
    private let defaults: UserDefaults

    /// The delay actually in effect: the preset interval, or the custom day
    /// count converted to seconds.
    var effectiveInterval: TimeInterval? {
        if autoArchiveDelay == .custom { return Double(max(1, customDays)) * 86_400 }
        return autoArchiveDelay.interval
    }

    private let fileURL: URL
    private let archiveURL: URL
    /// Serial queue for disk writes, so saving never blocks the UI. Mutations
    /// update the in-memory lists on the main thread (UI reacts instantly) and
    /// hand the snapshot here to be encoded and written; ordering is preserved.
    private let ioQueue = DispatchQueue(label: "com.tobardo.taskstore.io", qos: .utility)
    /// Periodically re-checks whether any completed task is now due for
    /// archiving, so it happens even while the app sits idle.
    private var sweepTimer: Timer?

    /// - Parameters:
    ///   - directory: where `tasks.json` / `archive.json` live. Defaults to the
    ///     app-support folder; tests pass a temp dir so they never touch real data.
    ///   - defaults: settings store. Defaults to `.standard`; tests pass a suite.
    init(directory: URL? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let fm = FileManager.default
        let dir = directory ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("To-Bar-Do", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("tasks.json")
        self.archiveURL = dir.appendingPathComponent("archive.json")
        let saved = defaults.string(forKey: Self.delayKey)
        self.autoArchiveDelay = saved.flatMap(AutoArchiveDelay.init) ?? .never
        self.customDays = min(365, max(1, (defaults.object(forKey: Self.customDaysKey) as? Int) ?? 7))
        load()
        archiveCompletedIfDue()
        startSweepTimer()
    }

    // MARK: - Derived

    /// How many archived todos are marked done — the running tally of
    /// everything completed in this app.
    var completedCount: Int { archive.lazy.filter { $0.isDone }.count }

    // MARK: - Mutations

    func add(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let task = TodoTask(title: trimmed)
        tasks.insert(task, at: 0)
        archive.insert(task, at: 0)
        save()
    }

    func toggle(_ task: TodoTask) {
        mutate(task.id) { t in
            t.isDone.toggle()
            t.completedAt = t.isDone ? Date() : nil
        }
        archiveCompletedIfDue()
    }

    /// Removes from the active list any completed task whose linger time has
    /// elapsed (it stays in the archive). No-op when the delay is "Never".
    func archiveCompletedIfDue() {
        guard let interval = effectiveInterval else { return }
        let now = Date()
        let before = tasks.count
        tasks.removeAll { task in
            guard task.isDone, let done = task.completedAt else { return false }
            return now.timeIntervalSince(done) >= interval
        }
        if tasks.count != before { save() }
    }

    /// Soft delete: drops the task from the active list but keeps its archive
    /// copy. Used by the menu bar and the main window's active list, so removing
    /// something never erases it from the history.
    func delete(_ task: TodoTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            lastDeleted = DeletedTask(task: tasks[index], index: index)
        }
        tasks.removeAll { $0.id == task.id }
        save()
    }

    /// Restores the most recently soft-deleted task to its old position. The
    /// archive copy was never removed, so undo only has to rebuild the active
    /// list (re-seeding the archive too, just in case it was cleared meanwhile).
    func undoLastDelete() {
        guard let deleted = lastDeleted else { return }
        let index = min(deleted.index, tasks.count)
        tasks.insert(deleted.task, at: index)
        if !archive.contains(where: { $0.id == deleted.task.id }) {
            archive.insert(deleted.task, at: 0)
        }
        lastDeleted = nil
        save()
    }

    /// Permanent delete: removes the task from the archive (and from the active
    /// list, if it's still there). Used only by the archive view, behind a
    /// confirmation. This is the one path that truly discards a task.
    func purge(_ task: TodoTask) {
        tasks.removeAll { $0.id == task.id }
        archive.removeAll { $0.id == task.id }
        save()
    }

    /// Reorders the active list (drag-to-reorder in the main window). The
    /// archive keeps its own order — it's a history, not a sortable list.
    func move(fromOffsets: IndexSet, toOffset: Int) {
        tasks.move(fromOffsets: fromOffsets, toOffset: toOffset)
        save()
    }

    /// Empties the archive of everything that's no longer on the active list —
    /// i.e. the purely historical, completed/removed items. Tasks still on your
    /// list stay (they must remain in the archive, which is a superset).
    func clearArchive() {
        let activeIDs = Set(tasks.map { $0.id })
        archive.removeAll { !activeIDs.contains($0.id) }
        save()
    }

    /// Replaces a task's title. Used by the menu bar's keyboard editing
    /// (type-to-append, Backspace-to-trim on the highlighted task).
    func updateTitle(_ task: TodoTask, to newTitle: String) {
        mutate(task.id) { $0.title = newTitle }
    }

    /// Sets (or clears, when blank/nil) a task's optional link.
    func updateURL(_ task: TodoTask, to newURL: String?) {
        let trimmed = newURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = (trimmed?.isEmpty ?? true) ? nil : trimmed
        mutate(task.id) { $0.url = value }
    }

    /// Applies a change to a task wherever it lives — the active list and/or the
    /// archive — keeping the two copies in sync, then saves.
    private func mutate(_ id: UUID, _ change: (inout TodoTask) -> Void) {
        if let i = tasks.firstIndex(where: { $0.id == id }) { change(&tasks[i]) }
        if let i = archive.firstIndex(where: { $0.id == id }) { change(&archive[i]) }
        save()
    }

    // MARK: - Persistence

    /// Fires periodically so completed tasks are swept to the archive even
    /// while the app is idle. Short delays are handled at toggle time; this
    /// covers the longer ones (an hour, a day, …) without needing a relaunch.
    private func startSweepTimer() {
        sweepTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.archiveCompletedIfDue() }
        }
    }

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([TodoTask].self, from: data) {
            // Tasks completed before this field existed get their clock started
            // now, so enabling auto-archive won't make them vanish instantly.
            tasks = decoded.map { task in
                guard task.isDone, task.completedAt == nil else { return task }
                var t = task
                t.completedAt = Date()
                return t
            }
        }
        if let data = try? Data(contentsOf: archiveURL),
           let decoded = try? JSONDecoder().decode([TodoTask].self, from: data) {
            archive = decoded
        } else {
            // First run after this feature shipped: no archive file yet, so seed
            // it from the existing tasks instead of starting the history empty.
            archive = tasks
            write(archive, to: archiveURL)
        }
    }

    private func save() {
        write(tasks, to: fileURL)
        write(archive, to: archiveURL)
    }

    /// Blocks until every queued disk write has finished. Not needed in normal
    /// use (writes are fire-and-forget); tests call it before opening a second
    /// store over the same directory to assert what was persisted.
    func flushPendingWrites() {
        ioQueue.sync {}
    }

    private func write(_ list: [TodoTask], to url: URL) {
        // `list` is a value type, so this snapshot is safe to hand to the
        // background queue. Encoding + the atomic write happen off the main
        // thread, so a large archive never makes the UI feel laggy.
        ioQueue.async {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            guard let data = try? encoder.encode(list) else { return }
            try? data.write(to: url, options: [.atomic])
        }
    }
}
