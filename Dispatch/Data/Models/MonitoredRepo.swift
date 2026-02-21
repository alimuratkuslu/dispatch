import Foundation

struct MonitoredRepo: Codable, Identifiable, Hashable {
    let id: String           // GitHub node ID
    let fullName: String     // "owner/name"
    let owner: String
    let name: String
    let defaultBranch: String
    var isPaused: Bool       // true when Pro entitlement lost

    init(id: String, fullName: String, owner: String, name: String, defaultBranch: String = "main", isPaused: Bool = false) {
        self.id = id
        self.fullName = fullName
        self.owner = owner
        self.name = name
        self.defaultBranch = defaultBranch
        self.isPaused = isPaused
    }
}
