import Foundation
import Combine
import os.log

// MARK: - AI Task Manager
@MainActor
class AITaskManager: ObservableObject {
    static let shared = AITaskManager()
    
    private let logger = Logger(subsystem: "com.marilena.ai", category: "taskmanager")
    private let taskQueue = DispatchQueue(label: "com.marilena.tasks", qos: .userInitiated)
    private let maxConcurrentTasks = 3
    private let maxRetries = 3
    
    @Published var activeTasks: [AITask] = []
    @Published var pendingTasks: [AITask] = []
    @Published var completedTasks: [AITask] = []
    @Published var failedTasks: [AITask] = []
    @Published var isProcessing = false
    
    private var taskCancellables: [UUID: AnyCancellable] = [:]
    private var processingTimer: Timer?
    
    private init() {
        startProcessing()
    }
    
    deinit {
        processingTimer?.invalidate()
        taskCancellables.values.forEach { $0.cancel() }
    }
    
    // MARK: - Task Management
    private func startProcessing() {
        isProcessing = true
        logger.info("Avvio gestione task AI")
        
        processingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                Task { @MainActor in
                    self?.processNextTask()
                }
            }
        }
    }
    
    private func processNextTask() {
        guard activeTasks.count < maxConcurrentTasks,
              let nextTask = getNextTask() else {
            return
        }
        
        // Sposta il task da pending a active
        pendingTasks.removeAll { $0.id == nextTask.id }
        activeTasks.append(nextTask)
        
        logger.info("Avvio task: \(nextTask.id) - \(nextTask.type.rawValue)")
        
        // Esegui il task
        executeTask(nextTask)
    }
    
    private func getNextTask() -> AITask? {
        return pendingTasks
            .sorted { $0.priority.rawValue > $1.priority.rawValue }
            .first
    }
    
    private func executeTask(_ task: AITask) {
        let cancellable = task.execute()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    Task { @MainActor in
                        self?.handleTaskCompletion(task, completion: completion)
                    }
                },
                receiveValue: { [weak self] result in
                    Task { @MainActor in
                        self?.handleTaskResult(task, result: result)
                    }
                }
            )
        
        taskCancellables[task.id] = cancellable
    }
    
    private func handleTaskCompletion(_ task: AITask, completion: Subscribers.Completion<Error>) {
        // Rimuovi il task da active
        activeTasks.removeAll { $0.id == task.id }
        taskCancellables[task.id]?.cancel()
        taskCancellables.removeValue(forKey: task.id)
        
        switch completion {
        case .finished:
            logger.info("Task completato con successo: \(task.id)")
            completedTasks.append(task)
            
        case .failure(let error):
            logger.error("Task fallito: \(task.id) - \(error.localizedDescription)")
            
            if task.retryCount < maxRetries {
                // Riprova il task
                let retryTask = task.retry()
                pendingTasks.append(retryTask)
                logger.info("Riprova task: \(task.id) - Tentativo \(retryTask.retryCount)")
            } else {
                // Task fallito definitivamente
                failedTasks.append(task)
                logger.error("Task fallito definitivamente: \(task.id)")
            }
        }
    }
    
    private func handleTaskResult(_ task: AITask, result: AITaskResult) {
        // Gestisci il risultato del task
        logger.info("Risultato task: \(task.id) - \(result.status.rawValue)")
        
        // Aggiorna le statistiche
        updateTaskStatistics(task, result: result)
    }
    
    private func updateTaskStatistics(_ task: AITask, result: AITaskResult) {
        // Aggiorna le statistiche del task manager
        // Implementazione futura per metriche e analytics
    }
    
    // MARK: - Public API
    func addTask(_ task: AITask) {
        pendingTasks.append(task)
        logger.info("Task aggiunto: \(task.id) - \(task.type.rawValue)")
    }
    
    func cancelTask(_ taskId: UUID) {
        if let task = activeTasks.first(where: { $0.id == taskId }) {
            taskCancellables[taskId]?.cancel()
            taskCancellables.removeValue(forKey: taskId)
            activeTasks.removeAll { $0.id == taskId }
            logger.info("Task cancellato: \(taskId)")
        }
        
        pendingTasks.removeAll { $0.id == taskId }
    }
    
    func pauseTask(_ taskId: UUID) {
        if let task = activeTasks.first(where: { $0.id == taskId }) {
            cancelTask(taskId)
            let pausedTask = task.pause()
            pendingTasks.append(pausedTask)
            logger.info("Task messo in pausa: \(taskId)")
        }
    }
    
    func resumeTask(_ taskId: UUID) {
        if let task = pendingTasks.first(where: { $0.id == taskId && $0.status == .paused }) {
            pendingTasks.removeAll { $0.id == taskId }
            let resumedTask = task.resume()
            pendingTasks.append(resumedTask)
            logger.info("Task ripreso: \(taskId)")
        }
    }
    
    func clearCompletedTasks() {
        completedTasks.removeAll()
        logger.info("Task completati puliti")
    }
    
    func clearFailedTasks() {
        failedTasks.removeAll()
        logger.info("Task falliti puliti")
    }
    
    func getTaskStatistics() -> AITaskStatistics {
        return AITaskStatistics(
            totalTasks: activeTasks.count + pendingTasks.count + completedTasks.count + failedTasks.count,
            activeTasks: activeTasks.count,
            pendingTasks: pendingTasks.count,
            completedTasks: completedTasks.count,
            failedTasks: failedTasks.count,
            averageExecutionTime: calculateAverageExecutionTime()
        )
    }
    
    private func calculateAverageExecutionTime() -> TimeInterval {
        let completedWithTime = completedTasks.filter { $0.executionTime > 0 }
        guard !completedWithTime.isEmpty else { return 0 }
        
        let totalTime = completedWithTime.reduce(0) { $0 + $1.executionTime }
        return totalTime / Double(completedWithTime.count)
    }
    
    func stopProcessing() {
        isProcessing = false
        processingTimer?.invalidate()
        processingTimer = nil
        
        // Cancella tutti i task attivi
        activeTasks.forEach { cancelTask($0.id) }
        
        logger.info("Gestione task AI fermata")
    }
}

