import Foundation
import Security

protocol APIKeyStoring {
    func loadAPIKey() -> String
    func saveAPIKey(_ secret: String)
}

struct KeychainStore: APIKeyStoring {
    private static let service = "com.kipyin.eloquent"
    private static let account = "api-key"

    func loadAPIKey() -> String {
        var query = Self.itemQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    func saveAPIKey(_ secret: String) {
        let query = Self.itemQuery

        if secret.isEmpty {
            SecItemDelete(query as CFDictionary)
            return
        }

        let data = Data(secret.utf8)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard updateStatus == errSecItemNotFound else {
            return
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private static let itemQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail
    ]
}
