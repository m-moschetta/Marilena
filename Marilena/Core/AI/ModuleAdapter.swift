import SwiftUI
import CoreData
import Combine

// MARK: - Module Adapter
// Adapter per integrare i moduli modulari con l'architettura esistente

public class ModuleAdapter: ObservableObject {
    @Published public var objectWillChange = ObservableObjectPublisher()
    
    // MARK: - Properties
    
    private let context: NSManagedObjectContext
    private let aiProviderManager: AIProviderManager
    private let promptManager: PromptManager
    
    // MARK: - Initialization
    
    public init(context: NSManagedObjectContext) {
        self.context = context
        self.aiProviderManager = AIProviderManager.shared
        self.promptManager = PromptManager.shared
    }
    
    // MARK: - Chat Module Integration
    
    public func createModularChatView(for chat: ChatMarilena) -> ModularChatView {
        // Converti ChatMarilena in ModularChatSession
        let session = convertChatToSession(chat)
        
        // Crea configurazione per il modulo
        let configuration = ChatConfiguration(
            session: session,
            aiProviderManager: aiProviderManager,
            promptManager: promptManager,
            context: context,
            adapter: self
        )
        
        return ModularChatView(
            title: chat.titolo ?? "Chat AI",
            configuration: configuration,
            showSettings: true
        )
    }
    
    public func createModularTranscriptionView(for recording: RegistrazioneAudio) -> ModularTranscriptionView {
        // Converti RegistrazioneAudio in ModularTranscriptionSession
        _ = convertRecordingToSession(recording)
        
        // Crea configurazione per il modulo
        let configuration = ModularTranscriptionConfiguration(
            mode: .auto,
            language: "it-IT",
            enableTimestamps: true,
            enableConfidence: true,
            enableSegments: true,
            maxProcessingTime: 300.0,
            retryCount: 3
        )
        
        return ModularTranscriptionView(
            title: "Trascrizione Audio",
            configuration: configuration,
            showSettings: true
        )
    }
    
    // MARK: - Conversion Methods
    
    private func convertChatToSession(_ chat: ChatMarilena) -> ModularChatSession {
        let allMessages = chat.messaggi?.allObjects as? [MessaggioMarilena] ?? []
        let sortedMessages = allMessages.sorted { ($0.dataCreazione ?? Date()) < ($1.dataCreazione ?? Date()) }
        let messages = sortedMessages.map { message in
                ModularChatMessage(
                    id: message.id ?? UUID(),
                    content: message.contenuto ?? "",
                    role: message.isUser ? .user : .assistant,
                    timestamp: message.dataCreazione ?? Date(),
                    metadata: MessageMetadata(
                        model: "unknown",
                        processingTime: nil,
                        context: nil
                    )
                )
            }
        
        return ModularChatSession(
            id: chat.id ?? UUID(),
            title: chat.titolo ?? "Chat",
            messages: messages,
            createdAt: chat.dataCreazione ?? Date(),
            updatedAt: Date(),
            type: "chat"
        )
    }
    
    private func convertRecordingToSession(_ recording: RegistrazioneAudio) -> ModularTranscriptionSession {
        let configuration = ModularTranscriptionConfiguration(
            mode: .auto,
            language: "it-IT",
            enableTimestamps: true,
            enableConfidence: true,
            enableSegments: true,
            maxProcessingTime: 300.0,
            retryCount: 3
        )
        
        let allTranscriptions = recording.trascrizioni?.allObjects as? [Trascrizione] ?? []
        let sortedTranscriptions = allTranscriptions.sorted { ($0.dataCreazione ?? Date()) > ($1.dataCreazione ?? Date()) }
                let transcriptions = sortedTranscriptions.map { transcription in
            ModularTranscriptionResult(
                text: transcription.testoCompleto ?? "",
                confidence: transcription.accuratezza,
                timestamps: [:],
                detectedLanguage: transcription.linguaRilevata ?? "it-IT",
                wordCount: Int(transcription.paroleTotali),
                framework: .speechFramework,
                processingTime: 0.0,
                segments: []
            )
        }
        
        return ModularTranscriptionSession(
            id: recording.id ?? UUID(),
            audioURL: recording.pathFile ?? URL(fileURLWithPath: ""),
            configuration: configuration
        )
    }
    
    // MARK: - Save Methods
    
    public func saveChatSession(_ session: ModularChatSession) {
        // Trova o crea il ChatMarilena corrispondente
        let fetchRequest: NSFetchRequest<ChatMarilena> = ChatMarilena.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
        
        do {
            let existingChats = try context.fetch(fetchRequest)
            let chat = existingChats.first ?? ChatMarilena(context: context)
            
            // Aggiorna i dati del chat
            chat.id = session.id
            chat.titolo = session.title
            chat.dataCreazione = session.createdAt
            chat.tipo = session.type
            
            // Salva i messaggi
            for message in session.messages {
                let chatMessage = MessaggioMarilena(context: context)
                chatMessage.id = message.id
                chatMessage.contenuto = message.content
                chatMessage.isUser = message.role == .user
                chatMessage.dataCreazione = message.timestamp
                chatMessage.chat = chat
            }
            
            try context.save()
        } catch {
            print("Errore salvataggio chat session: \(error)")
        }
    }
    
    public func saveTranscriptionSession(_ session: ModularTranscriptionSession) {
        // Trova o crea la RegistrazioneAudio corrispondente
        let fetchRequest: NSFetchRequest<RegistrazioneAudio> = RegistrazioneAudio.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
        
        do {
            let existingRecordings = try context.fetch(fetchRequest)
            let recording = existingRecordings.first ?? RegistrazioneAudio(context: context)
            
            // Aggiorna i dati della registrazione
            recording.id = session.id
            recording.titolo = "Registrazione"
            recording.dataCreazione = session.createdAt
            recording.pathFile = session.audioURL
            
            // Salva la trascrizione se disponibile
            if let result = session.result {
                let transcription = Trascrizione(context: context)
                transcription.id = UUID()
                transcription.testoCompleto = result.text
                transcription.accuratezza = result.confidence
                transcription.linguaRilevata = result.detectedLanguage
                transcription.dataCreazione = Date()
                transcription.paroleTotali = Int32(result.wordCount)
                transcription.frameworkUtilizzato = "SpeechFramework"
                transcription.registrazione = recording
            }
            
            try context.save()
        } catch {
            print("Errore salvataggio transcription session: \(error)")
        }
    }
} 