import Foundation
import Combine

// MARK: - Email Categorization Statistics

public struct EmailCategorizationStats {
    
    // MARK: - Usage Statistics
    
    /// Numero totale di email categorizzate
    public let totalEmailsCategorized: Int
    
    /// Numero di email categorizzate con AI
    public let aiCategorized: Int
    
    /// Numero di email categorizzate con metodi tradizionali
    public let traditionalCategorized: Int
    
    /// Percentuale di utilizzo AI
    public var aiUsagePercentage: Double {
        guard totalEmailsCategorized > 0 else { return 0 }
        return Double(aiCategorized) / Double(totalEmailsCategorized) * 100
    }
    
    /// Percentuale di utilizzo metodi tradizionali
    public var traditionalUsagePercentage: Double {
        guard totalEmailsCategorized > 0 else { return 0 }
        return Double(traditionalCategorized) / Double(totalEmailsCategorized) * 100
    }
    
    // MARK: - Performance Statistics
    
    /// Tempo medio per categorizzazione AI (in secondi)
    public let averageAITime: Double
    
    /// Tempo medio per categorizzazione tradizionale (in secondi)
    public let averageTraditionalTime: Double
    
    /// Costo stimato API (in USD)
    public let estimatedCost: Double
    
    /// Risparmio stimato vs solo AI (in USD)
    public let estimatedSavings: Double
    
    // MARK: - Session Statistics
    
    /// Email categorizzate in questa sessione
    public let sessionCategorized: Int
    
    /// AI utilizzate in questa sessione
    public let sessionAIUsed: Int
    
    /// Limite sessione rimanente
    public let sessionAIRemaining: Int
    
    // MARK: - Category Distribution
    
    /// Distribuzione per categoria
    public let categoryDistribution: [EmailCategory: Int]
    
    // MARK: - Accuracy Metrics
    
    /// Accuracy stimata metodi tradizionali
    public let traditionalAccuracy: Double
    
    /// Confidence media metodi tradizionali
    public let averageTraditionalConfidence: Double
}

// MARK: - Email Categorization Monitor

