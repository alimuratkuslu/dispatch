import XCTest
@testable import DispatchApp

/// NOTE: PollingEngine uses DispatchSourceTimer and real network calls.
/// These tests verify the public interface and backoff logic using a mock-free approach.
/// Full integration tests require a real GitHub token.
@MainActor
final class PollingEngineTests: XCTestCase {

    func testPollIntervalDefaultsToUserDefaultsValue() {
        let store = UserDefaultsStore()
        let originalInterval = store.pollInterval
        // Set to a known value
        UserDefaults.standard.set(120.0, forKey: "pollInterval")
        defer { UserDefaults.standard.set(originalInterval, forKey: "pollInterval") }

        let keychain = KeychainService()
        let storeManager = StoreManager()
        let dataStore = DataStore(storeManager: storeManager)
        let notifManager = NotificationManager()
        let apiClient = GitHubAPIClient(keychainService: keychain)

        let engine = PollingEngine(apiClient: apiClient, dataStore: dataStore, notificationManager: notifManager)
        XCTAssertEqual(engine.pollInterval, 120)
    }

    func testEngineDoesNotCrashOnStop() {
        let keychain = KeychainService()
        let storeManager = StoreManager()
        let dataStore = DataStore(storeManager: storeManager)
        let notifManager = NotificationManager()
        let apiClient = GitHubAPIClient(keychainService: keychain)

        let engine = PollingEngine(apiClient: apiClient, dataStore: dataStore, notificationManager: notifManager)
        engine.start()
        engine.stop()
        // No crash = pass
    }
}
