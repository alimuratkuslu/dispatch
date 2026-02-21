import Foundation

enum ReviewState: String, Codable, Hashable {
    case approved = "APPROVED"
    case changesRequested = "CHANGES_REQUESTED"
    case commented = "COMMENTED"
    case dismissed = "DISMISSED"

    var displayName: String {
        switch self {
        case .approved: return "Approved"
        case .changesRequested: return "Changes Requested"
        case .commented: return "Commented"
        case .dismissed: return "Dismissed"
        }
    }
}

struct PRReview: Codable, Identifiable, Hashable {
    let id: String
    let state: ReviewState
    let body: String
    let author: PRAuthor
    let submittedAt: Date
    let prNodeID: String   // injected after decoding
}