@MainActor
public class EmailCategorizationMonitor: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var currentStats: EmailCategorizationStats
    @Published public private(set) var isMonitoring = false
    
    // MARK: - Private Properties
    
    private let categorizationService: EmailCategorizationService
    private var cancellables = Set<AnyCancellable>()
    
    // Tracking delle performance
    private var aiTimings: [Double] = []
    private var traditionalTimings: [Double] = []
    private var categoryStats: [EmailCategory: Int] = [:]
    private var confidenceScores: [Double] = []
    
    // Contatori
    private var totalCategorized = 0
    private var aiCount = 0
    private var traditionalCount = 0
    private var sessionCategorized = 0
    private var sessionAICount = 0
    
    // Costi API (stimati)
    private let costPerAICall = 0.0005 // $0.0005 per chiamata AI
    
    // MARK: - Initialization
    
    public init(categorizationService: EmailCategorizationService) {
        self.categorizationService = categorizationService
        
        // Inizializza statistiche vuote
        self.currentStats = EmailCategorizationStats(
            totalEmailsCategorized: 0,
            aiCategorized: 0,
            traditionalCategorized: 0,
            averageAITime: 0,
            averageTraditionalTime: 0,
            estimatedCost: 0,
            estimatedSavings: 0,
            sessionCategorized: 0,
            sessionAIUsed: 0,
            sessionAIRemaining: 0,
            categoryDistribution: [:],
            traditionalAccuracy: 0,
            averageTraditionalConfidence: 0
        )
        
        loadStoredStats()
        startMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Avvia il monitoraggio
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        // Timer per aggiornamenti periodici
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateStats()
            }
            .store(in: &cancellables)
        
        print("📊 EmailCategorizationMonitor: Monitoraggio avviato")
    }
    
    /// Ferma il monitoraggio
    public func stopMonitoring() {
        isMonitoring = false
        cancellables.removeAll()
        print("📊 EmailCategorizationMonitor: Monitoraggio fermato")
    }
    
    /// Registra una categorizzazione AI
    public func recordAICategorization(duration: TimeInterval, category: EmailCategory) {
        aiTimings.append(duration)
        aiCount += 1
        sessionAICount += 1
        recordCategorization(category: category)
        updateStats()
        
        if EmailCategorizationConfigManager.shared.currentConfig.enableDetailedLogging {
            print("📊 EmailCategorizationMonitor: AI categorization recorded (\(String(format: "%.2f", duration))s) -> \(category.displayName)")
        }
    }
    
    /// Registra una categorizzazione tradizionale
    public func recordTraditionalCategorization(duration: TimeInterval, category: EmailCategory, confidence: Double) {
        traditionalTimings.append(duration)
        traditionalCount += 1
        confidenceScores.append(confidence)
        recordCategorization(category: category)
        updateStats()
        
        if EmailCategorizationConfigManager.shared.currentConfig.enableDetailedLogging {
            print("📊 EmailCategorizationMonitor: Traditional categorization recorded (\(String(format: "%.2f", duration))s, confidence: \(String(format: "%.2f", confidence))) -> \(category.displayName)")
        }
    }
    
    /// Resetta le statistiche di sessione
    public func resetSessionStats() {
        sessionCategorized = 0
        sessionAICount = 0
        updateStats()
        print("🔄 EmailCategorizationMonitor: Statistiche sessione resettate")
    }
    
    /// Esporta statistiche come stringa
    public func exportStats() -> String {
        let stats = currentStats
        
        return """
        📊 STATISTICHE CATEGORIZZAZIONE EMAIL
        
        📈 UTILIZZO:
        • Totale categorizzate: \(stats.totalEmailsCategorized)
        • AI: \(stats.aiCategorized) (\(String(format: "%.1f", stats.aiUsagePercentage))%)
        • Tradizionale: \(stats.traditionalCategorized) (\(String(format: "%.1f", stats.traditionalUsagePercentage))%)
        
        ⚡ PERFORMANCE:
        • Tempo medio AI: \(String(format: "%.2f", stats.averageAITime))s
        • Tempo medio Tradizionale: \(String(format: "%.3f", stats.averageTraditionalTime))s
        • Accuracy Tradizionale: \(String(format: "%.1f", stats.traditionalAccuracy * 100))%
        
        💰 COSTI:
        • Costo stimato: $\(String(format: "%.4f", stats.estimatedCost))
        • Risparmio stimato: $\(String(format: "%.4f", stats.estimatedSavings))
        
        📊 SESSIONE CORRENTE:
        • Categorizzate: \(stats.sessionCategorized)
        • AI utilizzate: \(stats.sessionAIUsed)
        • AI rimanenti: \(stats.sessionAIRemaining)
        
        📂 DISTRIBUZIONE CATEGORIE:
        \(formatCategoryDistribution(stats.categoryDistribution))
        
        Generato: \(Date().formatted())
        """
    }
    
    // MARK: - Private Methods
    
    private func recordCategorization(category: EmailCategory) {
        totalCategorized += 1
        sessionCategorized += 1
        categoryStats[category] = (categoryStats[category] ?? 0) + 1
    }
    
    private func updateStats() {
        let aiUsageStats = categorizationService.getAIUsageStats()
        
        let averageAITime = aiTimings.isEmpty ? 0 : aiTimings.reduce(0, +) / Double(aiTimings.count)
        let averageTraditionalTime = traditionalTimings.isEmpty ? 0 : traditionalTimings.reduce(0, +) / Double(traditionalTimings.count)
        let averageConfidence = confidenceScores.isEmpty ? 0 : confidenceScores.reduce(0, +) / Double(confidenceScores.count)
        
        // Calcola accuracy tradizionale (basata su confidence)
        let traditionalAccuracy = averageConfidence
        
        // Calcola costi
        let estimatedCost = Double(aiCount) * costPerAICall
        let costIfAllAI = Double(totalCategorized) * costPerAICall
        let estimatedSavings = costIfAllAI - estimatedCost
        
        // Calcola AI rimanenti
        let sessionAIRemaining = max(0, aiUsageStats.maxSession - aiUsageStats.sessionCount)
        
        let newStats = EmailCategorizationStats(
            totalEmailsCategorized: totalCategorized,
            aiCategorized: aiCount,
            traditionalCategorized: traditionalCount,
            averageAITime: averageAITime,
            averageTraditionalTime: averageTraditionalTime,
            estimatedCost: estimatedCost,
            estimatedSavings: estimatedSavings,
            sessionCategorized: sessionCategorized,
            sessionAIUsed: aiUsageStats.sessionCount,
            sessionAIRemaining: sessionAIRemaining,
            categoryDistribution: categoryStats,
            traditionalAccuracy: traditionalAccuracy,
            averageTraditionalConfidence: averageConfidence
        )
        
        currentStats = newStats
        
        // Salva statistiche
        saveStats()
    }
    
    private func formatCategoryDistribution(_ distribution: [EmailCategory: Int]) -> String {
        let total = distribution.values.reduce(0, +)
        guard total > 0 else { return "• Nessuna categoria" }
        
        return distribution
            .sorted { $0.value > $1.value }
            .map { category, count in
                let percentage = Double(count) / Double(total) * 100
                return "• \(category.displayName): \(count) (\(String(format: "%.1f", percentage))%)"
            }
            .joined(separator: "\n")
    }
    
    // MARK: - Persistence
    
    private func saveStats() {
        let statsData: [String: Any] = [
            "totalCategorized": totalCategorized,
            "aiCount": aiCount,
            "traditionalCount": traditionalCount,
            "sessionCategorized": sessionCategorized,
            "sessionAICount": sessionAICount,
            "aiTimings": aiTimings,
            "traditionalTimings": traditionalTimings,
            "confidenceScores": confidenceScores,
            "categoryStats": categoryStats.mapKeys { $0.rawValue }
        ]
        
        UserDefaults.standard.set(statsData, forKey: "email_categorization_stats")
    }
    
    private func loadStoredStats() {
        guard let statsData = UserDefaults.standard.dictionary(forKey: "email_categorization_stats") else { return }
        
        totalCategorized = statsData["totalCategorized"] as? Int ?? 0
        aiCount = statsData["aiCount"] as? Int ?? 0
        traditionalCount = statsData["traditionalCount"] as? Int ?? 0
        sessionCategorized = statsData["sessionCategorized"] as? Int ?? 0
        sessionAICount = statsData["sessionAICount"] as? Int ?? 0
        
        aiTimings = statsData["aiTimings"] as? [Double] ?? []
        traditionalTimings = statsData["traditionalTimings"] as? [Double] ?? []
        confidenceScores = statsData["confidenceScores"] as? [Double] ?? []
        
        if let categoryStatsRaw = statsData["categoryStats"] as? [String: Int] {
            categoryStats = categoryStatsRaw.compactMapKeys { EmailCategory(rawValue: $0) }
        }
        
        updateStats()
        print("📊 EmailCategorizationMonitor: Statistiche caricate - Totale: \(totalCategorized), AI: \(aiCount), Tradizionale: \(traditionalCount)")
    }
}

// MARK: - Dictionary Extensions

extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        return Dictionary<T, Value>(uniqueKeysWithValues: self.map { (transform($0), $1) })
    }
    
    func compactMapKeys<T: Hashable>(_ transform: (Key) -> T?) -> [T: Value] {
        return Dictionary<T, Value>(uniqueKeysWithValues: self.compactMap { key, value in
            guard let newKey = transform(key) else { return nil }
            return (newKey, value)
        })
    }
}