// MARK: - Supporting Types
struct AITask: Identifiable, Equatable {
    let id: UUID
    let type: TaskType
    let priority: TaskPriority
    let payload: TaskPayload
    let createdAt: Date
    var status: TaskStatus
    var retryCount: Int
    var executionTime: TimeInterval
    var result: AITaskResult?
    
    init(type: TaskType, priority: TaskPriority = .normal, payload: TaskPayload) {
        self.id = UUID()
        self.type = type
        self.priority = priority
        self.payload = payload
        self.createdAt = Date()
        self.status = .pending
        self.retryCount = 0
        self.executionTime = 0
        self.result = nil
    }
    
    func execute() -> AnyPublisher<AITaskResult, Error> {
        let startTime = Date()
        
        return Future<AITaskResult, Error> { promise in
            // Simula l'esecuzione del task
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                let executionTime = Date().timeIntervalSince(startTime)
                
                // Simula successo o fallimento casuale
                if Bool.random() {
                    let result = AITaskResult(
                        taskId: self.id,
                        status: .completed,
                        data: "Task completato con successo",
                        executionTime: executionTime
                    )
                    promise(.success(result))
                } else {
                    promise(.failure(TaskError.executionFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func retry() -> AITask {
        var retryTask = self
        retryTask.retryCount += 1
        retryTask.status = .pending
        return retryTask
    }
    
    func pause() -> AITask {
        var pausedTask = self
        pausedTask.status = .paused
        return pausedTask
    }
    
    func resume() -> AITask {
        var resumedTask = self
        resumedTask.status = .pending
        return resumedTask
    }
    
    // MARK: - Equatable
    static func == (lhs: AITask, rhs: AITask) -> Bool {
        return lhs.id == rhs.id
    }
}

enum TaskType: String, CaseIterable {
    case chatCompletion = "Chat Completion"
    case transcription = "Transcription"
    case emailAnalysis = "Email Analysis"
    case contextUpdate = "Context Update"
    case cacheCleanup = "Cache Cleanup"
    case performanceOptimization = "Performance Optimization"
}

enum TaskPriority: Int, CaseIterable {
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4
    
    var description: String {
        switch self {
        case .low: return "Bassa"
        case .normal: return "Normale"
        case .high: return "Alta"
        case .critical: return "Critica"
        }
    }
}

enum TaskStatus: String, CaseIterable {
    case pending = "In attesa"
    case active = "Attivo"
    case completed = "Completato"
    case failed = "Fallito"
    case paused = "In pausa"
    case cancelled = "Cancellato"
}

struct TaskPayload: Equatable {
    let data: [String: String]
    let metadata: [String: String]
    
    init(data: [String: String] = [:], metadata: [String: String] = [:]) {
        self.data = data
        self.metadata = metadata
    }
}

struct AITaskResult: Equatable {
    let taskId: UUID
    let status: TaskResultStatus
    let data: String
    let executionTime: TimeInterval
    let timestamp: Date
    
    init(taskId: UUID, status: TaskResultStatus, data: String, executionTime: TimeInterval) {
        self.taskId = taskId
        self.status = status
        self.data = data
        self.executionTime = executionTime
        self.timestamp = Date()
    }
}

enum TaskResultStatus: String, CaseIterable {
    case completed = "Completato"
    case partial = "Parziale"
    case failed = "Fallito"
    case cancelled = "Cancellato"
}

enum TaskError: Error, LocalizedError {
    case executionFailed
    case timeout
    case invalidPayload
    case resourceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .executionFailed:
            return "Esecuzione del task fallita"
        case .timeout:
            return "Timeout del task"
        case .invalidPayload:
            return "Payload del task non valido"
        case .resourceUnavailable:
            return "Risorse non disponibili"
        }
    }
}

struct AITaskStatistics {
    let totalTasks: Int
    let activeTasks: Int
    let pendingTasks: Int
    let completedTasks: Int
    let failedTasks: Int
    let averageExecutionTime: TimeInterval
    
    var successRate: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks) * 100
    }
    
    var failureRate: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(failedTasks) / Double(totalTasks) * 100
    }
} 