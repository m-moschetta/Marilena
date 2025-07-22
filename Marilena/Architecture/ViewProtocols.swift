import SwiftUI
import CoreData

// MARK: - View Protocols
// Protocolli per standardizzare le viste e separare logica dall'interfaccia

// MARK: - Base View Protocol
protocol BaseViewProtocol: View {
    associatedtype Coordinator: ObservableObject
    var coordinator: Coordinator { get }
}

// MARK: - List View Protocol
protocol ListViewProtocol: BaseViewProtocol {
    associatedtype Item: Identifiable
    var items: [Item] { get }
    var isLoading: Bool { get }
    var searchText: String { get set }
    
    func loadItems()
    func deleteItem(_ item: Item)
    func selectItem(_ item: Item)
}

// MARK: - Detail View Protocol
protocol DetailViewProtocol: BaseViewProtocol {
    associatedtype Item: Identifiable
    var item: Item { get }
    
    func saveItem()
    func deleteItem()
    func shareItem()
}

// MARK: - Chat View Protocol
protocol ChatViewProtocol: BaseViewProtocol {
    var messages: [ChatMessage] { get }
    var isLoading: Bool { get }
    var messageText: String { get set }
    
    func sendMessage()
    func searchWithPerplexity()
    func selectModel(_ model: String)
}

// MARK: - Recording View Protocol
protocol RecordingViewProtocol: BaseViewProtocol {
    var isRecording: Bool { get }
    var recordingDuration: TimeInterval { get }
    
    func startRecording()
    func stopRecording()
    func pauseRecording()
    func resumeRecording()
}

// MARK: - Transcription View Protocol
protocol TranscriptionViewProtocol: BaseViewProtocol {
    var transcription: String { get }
    var isTranscribing: Bool { get }
    var confidence: Double { get }
    
    func startTranscription()
    func stopTranscription()
    func exportTranscription()
}

// MARK: - Profile View Protocol
protocol ProfileViewProtocol: BaseViewProtocol {
    var profile: ProfiloUtente { get }
    var isEditing: Bool { get set }
    
    func saveProfile()
    func updateContext()
    func exportProfile()
}

// MARK: - Settings View Protocol
protocol SettingsViewProtocol: BaseViewProtocol {
    var selectedModel: String { get set }
    var temperature: Double { get set }
    var maxTokens: Double { get set }
    
    func saveSettings()
    func testConnection()
    func resetSettings()
}

// MARK: - Error Handling Protocol
protocol ErrorHandlingProtocol {
    var errorMessage: String? { get set }
    var showingError: Bool { get set }
    
    func showError(_ message: String)
    func clearError()
}

// MARK: - Loading Protocol
protocol LoadingProtocol {
    var isLoading: Bool { get set }
    
    func showLoading()
    func hideLoading()
}

// MARK: - Search Protocol
protocol SearchProtocol {
    var searchText: String { get set }
    var searchResults: [Any] { get }
    var isSearching: Bool { get }
    
    func performSearch()
    func clearSearch()
}

// MARK: - Export Protocol
protocol ExportProtocol {
    func exportAsText() -> String
    func exportAsJSON() -> Data?
    func exportAsPDF() -> Data?
    func shareContent()
}

// MARK: - Analytics Protocol
protocol AnalyticsProtocol {
    func trackEvent(_ event: String, properties: [String: Any]?)
    func trackScreen(_ screen: String)
    func trackError(_ error: Error)
}

// MARK: - Accessibility Protocol
protocol AccessibilityProtocol {
    var accessibilityLabel: String { get }
    var accessibilityHint: String { get }
    var accessibilityValue: String { get }
    
    func configureAccessibility()
}

// MARK: - Deep Link Protocol
protocol DeepLinkProtocol {
    func handleDeepLink(_ url: URL)
    func canHandleDeepLink(_ url: URL) -> Bool
}

// MARK: - State Management Protocol
protocol StateManagementProtocol {
    associatedtype State
    var currentState: State { get set }
    
    func updateState(_ newState: State)
    func resetState()
}

// MARK: - Data Persistence Protocol
protocol DataPersistenceProtocol {
    func saveData()
    func loadData()
    func clearData()
    func exportData() -> Data?
    func importData(_ data: Data)
}

// MARK: - Network Protocol
protocol NetworkProtocol {
    var isConnected: Bool { get }
    var connectionType: ConnectionType { get }
    
    func checkConnection()
    func retryConnection()
}

enum ConnectionType {
    case wifi
    case cellular
    case ethernet
    case none
}

// MARK: - Permission Protocol
protocol PermissionProtocol {
    var microphonePermission: PermissionStatus { get }
    var speechPermission: PermissionStatus { get }
    var notificationPermission: PermissionStatus { get }
    
    func requestMicrophonePermission()
    func requestSpeechPermission()
    func requestNotificationPermission()
}

enum PermissionStatus {
    case granted
    case denied
    case notDetermined
    case restricted
}

// MARK: - Theme Protocol
protocol ThemeProtocol {
    var isDarkMode: Bool { get }
    var accentColor: Color { get }
    var backgroundColor: Color { get }
    var textColor: Color { get }
    
    func toggleTheme()
    func setTheme(_ isDark: Bool)
}

// MARK: - Localization Protocol
protocol LocalizationProtocol {
    var currentLanguage: String { get }
    var supportedLanguages: [String] { get }
    
    func setLanguage(_ language: String)
    func localizedString(_ key: String) -> String
}

// MARK: - Security Protocol
protocol SecurityProtocol {
    func encryptData(_ data: Data) -> Data?
    func decryptData(_ data: Data) -> Data?
    func validateInput(_ input: String) -> Bool
    func sanitizeInput(_ input: String) -> String
}

// MARK: - Cache Protocol
protocol CacheProtocol {
    func cacheData(_ data: Data, for key: String)
    func getCachedData(for key: String) -> Data?
    func clearCache()
    func clearCache(for key: String)
}

// MARK: - Logging Protocol
protocol LoggingProtocol {
    func logInfo(_ message: String)
    func logWarning(_ message: String)
    func logError(_ message: String, error: Error?)
    func logDebug(_ message: String)
}

// MARK: - Validation Protocol
protocol ValidationProtocol {
    func validateEmail(_ email: String) -> Bool
    func validatePhone(_ phone: String) -> Bool
    func validateURL(_ url: String) -> Bool
    func validateRequired(_ value: String) -> Bool
}

// MARK: - Formatting Protocol
protocol FormattingProtocol {
    func formatDate(_ date: Date) -> String
    func formatDuration(_ duration: TimeInterval) -> String
    func formatFileSize(_ size: Int64) -> String
    func formatPercentage(_ value: Double) -> String
} 