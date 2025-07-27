import Foundation
import Combine
import Security

// MARK: - Email Service
// Servizio principale per la gestione delle email con autenticazione OAuth e sincronizzazione IMAP

@MainActor
public class EmailService: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isAuthenticated = false
    @Published public var isLoading = false
    @Published public var error: String?
    @Published public var emails: [EmailMessage] = []
    @Published public var currentAccount: EmailAccount?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let keychainManager = KeychainManager.shared
    
    // MARK: - OAuth Configuration
    private let googleClientId = "your-google-client-id"
    private let googleClientSecret = "your-google-client-secret"
    private let microsoftClientId = "your-microsoft-client-id"
    private let microsoftClientSecret = "your-microsoft-client-secret"
    
    // MARK: - Email Providers
    private let gmailIMAPHost = "imap.gmail.com"
    private let gmailIMAPPort = 993
    private let outlookIMAPHost = "outlook.office365.com"
    private let outlookIMAPPort = 993
    
    // MARK: - Initialization
    
    public init() {
        loadSavedAccount()
    }
    
    // MARK: - Public Methods
    
    /// Avvia il processo di autenticazione OAuth per Google
    public func authenticateWithGoogle() async {
        isLoading = true
        error = nil
        
        do {
            let authURL = createGoogleAuthURL()
            let token = try await performOAuthFlow(url: authURL, provider: .google)
            
            let account = EmailAccount(
                provider: .google,
                email: token.email,
                accessToken: token.accessToken,
                refreshToken: token.refreshToken,
                expiresAt: token.expiresAt
            )
            
            await saveAccount(account)
            await loadEmails(for: account)
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Avvia il processo di autenticazione OAuth per Microsoft
    public func authenticateWithMicrosoft() async {
        isLoading = true
        error = nil
        
        do {
            let authURL = createMicrosoftAuthURL()
            let token = try await performOAuthFlow(url: authURL, provider: .microsoft)
            
            let account = EmailAccount(
                provider: .microsoft,
                email: token.email,
                accessToken: token.accessToken,
                refreshToken: token.refreshToken,
                expiresAt: token.expiresAt
            )
            
            await saveAccount(account)
            await loadEmails(for: account)
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Carica le email per l'account specificato
    public func loadEmails(for account: EmailAccount) async {
        isLoading = true
        error = nil
        
        do {
            let imapClient = try createIMAPClient(for: account)
            let messages = try await imapClient.fetchMessages(folder: "INBOX", limit: 50)
            
            self.emails = messages
            self.currentAccount = account
            self.isAuthenticated = true
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Aggiorna il token di accesso se necessario
    public func refreshTokenIfNeeded() async {
        guard let account = currentAccount,
              let refreshToken = account.refreshToken,
              account.isTokenExpired else { return }
        
        do {
            let newToken = try await refreshAccessToken(for: account)
            let updatedAccount = EmailAccount(
                provider: account.provider,
                email: account.email,
                accessToken: newToken.accessToken,
                refreshToken: newToken.refreshToken,
                expiresAt: newToken.expiresAt
            )
            
            await saveAccount(updatedAccount)
            self.currentAccount = updatedAccount
            
        } catch {
            self.error = "Errore aggiornamento token: \(error.localizedDescription)"
        }
    }
    
    /// Disconnetti l'account corrente
    public func disconnect() {
        currentAccount = nil
        isAuthenticated = false
        emails.removeAll()
        keychainManager.deleteAPIKey(for: "email_access_token")
        keychainManager.deleteAPIKey(for: "email_refresh_token")
    }
    
    // MARK: - Private Methods
    
    private func createGoogleAuthURL() -> URL {
        var components = URLComponents(string: "https://accounts.google.com/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: googleClientId),
            URLQueryItem(name: "redirect_uri", value: "com.marilena.email://oauth/callback"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "https://mail.google.com/ https://www.googleapis.com/auth/userinfo.email"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components.url!
    }
    
    private func createMicrosoftAuthURL() -> URL {
        var components = URLComponents(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: microsoftClientId),
            URLQueryItem(name: "redirect_uri", value: "com.marilena.email://oauth/callback"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "https://graph.microsoft.com/Mail.Read https://graph.microsoft.com/User.Read"),
            URLQueryItem(name: "response_mode", value: "query")
        ]
        return components.url!
    }
    
    private func performOAuthFlow(url: URL, provider: EmailProvider) async throws -> OAuthToken {
        // Implementazione del flusso OAuth
        // Questo è un placeholder - l'implementazione completa richiede gestione URL scheme
        throw EmailError.oauthNotImplemented
    }
    
    private func createIMAPClient(for account: EmailAccount) throws -> IMAPClient {
        let host: String
        let port: Int
        
        switch account.provider {
        case .google:
            host = gmailIMAPHost
            port = gmailIMAPPort
        case .microsoft:
            host = outlookIMAPHost
            port = outlookIMAPPort
        }
        
        return IMAPClient(host: host, port: port, accessToken: account.accessToken)
    }
    
    private func refreshAccessToken(for account: EmailAccount) async throws -> OAuthToken {
        // Implementazione del refresh token
        throw EmailError.oauthNotImplemented
    }
    
    private func saveAccount(_ account: EmailAccount) async {
        keychainManager.saveAPIKey(account.accessToken, for: "email_access_token")
        if let refreshToken = account.refreshToken {
            keychainManager.saveAPIKey(refreshToken, for: "email_refresh_token")
        }
        
        // Salva anche in UserDefaults per informazioni non sensibili
        UserDefaults.standard.set(account.email, forKey: "email_account")
        UserDefaults.standard.set(account.provider.rawValue, forKey: "email_provider")
    }
    
    private func loadSavedAccount() {
        guard let email = UserDefaults.standard.string(forKey: "email_account"),
              let providerString = UserDefaults.standard.string(forKey: "email_provider"),
              let provider = EmailProvider(rawValue: providerString),
              let accessToken = keychainManager.getAPIKey(for: "email_access_token") else {
            return
        }
        
        let refreshToken = keychainManager.getAPIKey(for: "email_refresh_token")
        
        let account = EmailAccount(
            provider: provider,
            email: email,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: nil // TODO: Salvare expiresAt
        )
        
        self.currentAccount = account
        self.isAuthenticated = true
    }
}

// MARK: - Supporting Types

public struct EmailAccount {
    public let provider: EmailProvider
    public let email: String
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date?
    
    public var isTokenExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
}

public enum EmailProvider: String, CaseIterable {
    case google = "google"
    case microsoft = "microsoft"
    
    public var displayName: String {
        switch self {
        case .google:
            return "Gmail"
        case .microsoft:
            return "Outlook"
        }
    }
    
    public var iconName: String {
        switch self {
        case .google:
            return "envelope.circle.fill"
        case .microsoft:
            return "envelope.badge.fill"
        }
    }
}

public struct EmailMessage: Identifiable, Codable {
    public let id: String
    public let from: String
    public let to: [String]
    public let subject: String
    public let body: String
    public let date: Date
    public let isRead: Bool
    public let hasAttachments: Bool
    
    public init(
        id: String,
        from: String,
        to: [String],
        subject: String,
        body: String,
        date: Date,
        isRead: Bool = false,
        hasAttachments: Bool = false
    ) {
        self.id = id
        self.from = from
        self.to = to
        self.subject = subject
        self.body = body
        self.date = date
        self.isRead = isRead
        self.hasAttachments = hasAttachments
    }
}

public struct OAuthToken {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date?
    public let email: String
}

public enum EmailError: LocalizedError {
    case oauthNotImplemented
    case invalidCredentials
    case networkError(String)
    case imapConnectionFailed
    case tokenExpired
    
    public var errorDescription: String? {
        switch self {
        case .oauthNotImplemented:
            return "Autenticazione OAuth non ancora implementata"
        case .invalidCredentials:
            return "Credenziali non valide"
        case .networkError(let message):
            return "Errore di rete: \(message)"
        case .imapConnectionFailed:
            return "Impossibile connettersi al server IMAP"
        case .tokenExpired:
            return "Token di accesso scaduto"
        }
    }
} 