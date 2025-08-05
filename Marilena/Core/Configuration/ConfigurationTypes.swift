import Foundation

// MARK: - Configuration Types

/// AI Configuration settings for all providers and models
public struct AIConfiguration: Codable {
    public let selectedProvider: AIModelProvider
    public let openAIModel: String
    public let anthropicModel: String
    public let perplexityModel: String
    public let groqModel: String
    public let temperature: Double
    public let maxTokens: Int
    public let timeout: TimeInterval
    public let enableFunctionCalling: Bool
    public let enableStreaming: Bool
    public let enableCaching: Bool
    
    public init(
        selectedProvider: AIModelProvider = .openai,
        openAIModel: String = "gpt-4.1",
        anthropicModel: String = "claude-4-sonnet",
        perplexityModel: String = "sonar-pro",
        groqModel: String = "llama-4-maverick",
        temperature: Double = 0.7,
        maxTokens: Int = 4000,
        timeout: TimeInterval = 30.0,
        enableFunctionCalling: Bool = true,
        enableStreaming: Bool = true,
        enableCaching: Bool = true
    ) {
        self.selectedProvider = selectedProvider
        self.openAIModel = openAIModel
        self.anthropicModel = anthropicModel
        self.perplexityModel = perplexityModel
        self.groqModel = groqModel
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.timeout = timeout
        self.enableFunctionCalling = enableFunctionCalling
        self.enableStreaming = enableStreaming
        self.enableCaching = enableCaching
    }
    
    public static let `default` = AIConfiguration()
}

/// Email-specific configuration settings
public struct EmailConfiguration: Codable {
    public let autoCreateChat: Bool
    public let autoCategorize: Bool
    public let fetchInterval: TimeInterval
    public let maxEmailsPerFetch: Int
    public let enableSmartReply: Bool
    public let aiCategorizationLimit: Int
    public let prompts: EmailPrompts
    public let notifications: EmailNotifications
    
    public init(
        autoCreateChat: Bool = true,
        autoCategorize: Bool = true,
        fetchInterval: TimeInterval = 300,
        maxEmailsPerFetch: Int = 50,
        enableSmartReply: Bool = true,
        aiCategorizationLimit: Int = 50,
        prompts: EmailPrompts = .default,
        notifications: EmailNotifications = .default
    ) {
        self.autoCreateChat = autoCreateChat
        self.autoCategorize = autoCategorize
        self.fetchInterval = fetchInterval
        self.maxEmailsPerFetch = maxEmailsPerFetch
        self.enableSmartReply = enableSmartReply
        self.aiCategorizationLimit = aiCategorizationLimit
        self.prompts = prompts
        self.notifications = notifications
    }
    
    public static let `default` = EmailConfiguration()
}

/// Email prompts configuration for AI assistance
public struct EmailPrompts: Codable {
    public let analysisPrompt: String
    public let responsePrompt: String
    public let categorizationPrompt: String
    public let summarizationPrompt: String
    public let toneInstructions: [String: String]
    
    public init(
        analysisPrompt: String = defaultAnalysisPrompt,
        responsePrompt: String = defaultResponsePrompt,
        categorizationPrompt: String = defaultCategorizationPrompt,
        summarizationPrompt: String = defaultSummarizationPrompt,
        toneInstructions: [String: String] = defaultToneInstructions
    ) {
        self.analysisPrompt = analysisPrompt
        self.responsePrompt = responsePrompt
        self.categorizationPrompt = categorizationPrompt
        self.summarizationPrompt = summarizationPrompt
        self.toneInstructions = toneInstructions
    }
    
    public static let `default` = EmailPrompts()
    
    // MARK: - Default Prompts
    
    public static let defaultAnalysisPrompt = """
    Analizza questa email e fornisci:
    1. Categoria (Work, Personal, Notifications, Promotional/Spam)
    2. Urgenza (Alta, Media, Bassa)
    3. Tono (Formale, Informale, Neutro, Urgente)
    4. Punti chiave
    5. Azioni richieste
    
    Email: {EMAIL_CONTENT}
    """
    
    public static let defaultResponsePrompt = """
    Basandoti sull'email ricevuta, scrivi una risposta appropriata in italiano.
    
    Considera:
    - Il tono dell'email originale
    - Il contesto e la relazione con il mittente
    - Eventuali azioni o informazioni richieste
    - Mantieni un tono professionale ma cordiale
    
    Email originale: {EMAIL_CONTENT}
    Analisi: {EMAIL_ANALYSIS}
    
    Risposta suggerita:
    """
    
    public static let defaultCategorizationPrompt = """
    Classifica questa email in una delle seguenti categorie:
    - Work: Email di lavoro, progetti, meeting, collaborazioni
    - Personal: Email personali, famiglia, amici
    - Notifications: Notifiche, alert, conferme, newsletter
    - Promotional: Pubblicità, spam, offerte commerciali
    
    Email: {EMAIL_CONTENT}
    Categoria:
    """
    
