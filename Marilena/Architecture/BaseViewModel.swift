import SwiftUI
import CoreData
import Combine

// MARK: - Base ViewModel
// ViewModel base che implementa i protocolli principali

@MainActor
class BaseViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingError = false
    @Published var searchText = ""
    @Published var isSearching = false
    
    // MARK: - Services
    let context: NSManagedObjectContext
    let coordinator: AppCoordinator
    
    // MARK: - Cancellables
    var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(context: NSManagedObjectContext, coordinator: AppCoordinator) {
        self.context = context
        self.coordinator = coordinator
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Binding per error handling
        $errorMessage
            .map { $0 != nil }
            .assign(to: \.showingError, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Loading Protocol Implementation
    func showLoading() {
        isLoading = true
    }
    
    func hideLoading() {
        isLoading = false
    }
    
    // MARK: - Error Handling Protocol Implementation
    func showError(_ message: String) {
        errorMessage = message
        coordinator.showError(message)
    }
    
    func clearError() {
        errorMessage = nil
        coordinator.clearError()
    }
    
    // MARK: - Search Protocol Implementation
    func performSearch() {
        isSearching = true
        // Implementazione specifica nelle sottoclassi
    }
    
    func clearSearch() {
        searchText = ""
        isSearching = false
    }
    
    // MARK: - Data Persistence Protocol Implementation
    func saveData() {
        do {
            try context.save()
        } catch {
            showError("Errore nel salvataggio: \(error.localizedDescription)")
        }
    }
    
    func loadData() {
        // Implementazione specifica nelle sottoclassi
    }
    
    func clearData() {
        // Implementazione specifica nelle sottoclassi
    }
    
    func exportData() -> Data? {
        // Implementazione specifica nelle sottoclassi
        return nil
    }
    
    func importData(_ data: Data) {
        // Implementazione specifica nelle sottoclassi
    }
    
    // MARK: - Validation Protocol Implementation
    func validateEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    func validatePhone(_ phone: String) -> Bool {
        let phoneRegex = "^[+]?[0-9]{10,15}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: phone)
    }
    
    func validateURL(_ url: String) -> Bool {
        guard let url = URL(string: url) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
    
    func validateRequired(_ value: String) -> Bool {
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Formatting Protocol Implementation
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    func formatPercentage(_ value: Double) -> String {
        return String(format: "%.1f%%", value * 100)
    }
    
    // MARK: - Logging Protocol Implementation
    func logInfo(_ message: String) {
        print("ℹ️ [INFO] \(message)")
    }
    
    func logWarning(_ message: String) {
        print("⚠️ [WARNING] \(message)")
    }
    
    func logError(_ message: String, error: Error? = nil) {
        if let error = error {
            print("❌ [ERROR] \(message): \(error.localizedDescription)")
        } else {
            print("❌ [ERROR] \(message)")
        }
    }
    
    func logDebug(_ message: String) {
        #if DEBUG
        print("🔍 [DEBUG] \(message)")
        #endif
    }
    
    // MARK: - Utility Methods
    func debounce<T>(_ publisher: AnyPublisher<T, Never>, delay: TimeInterval = 0.5) -> AnyPublisher<T, Never> {
        return publisher
            .debounce(for: .seconds(delay), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    func throttle<T>(_ publisher: AnyPublisher<T, Never>, interval: TimeInterval = 1.0) -> AnyPublisher<T, Never> {
        return publisher
            .throttle(for: .seconds(interval), scheduler: RunLoop.main, latest: true)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Lifecycle
    func onAppear() {
        logDebug("ViewModel appeared")
    }
    
    func onDisappear() {
        logDebug("ViewModel disappeared")
        cancellables.removeAll()
    }
}

// MARK: - List ViewModel
class ListViewModel<T: Identifiable>: BaseViewModel {
    @Published var items: [T] = []
    @Published var filteredItems: [T] = []
    
    override func performSearch() {
        isSearching = true
        // Implementazione di default - filtra gli items
        if searchText.isEmpty {
            filteredItems = items
        } else {
            // Implementazione specifica nelle sottoclassi
            filteredItems = items
        }
        isSearching = false
    }
    
    func loadItems() {
        showLoading()
        // Implementazione specifica nelle sottoclassi
        hideLoading()
    }
    
    func deleteItem(_ item: T) {
        // Implementazione specifica nelle sottoclassi
    }
    
    func selectItem(_ item: T) {
        // Implementazione specifica nelle sottoclassi
    }
}

// MARK: - Detail ViewModel
class DetailViewModel<T: Identifiable>: BaseViewModel {
    @Published var item: T
    
    init(item: T, context: NSManagedObjectContext, coordinator: AppCoordinator) {
        self.item = item
        super.init(context: context, coordinator: coordinator)
    }
    
    func saveItem() {
        showLoading()
        saveData()
        hideLoading()
    }
    
    func deleteItem() {
        showLoading()
        // Implementazione specifica nelle sottoclassi
        hideLoading()
    }
    
    func shareItem() {
        // Implementazione specifica nelle sottoclassi
    }
}

// MARK: - Chat ViewModel
class ChatViewModel: BaseViewModel {
    @Published var messages: [ChatMessage] = []
    @Published var messageText = ""
    @Published var selectedModel = "gpt-4o-mini"
    @Published var selectedPerplexityModel = "sonar-pro"
    
    let chat: ChatMarilena
    private let openAIService = OpenAIService.shared
    private let perplexityService = PerplexityService.shared
    
    init(chat: ChatMarilena, context: NSManagedObjectContext, coordinator: AppCoordinator) {
        self.chat = chat
        super.init(context: context, coordinator: coordinator)
        loadMessages()
    }
    
    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let text = messageText
        messageText = ""
        
        // Aggiungi messaggio utente
        let userMessage = MessaggioMarilena(context: context)
        userMessage.id = UUID()
        userMessage.contenuto = text
        userMessage.isUser = true
        userMessage.dataCreazione = Date()
        userMessage.chat = chat
        
        saveData()
        loadMessages()
        
        // Invia all'AI
        sendToAI(text)
    }
    
    func searchWithPerplexity() {
        let query = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        messageText = ""
        showLoading()
        
        Task {
            do {
                let result = try await perplexityService.search(query: query, model: selectedPerplexityModel)
                await MainActor.run {
                    hideLoading()
                    // Gestisci risultato
                }
            } catch {
                await MainActor.run {
                    hideLoading()
                    showError("Errore ricerca: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func selectModel(_ model: String) {
        selectedModel = model
        UserDefaults.standard.set(model, forKey: "selected_model")
    }
    
    private func sendToAI(_ text: String) {
        showLoading()
        
        let messages = buildConversationHistory(newMessage: text)
        
        openAIService.sendMessage(messages: messages, model: selectedModel) { [weak self] result in
            DispatchQueue.main.async {
                self?.hideLoading()
                
                switch result {
                case .success(let response):
                    self?.addAIMessage(response)
                case .failure(let error):
                    self?.showError("Errore AI: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func addAIMessage(_ content: String) {
        let aiMessage = MessaggioMarilena(context: context)
        aiMessage.id = UUID()
        aiMessage.contenuto = content
        aiMessage.isUser = false
        aiMessage.dataCreazione = Date()
        aiMessage.chat = chat
        
        saveData()
        loadMessages()
    }
    
    private func loadMessages() {
        let messaggi = chat.messaggi?.allObjects as? [MessaggioMarilena] ?? []
        let messaggiOrdinati = messaggi.sorted { 
            ($0.dataCreazione ?? Date()) < ($1.dataCreazione ?? Date()) 
        }
        
        messages = messaggiOrdinati.map { messaggio in
            ChatMessage(
                content: messaggio.contenuto ?? "",
                isUser: messaggio.isUser,
                timestamp: messaggio.dataCreazione ?? Date()
            )
        }
    }
    
    private func buildConversationHistory(newMessage: String) -> [OpenAIMessage] {
        var messages: [OpenAIMessage] = []
        
        // Aggiungi messaggi precedenti
        for message in self.messages {
            messages.append(OpenAIMessage(
                role: message.isUser ? "user" : "assistant",
                content: message.content
            ))
        }
        
        // Aggiungi il nuovo messaggio
        messages.append(OpenAIMessage(role: "user", content: newMessage))
        
        return messages
    }
}

// MARK: - Recording ViewModel
class RecordingViewModel: BaseViewModel {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordings: [RegistrazioneAudio] = []
    
    private var recordingTimer: Timer?
    
    override func onAppear() {
        super.onAppear()
        loadRecordings()
    }
    
    func startRecording() {
        coordinator.startRecording()
        isRecording = true
        startTimer()
    }
    
    func stopRecording() {
        coordinator.stopRecording()
        isRecording = false
        stopTimer()
        loadRecordings()
    }
    
    func pauseRecording() {
        // Implementazione specifica
    }
    
    func resumeRecording() {
        // Implementazione specifica
    }
    
    private func startTimer() {
        recordingDuration = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.recordingDuration += 1
        }
    }
    
    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = 0
    }
    
    private func loadRecordings() {
        let request: NSFetchRequest<RegistrazioneAudio> = RegistrazioneAudio.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \RegistrazioneAudio.dataCreazione, ascending: false)]
        
        do {
            recordings = try context.fetch(request)
        } catch {
            showError("Errore caricamento registrazioni: \(error.localizedDescription)")
        }
    }
} 