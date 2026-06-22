import Foundation

/// A single to-do item.
///
/// Named `TodoTask` rather than `Task` to avoid colliding with Swift
/// Concurrency's `Task` type.
struct TodoTask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
    let createdAt: Date
    /// Optional link for the task (e.g. a Jira ticket URL). Decodes to `nil`
    /// for tasks saved before this field existed.
    var url: String?

    init(id: UUID = UUID(), title: String, isDone: Bool = false, createdAt: Date = Date(), url: String? = nil) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
        self.url = url
    }
}
