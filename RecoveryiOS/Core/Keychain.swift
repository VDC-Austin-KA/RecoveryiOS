import Foundation
import Security

/// Minimal generic-password Keychain wrapper for API keys and the journal encryption key.
enum Keychain {
    private static let service = Bundle.main.bundleIdentifier ?? "RecoveryiOS"

    private static func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func data(for account: String) -> Data? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    /// Stores `data`, or deletes the item when `data` is nil/empty.
    @discardableResult
    static func set(_ data: Data?, for account: String) -> Bool {
        SecItemDelete(baseQuery(account) as CFDictionary)
        guard let data, !data.isEmpty else { return true }
        var attributes = baseQuery(account)
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    static func string(for account: String) -> String? {
        guard let data = data(for: account) else { return nil }
        let value = String(decoding: data, as: UTF8.self)
        return value.isEmpty ? nil : value
    }

    static func setString(_ value: String?, for account: String) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        set(trimmed.map { Data($0.utf8) }, for: account)
    }
}
