import Foundation

struct PRAuthor: Codable, Hashable, Identifiable {
    let login: String
    let avatarURL: URL
    let isBot: Bool

    var id: String { login }
    var isCopilot: Bool { isBot && login.lowercased().contains("copilot") }

    init(login: String, avatarURL: URL, isBot: Bool = false) {
        self.login = login
        self.avatarURL = avatarURL
        self.isBot = isBot
    }

    // MARK: - Codable (raw GitHub API shape)
    private enum CodingKeys: String, CodingKey {
        case login
        case avatarURL = "avatarUrl"
        case typename = "__typename"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        login = try c.decode(String.self, forKey: .login)
        let avatarString = try c.decode(String.self, forKey: .avatarURL)
        avatarURL = URL(string: avatarString) ?? URL(string: "https://github.com/identicons/\(login).png")!
        let typename = try c.decodeIfPresent(String.self, forKey: .typename) ?? "User"
        isBot = (typename == "Bot")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(login, forKey: .login)
        try c.encode(avatarURL.absoluteString, forKey: .avatarURL)
        try c.encode(isBot ? "Bot" : "User", forKey: .typename)
    }
}
