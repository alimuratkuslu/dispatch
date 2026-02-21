import Foundation

struct PRComment: Codable, Identifiable, Hashable {
    let id: String
    let body: String
    let author: PRAuthor
    let createdAt: Date
    let updatedAt: Date
    let prNodeID: String   // injected after decoding
}
