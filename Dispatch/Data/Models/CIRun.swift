import Foundation
import SwiftUI

enum CIStatus: String, Codable, Hashable {
    case passing
    case failing
    case pending
    case skipped
    case unknown

    // Map from GitHub API strings
    init(checkRunState: String?, conclusion: String?) {
        let status = checkRunState?.uppercased() ?? ""
        let conc = conclusion?.uppercased() ?? ""
        if status == "COMPLETED" {
            switch conc {
            case "SUCCESS":  self = .passing
            case "FAILURE", "TIMED_OUT", "STARTUP_FAILURE": self = .failing
            case "SKIPPED", "CANCELLED": self = .skipped
            default: self = .unknown
            }
        } else if status == "IN_PROGRESS" || status == "QUEUED" || status == "WAITING" {
            self = .pending
        } else {
            self = .unknown
        }
    }

    // Map from GitHub statusCheckRollup state
    init(rollupState: String) {
        switch rollupState.uppercased() {
        case "SUCCESS":  self = .passing
        case "FAILURE", "ERROR": self = .failing
        case "PENDING", "EXPECTED": self = .pending
        default: self = .unknown
        }
    }

    var dotColor: Color {
        switch self {
        case .passing: return .green
        case .failing: return .red
        case .pending: return .yellow
        case .skipped: return .gray
        case .unknown: return .gray
        }
    }

    var displayName: String {
        switch self {
        case .passing: return "Passing"
        case .failing: return "Failing"
        case .pending: return "Pending"
        case .skipped: return "Skipped"
        case .unknown: return "Unknown"
        }
    }
}

struct CIRun: Codable, Identifiable, Hashable {
    let id: String
    let repoFullName: String
    let branch: String
    let status: CIStatus
    let url: URL?
    let updatedAt: Date
}
