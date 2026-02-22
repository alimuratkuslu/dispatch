import Foundation

actor GitHubAPIClient {
    private let keychain: KeychainService
    private let session: URLSession
    private var restETagCache: [String: String] = [:]
    private var restResponseCache: [String: Data] = [:]

    private let graphqlEndpoint = URL(string: "https://api.github.com/graphql")!
    private let restBase = "https://api.github.com"

    init(keychainService: KeychainService) {
        self.keychain = keychainService
        let config = URLSessionConfiguration.ephemeral
        config.httpAdditionalHeaders = ["Accept": "application/vnd.github+json",
                                        "X-GitHub-Api-Version": "2022-11-28"]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Token helpers
    private func token() async throws -> String {
        try await keychain.load(account: "github")
    }

    // MARK: - Auth header
    private func authHeaders(token: String) -> [String: String] {
        ["Authorization": "Bearer \(token)"]
    }

    // MARK: - User info
    func fetchCurrentUser() async throws -> Account {
        let tok = try await token()
        return try await fetchCurrentUser(token: tok)
    }

    func fetchCurrentUser(token tok: String) async throws -> Account {
        let url = URL(string: "\(restBase)/user")!
        var request = URLRequest(url: url)
        authHeaders(token: tok).forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let raw = try decoder.decode(RawUser.self, from: data)
        let avatarURL = URL(string: raw.avatarUrl) ?? URL(string: "https://github.com/ghost.png")!
        return Account(login: raw.login, avatarURL: avatarURL)
    }

    // MARK: - Repositories
    func fetchUserRepos() async throws -> [MonitoredRepo] {
        let tok = try await token()
        var repos: [MonitoredRepo] = []
        var page = 1
        var keepGoing = true

        while keepGoing {
            let urlStr = "\(restBase)/user/repos?per_page=100&page=\(page)&sort=pushed&type=all"
            let url = URL(string: urlStr)!
            var request = URLRequest(url: url)
            authHeaders(token: tok).forEach { request.setValue($1, forHTTPHeaderField: $0) }

            if let etag = restETagCache[urlStr] {
                request.setValue(etag, forHTTPHeaderField: "If-None-Match")
            }

            let (data, response) = try await session.data(for: request)
            let http = response as! HTTPURLResponse

            if http.statusCode == 304 {
                if let cached = restResponseCache[urlStr] {
                    let raw = try JSONDecoder().decode([RawRepo].self, from: cached)
                    return raw.map { $0.toMonitoredRepo() }
                } else {
                    restETagCache.removeValue(forKey: urlStr)
                    continue
                }
            }

            try validateResponse(response, data: data)

            if let etag = http.value(forHTTPHeaderField: "ETag") {
                restETagCache[urlStr] = etag
                restResponseCache[urlStr] = data
            }

            let rawRepos = try JSONDecoder().decode([RawRepo].self, from: data)
            repos.append(contentsOf: rawRepos.map { $0.toMonitoredRepo() })

            keepGoing = rawRepos.count == 100
            page += 1
        }
        return repos
    }

    // MARK: - Main GraphQL poll
    func fetchPRData(repo: MonitoredRepo) async throws -> (prs: [PullRequest], viewerLogin: String, ciRun: CIRun?) {
        let tok = try await token()
        let body = GraphQLBody(query: GitHubGraphQL.pollQuery,
                               variables: ["owner": .string(repo.owner), "name": .string(repo.name)])
        let bodyData = try JSONEncoder().encode(body)

        var request = URLRequest(url: graphqlEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authHeaders(token: tok).forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: s) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: s) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: dec.codingPath, debugDescription: "Bad date: \(s)"))
        }

        let response2 = try decoder.decode(GraphQLResponse<PollData>.self, from: data)

        if let errors = response2.errors, !errors.isEmpty {
            throw APIError.graphQLError(errors.map(\.message).joined(separator: "; "))
        }

        guard let pollData = response2.data else {
            throw APIError.graphQLError("Empty response data")
        }

        let viewerLogin = pollData.viewer.login
        let repoData = pollData.repository

        let prs = (repoData?.pullRequests.nodes ?? []).map { node -> PullRequest in
            node.toPullRequest(repoFullName: repo.fullName)
        }

        let ciRun: CIRun?
        if let defaultBranch = repoData?.defaultBranchRef,
           let rollup = defaultBranch.target?.statusCheckRollup {
            let status = CIStatus(rollupState: rollup.state)
            ciRun = CIRun(
                id: "\(repo.fullName):\(defaultBranch.name)",
                repoFullName: repo.fullName,
                branch: defaultBranch.name,
                status: status,
                url: URL(string: "https://github.com/\(repo.fullName)/actions"),
                updatedAt: Date()
            )
        } else {
            ciRun = nil
        }

        return (prs, viewerLogin, ciRun)
    }

    // MARK: - PR merge status
    /// Returns true if the PR was merged, false if it was closed without merging.
    /// Uses GET /repos/{owner}/{repo}/pulls/{number}/merge → 204 = merged, 404 = not merged.
    func checkIsPRMerged(owner: String, repo: String, number: Int) async throws -> Bool {
        let tok = try await token()
        let url = URL(string: "\(restBase)/repos/\(owner)/\(repo)/pulls/\(number)/merge")!
        var request = URLRequest(url: url)
        authHeaders(token: tok).forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let (_, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return status == 204
    }

    func markPullRequestReady(id: String) async throws {
        let tok = try await token()
        let input: [String: JSONValue] = ["pullRequestId": .string(id)]
        let body = GraphQLBody(query: GitHubGraphQL.markReadyMutation,
                               variables: ["input": .dictionary(input)])
        let bodyData = try JSONEncoder().encode(body)

        var request = URLRequest(url: graphqlEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authHeaders(token: tok).forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        let response2 = try JSONDecoder().decode(GraphQLResponse<MarkReadyData>.self, from: data)
        if let errors = response2.errors, !errors.isEmpty {
            throw APIError.graphQLError(errors.map(\.message).joined(separator: "; "))
        }
    }

    func requestCopilotReview(owner: String, repo: String, number: Int) async throws {
        let tok = try await token()
        // Mimic the GitHub Web UI request to trigger copilot-workspace/code-review directly
        let url = URL(string: "https://github.com/\(owner)/\(repo)/pull/\(number)/review-requests")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Use the PAT as auth to see if the web endpoint accepts it
        authHeaders(token: tok).forEach { request.setValue($1, forHTTPHeaderField: $0) }

        // Send an empty body or the specific reviewer structure if required.
        // We observe that sending an empty JSON object `{}` or nothing typically triggers the internal flow
        // when hitting the explicit `review-requests` web endpoint, assuming session/PAT grants access.
        let body: [String: String] = [:]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            print("[Copilot Web Trigger] HTTP \(http.statusCode)")
            if http.statusCode != 200 && http.statusCode != 201 {
                let raw = String(data: data, encoding: .utf8) ?? "(no body)"
                print("[Copilot Web Trigger] Unexpected response: \(raw)")
            }
        }
    }

    /// Posts a PR comment mentioning @copilot which triggers the Copilot coding
    /// agent to review the PR. This works on any repo with the Copilot agent available,
    /// even without Copilot for Business. The review appears as comments on the PR.
    func postComment(owner: String, repo: String, number: Int, body: String) async throws {
        let tok = try await token()
        let url = URL(string: "\(restBase)/repos/\(owner)/\(repo)/issues/\(number)/comments")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authHeaders(token: tok).forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let payload: [String: String] = ["body": body]
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode != 201 {
                let raw = String(data: data, encoding: .utf8) ?? "(no body)"
                print("[Comment] Error \(http.statusCode): \(raw)")
            }
        }
        try validateResponse(response, data: data)
    }

    func postCopilotReviewComment(owner: String, repo: String, number: Int) async throws {
        let body = "@copilot please review this pull request. Analyze the code changes, point out any potential bugs, security issues, or improvements, and provide a summary of the changes."
        try await postComment(owner: owner, repo: repo, number: number, body: body)
    }

    func submitThreadReply(threadID: String, body: String) async throws {
        let tok = try await token()
        let input: [String: JSONValue] = [
            "pullRequestReviewThreadId": .string(threadID),
            "body": .string(body)
        ]
        let gBody = GraphQLBody(query: GitHubGraphQL.addThreadReplyMutation,
                                variables: ["input": .dictionary(input)])
        let bodyData = try JSONEncoder().encode(gBody)

        var request = URLRequest(url: graphqlEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authHeaders(token: tok).forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
    }

    // MARK: - Rate limit check
    func checkRateLimit() async throws -> (remaining: Int, resetDate: Date) {
        let tok = try await token()
        let url = URL(string: "\(restBase)/rate_limit")!
        var request = URLRequest(url: url)
        authHeaders(tok: tok).forEach { request.setValue($1, forHTTPHeaderField: $0) }
        if let etag = restETagCache["rate_limit"] {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        let (data, response) = try await session.data(for: request)
        let http = response as! HTTPURLResponse
        if let etag = http.value(forHTTPHeaderField: "ETag") { restETagCache["rate_limit"] = etag }
        try validateResponse(response, data: data)
        let raw = try JSONDecoder().decode(RateLimitResponse.self, from: data)
        return (raw.rate.remaining, Date(timeIntervalSince1970: TimeInterval(raw.rate.reset)))
    }

    // MARK: - OAuth Device Flow
    struct DeviceCodeResponse {
        let deviceCode: String
        let userCode: String
        let verificationURI: URL
        let interval: Int
        let expiresIn: Int
    }

    func requestDeviceCode(clientID: String) async throws -> DeviceCodeResponse {
        guard !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.deviceFlowError("GitHub Client ID is missing. If you downloaded a release build, ensure the DISPATCH_CLIENT_ID secret is set in your GitHub repository before compiling.")
        }
        
        let url = URL(string: "https://github.com/login/device/code")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID.trimmingCharacters(in: .whitespacesAndNewlines)),
            URLQueryItem(name: "scope", value: "repo read:user notifications")
        ]
        
        // GitHub device flow requires spaces to be %20, not +
        let formBody = components.query?.replacingOccurrences(of: "+", with: "%20")
        request.httpBody = formBody?.data(using: .utf8)

        let authSession = URLSession(configuration: .ephemeral)
        let (data, _) = try await authSession.data(for: request)

        if let json = try? JSONDecoder().decode(DeviceCodeJSONResponse.self, from: data),
           !json.device_code.isEmpty {
            return DeviceCodeResponse(
                deviceCode: json.device_code,
                userCode: json.user_code,
                verificationURI: URL(string: json.verification_uri) ?? URL(string: "https://github.com/login/device")!,
                interval: json.interval,
                expiresIn: json.expires_in
            )
        }
        
        // Attempt to parse GitHub's error response
        if let errResp = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
            let msg = errResp.error_description ?? errResp.error ?? errResp.message ?? "Unknown GitHub OAuth error"
            throw APIError.deviceFlowError(msg)
        }
        
        // Print the raw response string to see what went wrong
        let rawResponse = String(data: data, encoding: .utf8) ?? "(no body)"
        print("Device flow failed. Raw response: \\(rawResponse)")

        throw APIError.deviceFlowError("Invalid response from device code endpoint. \\(rawResponse)")
    }

    func pollForToken(clientID: String, deviceCode: String) async throws -> String {
        let url = URL(string: "https://github.com/login/oauth/access_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(nil, forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID.trimmingCharacters(in: .whitespacesAndNewlines)),
            URLQueryItem(name: "device_code", value: deviceCode.trimmingCharacters(in: .whitespacesAndNewlines)),
            URLQueryItem(name: "grant_type", value: "urn:ietf:params:oauth:grant-type:device_code")
        ]
        request.httpBody = components.query?.data(using: .utf8)

        let (data, _) = try await session.data(for: request)

        // Try JSON (preferred — set Accept: application/json)
        let decoder = JSONDecoder()
        if let json = try? decoder.decode(TokenJSONResponse.self, from: data) {
            if let token = json.access_token, !token.isEmpty { return token }
            switch json.error ?? "" {
            case "authorization_pending": throw APIError.deviceFlowPending
            case "slow_down":            throw APIError.deviceFlowSlowDown
            case "expired_token":        throw APIError.deviceFlowExpired
            case "access_denied":        throw APIError.deviceFlowAccessDenied
            case let e where !e.isEmpty:
                let desc = json.error_description ?? e
                throw APIError.graphQLError(desc)
            default: break
            }
        }

        // Form-encoded fallback
        let str = String(data: data, encoding: .utf8) ?? ""
        let params = parseFormEncoded(str)
        if let token = params["access_token"], !token.isEmpty { return token }
        switch params["error"] ?? "" {
        case "authorization_pending": throw APIError.deviceFlowPending
        case "slow_down":            throw APIError.deviceFlowSlowDown
        case "expired_token":        throw APIError.deviceFlowExpired
        case "access_denied":        throw APIError.deviceFlowAccessDenied
        case let e where !e.isEmpty:
            let desc = (params["error_description"] ?? e).replacingOccurrences(of: "+", with: " ")
            throw APIError.graphQLError(desc)
        default: break
        }
        throw APIError.graphQLError("No token received. Please try again.")
    }

    // MARK: - Helpers
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        let headers = http.allHeaderFields
        if let error = APIError.from(statusCode: http.statusCode, headers: headers) {
            throw error
        }
    }

    private func parseFormEncoded(_ str: String) -> [String: String] {
        var result: [String: String] = [:]
        for pair in str.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2 {
                let key = String(kv[0]).removingPercentEncoding ?? String(kv[0])
                let val = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                result[key] = val
            }
        }
        return result
    }

    private func authHeaders(tok: String) -> [String: String] {
        ["Authorization": "Bearer \(tok)"]
    }
}

