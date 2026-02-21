import XCTest
@testable import DispatchApp

final class KeychainServiceTests: XCTestCase {
    private let keychain = KeychainService()
    private let testAccount = "test.dispatch.keychain.unit"

    override func setUp() async throws {
        // Check if Keychain is accessible (requires code signing entitlements)
        do {
            try await keychain.save(token: "setup_probe", account: testAccount)
            try await keychain.delete(account: testAccount)
        } catch {
            throw XCTSkip("Keychain not accessible in this environment (requires code signing). Error: \(error)")
        }
    }

    override func tearDown() async throws {
        try? await keychain.delete(account: testAccount)
    }

    func testSaveAndLoad() async throws {
        try await keychain.save(token: "ghp_testtoken123", account: testAccount)
        let loaded = try await keychain.load(account: testAccount)
        XCTAssertEqual(loaded, "ghp_testtoken123")
    }

    func testOverwriteWorks() async throws {
        try await keychain.save(token: "first_token", account: testAccount)
        try await keychain.save(token: "second_token", account: testAccount)
        let loaded = try await keychain.load(account: testAccount)
        XCTAssertEqual(loaded, "second_token")
    }

    func testDeleteRemovesToken() async throws {
        try await keychain.save(token: "ghp_todelete", account: testAccount)
        try await keychain.delete(account: testAccount)

        do {
            _ = try await keychain.load(account: testAccount)
            XCTFail("Should have thrown after deletion")
        } catch KeychainService.KeychainError.itemNotFound {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testHasTokenReturnsTrueAfterSave() async throws {
        let before = await keychain.hasToken(account: testAccount)
        XCTAssertFalse(before)
        try await keychain.save(token: "ghp_test", account: testAccount)
        let after = await keychain.hasToken(account: testAccount)
        XCTAssertTrue(after)
    }

    func testLoadThrowsWhenNoToken() async {
        do {
            _ = try await keychain.load(account: testAccount)
            XCTFail("Should throw when no token exists")
        } catch KeychainService.KeychainError.itemNotFound {
            // Expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
