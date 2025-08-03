import Foundation
import Combine
import os.log
import UIKit

// MARK: - AI Performance Monitor
@MainActor
class AIPerformanceMonitor: ObservableObject {
    static let shared = AIPerformanceMonitor()
    
    private let logger = Logger(subsystem: "com.marilena.ai", category: "performance")
    private let metricsQueue = DispatchQueue(label: "com.marilena.performance", qos: .utility)
    
    @Published var currentMetrics = PerformanceMetrics(
        timestamp: Date(),
        systemMetrics: SystemMetrics(
            memoryUsage: 0,
            cpuUsage: 0.0,
            batteryLevel: 1.0,
            thermalState: .nominal
        ),
        aiMetrics: AIMetrics(
            activeRequests: 0,
            averageResponseTime: 0.0,
            cacheHitRate: 0.0,
            errorRate: 0.0
        ),
        collectionTime: 0.0
    )
    @Published var historicalMetrics: [PerformanceMetrics] = []
    @Published var isMonitoring = false
    @Published var optimizationSuggestions: [OptimizationSuggestion] = []
    
    private var monitoringTimer: Timer?
    private var maxHistorySize = 100
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        monitoringTimer?.invalidate()
    }
    
    // MARK: - Performance Monitoring
    private func startMonitoring() {
        isMonitoring = true
        logger.info("Avvio monitoraggio performance AI")
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateMetrics()
            }
        }
    }
    
    private func updateMetrics() async {
        let metrics = collectCurrentMetrics()
        currentMetrics = metrics
        
        // Aggiungi alle metriche storiche
        historicalMetrics.append(metrics)
        
        // Mantieni solo le ultime N metriche
        if historicalMetrics.count > maxHistorySize {
            historicalMetrics.removeFirst()
        }
        
        // Analizza e genera suggerimenti
        analyzePerformance()
    }
    
    private func collectCurrentMetrics() -> PerformanceMetrics {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Raccogli metriche di sistema
        let systemMetrics = collectSystemMetrics()
        
        // Raccogli metriche AI
        let aiMetrics = collectAIMetrics()
        
        let collectionTime = CFAbsoluteTimeGetCurrent() - startTime
        
        return PerformanceMetrics(
            timestamp: Date(),
            systemMetrics: systemMetrics,
            aiMetrics: aiMetrics,
            collectionTime: collectionTime
        )
    }
    
    private func collectSystemMetrics() -> SystemMetrics {
        let memoryUsage = getMemoryUsage()
        let cpuUsage = getCPUUsage()
        let batteryLevel = getBatteryLevel()
        let thermalState = ProcessInfo.processInfo.thermalState
        
        return SystemMetrics(
            memoryUsage: memoryUsage,
            cpuUsage: cpuUsage,
            batteryLevel: batteryLevel,
            thermalState: thermalState
        )
    }
    
    private func collectAIMetrics() -> AIMetrics {
        // Metriche AI (per ora placeholder)
        return AIMetrics(
            activeRequests: 0,
            averageResponseTime: 0.0,
            cacheHitRate: 0.0,
            errorRate: 0.0
        )
    }
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return UInt64(info.resident_size)
        } else {
            logger.error("Errore nel recupero dell'uso di memoria: \(kerr)")
            return 0
        }
    }
    
    private func getCPUUsage() -> Double {
        // Implementazione semplificata - in produzione usare host_statistics
        return 0.0
    }
    
    private func getBatteryLevel() -> Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryLevel
    }
    
    // MARK: - Performance Analysis
    private func analyzePerformance() {
        var suggestions: [OptimizationSuggestion] = []
        
        // Analizza memoria
        if currentMetrics.systemMetrics.memoryUsage > 150 * 1024 * 1024 { // 150MB
            suggestions.append(OptimizationSuggestion(
                type: .memory,
                priority: .high,
                title: "Uso memoria elevato",
                description: "L'uso di memoria è superiore a 150MB. Considera di pulire la cache.",
                action: "Pulisci cache AI"
            ))
        }
        
        // Analizza stato termico
        if currentMetrics.systemMetrics.thermalState == .critical {
            suggestions.append(OptimizationSuggestion(
                type: .thermal,
                priority: .critical,
                title: "Stato termico critico",
                description: "Il dispositivo è in stato termico critico. Riduci l'attività AI.",
                action: "Pausa operazioni AI"
            ))
        }
        
        // Analizza batteria
        if currentMetrics.systemMetrics.batteryLevel < 0.2 {
            suggestions.append(OptimizationSuggestion(
                type: .battery,
                priority: .medium,
                title: "Batteria scarica",
                description: "La batteria è sotto il 20%. Considera di ridurre l'attività AI.",
                action: "Riduci frequenza operazioni"
            ))
        }
        
        optimizationSuggestions = suggestions
    }
    
    // MARK: - Public API
    func getPerformanceReport() -> PerformanceReport {
        let averageMemory = historicalMetrics.map { $0.systemMetrics.memoryUsage }.reduce(0, +) / UInt64(historicalMetrics.count)
        let averageCPU = historicalMetrics.map { $0.systemMetrics.cpuUsage }.reduce(0, +) / Double(historicalMetrics.count)
        
        return PerformanceReport(
            currentMetrics: currentMetrics,
            averageMemory: averageMemory,
            averageCPU: averageCPU,
            suggestions: optimizationSuggestions,
            trend: calculateTrend()
        )
    }
    
    func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        logger.info("Monitoraggio performance AI fermato")
    }
    
    func clearHistory() {
        historicalMetrics.removeAll()
        logger.info("Cronologia metriche performance pulita")
    }
    
    private func calculateTrend() -> PerformanceTrend {
        guard historicalMetrics.count >= 3 else { return .stable }
        
        let recent = Array(historicalMetrics.suffix(3))
        let memoryTrend = recent.map { $0.systemMetrics.memoryUsage }
        
        if memoryTrend[0] < memoryTrend[1] && memoryTrend[1] < memoryTrend[2] {
            return .increasing
        } else if memoryTrend[0] > memoryTrend[1] && memoryTrend[1] > memoryTrend[2] {
            return .decreasing
        } else {
            return .stable
        }
    }
}

