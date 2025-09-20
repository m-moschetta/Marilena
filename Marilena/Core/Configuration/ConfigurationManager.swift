import Foundation
import Combine

// MARK: - Configuration Manager

/// Central configuration management system for Marilena
/// Handles app settings, AI configurations, email settings, and environment-based configs
@MainActor
public class ConfigurationManager: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = ConfigurationManager()
    
    // MARK: - Published Properties
    
    @Published public private(set) var currentEnvironment: AppEnvironment
    @Published public private(set) var aiConfiguration: AIConfiguration
    @Published public private(set) var emailConfiguration: EmailConfiguration
    @Published public private(set) var apiConfiguration: AppAPIConfiguration
    @Published public private(set) var uiConfiguration: UIConfiguration
    @Published public private(set) var securityConfiguration: SecurityConfiguration
    
    // MARK: - Private Properties
    
    private let userDefaults: UserDefaults
    private let keychain: KeychainManagerProtocol?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration Keys
    
    private enum ConfigKeys {
        static let environment = "app_environment"
        static let aiConfig = "ai_configuration"
        static let emailConfig = "email_configuration"
        static let apiConfig = "api_configuration"
        static let uiConfig = "ui_configuration"
        static let securityConfig = "security_configuration"
        static let lastConfigUpdate = "last_config_update"
    }
    
    // MARK: - Initialization
    
    private init(
        userDefaults: UserDefaults = .standard,
        keychain: KeychainManagerProtocol? = nil
    ) {
        self.userDefaults = userDefaults
        self.keychain = keychain
        
        // Load environment first
        let environment: AppEnvironment
        if let envString = userDefaults.string(forKey: ConfigKeys.environment),
           let env = AppEnvironment(rawValue: envString) {
            environment = env
        } else {
            environment = .production
        }
        self.currentEnvironment = environment
        
        // Load configurations
        self.aiConfiguration = Self.loadConfiguration(
            key: ConfigKeys.aiConfig,
            userDefaults: userDefaults,
            defaultValue: AIConfiguration.default
        )
        
        self.emailConfiguration = Self.loadConfiguration(
            key: ConfigKeys.emailConfig,
            userDefaults: userDefaults,
            defaultValue: EmailConfiguration.default
        )
        
        self.apiConfiguration = Self.loadConfiguration(
            key: ConfigKeys.apiConfig,
            userDefaults: userDefaults,
            defaultValue: AppAPIConfiguration.default(for: environment)
        )
        
        self.uiConfiguration = Self.loadConfiguration(
            key: ConfigKeys.uiConfig,
            userDefaults: userDefaults,
            defaultValue: UIConfiguration.default
        )
        
        self.securityConfiguration = Self.loadConfiguration(
            key: ConfigKeys.securityConfig,
            userDefaults: userDefaults,
            defaultValue: SecurityConfiguration.default
        )
        
        print("📊 ConfigurationManager: Initialized with environment: \(currentEnvironment.displayName)")
        
        setupObservers()
    }
    
    // MARK: - Public Configuration Access
    
    public func getAPIEndpoint(for service: String) -> String? {
        return apiConfiguration.endpoints[service]
    }
    
    public func getEmailSettings() -> EmailConfiguration {
        return emailConfiguration
    }
    
    public func getAISettings() -> AIConfiguration {
        return aiConfiguration
    }
    
    // MARK: - Public Configuration Methods
    
    public func updateEnvironment(_ environment: AppEnvironment) {
        guard environment != currentEnvironment else { return }
        
        print("📊 ConfigurationManager: Switching environment: \(currentEnvironment.displayName) → \(environment.displayName)")
        
        currentEnvironment = environment
        userDefaults.set(environment.rawValue, forKey: ConfigKeys.environment)
        
        // Update API configuration for new environment
        let newAPIConfig = AppAPIConfiguration.default(for: environment)
        updateAPIConfiguration(newAPIConfig)
        
        // Notify environment change
        NotificationCenter.default.post(
            name: .configurationEnvironmentChanged,
            object: self,
            userInfo: ["environment": environment]
        )
    }
    
    public func updateAIConfiguration(_ configuration: AIConfiguration) {
        aiConfiguration = configuration
        saveConfiguration(configuration, key: ConfigKeys.aiConfig)
        
        NotificationCenter.default.post(
            name: .configurationAIChanged,
            object: self,
            userInfo: ["configuration": configuration]
        )
        
        print("🤖 ConfigurationManager: AI configuration updated")
    }
    
    public func updateEmailConfiguration(_ configuration: EmailConfiguration) {
        emailConfiguration = configuration
        saveConfiguration(configuration, key: ConfigKeys.emailConfig)
        
        NotificationCenter.default.post(
            name: .configurationEmailChanged,
            object: self,
            userInfo: ["configuration": configuration]
        )
        
        print("📧 ConfigurationManager: Email configuration updated")
    }
    
    public func updateAPIConfiguration(_ configuration: AppAPIConfiguration) {
        apiConfiguration = configuration
        saveConfiguration(configuration, key: ConfigKeys.apiConfig)
        
        NotificationCenter.default.post(
            name: .configurationAPIChanged,
            object: self,
            userInfo: ["configuration": configuration]
        )
        
        print("🔗 ConfigurationManager: API configuration updated")
    }
    
    public func updateUIConfiguration(_ configuration: UIConfiguration) {
        uiConfiguration = configuration
        saveConfiguration(configuration, key: ConfigKeys.uiConfig)
        
        NotificationCenter.default.post(
            name: .configurationUIChanged,
            object: self,
            userInfo: ["configuration": configuration]
        )
        
        print("🎨 ConfigurationManager: UI configuration updated")
    }
    
    public func updateSecurityConfiguration(_ configuration: SecurityConfiguration) {
        securityConfiguration = configuration
        saveConfiguration(configuration, key: ConfigKeys.securityConfig)
        
        NotificationCenter.default.post(
            name: .configurationSecurityChanged,
            object: self,
            userInfo: ["configuration": configuration]
        )
        
        print("🔒 ConfigurationManager: Security configuration updated")
    }
    
    // MARK: - AI Model Management
    
    public func getRecommendedModels(for capability: AICapability) -> [AIModelConfiguration] {
        return AIModelConfiguration.models(with: capability)
            .filter { $0.availability.status == .available }
            .sorted { ($0.benchmarks.overallScore ?? 0) > ($1.benchmarks.overallScore ?? 0) }
    }
    
    public func getCurrentAIModel() -> AIModelConfiguration? {
        let modelId = getCurrentModelId()
        return AIModelConfiguration.allModels.first { $0.id == modelId }
    }
    
    public func getCurrentModelId() -> String {
        switch aiConfiguration.selectedProvider {
        case .apple:
            return "foundation-medium" // Apple Intelligence default
        case .openai:
            return aiConfiguration.openAIModel
        case .anthropic:
            return aiConfiguration.anthropicModel
        case .google:
            return "gemini-2.5-pro" // Default fallback
        case .meta:
            return "llama-4-maverick"
        case .perplexity:
            return aiConfiguration.perplexityModel
        case .groq:
            return aiConfiguration.groqModel
        case .xai:
            return "grok-4-latest" // xAI Grok default
        case .mistral:
            return "mistral-large-latest"
        case .deepseek:
            return "deepseek-chat"
        @unknown default:
            print("⚠️ ConfigurationManager: Unknown AI provider, falling back to OpenAI model")
            return aiConfiguration.openAIModel
        }
    }
    
    // MARK: - Configuration Validation
    
    public func validateConfiguration() -> [ConfigurationIssue] {
        var issues: [ConfigurationIssue] = []
        
        // Validate AI configuration
        if getCurrentAIModel() == nil {
            issues.append(ConfigurationIssue(
                type: .warning,
                category: .ai,
                message: "Selected AI model '\(getCurrentModelId())' not found in catalog",
                suggestion: "Update to a supported model"
            ))
        }
        
        // Validate API endpoints
        for (service, endpoint) in apiConfiguration.endpoints {
            if endpoint.isEmpty || !isValidURL(endpoint) {
                issues.append(ConfigurationIssue(
                    type: .error,
                    category: .api,
                    message: "Invalid endpoint for service '\(service)': \(endpoint)",
                    suggestion: "Provide a valid URL for \(service)"
                ))
            }
        }
        
        // Validate email configuration
        if emailConfiguration.fetchInterval < 60 {
            issues.append(ConfigurationIssue(
                type: .warning,
                category: .email,
                message: "Email fetch interval is very low (\(emailConfiguration.fetchInterval)s)",
                suggestion: "Consider increasing to reduce server load"
            ))
        }
        
        print("🔍 ConfigurationManager: Validation found \(issues.count) issues")
        return issues
    }
    
    // MARK: - Import/Export
    
    public func exportConfiguration() -> ConfigurationExport {
        return ConfigurationExport(
            environment: currentEnvironment,
            ai: aiConfiguration,
            email: emailConfiguration,
            api: apiConfiguration,
            ui: uiConfiguration,
            security: securityConfiguration,
            exportDate: Date(),
            version: "1.0"
        )
    }
    
    public func importConfiguration(_ export: ConfigurationExport) throws {
        // Validate import
        guard export.version == "1.0" else {
            throw ConfigurationError.unsupportedVersion(export.version)
        }
        
        // Import configurations
        updateEnvironment(export.environment)
        updateAIConfiguration(export.ai)
        updateEmailConfiguration(export.email)
        updateAPIConfiguration(export.api)
        updateUIConfiguration(export.ui)
        updateSecurityConfiguration(export.security)
        
        print("📥 ConfigurationManager: Configuration imported successfully")
    }
    
    // MARK: - Reset Methods
    
    public func resetToDefaults() {
        updateAIConfiguration(.default)
        updateEmailConfiguration(.default)
        updateAPIConfiguration(.default(for: currentEnvironment))
        updateUIConfiguration(.default)
        updateSecurityConfiguration(.default)
        
        print("🔄 ConfigurationManager: Reset to default configurations")
    }
    
    public func resetAIConfiguration() {
        updateAIConfiguration(.default)
    }
    
    public func resetEmailConfiguration() {
        updateEmailConfiguration(.default)
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Auto-save on configuration changes
        $aiConfiguration
            .dropFirst()
            .sink { [weak self] config in
                self?.saveConfiguration(config, key: ConfigKeys.aiConfig)
            }
            .store(in: &cancellables)
        
        $emailConfiguration
            .dropFirst()
            .sink { [weak self] config in
                self?.saveConfiguration(config, key: ConfigKeys.emailConfig)
            }
            .store(in: &cancellables)
        
        // Update last modified timestamp
        Publishers.CombineLatest4($aiConfiguration, $emailConfiguration, $apiConfiguration, $uiConfiguration)
            .dropFirst()
            .sink { [weak self] _, _, _, _ in
                self?.userDefaults.set(Date(), forKey: ConfigKeys.lastConfigUpdate)
            }
            .store(in: &cancellables)
    }
    
    private static func loadConfiguration<T: Codable>(
        key: String,
        userDefaults: UserDefaults,
        defaultValue: T
    ) -> T {
        guard let data = userDefaults.data(forKey: key),
              let config = try? JSONDecoder().decode(T.self, from: data) else {
            return defaultValue
        }
        return config
    }
    
    private func saveConfiguration<T: Codable>(_ configuration: T, key: String) {
        do {
            let data = try JSONEncoder().encode(configuration)
            userDefaults.set(data, forKey: key)
            print("💾 ConfigurationManager: Saved configuration for key: \(key)")
        } catch {
            print("❌ ConfigurationManager: Failed to save configuration for key \(key): \(error)")
        }
    }
    
    private func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return url.scheme != nil && url.host != nil
    }
}

