import Foundation
import Combine

// MARK: - Email Categorization Configuration
/// Configurazione centralizzata per il sistema di categorizzazione ibrida

public struct EmailCategorizationConfig {
    
    // MARK: - AI Limits
    
    /// Numero massimo di email da categorizzare con AI per sessione
    public let maxAICategorizationPerSession: Int
    
    /// Numero massimo di email da categorizzare con AI per account
    public let maxAICategorizationPerAccount: Int
    
    /// Soglia di giorni per considerare un'email "recente" (priorità AI)
    public let recentEmailDaysThreshold: Int
    
    // MARK: - Traditional Categorization
    
    /// Soglia di confidence per i metodi tradizionali (sotto questa soglia usa AI)
    public let traditionalConfidenceThreshold: Double
    
    /// Abilita categorizzazione veloce per domini conosciuti
    public let enableFastDomainMatching: Bool
    
    /// Abilita analisi del contenuto avanzata
    public let enableAdvancedContentAnalysis: Bool
    
    // MARK: - Batch Processing
    
    /// Dimensione batch per AI (più piccola per rispettare rate limits)
    public let aiBatchSize: Int
    
    /// Dimensione batch per metodi tradizionali (più grande perché veloce)
    public let traditionalBatchSize: Int
    
    /// Pausa tra batch AI (in secondi)
    public let aiBatchDelay: Double
    
    // MARK: - Performance
    
    /// Abilita cache dei risultati di categorizzazione
    public let enableResultsCaching: Bool
    
    /// Abilita logging dettagliato per debugging
    public let enableDetailedLogging: Bool
    
    // MARK: - Default Configuration
    
    public static let `default` = EmailCategorizationConfig(
        maxAICategorizationPerSession: 50,
        maxAICategorizationPerAccount: 100,
        recentEmailDaysThreshold: 7,
        traditionalConfidenceThreshold: 0.8,
        enableFastDomainMatching: true,
        enableAdvancedContentAnalysis: true,
        aiBatchSize: 3,
        traditionalBatchSize: 10,
        aiBatchDelay: 2.0,
        enableResultsCaching: true,
        enableDetailedLogging: true
    )
    
    // MARK: - Conservative Configuration (per account con molte email)
    
    public static let conservative = EmailCategorizationConfig(
        maxAICategorizationPerSession: 25,
        maxAICategorizationPerAccount: 50,
        recentEmailDaysThreshold: 3,
        traditionalConfidenceThreshold: 0.7,
        enableFastDomainMatching: true,
        enableAdvancedContentAnalysis: false,
        aiBatchSize: 2,
        traditionalBatchSize: 15,
        aiBatchDelay: 3.0,
        enableResultsCaching: true,
        enableDetailedLogging: false
    )
    
    // MARK: - Aggressive Configuration (per account con poche email)
    
    public static let aggressive = EmailCategorizationConfig(
        maxAICategorizationPerSession: 100,
        maxAICategorizationPerAccount: 200,
        recentEmailDaysThreshold: 14,
        traditionalConfidenceThreshold: 0.9,
        enableFastDomainMatching: true,
        enableAdvancedContentAnalysis: true,
        aiBatchSize: 5,
        traditionalBatchSize: 5,
        aiBatchDelay: 1.0,
        enableResultsCaching: true,
        enableDetailedLogging: true
    )
    
    // MARK: - Methods
    
    /// Sceglie automaticamente la configurazione migliore basata sul numero di email
    public static func automatic(for emailCount: Int) -> EmailCategorizationConfig {
        switch emailCount {
        case 0...100:
            return .aggressive
        case 101...500:
            return .default
        default:
            return .conservative
        }
    }
    
    /// Configurazione personalizzata per testing
    public static func testing() -> EmailCategorizationConfig {
        return EmailCategorizationConfig(
            maxAICategorizationPerSession: 10,
            maxAICategorizationPerAccount: 20,
            recentEmailDaysThreshold: 1,
            traditionalConfidenceThreshold: 0.5,
            enableFastDomainMatching: true,
            enableAdvancedContentAnalysis: true,
            aiBatchSize: 1,
            traditionalBatchSize: 5,
            aiBatchDelay: 0.5,
            enableResultsCaching: false,
            enableDetailedLogging: true
        )
    }
}

