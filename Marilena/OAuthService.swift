import Foundation
import AuthenticationServices
import SafariServices
import Combine

// MARK: - OAuth Service
// Servizio per gestire l'autenticazione OAuth con Google e Microsoft

@MainActor
public class OAuthService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isAuthenticating = false
    @Published public var error: String?
    
    // MARK: - Private Properties
    private var authSession: ASWebAuthenticationSession?
    private let keychainManager = KeychainManager.shared
    
    // MARK: - OAuth Configuration
    // Le credenziali sono gestite tramite EmailConfig
    
    // MARK: - Initialization
    public override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Avvia il flusso OAuth per Google
    public func authenticateWithGoogle() async throws -> OAuthToken {
        isAuthenticating = true
        error = nil
        
        // Debug: Mostra le credenziali attuali
        print("🔧 OAuth Debug: Verifica credenziali Google")
        print("🔧 OAuth Debug: Client ID = \(EmailConfig.googleClientId)")
        print("🔧 OAuth Debug: Client Secret = \(EmailConfig.googleClientSecret)")
        
        defer { isAuthenticating = false }
        
        let authURL = createGoogleAuthURL()
        return try await performOAuthFlow(url: authURL, provider: .google)
    }
    
    /// Avvia il flusso OAuth per Microsoft
    public func authenticateWithMicrosoft() async throws -> OAuthToken {
        isAuthenticating = true
        error = nil
        
        // Debug: Mostra le credenziali attuali
        print("🔧 OAuth Debug: Verifica credenziali Microsoft")
        print("🔧 OAuth Debug: Client ID = \(EmailConfig.microsoftClientId)")
        print("🔧 OAuth Debug: Client Secret = \(EmailConfig.microsoftClientSecret)")
        
        defer { isAuthenticating = false }
        
        let authURL = createMicrosoftAuthURL()
        return try await performOAuthFlow(url: authURL, provider: .microsoft)
    }
    
    /// Aggiorna un token di accesso scaduto
    public func refreshToken(for account: EmailAccount) async throws -> OAuthToken {
        guard let refreshToken = account.refreshToken else {
            throw OAuthError.noRefreshToken
        }
        
        let config = EmailConfig.getProviderConfig(for: account.provider)
        
        var request = URLRequest(url: URL(string: config.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "client_id": config.clientId,
            "client_secret": config.clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        
        let bodyString = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OAuthError.tokenRefreshFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        return OAuthToken(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
            email: account.email
        )
    }
    
    // MARK: - Private Methods
    
    private func createGoogleAuthURL() -> URL {
        let config = EmailConfig.getProviderConfig(for: .google)
        var components = URLComponents(string: config.oauthEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components.url!
    }
    
    private func createMicrosoftAuthURL() -> URL {
        let config = EmailConfig.getProviderConfig(for: .microsoft)
        var components = URLComponents(string: config.oauthEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "response_mode", value: "query")
        ]
        return components.url!
    }
    
    private func performOAuthFlow(url: URL, provider: EmailProvider) async throws -> OAuthToken {
        return try await withCheckedThrowingContinuation { continuation in
            authSession = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "com.marilena.email"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: OAuthError.authenticationFailed(error))
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: OAuthError.noCallbackURL)
                    return
                }
                
                Task {
                    do {
                        let token = try await self.exchangeCodeForToken(callbackURL: callbackURL, provider: provider)
                        continuation.resume(returning: token)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            authSession?.presentationContextProvider = self
            authSession?.prefersEphemeralWebBrowserSession = true
            authSession?.start()
        }
    }
    
    private func exchangeCodeForToken(callbackURL: URL, provider: EmailProvider) async throws -> OAuthToken {
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value else {
            print("❌ OAuth Error: No authorization code found in callback URL")
            throw OAuthError.invalidCallbackURL
        }
        
        let config = EmailConfig.getProviderConfig(for: provider)
        
        // Verifica che le credenziali siano configurate
        if provider == .microsoft {
            guard config.clientId != "your-microsoft-client-id" && config.clientSecret != "your-microsoft-client-secret" else {
                print("❌ OAuth Error: Credenziali Microsoft non configurate")
                print("❌ OAuth Error: Client ID = \(config.clientId)")
                print("❌ OAuth Error: Client Secret = \(config.clientSecret)")
                throw OAuthError.credentialsNotConfigured
            }
        } else if provider == .google {
            guard config.clientId != "your-google-client-id" && config.clientSecret != "your-google-client-secret" else {
                print("❌ OAuth Error: Credenziali Google non configurate")
                print("❌ OAuth Error: Client ID = \(config.clientId)")
                print("❌ OAuth Error: Client Secret = \(config.clientSecret)")
                throw OAuthError.credentialsNotConfigured
            }
        }
        
        print("🔧 OAuth Debug: Client ID = \(config.clientId)")
        print("🔧 OAuth Debug: Token Endpoint = \(config.tokenEndpoint)")
        print("🔧 OAuth Debug: Redirect URI = \(config.redirectURI)")
        
        var request = URLRequest(url: URL(string: config.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Per app pubbliche, non inviare il client_secret
        let parameters = [
            "client_id": config.clientId,
            "code": code,
            "redirect_uri": config.redirectURI,
            "grant_type": "authorization_code"
        ]
        
        // Per le app pubbliche (come le app mobile), NON inviare mai il client_secret
        // Microsoft richiede che le app pubbliche non inviino il client_secret
        print("🔧 OAuth Debug: Client secret NON aggiunto (app pubblica - Microsoft)")
        
        // Se in futuro avremo bisogno di app confidential, possiamo aggiungere una flag
        // if isConfidentialApp && !config.clientSecret.isEmpty {
        //     parameters["client_secret"] = config.clientSecret
        // }
        
        let bodyString = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        print("🔧 OAuth Debug: Request body = \(bodyString)")
        request.httpBody = bodyString.data(using: .utf8)
        
        print("🔧 OAuth Debug: Sending token request to \(config.tokenEndpoint)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ OAuth Error: Invalid HTTP response")
            throw OAuthError.tokenExchangeFailed
        }
        
                print("🔧 OAuth Debug: HTTP Status Code = \(httpResponse.statusCode)")
        
        // Debug: Mostra la risposta completa
        let responseString = String(data: data, encoding: .utf8) ?? "Unknown response"
        print("🔧 OAuth Debug: Response body = \(responseString)")

        if httpResponse.statusCode != 200 {
            print("❌ OAuth Error: Token exchange failed with status \(httpResponse.statusCode)")
            throw OAuthError.tokenExchangeFailed
        }
        
        do {
            print("🔧 OAuth Debug: Tentativo di parsing JSON...")
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            print("✅ OAuth Success: Token ottenuto con successo")
            print("🔧 OAuth Debug: Access Token = \(tokenResponse.accessToken.prefix(20))...")
            print("🔧 OAuth Debug: Token Type = \(tokenResponse.tokenType)")
            print("🔧 OAuth Debug: Expires In = \(tokenResponse.expiresIn)")
            
            // Ottieni l'email dell'utente
            let email = try await getUserEmail(accessToken: tokenResponse.accessToken, provider: provider)
        
                    return OAuthToken(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
                email: email
            )
        } catch {
            print("❌ OAuth Error: Errore nel parsing della risposta JSON")
            print("❌ OAuth Error: \(error)")
            throw OAuthError.tokenExchangeFailed
        }
    }
    
    private func getUserEmail(accessToken: String, provider: EmailProvider) async throws -> String {
        let url: URL
        let headers: [String: String]
        
        switch provider {
        case .google:
            url = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!
            headers = ["Authorization": "Bearer \(accessToken)"]
        case .microsoft:
            url = URL(string: "https://graph.microsoft.com/v1.0/me")!
            headers = ["Authorization": "Bearer \(accessToken)"]
        }
        
        var request = URLRequest(url: url)
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        print("🔧 OAuth Debug: Richiesta info utente a \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ OAuth Error: Invalid HTTP response for user info")
            throw OAuthError.userInfoFailed
        }
        
        print("🔧 OAuth Debug: User info HTTP Status = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ OAuth Error: User info failed with status \(httpResponse.statusCode)")
            print("❌ OAuth Error: User info response = \(errorResponse)")
            throw OAuthError.userInfoFailed
        }
        
        // Debug: Mostra la risposta completa
        let responseString = String(data: data, encoding: .utf8) ?? "Unknown response"
        print("🔧 OAuth Debug: User info response = \(responseString)")
        
        do {
            let userInfo = try JSONDecoder().decode(UserInfo.self, from: data)
            print("✅ OAuth Success: Email ottenuta = \(userInfo.email)")
            return userInfo.email
        } catch {
            print("❌ OAuth Error: Errore nel parsing user info JSON")
            print("❌ OAuth Error: \(error)")
            throw OAuthError.userInfoFailed
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension OAuthService: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available for OAuth presentation")
        }
        return window
    }
}

