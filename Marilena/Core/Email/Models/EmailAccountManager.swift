//
//  EmailAccountManager.swift
//  Marilena
//
//  Created by Claude
//  Multi-Account Email Manager
//

import Foundation
import SwiftUI
import Combine

@MainActor
public class EmailAccountManager: ObservableObject {
    public static let shared = EmailAccountManager()

    @Published public private(set) var accounts: [EmailAccount] = []
    @Published public var currentAccountId: String?

    public var currentAccount: EmailAccount? {
        accounts.first { $0.id == currentAccountId }
    }

    // Storage keys
    private let accountsKey = "email_accounts_list"
    private let currentAccountKey = "email_current_account_id"
    private let keychainManager = KeychainManager.shared

    private init() {
        loadAccounts()
        runMigrationIfNeeded()
    }

    // MARK: - Public Methods

    /// Aggiunge un nuovo account
    public func addAccount(_ account: EmailAccount) {
        // Verifica duplicati
        guard !accounts.contains(where: { $0.email == account.email }) else {
            print("Account già esistente: \(account.email)")
            return
        }

        // Salva tokens in Keychain con suffix accountId
        let accessTokenKey = "email_access_token_\(account.id)"
        let refreshTokenKey = "email_refresh_token_\(account.id)"

        _ = keychainManager.saveAPIKey(account.accessToken, for: accessTokenKey)
        if let refreshToken = account.refreshToken {
            _ = keychainManager.saveAPIKey(refreshToken, for: refreshTokenKey)
        }

        // Aggiungi account alla lista
        accounts.append(account)
        saveAccounts()

        // Se è il primo account, impostalo come corrente
        if currentAccountId == nil {
            currentAccountId = account.id
            UserDefaults.standard.set(account.id, forKey: currentAccountKey)
        }

        print("✅ Account aggiunto: \(account.email)")
    }

    /// Rimuove un account
    public func removeAccount(id: String) {
        guard let account = accounts.first(where: { $0.id == id }) else {
            return
        }

        // Rimuovi tokens da Keychain
        let accessTokenKey = "email_access_token_\(id)"
        let refreshTokenKey = "email_refresh_token_\(id)"
        _ = keychainManager.deleteAPIKey(for: accessTokenKey)
        _ = keychainManager.deleteAPIKey(for: refreshTokenKey)

        // Rimuovi account dalla lista
        accounts.removeAll { $0.id == id }
        saveAccounts()

        // Se era l'account corrente, switch al primo disponibile
        if currentAccountId == id {
            currentAccountId = accounts.first?.id
            if let newCurrent = currentAccountId {
                UserDefaults.standard.set(newCurrent, forKey: currentAccountKey)
            } else {
                UserDefaults.standard.removeObject(forKey: currentAccountKey)
            }
        }

        print("✅ Account rimosso: \(account.email)")
    }

    /// Cambia account corrente
    public func switchAccount(to accountId: String) {
        guard accounts.contains(where: { $0.id == accountId }) else {
            print("⚠️ Account non trovato: \(accountId)")
            return
        }

        currentAccountId = accountId
        UserDefaults.standard.set(accountId, forKey: currentAccountKey)
        print("✅ Switched to account: \(accountId)")
    }

    /// Aggiorna tokens per un account esistente
    public func updateTokens(accountId: String, accessToken: String, refreshToken: String?) {
        let accessTokenKey = "email_access_token_\(accountId)"
        let refreshTokenKey = "email_refresh_token_\(accountId)"

        _ = keychainManager.saveAPIKey(accessToken, for: accessTokenKey)
        if let refreshToken = refreshToken {
            _ = keychainManager.saveAPIKey(refreshToken, for: refreshTokenKey)
        }
    }

    /// Carica tokens per un account
    public func loadTokens(for accountId: String) -> (accessToken: String?, refreshToken: String?) {
        let accessTokenKey = "email_access_token_\(accountId)"
        let refreshTokenKey = "email_refresh_token_\(accountId)"

        let accessToken = keychainManager.getAPIKey(for: accessTokenKey)
        let refreshToken = keychainManager.getAPIKey(for: refreshTokenKey)

        return (accessToken, refreshToken)
    }

    // MARK: - Private Methods

    private func saveAccounts() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(accounts) {
            UserDefaults.standard.set(data, forKey: accountsKey)
        }
    }

    private func loadAccounts() {
        guard let data = UserDefaults.standard.data(forKey: accountsKey) else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        accounts = (try? decoder.decode([EmailAccount].self, from: data)) ?? []

        // Carica current account
        if let savedCurrentId = UserDefaults.standard.string(forKey: currentAccountKey),
           accounts.contains(where: { $0.id == savedCurrentId }) {
            currentAccountId = savedCurrentId
        } else {
            currentAccountId = accounts.first?.id
        }
    }

    private func runMigrationIfNeeded() {
        let migrationKey = "email_migration_completed_v2"

        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            return // Migration già eseguita
        }

        print("🔄 Eseguendo migration single → multi account...")
        EmailAccountMigration.migrate()
        UserDefaults.standard.set(true, forKey: migrationKey)

        // Ricarica accounts dopo migration
        loadAccounts()
    }
}