// MARK: - Supporting Types

public enum AppEnvironment: String, Codable, CaseIterable {
    case development = "development"
    case staging = "staging"
    case production = "production"
    
    public var displayName: String {
        switch self {
        case .development: return "Development"
        case .staging: return "Staging"
        case .production: return "Production"
        }
    }
    
    public var isDebug: Bool {
        return self != .production
    }
}

public struct ConfigurationIssue: Identifiable {
    public let id = UUID()
    public let type: IssueType
    public let category: IssueCategory
    public let message: String
    public let suggestion: String
    
    public enum IssueType {
        case error, warning, info
    }
    
    public enum IssueCategory {
        case ai, email, api, ui, security, general
    }
}

public enum ConfigurationError: Error, LocalizedError {
    case unsupportedVersion(String)
    case invalidConfiguration(String)
    case importFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "Unsupported configuration version: \(version)"
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        case .importFailed(let reason):
            return "Configuration import failed: \(reason)"
        }
    }
}

public struct ConfigurationExport: Codable {
    public let environment: AppEnvironment
    public let ai: AIConfiguration
    public let email: EmailConfiguration
    public let api: AppAPIConfiguration
    public let ui: UIConfiguration
    public let security: SecurityConfiguration
    public let exportDate: Date
    public let version: String
}

// MARK: - Notification Names

public extension Notification.Name {
    static let configurationEnvironmentChanged = Notification.Name("configuration.environment.changed")
    static let configurationAIChanged = Notification.Name("configuration.ai.changed")
    static let configurationEmailChanged = Notification.Name("configuration.email.changed")
    static let configurationAPIChanged = Notification.Name("configuration.api.changed")
    static let configurationUIChanged = Notification.Name("configuration.ui.changed")
    static let configurationSecurityChanged = Notification.Name("configuration.security.changed")
}