// MARK: - Configuration Manager

@MainActor
public class EmailCategorizationConfigManager: ObservableObject {
    
    @Published public private(set) var currentConfig: EmailCategorizationConfig
    
    private let configKey = "email_categorization_config"
    
    public static let shared = EmailCategorizationConfigManager()
    
    private init() {
        // Carica configurazione salvata o usa default
        if let data = UserDefaults.standard.data(forKey: configKey),
           let config = try? JSONDecoder().decode(EmailCategorizationConfig.self, from: data) {
            self.currentConfig = config
        } else {
            self.currentConfig = .default
        }
    }
    
    /// Aggiorna la configurazione
    public func updateConfig(_ config: EmailCategorizationConfig) {
        currentConfig = config
        saveConfig()
    }
    
    /// Adatta automaticamente la configurazione al numero di email
    public func adaptToEmailCount(_ count: Int) async {
        let newConfig = EmailCategorizationConfig.automatic(for: count)
        updateConfig(newConfig)
        print("🔧 EmailCategorizationConfig: Configurazione adattata per \(count) email")
    }
    
    /// Salva la configurazione in UserDefaults
    private func saveConfig() {
        if let data = try? JSONEncoder().encode(currentConfig) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }
    
    /// Resetta alla configurazione default
    public func resetToDefault() {
        updateConfig(.default)
    }
}

// MARK: - Codable Conformance

extension EmailCategorizationConfig: Codable {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        maxAICategorizationPerSession = try container.decode(Int.self, forKey: .maxAICategorizationPerSession)
        maxAICategorizationPerAccount = try container.decode(Int.self, forKey: .maxAICategorizationPerAccount)
        recentEmailDaysThreshold = try container.decode(Int.self, forKey: .recentEmailDaysThreshold)
        traditionalConfidenceThreshold = try container.decode(Double.self, forKey: .traditionalConfidenceThreshold)
        enableFastDomainMatching = try container.decode(Bool.self, forKey: .enableFastDomainMatching)
        enableAdvancedContentAnalysis = try container.decode(Bool.self, forKey: .enableAdvancedContentAnalysis)
        aiBatchSize = try container.decode(Int.self, forKey: .aiBatchSize)
        traditionalBatchSize = try container.decode(Int.self, forKey: .traditionalBatchSize)
        aiBatchDelay = try container.decode(Double.self, forKey: .aiBatchDelay)
        enableResultsCaching = try container.decode(Bool.self, forKey: .enableResultsCaching)
        enableDetailedLogging = try container.decode(Bool.self, forKey: .enableDetailedLogging)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(maxAICategorizationPerSession, forKey: .maxAICategorizationPerSession)
        try container.encode(maxAICategorizationPerAccount, forKey: .maxAICategorizationPerAccount)
        try container.encode(recentEmailDaysThreshold, forKey: .recentEmailDaysThreshold)
        try container.encode(traditionalConfidenceThreshold, forKey: .traditionalConfidenceThreshold)
        try container.encode(enableFastDomainMatching, forKey: .enableFastDomainMatching)
        try container.encode(enableAdvancedContentAnalysis, forKey: .enableAdvancedContentAnalysis)
        try container.encode(aiBatchSize, forKey: .aiBatchSize)
        try container.encode(traditionalBatchSize, forKey: .traditionalBatchSize)
        try container.encode(aiBatchDelay, forKey: .aiBatchDelay)
        try container.encode(enableResultsCaching, forKey: .enableResultsCaching)
        try container.encode(enableDetailedLogging, forKey: .enableDetailedLogging)
    }
    
    private enum CodingKeys: String, CodingKey {
        case maxAICategorizationPerSession
        case maxAICategorizationPerAccount
        case recentEmailDaysThreshold
        case traditionalConfidenceThreshold
        case enableFastDomainMatching
        case enableAdvancedContentAnalysis
        case aiBatchSize
        case traditionalBatchSize
        case aiBatchDelay
        case enableResultsCaching
        case enableDetailedLogging
    }
}