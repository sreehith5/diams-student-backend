import Foundation
import Security

enum KeychainHelper {
    private static func key(_ k: String) -> String { "com.diams.\(k)" }

    static func save(_ value: String, for account: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key(account),
        ]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData] = data
        SecItemAdd(item as CFDictionary, nil)
    }

    static func load(_ account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      key(account),
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ account: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key(account),
        ]
        SecItemDelete(query as CFDictionary)
    }
}

extension KeychainHelper {
    // JWT token
    static var token: String? {
        get { load("jwt") }
        set { newValue == nil ? delete("jwt") : save(newValue!, for: "jwt") }
    }
    // Stored credentials for silent re-login
    static var savedEmail: String? {
        get { load("email") }
        set { newValue == nil ? delete("email") : save(newValue!, for: "email") }
    }
    static var savedPassword: String? {
        get { load("password") }
        set { newValue == nil ? delete("password") : save(newValue!, for: "password") }
    }
    static var savedRole: String? {
        get { load("role") }
        set { newValue == nil ? delete("role") : save(newValue!, for: "role") }
    }

    // Check if stored JWT is still valid (not expired)
    static var isTokenValid: Bool {
        guard let token = token else { return false }
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return false }
        var base64 = String(parts[1])
        // Pad base64
        let remainder = base64.count % 4
        if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: base64),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = payload["exp"] as? TimeInterval else { return false }
        // Consider valid if more than 5 minutes remaining
        return Date().timeIntervalSince1970 < exp - 300
    }
}
