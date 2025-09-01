import Foundation
import Combine
import os.log

// MARK: - AI Coordinator
@MainActor
class AICoordinator: ObservableObject {
    static let shared = AICoordinator()
    
    private let logger = Logger(subsystem: "com.marilena.ai", category: "coordinator")
    
    // Core Services
    private let cacheManager = AICacheManager.shared
    private let memoryManager = AIMemoryManager.shared
    private let performanceMonitor = AIPerformanceMonitor.shared
    private let taskManager = AITaskManager.shared
    private let networkService = NetworkService.shared
    
    // Published Properties
    @Published var isInitialized = false
    @Published var currentStatus: CoordinatorStatus = .initializing
    @Published var activeServices: Set<AIServiceType> = []
    @Published var systemHealth = SystemHealth(
        cacheHealth: true,
        memoryHealth: true,
        performanceHealth: true,
        taskHealth: true,
        lastCheck: Date()
    )
    
    // Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var serviceInstances: [AIServiceType: AIServiceProtocol] = [:]
    private var healthCheckTimer: Timer?
    
    private init() {
        setupBindings()
        initializeServices()
    }
    
    deinit {
        healthCheckTimer?.invalidate()
        cancellables.forEach { $0.cancel() }
    }
    
    // MARK: - Initialization
    private func setupBindings() {
        // Monitor memory pressure
        memoryManager.$memoryPressure
            .sink { [weak self] pressure in
                Task { @MainActor in
                    self?.handleMemoryPressure(pressure)
                }
            }
            .store(in: &cancellables)
        
        // Monitor performance
        performanceMonitor.$currentMetrics
            .sink { [weak self] metrics in
                Task { @MainActor in
                    self?.updateSystemHealth(metrics)
                }
            }
            .store(in: &cancellables)
        
        // Monitor task manager
        taskManager.$isProcessing
            .sink { [weak self] isProcessing in
                Task { @MainActor in
                    self?.updateCoordinatorStatus(isProcessing: isProcessing)
                }
            }
            .store(in: &cancellables)
    }
    
    private func initializeServices() {
        logger.info("Inizializzazione servizi AI")
        currentStatus = .initializing
        
        // Initialize core services
        Task {
            await initializeCacheManager()
            await initializeMemoryManager()
            await initializePerformanceMonitor()
            await initializeTaskManager()
            
            // Start health monitoring
            startHealthMonitoring()
            
            isInitialized = true
            currentStatus = .ready
            logger.info("Servizi AI inizializzati con successo")
        }
    }
    
    private func initializeCacheManager() async {
        // Cache manager is already initialized as singleton
        logger.info("Cache Manager inizializzato")
    }
    
    private func initializeMemoryManager() async {
        // Memory manager is already initialized as singleton
        logger.info("Memory Manager inizializzato")
    }
    
    private func initializePerformanceMonitor() async {
        // Performance monitor is already initialized as singleton
        logger.info("Performance Monitor inizializzato")
    }
    
    private func initializeTaskManager() async {
        // Task manager is already initialized as singleton
        logger.info("Task Manager inizializzato")
    }
    
