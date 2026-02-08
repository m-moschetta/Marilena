//
//  EmailAuthServiceCompat.swift
//  Marilena
//
//  Created by Claude
//  Compatibility wrapper for EmailAuthService con multi-account support
//

import Foundation
import Combine
import GoogleSignIn
import AuthenticationServices

/// Servizio di autenticazione email compatibile con multi-account
@MainActor
public final class EmailAuthService: ObservableObject {

    // MARK: - Published Properties (deprecated ma mantenute per compatibilità)
    @Published public private(set) var currentAccount: EmailAccount?
    @Published public private(set) var isAuthenticated = false

    // MARK: - Private Properties
    private let keychainManager = KeychainManager.shared
    private let oauthService = OAuthService()
    private let accountManager = EmailAccountManager.shared

    // MARK: - Initialization
    public init() {
        // Carica account corrente da EmailAccountManager
        currentAccount = accountManager.currentAccount
        isAuthenticated = !accountManager.accounts.isEmpty

        Task {
            await restoreGoogleSignIn()
        }
    }

    // MARK: - Public Methods

    /// Ripristina sessione Google precedente
    public func restoreGoogleSignIn() async {
        do {
            var user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()

            let requiredScopes = EmailConfig.getProviderConfig(for: .google).scopes
            let granted = Set(user.grantedScopes ?? [])
            let missingScopes = requiredScopes.filter { !granted.contains($0) }

            if !missingScopes.isEmpty {
                if let windowScene = await MainActor.run(body: { UIApplication.shared.connectedScenes.first as? UIWindowScene }),
                   let rootVC = windowScene.windows.first?.rootViewController {
                    try await user.addScopes(missingScopes, presenting: rootVC)
                    if let refreshed = GIDSignIn.sharedInstance.currentUser {
                        user = refreshed
                    }
                }
            }

            // Crea account candidato dal profilo Google
            let candidateAccount = EmailAccount(
                provider: .google,
                email: user.profile?.email ?? "",
                displayName: user.profile?.name,
                photoURL: user.profile?.imageURL(withDimension: 200)?.absoluteString
            )

            let managedAccount = resolveManagedAccount(for: candidateAccount)

            // Salva tokens nel Keychain
            saveTokens(
                accountId: managedAccount.id,
                accessToken: user.accessToken.tokenString,
                refreshToken: user.refreshToken.tokenString,
                expiresAt: user.accessToken.expirationDate
            )

            currentAccount = managedAccount
            isAuthenticated = true

        } catch {
            print("ℹ️ EmailAuthService: No previous Google session")
        }
    }

    /// Autenticazione con Google
    public func authenticateWithGoogle() async throws -> EmailAccount {
        let token = try await oauthService.authenticateWithGoogle()

        let account = EmailAccount(
            provider: .google,
            email: token.email,
            displayName: nil, // TODO: recuperare da Google profile
            photoURL: nil
        )

        let managedAccount = resolveManagedAccount(for: account)

        saveTokens(
            accountId: managedAccount.id,
            accessToken: token.accessToken,
            refreshToken: token.refreshToken,
            expiresAt: token.expiresAt
        )

        currentAccount = managedAccount
        isAuthenticated = true

        return managedAccount
    }

    /// Autenticazione con Microsoft
    public func authenticateWithMicrosoft() async throws -> EmailAccount {
        let token = try await oauthService.authenticateWithMicrosoft()

        let account = EmailAccount(
            provider: .microsoft,
            email: token.email,
            displayName: nil, // TODO: recuperare da Microsoft profile
            photoURL: nil
        )

        let managedAccount = resolveManagedAccount(for: account)

        saveTokens(
            accountId: managedAccount.id,
            accessToken: token.accessToken,
            refreshToken: token.refreshToken,
            expiresAt: token.expiresAt
        )

        currentAccount = managedAccount
        isAuthenticated = true

        return managedAccount
    }

    /// Refresh token se necessario
    public func refreshTokenIfNeeded(for account: EmailAccount) async throws -> EmailAccount {
        guard account.isTokenExpired, account.refreshToken != nil else {
            return account
        }

        let newToken = try await oauthService.refreshToken(for: account)

        // Aggiorna solo i tokens, non l'account
        saveTokens(
            accountId: account.id,
            accessToken: newToken.accessToken,
            refreshToken: newToken.refreshToken,
            expiresAt: newToken.expiresAt
        )

        // Ritorna l'account esistente (i token vengono letti dal Keychain)
        return account
    }

    /// Disconnetti account corrente
    public func disconnect() {
        guard let account = currentAccount else { return }

        accountManager.removeAccount(id: account.id)

        // Aggiorna stato locale
        currentAccount = accountManager.currentAccount
        isAuthenticated = !accountManager.accounts.isEmpty
    }

    /// Verifica e aggiunge scope Gmail se necessari
    public func ensureGmailScopes() async -> Bool {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            return false
        }

        let required = Set(EmailConfig.getProviderConfig(for: .google).scopes)
        let granted = Set(currentUser.grantedScopes ?? [])
        let missing = Array(required.subtracting(granted))

        if missing.isEmpty {
            return true
        }

        do {
            if let windowScene = await MainActor.run(body: { UIApplication.shared.connectedScenes.first as? UIWindowScene }),
               let rootVC = windowScene.windows.first?.rootViewController {
                try await currentUser.addScopes(missing, presenting: rootVC)

                if let account = currentAccount {
                    let updatedUser = GIDSignIn.sharedInstance.currentUser ?? currentUser
                    saveTokens(
                        accountId: account.id,
                        accessToken: updatedUser.accessToken.tokenString,
                        refreshToken: updatedUser.refreshToken.tokenString,
                        expiresAt: updatedUser.accessToken.expirationDate
                    )
                }
                return true
            }
        } catch {
            print("❌ EmailAuthService: Error adding Gmail scopes: \(error)")
        }

        return false
    }

    // MARK: - Private Methods

    private func resolveManagedAccount(for candidate: EmailAccount) -> EmailAccount {
        if let existing = accountManager.accounts.first(where: {
            $0.provider == candidate.provider && $0.email.caseInsensitiveCompare(candidate.email) == .orderedSame
        }) {
            accountManager.switchAccount(to: existing.id)
            return existing
        }

        accountManager.addAccount(candidate)
        accountManager.switchAccount(to: candidate.id)

        return accountManager.currentAccount ?? candidate
    }

    private func saveTokens(accountId: String, accessToken: String, refreshToken: String?, expiresAt: Date?) {
        accountManager.updateTokens(
            accountId: accountId,
            accessToken: accessToken,
            refreshToken: refreshToken
        )

        // Salva anche expiresAt in UserDefaults
        if let expiresAt = expiresAt {
            let key = "email_token_expires_at_\(accountId)"
            UserDefaults.standard.set(expiresAt.timeIntervalSince1970, forKey: key)
        }
    }
}
