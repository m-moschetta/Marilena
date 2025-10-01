import Foundation
import Combine
import GoogleSignIn
import AuthenticationServices

/// Servizio dedicato all'autenticazione OAuth
@MainActor
public final class EmailAuthService: ObservableObject {

    // MARK: - Published Properties
    @Published public private(set) var currentAccount: EmailAccount?
    @Published public private(set) var isAuthenticated = false

    // MARK: - Private Properties
    private let keychainManager = KeychainManager.shared
    private let oauthService = OAuthService()

    // MARK: - Initialization
    public init() {
        loadSavedAccount()
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

            let account = EmailAccount(
                provider: .google,
                email: user.profile?.email ?? "",
                accessToken: user.accessToken.tokenString,
                refreshToken: user.refreshToken.tokenString,
                expiresAt: user.accessToken.expirationDate
            )

            await saveAccount(account)

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
            accessToken: token.accessToken,
            refreshToken: token.refreshToken,
            expiresAt: token.expiresAt
        )

        await saveAccount(account)
        return account
    }

    /// Autenticazione con Microsoft
    public func authenticateWithMicrosoft() async throws -> EmailAccount {
        let token = try await oauthService.authenticateWithMicrosoft()

        let account = EmailAccount(
            provider: .microsoft,
            email: token.email,
            accessToken: token.accessToken,
            refreshToken: token.refreshToken,
            expiresAt: token.expiresAt
        )

        await saveAccount(account)
        return account
    }

    /// Refresh token se necessario
    public func refreshTokenIfNeeded(for account: EmailAccount) async throws -> EmailAccount {
        guard account.isTokenExpired, account.refreshToken != nil else {
            return account
        }

        let newToken = try await oauthService.refreshToken(for: account)
        let updatedAccount = EmailAccount(
            provider: account.provider,
            email: account.email,
            accessToken: newToken.accessToken,
            refreshToken: newToken.refreshToken,
            expiresAt: newToken.expiresAt
        )

        await saveAccount(updatedAccount)
        return updatedAccount
    }

    /// Disconnetti account
    public func disconnect() {
        currentAccount = nil
        isAuthenticated = false

        _ = keychainManager.deleteAPIKey(for: "email_access_token")
        _ = keychainManager.deleteAPIKey(for: "email_refresh_token")

        UserDefaults.standard.removeObject(forKey: "email_account")
        UserDefaults.standard.removeObject(forKey: "email_provider")
        UserDefaults.standard.removeObject(forKey: "email_token_expires_at")
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
                    let updatedAccount = EmailAccount(
                        provider: account.provider,
                        email: account.email,
                        accessToken: updatedUser.accessToken.tokenString,
                        refreshToken: updatedUser.refreshToken.tokenString,
                        expiresAt: updatedUser.accessToken.expirationDate
                    )
                    await saveAccount(updatedAccount)
                }
                return true
            }
        } catch {
            print("❌ EmailAuthService: Error adding Gmail scopes: \(error)")
        }

        return false
    }

    // MARK: - Private Methods

    private func saveAccount(_ account: EmailAccount) async {
        _ = keychainManager.saveAPIKey(account.accessToken, for: "email_access_token")
        if let refreshToken = account.refreshToken {
            _ = keychainManager.saveAPIKey(refreshToken, for: "email_refresh_token")
        }

        UserDefaults.standard.set(account.email, forKey: "email_account")
        UserDefaults.standard.set(account.provider.rawValue, forKey: "email_provider")

        if let expiresAt = account.expiresAt {
            UserDefaults.standard.set(expiresAt.timeIntervalSince1970, forKey: "email_token_expires_at")
        }

        currentAccount = account
        isAuthenticated = true
    }

    private func loadSavedAccount() {
        guard let email = UserDefaults.standard.string(forKey: "email_account"),
              let providerString = UserDefaults.standard.string(forKey: "email_provider"),
              let provider = EmailProvider(rawValue: providerString),
              let accessToken = keychainManager.getAPIKey(for: "email_access_token") else {
            return
        }

        let refreshToken = keychainManager.getAPIKey(for: "email_refresh_token")

        var expiresAt: Date?
        if let expiresInterval = UserDefaults.standard.object(forKey: "email_token_expires_at") as? TimeInterval {
            expiresAt = Date(timeIntervalSince1970: expiresInterval)
        }

        let account = EmailAccount(
            provider: provider,
            email: email,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt
        )

        currentAccount = account
        isAuthenticated = true
    }
}
