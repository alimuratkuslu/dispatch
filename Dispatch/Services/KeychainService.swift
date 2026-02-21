import Foundation
import Security

actor KeychainService {
    private let serviceName = "com.dispatch.app"

    enum KeychainError: LocalizedError {
        case itemNotFound
        case duplicateItem
        case unexpectedStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .itemNotFound: return "Token not found in Keychain."
            case .duplicateItem: return "Token already exists in Keychain."
            case .unexpectedStatus(let s): return "Keychain error: \(s)"
            }
        }
    }

    func save(token: String, account: String) throws {
        guard let data = token.data(using: .utf8) else { return }

        // Delete existing first to allow overwrite
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func load(account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound { throw KeychainError.itemNotFound }
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.itemNotFound
        }
        return token
    }

    func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func hasToken(account: String) -> Bool {
        (try? load(account: account)) != nil
    }
}