    public static let defaultSummarizationPrompt = """
    Riassumi questa email in 2-3 frasi catturando i punti essenziali:
    
    Email: {EMAIL_CONTENT}
    
    Riassunto:
    """
    
    public static let defaultToneInstructions = [
        "formal": "Mantieni un tono formale e professionale",
        "casual": "Usa un tono informale e amichevole",
        "brief": "Sii conciso e vai dritto al punto",
        "detailed": "Fornisci una risposta dettagliata e completa",
        "neutral": "Mantieni un tono neutro e oggettivo"
    ]
}

/// Email notification settings
public struct EmailNotifications: Codable {
    public let enablePushNotifications: Bool
    public let enableSoundAlerts: Bool
    public let enableBadgeUpdates: Bool
    public let enableChatNotifications: Bool
    public let notificationCategories: [String]
    public let quietHours: QuietHours?
    
    public init(
        enablePushNotifications: Bool = true,
        enableSoundAlerts: Bool = true,
        enableBadgeUpdates: Bool = true,
        enableChatNotifications: Bool = true,
        notificationCategories: [String] = ["Work", "Personal"],
        quietHours: QuietHours? = nil
    ) {
        self.enablePushNotifications = enablePushNotifications
        self.enableSoundAlerts = enableSoundAlerts
        self.enableBadgeUpdates = enableBadgeUpdates
        self.enableChatNotifications = enableChatNotifications
        self.notificationCategories = notificationCategories
        self.quietHours = quietHours
    }
    
    public static let `default` = EmailNotifications()
}

/// Quiet hours configuration
public struct QuietHours: Codable {
    public let enabled: Bool
    public let startHour: Int
    public let startMinute: Int
    public let endHour: Int
    public let endMinute: Int
    public let daysOfWeek: [Int] // 1 = Sunday, 2 = Monday, etc.
    
    public init(
        enabled: Bool = false,
        startHour: Int = 22,
        startMinute: Int = 0,
        endHour: Int = 8,
        endMinute: Int = 0,
        daysOfWeek: [Int] = Array(1...7)
    ) {
        self.enabled = enabled
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.daysOfWeek = daysOfWeek
    }
}

/// API endpoints and service configuration
public struct AppAPIConfiguration: Codable {
    public let endpoints: [String: String]
    public let apiKeys: [String: String]
    public let timeouts: [String: TimeInterval]
    public let rateLimits: [String: RateLimit]
    public let retryPolicies: [String: RetryPolicy]
    
    public init(
        endpoints: [String: String],
        apiKeys: [String: String] = [:],
        timeouts: [String: TimeInterval] = [:],
        rateLimits: [String: RateLimit] = [:],
        retryPolicies: [String: RetryPolicy] = [:]
    ) {
        self.endpoints = endpoints
        self.apiKeys = apiKeys
        self.timeouts = timeouts
        self.rateLimits = rateLimits
        self.retryPolicies = retryPolicies
    }
    
    public static func `default`(for environment: AppEnvironment) -> AppAPIConfiguration {
        switch environment {
        case .development:
            return AppAPIConfiguration(endpoints: developmentEndpoints)
        case .staging:
            return AppAPIConfiguration(endpoints: stagingEndpoints)
        case .production:
            return AppAPIConfiguration(endpoints: productionEndpoints)
        }
    }
    
    // MARK: - Environment Endpoints
    
    private static let developmentEndpoints = [
        "openai": "https://api.openai.com/v1",
        "anthropic": "https://api.anthropic.com/v1",
        "google": "https://generativelanguage.googleapis.com/v1",
        "meta": "https://api.llama-api.com/v1",
        "xai": "https://api.x.ai/v1",
        "perplexity": "https://api.perplexity.ai",
        "groq": "https://api.groq.com/openai/v1",
        "email": "https://graph.microsoft.com/v1.0",
        "gmail": "https://gmail.googleapis.com/gmail/v1"
    ]
    
    private static let stagingEndpoints = developmentEndpoints // Same for now
    
    private static let productionEndpoints = developmentEndpoints // Same for now
}

/// Rate limiting configuration
public struct RateLimit: Codable {
    public let requestsPerMinute: Int
    public let tokensPerMinute: Int?
    public let burstLimit: Int?
    
    public init(requestsPerMinute: Int, tokensPerMinute: Int? = nil, burstLimit: Int? = nil) {
        self.requestsPerMinute = requestsPerMinute
        self.tokensPerMinute = tokensPerMinute
        self.burstLimit = burstLimit
    }
}

/// Retry policy configuration
public struct RetryPolicy: Codable {
    public let maxRetries: Int
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let exponentialBackoff: Bool
    
    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 10.0,
        exponentialBackoff: Bool = true
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.exponentialBackoff = exponentialBackoff
    }
}

