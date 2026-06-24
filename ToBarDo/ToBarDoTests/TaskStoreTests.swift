import XCTest
@testable import ToBarDo

/// Logic tests for `TaskStore`. Every store is built against a throwaway temp
/// directory and an isolated `UserDefaults` suite, so these never read or write
/// the real `~/Library/Application Support/To-Bar-Do/` files or your settings.
@MainActor
final class TaskStoreTests: XCTestCase {

    private var dir: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tobardo-tests-\(UUID().uuidString)", isDirectory: true)
        suiteName = "tobardo-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        defaults.removePersistentDomain(forName: suiteName)
        dir = nil; defaults = nil; suiteName = nil
        super.tearDown()
    }

    /// Fresh store rooted at the test's temp dir + isolated defaults.
    private func makeStore() -> TaskStore {
        TaskStore(directory: dir, defaults: defaults)
    }

    // MARK: - add

    func testAddInsertsAtFrontOfBothLists() {
        let store = makeStore()
        store.add(title: "first")
        store.add(title: "second")
        XCTAssertEqual(store.tasks.map(\.title), ["second", "first"])
        XCTAssertEqual(store.archive.map(\.title), ["second", "first"])
    }

    func testAddTrimsWhitespace() {
        let store = makeStore()
        store.add(title: "   spaced   ")
        XCTAssertEqual(store.tasks.first?.title, "spaced")
    }

    func testAddIgnoresEmptyAndWhitespaceOnly() {
        let store = makeStore()
        store.add(title: "")
        store.add(title: "    \n\t ")
        XCTAssertTrue(store.tasks.isEmpty)
        XCTAssertTrue(store.archive.isEmpty)
    }

    // MARK: - toggle

    func testToggleSetsAndClearsDoneAndCompletedAt() {
        let store = makeStore()
        store.add(title: "task")
        let task = store.tasks[0]

        store.toggle(task)
        XCTAssertTrue(store.tasks[0].isDone)
        XCTAssertNotNil(store.tasks[0].completedAt)

        store.toggle(store.tasks[0])
        XCTAssertFalse(store.tasks[0].isDone)
        XCTAssertNil(store.tasks[0].completedAt)
    }

    func testToggleSyncsArchiveCopy() {
        let store = makeStore()
        store.add(title: "task")
        store.toggle(store.tasks[0])
        XCTAssertTrue(store.archive[0].isDone, "archive copy should track the active copy")
    }

    // MARK: - soft delete vs purge

    func testSoftDeleteRemovesFromActiveButKeepsArchive() {
        let store = makeStore()
        store.add(title: "task")
        let task = store.tasks[0]
        store.delete(task)
        XCTAssertTrue(store.tasks.isEmpty)
        XCTAssertEqual(store.archive.map(\.title), ["task"], "soft delete must keep the history")
    }

    func testPurgeRemovesFromBothLists() {
        let store = makeStore()
        store.add(title: "task")
        store.purge(store.tasks[0])
        XCTAssertTrue(store.tasks.isEmpty)
        XCTAssertTrue(store.archive.isEmpty)
    }

    // MARK: - undo delete

    func testUndoRestoresDeletedTaskToOriginalIndex() {
        let store = makeStore()
        store.add(title: "a") // [a]
        store.add(title: "b") // [b, a]
        store.add(title: "c") // [c, b, a]
        store.delete(store.tasks[1]) // remove "b" from the middle
        XCTAssertEqual(store.tasks.map(\.title), ["c", "a"])
        store.undoLastDelete()
        XCTAssertEqual(store.tasks.map(\.title), ["c", "b", "a"], "undo should restore position")
        XCTAssertNil(store.lastDeleted, "undo clears the pending undo")
    }

    func testUndoIsNoopWhenNothingDeleted() {
        let store = makeStore()
        store.add(title: "a")
        store.undoLastDelete()
        XCTAssertEqual(store.tasks.map(\.title), ["a"])
    }

    func testDeleteSetsLastDeleted() {
        let store = makeStore()
        store.add(title: "a")
        XCTAssertNil(store.lastDeleted)
        store.delete(store.tasks[0])
        XCTAssertEqual(store.lastDeleted?.task.title, "a")
    }

    // MARK: - completedCount

    func testCompletedCountTracksArchivedDoneItems() {
        let store = makeStore()
        store.add(title: "a")
        store.add(title: "b")
        XCTAssertEqual(store.completedCount, 0)
        store.toggle(store.tasks[0])
        XCTAssertEqual(store.completedCount, 1)
    }

    // MARK: - move

    func testMoveReordersActiveList() {
        let store = makeStore()
        store.add(title: "a") // tasks: [a]
        store.add(title: "b") // tasks: [b, a]
        store.add(title: "c") // tasks: [c, b, a]
        store.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(store.tasks.map(\.title), ["b", "a", "c"])
    }

    // MARK: - updateTitle / updateURL

    func testUpdateTitleSyncsBothLists() {
        let store = makeStore()
        store.add(title: "old")
        store.updateTitle(store.tasks[0], to: "new")
        XCTAssertEqual(store.tasks[0].title, "new")
        XCTAssertEqual(store.archive[0].title, "new")
    }

    func testUpdateURLSetsAndClears() {
        let store = makeStore()
        store.add(title: "task")
        store.updateURL(store.tasks[0], to: "https://example.com")
        XCTAssertEqual(store.tasks[0].url, "https://example.com")
        store.updateURL(store.tasks[0], to: "   ")        // blank clears
        XCTAssertNil(store.tasks[0].url)
    }

    // MARK: - clearArchive

    func testClearArchiveKeepsActiveDropsHistorical() {
        let store = makeStore()
        store.add(title: "active")
        store.add(title: "removed")
        store.delete(store.tasks[0])  // "removed" is now history-only
        store.clearArchive()
        XCTAssertEqual(store.archive.map(\.title), ["active"],
                       "active tasks must remain in the archive (it's a superset)")
    }

    // MARK: - auto-archive

    func testAutoArchiveNeverKeepsCompletedOnList() {
        let store = makeStore()
        store.autoArchiveDelay = .never
        store.add(title: "task")
        store.toggle(store.tasks[0])
        store.archiveCompletedIfDue()
        XCTAssertEqual(store.tasks.count, 1, "Never must leave completed tasks on the list")
    }

    func testAutoArchiveImmediatelyDropsCompletedFromList() {
        let store = makeStore()
        store.autoArchiveDelay = .immediately
        store.add(title: "task")
        store.toggle(store.tasks[0])   // toggle re-runs the sweep
        XCTAssertTrue(store.tasks.isEmpty, "Immediately must drop a completed task at once")
        XCTAssertEqual(store.archive.count, 1, "…but keep it in the archive")
    }

    func testAutoArchiveNotDueKeepsRecentlyCompleted() {
        let store = makeStore()
        store.autoArchiveDelay = .afterWeek
        store.add(title: "task")
        store.toggle(store.tasks[0])   // completed just now → not due for a week
        XCTAssertEqual(store.tasks.count, 1)
    }

    func testEffectiveIntervalForCustomDays() {
        let store = makeStore()
        store.autoArchiveDelay = .custom
        store.customDays = 3
        XCTAssertEqual(store.effectiveInterval, 3 * 86_400)
    }

    // MARK: - persistence

    func testTasksPersistAcrossStoreInstances() {
        let first = makeStore()
        first.add(title: "persist me")
        // A second store over the same dir should load what the first wrote.
        let second = TaskStore(directory: dir, defaults: defaults)
        XCTAssertEqual(second.tasks.map(\.title), ["persist me"])
    }

    /// A done task saved before `completedAt` existed should get its clock
    /// started on load, so enabling auto-archive doesn't make it vanish at once.
    func testLoadMigratesMissingCompletedAtForDoneTasks() throws {
        let legacy = """
        [
          { "id": "\(UUID().uuidString)", "title": "legacy done",
            "isDone": true, "createdAt": 0 }
        ]
        """
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try legacy.data(using: .utf8)!.write(to: dir.appendingPathComponent("tasks.json"))

        let store = makeStore()
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertTrue(store.tasks[0].isDone)
        XCTAssertNotNil(store.tasks[0].completedAt, "migration should backfill completedAt")
    }
}
