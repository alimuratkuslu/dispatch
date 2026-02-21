import Foundation

/// GitHub OAuth App credentials.
/// Replace with your actual GitHub OAuth App's client_id.
/// Create one at: https://github.com/settings/developers → OAuth Apps → New OAuth App
/// Authorization callback URL: https://github.com
enum GitHubOAuth {
    static let clientID = Secrets.githubClientID
    static let scope = "repo,read:user,notifications"
}
