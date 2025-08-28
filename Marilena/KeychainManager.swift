import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    private let service = "com.marilena.apikeys"
    
    func save(key: String, value: String) -> Bool {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Elimina eventuali chiavi esistenti
        SecItemDelete(query as CFDictionary)
        
        // Aggiungi la nuova chiave
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
    
    // MARK: - API Key Methods (Compatibilità con EmailService)
    
    private func normalizedKey(_ key: String) -> String {
        // Accept both full keys (e.g., "openai_api_key") and short names (e.g., "openai")
        let lower = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.hasSuffix("_api_key") { return lower }
        switch lower {
        case "openai": return "openai_api_key"
        case "anthropic": return "anthropic_api_key"
        case "groq": return "groq_api_key"
        case "perplexity": return "perplexity_api_key"
        default: return lower
        }
    }
    
    func saveAPIKey(_ value: String, for key: String) -> Bool {
        return save(key: normalizedKey(key), value: value)
    }
    
    func getAPIKey(for key: String) -> String? {
        return load(key: normalizedKey(key))
    }
    
    func deleteAPIKey(for key: String) -> Bool {
        return delete(key: normalizedKey(key))
    }
}