/// UI configuration and preferences
public struct UIConfiguration: Codable {
    public let theme: AppTheme
    public let primaryColor: String
    public let accentColor: String
    public let fontSize: FontSize
    public let animations: AnimationSettings
    public let hapticFeedback: HapticSettings
    public let accessibility: AccessibilitySettings
    
    public init(
        theme: AppTheme = .system,
        primaryColor: String = "#007AFF",
        accentColor: String = "#FF9500",
        fontSize: FontSize = .medium,
        animations: AnimationSettings = .default,
        hapticFeedback: HapticSettings = .default,
        accessibility: AccessibilitySettings = .default
    ) {
        self.theme = theme
        self.primaryColor = primaryColor
        self.accentColor = accentColor
        self.fontSize = fontSize
        self.animations = animations
        self.hapticFeedback = hapticFeedback
        self.accessibility = accessibility
    }
    
    public static let `default` = UIConfiguration()
}

public enum AppTheme: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    public var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

public enum FontSize: String, Codable, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case extraLarge = "extra_large"
    
    public var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }
    
    public var scaleFactor: CGFloat {
        switch self {
        case .small: return 0.8
        case .medium: return 1.0
        case .large: return 1.2
        case .extraLarge: return 1.4
        }
    }
}

public struct AnimationSettings: Codable {
    public let enableAnimations: Bool
    public let animationSpeed: Double
    public let enableTransitions: Bool
    public let reduceMotion: Bool
    
    public init(
        enableAnimations: Bool = true,
        animationSpeed: Double = 1.0,
        enableTransitions: Bool = true,
        reduceMotion: Bool = false
    ) {
        self.enableAnimations = enableAnimations
        self.animationSpeed = animationSpeed
        self.enableTransitions = enableTransitions
        self.reduceMotion = reduceMotion
    }
    
    public static let `default` = AnimationSettings()
}

public struct HapticSettings: Codable {
    public let enableHaptics: Bool
    public let hapticStrength: Double
    public let enableKeyboardHaptics: Bool
    public let enableNotificationHaptics: Bool
    
    public init(
        enableHaptics: Bool = true,
        hapticStrength: Double = 1.0,
        enableKeyboardHaptics: Bool = true,
        enableNotificationHaptics: Bool = true
    ) {
        self.enableHaptics = enableHaptics
        self.hapticStrength = hapticStrength
        self.enableKeyboardHaptics = enableKeyboardHaptics
        self.enableNotificationHaptics = enableNotificationHaptics
    }
    
    public static let `default` = HapticSettings()
}

public struct AccessibilitySettings: Codable {
    public let enableVoiceOver: Bool
    public let enableReducedMotion: Bool
    public let enableHighContrast: Bool
    public let enableLargeText: Bool
    public let enableButtonShapes: Bool
    
    public init(
        enableVoiceOver: Bool = false,
        enableReducedMotion: Bool = false,
        enableHighContrast: Bool = false,
        enableLargeText: Bool = false,
        enableButtonShapes: Bool = false
    ) {
        self.enableVoiceOver = enableVoiceOver
        self.enableReducedMotion = enableReducedMotion
        self.enableHighContrast = enableHighContrast
        self.enableLargeText = enableLargeText
        self.enableButtonShapes = enableButtonShapes
    }
    
    public static let `default` = AccessibilitySettings()
}

/// Security and privacy configuration
public struct SecurityConfiguration: Codable {
    public let enableBiometricAuth: Bool
    public let requireAuthOnLaunch: Bool
    public let autoLockTimeout: TimeInterval
    public let enableDataEncryption: Bool
    public let enableNetworkSecurity: Bool
    public let allowInsecureConnections: Bool
    public let enableLogging: Bool
    public let logLevel: LogLevel
    
    public init(
        enableBiometricAuth: Bool = true,
        requireAuthOnLaunch: Bool = false,
        autoLockTimeout: TimeInterval = 300,
        enableDataEncryption: Bool = true,
        enableNetworkSecurity: Bool = true,
        allowInsecureConnections: Bool = false,
        enableLogging: Bool = true,
        logLevel: LogLevel = .info
    ) {
        self.enableBiometricAuth = enableBiometricAuth
        self.requireAuthOnLaunch = requireAuthOnLaunch
        self.autoLockTimeout = autoLockTimeout
        self.enableDataEncryption = enableDataEncryption
        self.enableNetworkSecurity = enableNetworkSecurity
        self.allowInsecureConnections = allowInsecureConnections
        self.enableLogging = enableLogging
        self.logLevel = logLevel
    }
    
    public static let `default` = SecurityConfiguration()
}

public enum LogLevel: String, Codable, CaseIterable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case none = "none"
    
    public var displayName: String {
        switch self {
        case .debug: return "Debug"
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        case .none: return "None"
        }
    }
}

// MARK: - KeychainManager Protocol

public protocol KeychainManagerProtocol {
    // Add keychain methods as needed
}

// Note: KeychainManager is already implemented in KeychainManager.swift
// We'll extend it to conform to KeychainManagerProtocol if needed