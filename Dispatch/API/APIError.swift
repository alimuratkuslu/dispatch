import Foundation

enum APIError: LocalizedError {
    case noToken
    case unauthorized
    case rateLimitExceeded(resetDate: Date)
    case notFound
    case serverError(Int)
    case decodingError(Error)
    case networkError(Error)
    case graphQLError(String)
    case deviceFlowPending
    case deviceFlowSlowDown
    case deviceFlowExpired
    case deviceFlowAccessDenied
    case deviceFlowError(String)

    var errorDescription: String? {
        switch self {
        case .noToken: return "No GitHub token found. Please connect your account."
        case .unauthorized: return "GitHub token expired or invalid. Please reconnect."
        case .rateLimitExceeded: return "GitHub API rate limit exceeded."
        case .notFound: return "Repository not found."
        case .serverError(let code): return "GitHub API error (\(code))."
        case .decodingError(let e): return "Data parsing error: \(e.localizedDescription)"
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .graphQLError(let msg): return "GitHub API error: \(msg)"
        case .deviceFlowError(let msg): return "Device flow error: \(msg)"
        default: return nil
        }
    }

    static func from(statusCode: Int, headers: [AnyHashable: Any]) -> APIError? {
        switch statusCode {
        case 200, 201, 204, 304: return nil
        case 401: return .unauthorized
        case 403:
            if let reset = headers["X-RateLimit-Reset"] as? String,
               let ts = TimeInterval(reset) {
                return .rateLimitExceeded(resetDate: Date(timeIntervalSince1970: ts))
            }
            return .unauthorized
        case 404: return .notFound
        case 429:
            if let reset = headers["X-RateLimit-Reset"] as? String,
               let ts = TimeInterval(reset) {
                return .rateLimitExceeded(resetDate: Date(timeIntervalSince1970: ts))
            }
            return .rateLimitExceeded(resetDate: Date().addingTimeInterval(60))
        case 500...599: return .serverError(statusCode)
        default: return .serverError(statusCode)
        }
    }
}
