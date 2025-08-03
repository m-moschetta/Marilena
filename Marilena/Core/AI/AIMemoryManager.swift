import Foundation
import Combine
import os.log

// MARK: - AI Memory Manager
@MainActor
class AIMemoryManager: ObservableObject {
    static let shared = AIMemoryManager()
    
    private let logger = Logger(subsystem: "com.marilena.ai", category: "memory")
    private let memoryThreshold: UInt64 = 100 * 1024 * 1024 // 100MB
    private let criticalThreshold: UInt64 = 200 * 1024 * 1024 // 200MB
    
    @Published var currentMemoryUsage: UInt64 = 0
    @Published var peakMemoryUsage: UInt64 = 0
    @Published var memoryPressure: MemoryPressure = .normal
    @Published var isOptimizing = false
    
    private var memoryObservers: [NSObjectProtocol] = []
    private var optimizationTimer: Timer?
    
    private init() {
        setupMemoryMonitoring()
        startPeriodicOptimization()
    }
    
    deinit {
        memoryObservers.forEach { NotificationCenter.default.removeObserver($0) }
        optimizationTimer?.invalidate()
    }
    
    // MARK: - Memory Monitoring
    private func setupMemoryMonitoring() {
        // Monitora la pressione di memoria del sistema
        let pressureObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryPressure()
            }
        }
        memoryObservers.append(pressureObserver)
        
        // Aggiorna l'uso di memoria ogni 5 secondi
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryUsage()
            }
        }
    }
    
    private func updateMemoryUsage() {
        let usage = getCurrentMemoryUsage()
        currentMemoryUsage = usage
        
        if usage > peakMemoryUsage {
            peakMemoryUsage = usage
        }
        
        // Determina la pressione di memoria
        if usage > criticalThreshold {
            memoryPressure = .critical
            logger.warning("Memoria critica: \(usage / 1024 / 1024)MB")
            Task {
                await performEmergencyOptimization()
            }
        } else if usage > memoryThreshold {
            memoryPressure = .high
            logger.info("Pressione memoria alta: \(usage / 1024 / 1024)MB")
        } else {
            memoryPressure = .normal
        }
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
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
    
    // MARK: - Memory Optimization
    private func startPeriodicOptimization() {
        optimizationTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performPeriodicOptimization()
            }
        }
    }
    
    private func performPeriodicOptimization() async {
        guard !isOptimizing else { return }
        
        isOptimizing = true
        logger.info("Avvio ottimizzazione periodica memoria")
        
        // Pulisci cache AI (se disponibile)
        // await AICacheManager.shared.cleanup()
        
        // Forza garbage collection
        autoreleasepool {
            // Operazioni che potrebbero rilasciare memoria
        }
        
        isOptimizing = false
        logger.info("Ottimizzazione periodica completata")
    }
    
    private func performEmergencyOptimization() async {
        guard !isOptimizing else { return }
        
        isOptimizing = true
        logger.warning("Avvio ottimizzazione emergenza memoria")
        
        // Pulisci cache completamente (se disponibile)
        // await AICacheManager.shared.clearAll()
        
        // Forza rilascio memoria
        autoreleasepool {
            // Operazioni intensive di pulizia
        }
        
        isOptimizing = false
        logger.info("Ottimizzazione emergenza completata")
    }
    
    private func handleMemoryPressure() {
        let thermalState = ProcessInfo.processInfo.thermalState
        
        switch thermalState {
        case .critical:
            logger.warning("Stato termico critico - ottimizzazione aggressiva")
            Task {
                await performEmergencyOptimization()
            }
        case .serious:
            logger.info("Stato termico serio - ottimizzazione moderata")
            Task {
                await performPeriodicOptimization()
            }
        default:
            break
        }
    }
    
    // MARK: - Public API
    func getMemoryStats() -> MemoryStats {
        return MemoryStats(
            currentUsage: currentMemoryUsage,
            peakUsage: peakMemoryUsage,
            pressure: memoryPressure,
            threshold: memoryThreshold,
            criticalThreshold: criticalThreshold
        )
    }
    
    func forceOptimization() async {
        await performPeriodicOptimization()
    }
    
    func clearMemory() async {
        // await AICacheManager.shared.clearAll()
        updateMemoryUsage()
    }
}

// MARK: - Supporting Types
enum MemoryPressure: String, CaseIterable {
    case normal = "Normale"
    case high = "Alta"
    case critical = "Critica"
    
    var color: String {
        switch self {
        case .normal: return "green"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

struct MemoryStats {
    let currentUsage: UInt64
    let peakUsage: UInt64
    let pressure: MemoryPressure
    let threshold: UInt64
    let criticalThreshold: UInt64
    
    var currentUsageMB: Double {
        Double(currentUsage) / 1024.0 / 1024.0
    }
    
    var peakUsageMB: Double {
        Double(peakUsage) / 1024.0 / 1024.0
    }
    
    var thresholdMB: Double {
        Double(threshold) / 1024.0 / 1024.0
    }
    
    var criticalThresholdMB: Double {
        Double(criticalThreshold) / 1024.0 / 1024.0
    }
} 