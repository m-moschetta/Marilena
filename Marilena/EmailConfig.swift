import Foundation

// MARK: - Email Configuration
// Configurazione per le credenziali OAuth e impostazioni email

public struct EmailConfig {
    
    // MARK: - OAuth Credentials
    // IMPORTANTE: Sostituisci con le tue credenziali reali
    
    // Google OAuth
    public static var googleClientId: String {
        // Prima prova a leggere da Info.plist (per GoogleSignIn)
        if let clientId = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String {
            return clientId
        }
        // Fallback su UserDefaults
        return UserDefaults.standard.string(forKey: "google_client_id") ?? "your-google-client-id"
    }
    
    public static var googleClientSecret: String {
        return KeychainManager.shared.load(key: "google_client_secret") ?? "your-google-client-secret"
    }
    
    public static let googleRedirectURI = "com.marilena.email://oauth/callback"
    
    // Microsoft OAuth
    public static var microsoftClientId: String {
        let clientId = UserDefaults.standard.string(forKey: "microsoft_client_id") ?? "your-microsoft-client-id"
        print("🔧 EmailConfig Debug: Microsoft Client ID = \(clientId)")
        return clientId
    }
    
    public static var microsoftClientSecret: String {
        let clientSecret = KeychainManager.shared.load(key: "microsoft_client_secret") ?? "your-microsoft-client-secret"
        print("🔧 EmailConfig Debug: Microsoft Client Secret = \(clientSecret)")
        return clientSecret
    }
    
    public static let microsoftRedirectURI = "com.marilena.email://oauth/callback"
    
    // MARK: - Email Providers Configuration
    
    public static let gmailIMAPHost = "imap.gmail.com"
    public static let gmailIMAPPort = 993
    public static let gmailSMTPHost = "smtp.gmail.com"
    public static let gmailSMTPPort = 587
    
    public static let outlookIMAPHost = "outlook.office365.com"
    public static let outlookIMAPPort = 993
    public static let outlookSMTPHost = "smtp.office365.com"
    public static let outlookSMTPPort = 587
    
    // MARK: - AI Configuration
    
    public static let defaultAIModel = "gpt-4o-mini"
    public static let defaultMaxTokens = 1000
    public static let defaultTemperature = 0.7
    
    // MARK: - App Configuration
    
    public static let appBundleIdentifier = "com.marilena.email"
    public static let appName = "Marilena Email"
    
    // MARK: - Privacy & Security
    
    public static let dataRetentionDays = 30
    public static let maxEmailCacheSize = 100 // MB
    public static let enableEmailEncryption = true
    
    // MARK: - UI Configuration
    
    public static let maxEmailsPerPage = 50
    public static let refreshInterval = 300 // seconds
    public static let enablePushNotifications = true
    
    // MARK: - Validation Methods
    
    public static func validateGoogleCredentials() -> Bool {
        return googleClientId != "your-google-client-id" && 
               googleClientSecret != "your-google-client-secret"
    }
    
    public static func validateMicrosoftCredentials() -> Bool {
        return microsoftClientId != "your-microsoft-client-id" && 
               microsoftClientSecret != "your-microsoft-client-secret"
    }
    
    public static func hasValidCredentials() -> Bool {
        return validateGoogleCredentials() || validateMicrosoftCredentials()
    }
    
    // MARK: - Provider Configuration
    
    public static func getProviderConfig(for provider: EmailProvider) -> ProviderConfig {
        switch provider {
        case .google:
            return ProviderConfig(
                name: "Gmail",
                imapHost: gmailIMAPHost,
                imapPort: gmailIMAPPort,
                smtpHost: gmailSMTPHost,
                smtpPort: gmailSMTPPort,
                oauthEndpoint: "https://accounts.google.com/oauth/authorize",
                tokenEndpoint: "https://oauth2.googleapis.com/token",
                clientId: googleClientId,
                clientSecret: googleClientSecret,
                redirectURI: googleRedirectURI,
                scopes: [
                    "https://mail.google.com/",
                    "https://www.googleapis.com/auth/gmail.readonly",
                    "https://www.googleapis.com/auth/gmail.modify",
                    "https://www.googleapis.com/auth/userinfo.email",
                    "https://www.googleapis.com/auth/gmail.send",
                    "https://www.googleapis.com/auth/gmail.compose"
                ]
            )
        case .microsoft:
            return ProviderConfig(
                name: "Outlook",
                imapHost: outlookIMAPHost,
                imapPort: outlookIMAPPort,
                smtpHost: outlookSMTPHost,
                smtpPort: outlookSMTPPort,
                oauthEndpoint: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
                tokenEndpoint: "https://login.microsoftonline.com/common/oauth2/v2.0/token",
                clientId: microsoftClientId,
                clientSecret: microsoftClientSecret,
                redirectURI: microsoftRedirectURI,
                scopes: [
                    "https://graph.microsoft.com/Mail.Read",
                    "https://graph.microsoft.com/Mail.Send",
                    "https://graph.microsoft.com/User.Read",
                    "https://graph.microsoft.com/Mail.ReadWrite"
                ]
            )
        }
    }
}

// MARK: - Provider Configuration

public struct ProviderConfig {
    public let name: String
    public let imapHost: String
    public let imapPort: Int
    public let smtpHost: String
    public let smtpPort: Int
    public let oauthEndpoint: String
    public let tokenEndpoint: String
    public let clientId: String
    public let clientSecret: String
    public let redirectURI: String
    public let scopes: [String]
    
    public init(
        name: String,
        imapHost: String,
        imapPort: Int,
        smtpHost: String,
        smtpPort: Int,
        oauthEndpoint: String,
        tokenEndpoint: String,
        clientId: String,
        clientSecret: String,
        redirectURI: String,
        scopes: [String]
    ) {
        self.name = name
        self.imapHost = imapHost
        self.imapPort = imapPort
        self.smtpHost = smtpHost
        self.smtpPort = smtpPort
        self.oauthEndpoint = oauthEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
        self.scopes = scopes
    }
}

// MARK: - Privacy Configuration

public struct PrivacyConfig {
    public static let dataProcessingPurpose = "Funzionalità dell'App"
    public static let dataLinkage = "Dati collegati all'utente"
    public static let dataTypes = [
        "Email o Messaggi di Testo",
        "Contenuti dell'Utente"
    ]
    
    public static let privacyPolicyURL = "https://your-app.com/privacy"
    public static let termsOfServiceURL = "https://your-app.com/terms"
    
    public static let gdprCompliant = true
    public static let dataRetentionPolicy = "I dati email vengono conservati solo localmente e non vengono condivisi con terze parti"
    
    public static let aiDataUsage = """
    I contenuti delle email vengono inviati ai servizi AI (OpenAI/Anthropic) per:
    - Generazione di bozze di risposta
    - Analisi del contenuto
    - Categorizzazione automatica
    
    I dati non vengono utilizzati per addestrare i modelli AI.
    """
} 