// MARK: - Raw API shapes

private struct GraphQLBody: Encodable {
    let query: String
    let variables: [String: JSONValue]
}

private enum JSONValue: Encodable {
    case string(String)
    case int(Int)
    case dictionary([String: JSONValue])

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .int(let i): try c.encode(i)
        case .dictionary(let d):
            var container = encoder.container(keyedBy: DynamicCodingKeys.self)
            for (key, value) in d {
                try container.encode(value, forKey: DynamicCodingKeys(stringValue: key)!)
            }
        }
    }
}

private struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { nil }
    init?(intValue: Int) { return nil }
}

private struct GraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLErrorItem]?
}
private struct GraphQLErrorItem: Decodable { let message: String }

private struct PollData: Decodable {
    let viewer: ViewerNode
    let repository: RepoNode?
}
private struct ViewerNode: Decodable { let login: String }
private struct RepoNode: Decodable {
    let pullRequests: NodesWrapper<PRNode>
    let defaultBranchRef: DefaultBranchNode?
}
private struct NodesWrapper<T: Decodable>: Decodable { let nodes: [T] }
private struct DefaultBranchNode: Decodable {
    let name: String
    let target: BranchTargetNode?
}
private struct BranchTargetNode: Decodable {
    let statusCheckRollup: StatusRollupNode?
}
private struct StatusRollupNode: Decodable { let state: String }