// MARK: - Supporting Types

public struct OAuthToken {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date?
    public let email: String
}

private struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

private struct UserInfo: Codable {
    let email: String
    
    enum CodingKeys: String, CodingKey {
        case email
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Microsoft Graph usa "mail", Google usa "email"
        if let mail = try? container.decode(String.self, forKey: .email) {
            self.email = mail
        } else {
            // Prova con "mail" per Microsoft
            let mailContainer = try decoder.container(keyedBy: MailCodingKeys.self)
            self.email = try mailContainer.decode(String.self, forKey: .mail)
        }
    }
    
    private enum MailCodingKeys: String, CodingKey {
        case mail
    }
}

public enum OAuthError: LocalizedError {
    case authenticationFailed(Error)
    case noCallbackURL
    case invalidCallbackURL
    case tokenExchangeFailed
    case userInfoFailed
    case noRefreshToken
    case tokenRefreshFailed
    case credentialsNotConfigured
    
    public var errorDescription: String? {
        switch self {
        case .authenticationFailed(let error):
            return "Errore di autenticazione: \(error.localizedDescription)"
        case .noCallbackURL:
            return "Nessun URL di callback ricevuto"
        case .invalidCallbackURL:
            return "URL di callback non valido"
        case .tokenExchangeFailed:
            return "Errore nello scambio del codice per il token"
        case .userInfoFailed:
            return "Errore nel recupero delle informazioni utente"
        case .noRefreshToken:
            return "Nessun refresh token disponibile"
        case .tokenRefreshFailed:
            return "Errore nell'aggiornamento del token"
        case .credentialsNotConfigured:
            return "Credenziali OAuth non configurate. Vai su Impostazioni → Email OAuth Configuration"
        }
    }
} 