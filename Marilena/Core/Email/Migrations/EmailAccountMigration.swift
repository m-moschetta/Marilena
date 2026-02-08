//
//  EmailAccountMigration.swift
//  Marilena
//
//  Created by Claude
//  Migration da sistema single-account a multi-account
//

import Foundation

public struct EmailAccountMigration {

    /// Esegue la migration da single-account a multi-account
    public static func migrate() {
        let userDefaults = UserDefaults.standard
        let keychainManager = KeychainManager.shared

        // Leggi vecchie chiavi single-account
        guard let oldEmail = userDefaults.string(forKey: "email_account"),
              let oldProvider = userDefaults.string(forKey: "email_provider"),
              let oldAccessToken = keychainManager.getAPIKey(for: "email_access_token")
        else {
            print("⚠️ Nessun account legacy trovato, skip migration")
            return
        }

        print("🔄 Trovato account legacy: \(oldEmail)")

        // Crea nuovo EmailAccount con UUID
        let accountId = UUID().uuidString
        let oldRefreshToken = keychainManager.getAPIKey(for: "email_refresh_token")

        // Determina provider
        let provider: EmailProvider
        switch oldProvider.lowercased() {
        case "google":
            provider = .google
        case "microsoft":
            provider = .microsoft
        default:
            provider = .google // Default Google
        }

        let newAccount = EmailAccount(
            id: accountId,
            provider: provider,
            email: oldEmail,
            displayName: nil, // Non disponibile da vecchio sistema
            photoURL: nil,
            addedAt: Date()
        )

        // Salva tokens in nuove chiavi con suffix accountId
        let newAccessTokenKey = "email_access_token_\(accountId)"
        let newRefreshTokenKey = "email_refresh_token_\(accountId)"

        _ = keychainManager.saveAPIKey(oldAccessToken, for: newAccessTokenKey)
        if let refreshToken = oldRefreshToken {
            _ = keychainManager.saveAPIKey(refreshToken, for: newRefreshTokenKey)
        }

        // Salva nuovo account in array
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode([newAccount]) {
            userDefaults.set(data, forKey: "email_accounts_list")
            userDefaults.set(accountId, forKey: "email_current_account_id")
        }

        // Mantieni vecchie chiavi per backward compatibility (non eliminarle)
        // Se qualcosa va male, l'utente può fare re-login

        print("✅ Migration completata: account \(oldEmail) migrato con ID \(accountId)")
    }
}