// MARK: - Supporting Types
struct PerformanceMetrics {
    let timestamp: Date
    let systemMetrics: SystemMetrics
    let aiMetrics: AIMetrics
    let collectionTime: CFAbsoluteTime
}

struct SystemMetrics {
    let memoryUsage: UInt64
    let cpuUsage: Double
    let batteryLevel: Float
    let thermalState: ProcessInfo.ThermalState
    
    var memoryUsageMB: Double {
        Double(memoryUsage) / 1024.0 / 1024.0
    }
}

struct AIMetrics {
    let activeRequests: Int
    let averageResponseTime: Double
    let cacheHitRate: Double
    let errorRate: Double
}

struct OptimizationSuggestion {
    let type: SuggestionType
    let priority: SuggestionPriority
    let title: String
    let description: String
    let action: String
}

enum SuggestionType: String, CaseIterable {
    case memory = "Memoria"
    case thermal = "Termico"
    case battery = "Batteria"
    case performance = "Performance"
}

enum SuggestionPriority: String, CaseIterable {
    case low = "Bassa"
    case medium = "Media"
    case high = "Alta"
    case critical = "Critica"
    
    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

enum PerformanceTrend: String, CaseIterable {
    case increasing = "Crescente"
    case decreasing = "Decrescente"
    case stable = "Stabile"
}

struct PerformanceReport {
    let currentMetrics: PerformanceMetrics
    let averageMemory: UInt64
    let averageCPU: Double
    let suggestions: [OptimizationSuggestion]
    let trend: PerformanceTrend
    
    var averageMemoryMB: Double {
        Double(averageMemory) / 1024.0 / 1024.0
    }
} 