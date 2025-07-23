import Foundation
import Speech
import AVFoundation
import Combine
import NaturalLanguage

// SpeechAnalyzer import condizionale per iOS 26+
#if canImport(SpeechAnalyzer)
import SpeechAnalyzer
#endif

// MARK: - Modular Transcription Service
// Servizio di trascrizione modulare e riutilizzabile

@MainActor
public class ModularTranscriptionService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var currentSession: ModularTranscriptionSession?
    @Published public var isPermissionGranted = false
    @Published public var volatileText: String = ""
    @Published public var finalizedText: String = ""
    @Published public var detectedLanguage: String = ""
    @Published public var currentProgress: Double = 0.0
    
    // MARK: - Private Properties
    
    private var sessions: [ModularTranscriptionSession] = []
    private var availableFramework: ModularTranscriptionFramework
    
    // iOS 26+ SpeechAnalyzer
    #if canImport(SpeechAnalyzer)
    @available(iOS 26.0, *)
    private var speechAnalyzer: SpeechAnalyzer?
    @available(iOS 26.0, *)
    private var speechTranscriber: SpeechTranscriber?
    @available(iOS 26.0, *)
    private var analyzerFormat: AVAudioFormat?
    #endif
    
    // iOS 13-25 Speech Framework (fallback)
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    
    // Gestione testo e timing
    private var textSegments: [ModularTranscriptionSegment] = []
    private var timestampMap: [TimeInterval: String] = [:]
    
    // MARK: - Initialization
    
    public override init() {
        // Determina quale framework utilizzare
        let selectedMode = UserDefaults.standard.string(forKey: "transcription_mode") ?? "auto"
        
        switch selectedMode {
        case "speech_analyzer":
            #if canImport(SpeechAnalyzer)
            if #available(iOS 26.0, *) {
                self.availableFramework = .speechAnalyzer
            } else {
                print("⚠️ Speech Analyzer richiesto ma iOS 26+ non disponibile, fallback a Speech Framework")
                self.availableFramework = .speechFramework
            }
            #else
            print("⚠️ Speech Analyzer richiesto ma non disponibile, fallback a Speech Framework")
            self.availableFramework = .speechFramework
            #endif
            
        case "speech_framework":
            if #available(iOS 13.0, *) {
                self.availableFramework = .speechFramework
            } else {
                print("❌ Speech Framework non disponibile su questa versione iOS")
                self.availableFramework = .unavailable
            }
            
        case "whisper":
            if #available(iOS 13.0, *) {
                self.availableFramework = .speechFramework
            } else {
                self.availableFramework = .unavailable
            }
            
        case "local":
            if #available(iOS 13.0, *) {
                self.availableFramework = .speechFramework
            } else {
                self.availableFramework = .unavailable
            }
            
        default: // "auto"
            #if canImport(SpeechAnalyzer)
            if #available(iOS 26.0, *) {
                self.availableFramework = .speechAnalyzer
            } else if #available(iOS 13.0, *) {
                self.availableFramework = .speechFramework
            } else {
                self.availableFramework = .unavailable
            }
            #else
            if #available(iOS 13.0, *) {
                self.availableFramework = .speechFramework
            } else {
                self.availableFramework = .unavailable
            }
            #endif
        }
        
        super.init()
        
        setupSpeechRecognition()
        checkPermissions()
        
        print("🎤 Framework trascrizione selezionato: \(frameworkDescription)")
    }
    
    // MARK: - Public Methods
    
    public func transcribeAudio(
        url: URL,
        configuration: ModularTranscriptionConfiguration
    ) async throws -> ModularTranscriptionResult {
        
        print("🎤 ModularTranscriptionService: Inizio trascrizione")
        print("🎤 ModularTranscriptionService: URL: \(url)")
        print("🎤 ModularTranscriptionService: Lingua: \(configuration.language)")
        
        // Crea sessione
        let session = ModularTranscriptionSession(
            audioURL: url,
            configuration: configuration
        )
        
        await MainActor.run {
            currentSession = session
            sessions.append(session)
            currentProgress = 0.0
            volatileText = ""
            finalizedText = ""
        }
        
        // Verifica permessi
        guard isPermissionGranted else {
            throw ModularTranscriptionError.permissionDenied
        }
        
        // Verifica file audio
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ModularTranscriptionError.audioFileNotFound
        }
        
        // Verifica formato audio
        do {
            let audioFile = try AVAudioFile(forReading: url)
            print("🎤 ModularTranscriptionService: Formato audio: \(audioFile.processingFormat)")
            
            let supportedFormats = [kAudioFormatMPEG4AAC, kAudioFormatLinearPCM, kAudioFormatAppleLossless]
            let formatID = audioFile.processingFormat.streamDescription.pointee.mFormatID
            
            if !supportedFormats.contains(formatID) {
                print("⚠️ ModularTranscriptionService: Formato audio non ottimale per Speech Recognition: \(formatID)")
            }
            
        } catch {
            print("❌ ModularTranscriptionService: Errore nel leggere file audio: \(error)")
            throw ModularTranscriptionError.unsupportedAudioFormat
        }
        
        // Aggiorna stato
        await MainActor.run {
            currentSession?.state = .processing
        }
        
        let startTime = Date()
        
        do {
            let result: ModularTranscriptionResult
            
            switch configuration.mode {
            case .whisper:
                print("🎤 ModularTranscriptionService: Tentativo con Whisper API...")
                result = try await transcribeWithWhisperAPI(url: url, configuration: configuration)
                
            case .speechAnalyzer:
                #if canImport(SpeechAnalyzer)
                if #available(iOS 26.0, *), availableFramework == .speechAnalyzer {
                    print("🎤 ModularTranscriptionService: Tentativo con Speech Analyzer...")
                    result = try await transcribeWithSpeechAnalyzer(url: url, configuration: configuration)
                } else {
                    print("⚠️ ModularTranscriptionService: Speech Analyzer non disponibile, fallback a Speech Framework")
                    result = try await transcribeWithSpeechFramework(url: url, configuration: configuration)
                }
                #else
                print("⚠️ ModularTranscriptionService: Speech Analyzer non disponibile, fallback a Speech Framework")
                result = try await transcribeWithSpeechFramework(url: url, configuration: configuration)
                #endif
                
            case .speechFramework:
                result = try await transcribeWithSpeechFramework(url: url, configuration: configuration)
                
            case .local:
                result = try await transcribeWithSpeechFramework(url: url, configuration: configuration)
                
            case .auto:
                #if canImport(SpeechAnalyzer)
                if #available(iOS 26.0, *), availableFramework == .speechAnalyzer {
                    print("🎤 ModularTranscriptionService: Tentativo con Speech Analyzer...")
                    result = try await transcribeWithSpeechAnalyzer(url: url, configuration: configuration)
                } else {
                    print("⚠️ ModularTranscriptionService: Speech Analyzer non disponibile, fallback a Speech Framework")
                    result = try await transcribeWithSpeechFramework(url: url, configuration: configuration)
                }
                #else
                print("⚠️ ModularTranscriptionService: Speech Analyzer non disponibile, fallback a Speech Framework")
                result = try await transcribeWithSpeechFramework(url: url, configuration: configuration)
                #endif
            }
            
            let processingTime = Date().timeIntervalSince(startTime)
            
            // Aggiorna sessione
            await MainActor.run {
                currentSession?.result = result
                currentSession?.state = .completed
                currentProgress = 1.0
                finalizedText = result.text
                detectedLanguage = result.detectedLanguage
            }
            
            print("✅ ModularTranscriptionService: Trascrizione completata in \(processingTime)s")
            return result
            
        } catch {
            await MainActor.run {
                currentSession?.state = .error(error)
                currentSession?.error = error
            }
            throw error
        }
    }
    
    public func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.isPermissionGranted = status == .authorized
                print("🎤 ModularTranscriptionService: Permessi riconoscimento vocale: \(status.rawValue)")
            }
        }
    }
    
    public func getStats() -> ModularTranscriptionStats {
        let completedSessions = sessions.filter { $0.isCompleted }
        let successfulSessions = completedSessions.filter { $0.result != nil }
        
        let totalProcessingTime = successfulSessions.compactMap { $0.result?.processingTime }.reduce(0, +)
        let averageProcessingTime = successfulSessions.isEmpty ? 0 : totalProcessingTime / Double(successfulSessions.count)
        
        let totalConfidence = successfulSessions.compactMap { $0.result?.confidence }.reduce(0, +)
        let averageConfidence = successfulSessions.isEmpty ? 0 : totalConfidence / Double(successfulSessions.count)
        
        let totalWords = successfulSessions.compactMap { $0.result?.wordCount }.reduce(0, +)
        let averageWordsPerSession = successfulSessions.isEmpty ? 0 : totalWords / successfulSessions.count
        
        // Trova il framework più usato
        let frameworkCounts = Dictionary(grouping: successfulSessions.compactMap { $0.result?.framework }, by: { $0 })
        let mostUsedFramework = frameworkCounts.max(by: { $0.value.count < $1.value.count })?.key ?? .speechFramework
        
        return ModularTranscriptionStats(
            totalSessions: sessions.count,
            successfulTranscriptions: successfulSessions.count,
            averageProcessingTime: averageProcessingTime,
            averageConfidence: averageConfidence,
            mostUsedFramework: mostUsedFramework,
            totalWords: totalWords,
            averageWordsPerSession: averageWordsPerSession
        )
    }
    
    public func clearSessions() {
        sessions.removeAll()
        currentSession = nil
    }
    
    // MARK: - Private Methods
    
    private var frameworkDescription: String {
        switch availableFramework {
        case .speechAnalyzer:
            return "Speech Analyzer (iOS 26+)"
        case .speechFramework:
            return "Speech Framework (iOS 13+)"
        case .whisperAPI:
            return "Whisper API (OpenAI)"
        case .unavailable:
            return "Non disponibile"
        }
    }
    
    private func setupSpeechRecognition() {
        guard #available(iOS 13.0, *) else { return }
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "it-IT"))
        
        #if canImport(SpeechAnalyzer)
        if #available(iOS 26.0, *), availableFramework == .speechAnalyzer {
            setupSpeechAnalyzer()
        }
        #endif
    }
    
    private func checkPermissions() {
        guard #available(iOS 13.0, *) else { return }
        
        let status = SFSpeechRecognizer.authorizationStatus()
        isPermissionGranted = status == .authorized
        
        if status == .notDetermined {
            requestPermissions()
        }
    }
    
    #if canImport(SpeechAnalyzer)
    @available(iOS 26.0, *)
    private func setupSpeechAnalyzer() {
        Task {
            do {
                speechTranscriber = SpeechTranscriber(
                    locale: Locale.current,
                    reportingOptions: [.volatileResults],
                    attributeOptions: [.audioTimeRange]
                )
                
                guard let transcriber = speechTranscriber else {
                    throw NSError(domain: "ModularTranscriptionService", code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "Impossibile creare SpeechTranscriber"])
                }
                
                speechAnalyzer = SpeechAnalyzer(modules: [transcriber])
                analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
                
                print("✅ ModularTranscriptionService: SpeechAnalyzer configurato correttamente")
                
            } catch {
                print("❌ ModularTranscriptionService: Errore setup SpeechAnalyzer: \(error)")
            }
        }
    }
    #endif
    
    private func transcribeWithSpeechFramework(
        url: URL,
        configuration: ModularTranscriptionConfiguration
    ) async throws -> ModularTranscriptionResult {
        
        guard #available(iOS 13.0, *) else {
            throw ModularTranscriptionError.frameworkUnavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            
            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: configuration.language)) else {
                continuation.resume(throwing: ModularTranscriptionError.frameworkUnavailable)
                return
            }
            
            guard recognizer.isAvailable else {
                continuation.resume(throwing: ModularTranscriptionError.frameworkUnavailable)
                return
            }
            
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = configuration.enableSegments
            
            let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self else { return }
                
                if let error = error {
                    continuation.resume(throwing: ModularTranscriptionError.transcriptionFailed(error.localizedDescription))
                    return
                }
                
                guard let result = result else {
                    continuation.resume(throwing: ModularTranscriptionError.transcriptionFailed("Nessun risultato"))
                    return
                }
                
                if result.isFinal {
                    let transcriptionResult = ModularTranscriptionResult(
                        text: result.bestTranscription.formattedString,
                        confidence: Double(result.bestTranscription.segments.map { $0.confidence }.reduce(0, +)) / Double(result.bestTranscription.segments.count),
                        timestamps: [:], // Speech Framework non fornisce timestamp diretti
                        detectedLanguage: configuration.language,
                        wordCount: result.bestTranscription.formattedString.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count,
                        framework: .speechFramework,
                        processingTime: 0, // Calcolato esternamente
                        segments: []
                    )
                    
                    continuation.resume(returning: transcriptionResult)
                } else if configuration.enableSegments {
                    Task { @MainActor in
                        self.volatileText = result.bestTranscription.formattedString
                    }
                }
            }
        }
    }
    
    #if canImport(SpeechAnalyzer)
    @available(iOS 26.0, *)
    private func transcribeWithSpeechAnalyzer(
        url: URL,
        configuration: ModularTranscriptionConfiguration
    ) async throws -> ModularTranscriptionResult {
        
        guard let analyzer = speechAnalyzer,
              let transcriber = speechTranscriber else {
            throw ModularTranscriptionError.frameworkUnavailable
        }
        
        // Implementazione SpeechAnalyzer
        // Per ora fallback a Speech Framework
        return try await transcribeWithSpeechFramework(url: url, configuration: configuration)
    }
    #endif
    
    private func transcribeWithWhisperAPI(
        url: URL,
        configuration: ModularTranscriptionConfiguration
    ) async throws -> ModularTranscriptionResult {
        
        // Implementazione Whisper API
        // Per ora fallback a Speech Framework
        return try await transcribeWithSpeechFramework(url: url, configuration: configuration)
    }
} 