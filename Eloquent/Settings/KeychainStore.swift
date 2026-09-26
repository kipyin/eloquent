import Foundation
import Security

// The login Keychain's old API key item, read once for launch migration (ADR 0002).
protocol LegacyAPIKeyStoring {
    func loadAPIKey() -> String?
    func deleteAPIKey()
}

struct KeychainStore: LegacyAPIKeyStoring {
    private static let service = "com.kipyin.eloquent"
    private static let account = "api-key"

    func loadAPIKey() -> String? {
        var query = Self.itemQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func deleteAPIKey() {
        SecItemDelete(Self.itemQuery as CFDictionary)
    }

    private static let itemQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail
    ]
}