    // MARK: - Health Monitoring
    private func startHealthMonitoring() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performHealthCheck()
            }
        }
    }
    
    private func performHealthCheck() {
        logger.info("Esecuzione health check del sistema")
        
        // Check cache health
        let cacheStats = cacheManager.cacheStats
        
        // Check memory health
        let memoryUsage = memoryManager.currentMemoryUsage
        
        // Check performance health
        let performanceMetrics = performanceMonitor.currentMetrics
        
        // Check task manager health
        let taskStats = taskManager.getTaskStatistics()
        
        // Update system health
        systemHealth = SystemHealth(
            cacheHealth: cacheStats.hitRate > 0.7,
            memoryHealth: memoryUsage < 100 * 1024 * 1024, // 100MB
            performanceHealth: performanceMetrics.systemMetrics.cpuUsage < 0.8,
            taskHealth: taskStats.successRate > 0.9,
            lastCheck: Date()
        )
        
        // Log health status
        if systemHealth.isHealthy {
            logger.info("Sistema AI in salute")
        } else {
            logger.warning("Problemi di salute rilevati nel sistema AI")
        }
    }
    
    // MARK: - Service Management
    func getService(for type: AIServiceType) -> AIServiceProtocol? {
        if let existingService = serviceInstances[type] {
            return existingService
        }
        
        // Create new service instance; se manca la key, alcuni servizi gestiscono fallback
        let apiKey = getAPIKey(for: type) ?? ""
        
        // Create service based on type
        let service: AIServiceProtocol
        switch type {
        case .openAI:
            service = ModernOpenAIService(apiKey: apiKey)
        case .anthropic:
            // For now, return nil as we don't have a modern Anthropic service
            logger.error("Servizio Anthropic non ancora implementato")
            return nil
        case .perplexity:
            // For now, return nil as we don't have a modern Perplexity service
            logger.error("Servizio Perplexity non ancora implementato")
            return nil
        }
        
        serviceInstances[type] = service
        activeServices.insert(type)
        
        logger.info("Servizio \(type.rawValue) creato e attivato")
        return service
    }
    
    func removeService(for type: AIServiceType) {
        serviceInstances.removeValue(forKey: type)
        activeServices.remove(type)
        logger.info("Servizio \(type.rawValue) rimosso")
    }
    
    func clearAllServices() {
        serviceInstances.removeAll()
        activeServices.removeAll()
        logger.info("Tutti i servizi AI rimossi")
    }
    
    // MARK: - API Key Management
    private func getAPIKey(for type: AIServiceType) -> String? {
        let keyName: String
        switch type {
        case .openAI:
            keyName = "openai"
        case .anthropic:
            keyName = "anthropic"
        case .perplexity:
            keyName = "perplexity"
        }
        
        return KeychainManager.shared.getAPIKey(for: keyName)
    }
    
    // MARK: - Task Management
    func submitTask(_ task: AITask) {
        guard isInitialized else {
            logger.error("Coordinator non ancora inizializzato")
            return
        }
        
        taskManager.addTask(task)
        logger.info("Task \(task.type.rawValue) sottomesso al coordinator")
    }
    
    func cancelTask(_ taskId: UUID) {
        taskManager.cancelTask(taskId)
        logger.info("Task \(taskId) cancellato")
    }
    
    // MARK: - Memory Management
    private func handleMemoryPressure(_ pressure: MemoryPressure) {
        switch pressure {
        case .normal:
            logger.info("Pressione memoria normale")
        case .high:
            logger.warning("Pressione memoria elevata - ottimizzazione in corso")
            optimizeMemoryUsage()
        case .critical:
            logger.error("Pressione memoria critica - pulizia emergenziale")
            performEmergencyCleanup()
        }
    }
    
    private func optimizeMemoryUsage() {
        // Clear old cache entries - for now just log
        logger.info("Ottimizzazione cache in corso")
        
        // Cancel low priority tasks
        let lowPriorityTasks = taskManager.pendingTasks.filter { $0.priority == .low }
        lowPriorityTasks.forEach { taskManager.cancelTask($0.id) }
        
        logger.info("Ottimizzazione memoria completata")
    }
    
    private func performEmergencyCleanup() {
        // Clear all cache - for now just log
        logger.info("Pulizia cache emergenziale")
        
        // Cancel all pending tasks
        taskManager.pendingTasks.forEach { taskManager.cancelTask($0.id) }
        
        // Clear service instances
        clearAllServices()
        
        logger.info("Pulizia emergenziale completata")
    }
    
    // MARK: - Performance Management
    private func updateSystemHealth(_ metrics: PerformanceMetrics) {
        // Update system health based on performance metrics
        let cpuUsage = metrics.systemMetrics.cpuUsage
        let memoryUsage = metrics.systemMetrics.memoryUsage
        
        if cpuUsage > 0.9 || memoryUsage > 200 * 1024 * 1024 { // 200MB
            logger.warning("Performance degradata rilevata")
            triggerPerformanceOptimization()
        }
    }
    
    private func triggerPerformanceOptimization() {
        // Implement performance optimization strategies
        logger.info("Ottimizzazione performance attivata")
        
        // Reduce concurrent tasks
        // Optimize cache usage
        // Scale down service instances
    }
    
    private func updateCoordinatorStatus(isProcessing: Bool) {
        if isProcessing {
            currentStatus = .processing
        } else {
            currentStatus = .ready
        }
    }
    
    // MARK: - Public API
    func getSystemStatus() -> SystemStatus {
        return SystemStatus(
            isInitialized: isInitialized,
            coordinatorStatus: currentStatus,
            activeServices: Array(activeServices),
            systemHealth: systemHealth,
            cacheStats: cacheManager.cacheStats,
            memoryUsage: memoryManager.currentMemoryUsage,
            performanceMetrics: performanceMonitor.currentMetrics,
            taskStats: taskManager.getTaskStatistics()
        )
    }
    
    func shutdown() {
        logger.info("Arresto coordinator AI")
        
        // Stop health monitoring
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        
        // Stop task processing
        taskManager.stopProcessing()
        
        // Clear all services
        clearAllServices()
        
        // Clear cache - for now just log
        logger.info("Pulizia cache durante shutdown")
        
        currentStatus = .shutdown
        isInitialized = false
        
        logger.info("Coordinator AI arrestato")
    }
    
    func restart() {
        logger.info("Riavvio coordinator AI")
        shutdown()
        initializeServices()
    }
}

// MARK: - Supporting Types
enum CoordinatorStatus: String, CaseIterable {
    case initializing = "Inizializzazione"
    case ready = "Pronto"
    case processing = "Elaborazione"
    case error = "Errore"
    case shutdown = "Arrestato"
}

enum AIServiceType: String, CaseIterable, Hashable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case perplexity = "Perplexity"
}

struct SystemHealth {
    let cacheHealth: Bool
    let memoryHealth: Bool
    let performanceHealth: Bool
    let taskHealth: Bool
    let lastCheck: Date
    
    var isHealthy: Bool {
        return cacheHealth && memoryHealth && performanceHealth && taskHealth
    }
    
    var healthScore: Double {
        let checks = [cacheHealth, memoryHealth, performanceHealth, taskHealth]
        let healthyChecks = checks.filter { $0 }.count
        return Double(healthyChecks) / Double(checks.count)
    }
}

struct SystemStatus {
    let isInitialized: Bool
    let coordinatorStatus: CoordinatorStatus
    let activeServices: [AIServiceType]
    let systemHealth: SystemHealth
    let cacheStats: AICacheStats
    let memoryUsage: UInt64
    let performanceMetrics: PerformanceMetrics
    let taskStats: AITaskStatistics
    
    var summary: String {
        let healthStatus = systemHealth.isHealthy ? "Sano" : "Problemi rilevati"
        let serviceCount = activeServices.count
        let memoryMB = Double(memoryUsage) / (1024 * 1024)
        
        return """
        Status: \(coordinatorStatus.rawValue)
        Salute: \(healthStatus) (\(Int(systemHealth.healthScore * 100))%)
        Servizi attivi: \(serviceCount)
        Memoria: \(String(format: "%.1f", memoryMB)) MB
        Cache hit rate: \(String(format: "%.1f", cacheStats.hitRate * 100))%
        Task success rate: \(String(format: "%.1f", taskStats.successRate))%
        """
    }
} 