private struct PRNode: Decodable {
    let id: String
    let number: Int
    let state: String
    let title: String
    let url: String
    let headRefName: String
    let createdAt: Date
    let updatedAt: Date
    let isDraft: Bool
    let mergeable: String
    let author: AuthorNode?
    let reviewRequests: NodesWrapper<ReviewRequestNode>?
    let comments: NodesWrapper<CommentNode>?
    let reviews: NodesWrapper<ReviewNode>?
    let reviewThreads: NodesWrapper<ThreadNode>?
    let commits: NodesWrapper<CommitWrapperNode>?

    func toPullRequest(repoFullName: String) -> PullRequest {
        let prAuthor = author.map { PRAuthor(login: $0.login, avatarURL: URL(string: $0.avatarUrl) ?? URL(string: "https://github.com/ghost.png")!, isBot: $0.__typename == "Bot") } ?? PRAuthor(login: "unknown", avatarURL: URL(string: "https://github.com/ghost.png")!)
        let prURL = URL(string: url) ?? URL(string: "https://github.com")!
        let reviewerLogins: [String] = (reviewRequests?.nodes ?? []).compactMap { $0.requestedReviewer?.login }
        let ciStatus: CIStatus
        let headCommit = commits?.nodes.first?.commit
        if let rollup = headCommit?.statusCheckRollup {
            ciStatus = CIStatus(rollupState: rollup.state)
        } else { ciStatus = .unknown }
        // First line of the commit message only (trim after newline)
        let commitMsg = headCommit?.message.flatMap { $0.isEmpty ? nil : String($0.prefix(upTo: $0.firstIndex(of: "\n") ?? $0.endIndex)) }
        let mappedComments = (comments?.nodes ?? []).map { node -> PRComment in
            let a = PRAuthor(login: node.author?.login ?? "ghost", avatarURL: URL(string: node.author?.avatarUrl ?? "") ?? URL(string: "https://github.com/ghost.png")!, isBot: node.author?.__typename == "Bot")
            return PRComment(id: node.id, body: node.body, author: a, createdAt: node.createdAt, updatedAt: node.updatedAt, prNodeID: id)
        }
        let mappedReviews = (reviews?.nodes ?? []).map { node -> PRReview in
            let a = PRAuthor(login: node.author?.login ?? "ghost", avatarURL: URL(string: node.author?.avatarUrl ?? "") ?? URL(string: "https://github.com/ghost.png")!, isBot: node.author?.__typename == "Bot")
            let state = ReviewState(rawValue: node.state) ?? .commented
            return PRReview(id: node.id, state: state, body: node.body, author: a, submittedAt: node.submittedAt, prNodeID: id)
        }
        let mappedThreads = (reviewThreads?.nodes ?? []).map { thread -> ReviewThread in
            let threadComments = thread.comments.nodes.map { c -> ThreadComment in
                let a = PRAuthor(login: c.author?.login ?? "ghost", avatarURL: URL(string: c.author?.avatarUrl ?? "") ?? URL(string: "https://github.com/ghost.png")!, isBot: c.author?.__typename == "Bot")
                return ThreadComment(id: c.id, body: c.body, author: a, createdAt: c.createdAt, isOutdated: c.outdated, replyToID: c.replyTo?.id)
            }
            return ReviewThread(id: thread.id, path: thread.path, line: thread.line, isResolved: thread.isResolved, comments: threadComments, prNodeID: id)
        }
        let mState = PullRequest.MergeableState(rawValue: mergeable) ?? .unknown
        let prState = PullRequest.PRState(rawValue: state) ?? .open
        return PullRequest(id: id, number: number, state: prState, title: title, url: prURL, author: prAuthor, repoFullName: repoFullName, isDraft: isDraft, mergeable: mState, headRefName: headRefName, latestCommitMessage: commitMsg, createdAt: createdAt, updatedAt: updatedAt, reviews: mappedReviews, comments: mappedComments, reviewThreads: mappedThreads, ciStatus: ciStatus, requestedReviewerLogins: reviewerLogins)
    }
}

