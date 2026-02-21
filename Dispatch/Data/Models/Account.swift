import Foundation

enum AccountProvider: String, Codable {
    case github
}

struct Account: Codable, Identifiable, Hashable {
    let id: String
    let login: String
    let avatarURL: URL
    let provider: AccountProvider

    init(login: String, avatarURL: URL, provider: AccountProvider = .github) {
        self.id = "\(provider.rawValue):\(login)"
        self.login = login
        self.avatarURL = avatarURL
        self.provider = provider
    }
}
