import Foundation

struct ReviewThread: Codable, Identifiable, Hashable {
    let id: String
    let path: String
    let line: Int?
    let isResolved: Bool
    let comments: [ThreadComment]
    let prNodeID: String   // injected after decoding
}

struct ThreadComment: Codable, Identifiable, Hashable {
    let id: String
    let body: String
    let author: PRAuthor
    let createdAt: Date
    let isOutdated: Bool
    let replyToID: String?  // id of parent comment if this is a reply

    private enum CodingKeys: String, CodingKey {
        case id, body, author, createdAt, isOutdated = "outdated", replyToID
    }
}