private struct AuthorNode: Decodable {
    let login: String
    let avatarUrl: String
    let __typename: String

    private enum CodingKeys: String, CodingKey {
        case login, avatarUrl, __typename
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        login      = (try? c.decodeIfPresent(String.self, forKey: .login))      ?? "ghost"
        avatarUrl  = (try? c.decodeIfPresent(String.self, forKey: .avatarUrl))  ?? "https://github.com/ghost.png"
        __typename = (try? c.decodeIfPresent(String.self, forKey: .__typename)) ?? "User"
    }
}
private struct ReviewRequestNode: Decodable {
    let requestedReviewer: RequestedReviewerNode?
}
private struct RequestedReviewerNode: Decodable {
    let login: String?
}
private struct CommentNode: Decodable {
    let id: String
    let body: String
    let author: AuthorNode?
    let createdAt: Date
    let updatedAt: Date
}
private struct ReviewNode: Decodable {
    let id: String
    let state: String
    let body: String
    let author: AuthorNode?
    let submittedAt: Date
}
private struct ThreadNode: Decodable {
    let id: String
    let path: String
    let line: Int?
    let isResolved: Bool
    let comments: NodesWrapper<ThreadCommentNode>
}
private struct ThreadCommentNode: Decodable {
    let id: String
    let body: String
    let author: AuthorNode?
    let createdAt: Date
    let outdated: Bool
    let replyTo: ReplyToNode?
}
private struct ReplyToNode: Decodable { let id: String }
private struct CommitWrapperNode: Decodable {
    let commit: CommitNode
}
private struct CommitNode: Decodable {
    let message: String?
    let statusCheckRollup: StatusRollupNode?
}
private struct RawUser: Decodable {
    let login: String
    let avatarUrl: String
}
private struct RawRepo: Decodable {
    let nodeId: String
    let fullName: String
    let owner: RawOwner
    let name: String
    let defaultBranch: String
    enum CodingKeys: String, CodingKey {
        case nodeId = "node_id"
        case fullName = "full_name"
        case owner, name
        case defaultBranch = "default_branch"
    }
    func toMonitoredRepo() -> MonitoredRepo {
        MonitoredRepo(id: nodeId, fullName: fullName, owner: owner.login, name: name, defaultBranch: defaultBranch)
    }
}
private struct RawOwner: Decodable { let login: String }
private struct DeviceCodeJSONResponse: Decodable {
    let device_code: String
    let user_code: String
    let verification_uri: String
    let interval: Int
    let expires_in: Int
}
private struct TokenJSONResponse: Decodable {
    let access_token: String?
    let error: String?
    let error_description: String?
}
/// Generic GitHub OAuth error envelope — all fields optional so decoding always succeeds.
private struct OAuthErrorResponse: Decodable {
    let error: String?
    let error_description: String?
    let message: String?
}
private struct RateLimitResponse: Decodable {
    let rate: RateLimitData
}
private struct RateLimitData: Decodable {
    let remaining: Int
    let reset: Int
}

private struct MarkReadyData: Decodable {
    let markPullRequestReadyForReview: MarkReadyPayload
}
private struct MarkReadyPayload: Decodable {
    let pullRequest: MarkReadyNode
}
private struct MarkReadyNode: Decodable {
    let id: String
    let isDraft: Bool
}
