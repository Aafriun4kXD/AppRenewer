import Foundation
import Security

struct AppleIDCredentials: Codable {
    let email: String
    var password: String
    var session: AppleSession?
    
    struct AppleSession: Codable {
        let dsid: String
        let adsid: String
        let token: String
        let expiration: Date
        
        var isValid: Bool {
            return Date() < expiration
        }
    }
}

class CredentialsStore {
    static let shared = CredentialsStore()
    private let service = "AppRenewer"
    private let account = "AppleID"
    
    func save(_ credentials: AppleIDCredentials) {
        guard let data = try? JSONEncoder().encode(credentials) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func load() -> AppleIDCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let credentials = try? JSONDecoder().decode(AppleIDCredentials.self, from: data)
        else { return nil }
        
        return credentials
    }
    
    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}