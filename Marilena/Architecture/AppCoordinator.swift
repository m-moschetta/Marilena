import SwiftUI
import CoreData
import Combine

// MARK: - App Coordinator
// Gestisce la logica di navigazione e stato dell'app indipendentemente dall'interfaccia

@MainActor
class AppCoordinator: ObservableObject {
    @Published var currentRoute: AppRoute = .main
    @Published var selectedTab: Int = 1 // Default al registratore
    @Published var activeChat: ChatMarilena?
    @Published var activeRecording: RegistrazioneAudio?
    @Published var showingSettings = false
    @Published var showingNewChat = false
    
    // Servizi condivisi
    let recordingService: RecordingService
    let transcriptionService: SpeechTranscriptionService
    let profiloService = ProfiloUtenteService.shared
    
    // Stato dell'app
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init(context: NSManagedObjectContext) {
        self.recordingService = RecordingService(context: context)
        self.transcriptionService = SpeechTranscriptionService(context: context)
    }
    
    // MARK: - Navigation Methods
    
    func navigate(to route: AppRoute) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentRoute = route
        }
    }
    
    func selectTab(_ tab: Int) {
        selectedTab = tab
    }
    
    func openChat(_ chat: ChatMarilena) {
        activeChat = chat
        navigate(to: .chat(chat))
    }
    
    func openRecording(_ recording: RegistrazioneAudio) {
        activeRecording = recording
        navigate(to: .recordingDetail(recording))
    }
    
    func closeActiveItem() {
        activeChat = nil
        activeRecording = nil
        navigate(to: .main)
    }
    
    // MARK: - Business Logic
    
    func createNewChat() {
        showingNewChat = true
    }
    
    func startRecording() {
        recordingService.startRecording()
    }
    
    func stopRecording() {
        recordingService.stopRecording()
    }
    
    func showSettings() {
        showingSettings = true
    }
    
    func dismissSettings() {
        showingSettings = false
    }
    
    func dismissNewChat() {
        showingNewChat = false
    }
    
    // MARK: - Error Handling
    
    func showError(_ message: String) {
        errorMessage = message
    }
    
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - App Routes

enum AppRoute: Equatable {
    case main
    case chat(ChatMarilena)
    case recordingDetail(RegistrazioneAudio)
    case profile
    case settings
    case transcriptionAnalysis(RegistrazioneAudio)
    
    static func == (lhs: AppRoute, rhs: AppRoute) -> Bool {
        switch (lhs, rhs) {
        case (.main, .main):
            return true
        case (.chat(let lhsChat), .chat(let rhsChat)):
            return lhsChat.id == rhsChat.id
        case (.recordingDetail(let lhsRecording), .recordingDetail(let rhsRecording)):
            return lhsRecording.id == rhsRecording.id
        case (.profile, .profile):
            return true
        case (.settings, .settings):
            return true
        case (.transcriptionAnalysis(let lhsRecording), .transcriptionAnalysis(let rhsRecording)):
            return lhsRecording.id == rhsRecording.id
        default:
            return false
        }
    }
} 