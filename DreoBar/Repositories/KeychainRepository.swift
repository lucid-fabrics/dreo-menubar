import Foundation
import Security

/// Stores the Dreo email/password as a single JSON blob in the macOS
/// Keychain. Password is kept (not just the access token) so the app can
/// silently re-login once the token expires, per the login sheet + Keychain
/// design in the plan this app was built from.
actor KeychainRepository: KeychainRepositoryProtocol {
    private let service: String
    private let account = "credentials"

    init(service: String = Constants.Keychain.service) {
        self.service = service
    }

    func save(_ credentials: DreoCredentials) async throws {
        let data = try JSONEncoder().encode(credentials)
        var query = baseQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            try update(data: data)
        } else if status != errSecSuccess {
            throw KeychainError.saveFailed(status: status)
        }
    }

    func loadCredentials() async throws -> DreoCredentials? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.readFailed(status: status)
        }
        return try JSONDecoder().decode(DreoCredentials.self, from: data)
    }

    func deleteCredentials() async throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            throw KeychainError.deleteFailed(status: status)
        }
    }

    private func update(data: Data) throws {
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery() as CFDictionary, attributes as CFDictionary)
        if status != errSecSuccess {
            throw KeychainError.saveFailed(status: status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
