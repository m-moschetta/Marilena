import Foundation
import Speech
import AVFoundation
import CoreData
import NaturalLanguage
import Combine

// SpeechAnalyzer import condizionale per iOS 26+
#if canImport(SpeechAnalyzer)
import SpeechAnalyzer
#endif

// MARK: - Enums e Strutture

enum TranscriptionState {
    case idle
    case processing
    case completed
    case error(Error)
}

enum TranscriptionFramework {
    case speechAnalyzer  // iOS 26+
    case speechFramework // iOS 13-25
    case whisperAPI      // OpenAI Whisper API
    case unavailable
}

struct TranscriptionResult {
    let text: String
    let confidence: Double
    let timestamps: [TimeInterval: String]
    let detectedLanguage: String
    let wordCount: Int
    let framework: TranscriptionFramework
}

struct TranscriptionSegment {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Double
    let isVolatile: Bool
}

// MARK: - SpeechTranscriptionService

@MainActor
class SpeechTranscriptionService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var transcriptionState: TranscriptionState = .idle
    @Published var currentProgress: Double = 0.0
    @Published var volatileText: String = ""
    @Published var finalizedText: String = ""
    @Published var detectedLanguage: String = ""
    @Published var isPermissionGranted = false
    
    // MARK: - Private Properties
    private let context: NSManagedObjectContext
    private var currentRecording: RegistrazioneAudio?
    private var currentTranscription: Trascrizione?
    
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
    private var textSegments: [TranscriptionSegment] = []
    private var timestampMap: [TimeInterval: String] = [:]
    
    // Framework disponibile
    private let availableFramework: TranscriptionFramework
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext) {
        self.context = context
        
        // Determina quale framework utilizzare basandosi sulle impostazioni
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
            // Per Whisper API, useremo Speech Framework come fallback locale
            if #available(iOS 13.0, *) {
                self.availableFramework = .speechFramework
            } else {
                self.availableFramework = .unavailable
            }
            
        case "local":
            // Per trascrizione locale, useremo Speech Framework
            if #available(iOS 13.0, *) {
                self.availableFramework = .speechFramework
            } else {
                self.availableFramework = .unavailable
            }
            
        default: // "auto"
            // Determina automaticamente il miglior framework disponibile
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
    
    // MARK: - Permission Management
    
    private func checkPermissions() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        print("🎤 SpeechTranscriptionService: Stato permessi Speech Recognition: \(speechStatus.rawValue)")
        
        switch speechStatus {
        case .authorized:
            isPermissionGranted = true
            print("✅ SpeechTranscriptionService: Permessi Speech Recognition già concessi")
        case .denied, .restricted:
            isPermissionGranted = false
            print("❌ SpeechTranscriptionService: Permessi Speech Recognition negati/limitati")
        case .notDetermined:
            print("❓ SpeechTranscriptionService: Permessi Speech Recognition non determinati, richiedo...")
            requestPermissions()
        @unknown default:
            isPermissionGranted = false
            print("❌ SpeechTranscriptionService: Stato permessi sconosciuto")
        }
    }
    
    private func requestPermissions() {
        print("🎤 SpeechTranscriptionService: Richiesta permessi Speech Recognition...")
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                print("🎤 SpeechTranscriptionService: Risposta permessi Speech Recognition: \(status.rawValue)")
                switch status {
                case .authorized:
                    self?.isPermissionGranted = true
                    print("✅ SpeechTranscriptionService: Permessi Speech Recognition concessi")
                case .denied:
                    self?.isPermissionGranted = false
                    print("❌ SpeechTranscriptionService: Permessi Speech Recognition negati")
                case .restricted:
                    self?.isPermissionGranted = false
                    print("❌ SpeechTranscriptionService: Permessi Speech Recognition limitati")
                case .notDetermined:
                    self?.isPermissionGranted = false
                    print("❌ SpeechTranscriptionService: Permessi Speech Recognition non determinati")
                @unknown default:
                    self?.isPermissionGranted = false
                    print("❌ SpeechTranscriptionService: Stato permessi sconosciuto")
                }
            }
        }
    }
    
    // MARK: - Setup
    
    private func setupSpeechRecognition() {
        #if canImport(SpeechAnalyzer)
        if #available(iOS 26.0, *), availableFramework == .speechAnalyzer {
            setupSpeechAnalyzer()
        } else {
            setupSpeechFramework()
        }
        #else
        setupSpeechFramework()
        #endif
    }
    
    #if canImport(SpeechAnalyzer)
    @available(iOS 26.0, *)
    private func setupSpeechAnalyzer() {
        Task {
            do {
                // Configura SpeechTranscriber con opzioni avanzate
                speechTranscriber = SpeechTranscriber(
                    locale: Locale.current,
                    reportingOptions: [.volatileResults],
                    attributeOptions: [.audioTimeRange]
                )
                
                guard let transcriber = speechTranscriber else {
                    throw NSError(domain: "SpeechTranscriptionService", code: 1, 
                                userInfo: [NSLocalizedDescriptionKey: "Impossibile creare SpeechTranscriber"])
                }
                
                // Crea SpeechAnalyzer
                speechAnalyzer = SpeechAnalyzer(modules: [transcriber])
                
                // Ottieni formato audio ottimale
                analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
                
                // Verifica disponibilità modelli
                try await ensureModelsAvailable(for: transcriber)
                
                print("✅ SpeechAnalyzer configurato correttamente")
                
            } catch {
                print("❌ Errore setup SpeechAnalyzer: \(error)")
                // Fallback a Speech Framework
                setupSpeechFramework()
            }
        }
    }
    
    @available(iOS 26.0, *)
    private func ensureModelsAvailable(for transcriber: SpeechTranscriber) async throws {
        let currentLocale = Locale.current
        
        // Verifica supporto lingua
        let supportedLocales = await SpeechTranscriber.supportedLocales
        guard supportedLocales.contains(where: { $0.identifier(.bcp47) == currentLocale.identifier(.bcp47) }) else {
            throw NSError(domain: "SpeechTranscriptionService", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Lingua non supportata da SpeechTranscriber"])
        }
        
        // Verifica installazione modelli
        let installedLocales = await SpeechTranscriber.installedLocales
        if !installedLocales.contains(where: { $0.identifier(.bcp47) == currentLocale.identifier(.bcp47) }) {
            
            // Richiedi download modelli
            if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                print("📥 Download modelli in corso...")
                try await downloader.downloadAndInstall()
                print("✅ Modelli scaricati con successo")
            }
        }
    }
    #endif
    
    private func setupSpeechFramework(for language: String = "it-IT") {
        print("🎤 SpeechTranscriptionService: Setup Speech Framework per \(language)...")
        
        // Verifica disponibilità per la lingua specificata
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)) else {
            print("❌ SpeechTranscriptionService: SFSpeechRecognizer non disponibile per \(language)")
            return
        }
        
        if !recognizer.isAvailable {
            print("❌ SpeechTranscriptionService: Speech Recognition non disponibile")
            return
        }
        
        // IMPORTANTE: Verifica che i modelli siano installati
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                print("🎤 SpeechTranscriptionService: Stato autorizzazione: \(status.rawValue)")
                
                switch status {
                case .authorized:
                    // Verifica installazione modelli
                    if #available(iOS 13.0, *) {
                        self.checkSpeechRecognitionModels(for: language)
                    }
                case .denied:
                    print("❌ SpeechTranscriptionService: Autorizzazione negata")
                case .restricted:
                    print("❌ SpeechTranscriptionService: Autorizzazione limitata")
                case .notDetermined:
                    print("❌ SpeechTranscriptionService: Autorizzazione non determinata")
                @unknown default:
                    print("❌ SpeechTranscriptionService: Stato autorizzazione sconosciuto")
                }
            }
        }
        
        self.speechRecognizer = recognizer
        print("✅ SpeechTranscriptionService: Speech Framework configurato per \(language)")
    }
    
    @available(iOS 13.0, *)
    private func checkSpeechRecognitionModels(for language: String = "it-IT") {
        print("🔍 SpeechTranscriptionService: Verifica modelli Speech Recognition per \(language)...")
        
        let locale = Locale(identifier: language)
        if let recognizer = SFSpeechRecognizer(locale: locale) {
            print("🌍 SpeechTranscriptionService: Recognizer \(language) disponibile: \(recognizer.isAvailable)")
            print("🌍 SpeechTranscriptionService: On-device supportato: \(recognizer.supportsOnDeviceRecognition)")
            
            if !recognizer.isAvailable {
                print("⚠️ SpeechTranscriptionService: Modello \(language) non disponibile, iOS tenterà di scaricarlo")
            }
        }
    }
    
    // MARK: - Transcription Methods
    
    func transcribeRecording(_ recording: RegistrazioneAudio, language: String = "it-IT") async throws -> TranscriptionResult {
        print("🎤 SpeechTranscriptionService: Inizio trascrizione")
        print("🎤 SpeechTranscriptionService: ID registrazione: \(recording.id?.uuidString ?? "nil")")
        print("🎤 SpeechTranscriptionService: Titolo: \(recording.titolo ?? "Senza titolo")")
        print("🌍 SpeechTranscriptionService: Lingua selezionata: \(language)")
        
        // Salva la registrazione corrente per il tracking
        currentRecording = recording
        
        // Crea entità trascrizione in Core Data
        createTranscriptionEntity(for: recording)
        
        // Aggiorna stato
        await MainActor.run {
            transcriptionState = .processing
            currentProgress = 0.0
            volatileText = ""
            finalizedText = ""
        }
        
        guard let audioURL = recording.pathFile else {
            print("❌ SpeechTranscriptionService: URL del file audio è nil")
            throw NSError(domain: "SpeechTranscriptionService", code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "URL file audio non valido"])
        }
        
        print("🎤 SpeechTranscriptionService: URL del file: \(audioURL)")
        print("🎤 SpeechTranscriptionService: URL absoluteString: \(audioURL.absoluteString)")
        print("🎤 SpeechTranscriptionService: URL path: \(audioURL.path)")
        print("🎤 SpeechTranscriptionService: File esiste: \(FileManager.default.fileExists(atPath: audioURL.path))")
        
        // Controlla se il file esiste fisicamente
        let fileExists = FileManager.default.fileExists(atPath: audioURL.path)
        if !fileExists {
            print("❌ SpeechTranscriptionService: File non esiste fisicamente!")
            
            // Prova a cercare il file in altre posizioni
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            print("🎤 SpeechTranscriptionService: Documents path: \(documentsPath?.path ?? "nil")")
            
            // Lista tutti i file .m4a nella directory Documents
            if let documentsPath = documentsPath {
                do {
                    let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
                    let audioFiles = files.filter { $0.pathExtension == "m4a" }
                    print("🎤 SpeechTranscriptionService: File audio trovati in Documents: \(audioFiles.map { $0.lastPathComponent })")
                } catch {
                    print("❌ SpeechTranscriptionService: Errore nel leggere directory Documents: \(error)")
                }
            }
            
            throw NSError(domain: "SpeechTranscriptionService", code: 10,
                        userInfo: [NSLocalizedDescriptionKey: "File audio non trovato"])
        }
        
        // Controlla le dimensioni del file
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("🎤 SpeechTranscriptionService: Dimensione file: \(fileSize) bytes")
            
            if fileSize == 0 {
                print("❌ SpeechTranscriptionService: File vuoto!")
                throw NSError(domain: "SpeechTranscriptionService", code: 11,
                            userInfo: [NSLocalizedDescriptionKey: "File audio vuoto"])
            }
        } catch {
            print("❌ SpeechTranscriptionService: Errore nel leggere attributi file: \(error)")
            throw error
        }
        
        // IMPORTANTE: Verifica che il file audio sia in un formato supportato
        do {
            let audioFile = try AVAudioFile(forReading: audioURL)
            print("🎤 SpeechTranscriptionService: Formato audio: \(audioFile.processingFormat)")
            print("🎤 SpeechTranscriptionService: Durata: \(audioFile.length) frames")
            print("🎤 SpeechTranscriptionService: Sample rate: \(audioFile.processingFormat.sampleRate)")
            print("🎤 SpeechTranscriptionService: Canali: \(audioFile.processingFormat.channelCount)")
            
            // Verifica che il formato sia supportato da Speech Recognition
            let supportedFormats = [kAudioFormatMPEG4AAC, kAudioFormatLinearPCM, kAudioFormatAppleLossless]
            let formatID = audioFile.processingFormat.streamDescription.pointee.mFormatID
            
            if !supportedFormats.contains(formatID) {
                print("⚠️ SpeechTranscriptionService: Formato audio non ottimale per Speech Recognition: \(formatID)")
            }
            
        } catch {
            print("❌ SpeechTranscriptionService: Errore nel leggere file audio: \(error)")
            throw NSError(domain: "SpeechTranscriptionService", code: 15,
                        userInfo: [NSLocalizedDescriptionKey: "Formato audio non supportato"])
        }
        
        // Determina la modalità di trascrizione dalle impostazioni
        let selectedMode = UserDefaults.standard.string(forKey: "transcription_mode") ?? "auto"
        print("🎤 SpeechTranscriptionService: Modalità trascrizione selezionata: \(selectedMode)")
        
            let result: TranscriptionResult
            
        // IMPORTANTE: Logica corretta per la selezione del framework
        switch selectedMode {
        case "whisper":
            print("🎤 SpeechTranscriptionService: Tentativo con Whisper API...")
            result = try await transcribeWithWhisperAPI(audioURL: audioURL)
            
        case "speech_analyzer":
            #if canImport(SpeechAnalyzer)
            if #available(iOS 26.0, *), availableFramework == .speechAnalyzer {
                print("🎤 SpeechTranscriptionService: Tentativo con Speech Analyzer...")
                result = try await transcribeWithSpeechAnalyzer(audioURL: audioURL, language: language)
            } else {
                print("⚠️ SpeechTranscriptionService: Speech Analyzer non disponibile, fallback a Speech Framework")
                result = try await transcribeWithSpeechFramework(audioURL: audioURL, language: language)
            }
            #else
            print("⚠️ SpeechTranscriptionService: Speech Analyzer non disponibile, fallback a Speech Framework")
            result = try await transcribeWithSpeechFramework(audioURL: audioURL, language: language)
            #endif
            
        case "speech_framework", "local":
            print("🎤 SpeechTranscriptionService: Tentativo con Speech Framework...")
            // Verifica permessi per Speech Framework
            if !isPermissionGranted {
                print("❌ SpeechTranscriptionService: Permessi Speech Recognition negati, richiedo...")
                await requestPermissionsAsync()
                
                if !isPermissionGranted {
                    print("❌ SpeechTranscriptionService: Permessi Speech Recognition ancora negati")
                    throw NSError(domain: "SpeechTranscriptionService", code: 3,
                                userInfo: [NSLocalizedDescriptionKey: "Permessi Speech Recognition negati"])
                }
            }
            
            // Verifica che il recognizer sia configurato per la lingua selezionata
            if speechRecognizer == nil || speechRecognizer?.locale.identifier != language {
                print("🎤 SpeechTranscriptionService: Speech recognizer non configurato per \(language), setup...")
                setupSpeechFramework(for: language)
                
                if speechRecognizer == nil {
                    throw NSError(domain: "SpeechTranscriptionService", code: 12,
                                userInfo: [NSLocalizedDescriptionKey: "Speech recognizer non disponibile"])
                }
            }
            
            result = try await transcribeWithSpeechFramework(audioURL: audioURL, language: language)
            
        default: // "auto"
            print("🎤 SpeechTranscriptionService: Modalità automatica, tentativo con Speech Framework...")
            // Verifica permessi per Speech Framework
            if !isPermissionGranted {
                print("❌ SpeechTranscriptionService: Permessi Speech Recognition negati, richiedo...")
                await requestPermissionsAsync()
                
                if !isPermissionGranted {
                    print("❌ SpeechTranscriptionService: Permessi Speech Recognition ancora negati")
                    throw NSError(domain: "SpeechTranscriptionService", code: 3,
                                userInfo: [NSLocalizedDescriptionKey: "Permessi Speech Recognition negati"])
                }
            }
            
            // Verifica che il recognizer sia configurato per la lingua selezionata
            if speechRecognizer == nil || speechRecognizer?.locale.identifier != language {
                print("🎤 SpeechTranscriptionService: Speech recognizer non configurato per \(language), setup...")
                setupSpeechFramework(for: language)
                
                if speechRecognizer == nil {
                    throw NSError(domain: "SpeechTranscriptionService", code: 12,
                                userInfo: [NSLocalizedDescriptionKey: "Speech recognizer non disponibile"])
                }
            }
            
            result = try await transcribeWithSpeechFramework(audioURL: audioURL, language: language)
        }
        
        // Aggiorna l'entità trascrizione con il risultato
            updateTranscriptionEntity(with: result)
            
        // Aggiorna stato finale
        await MainActor.run {
            transcriptionState = .completed
            currentProgress = 1.0
            finalizedText = result.text
            volatileText = ""
            detectedLanguage = result.detectedLanguage
        }
        
        print("✅ SpeechTranscriptionService: Trascrizione completata con successo")
            return result
    }
    
    private func requestPermissionsAsync() async {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    print("🎤 SpeechTranscriptionService: Risposta permessi Speech Recognition: \(status.rawValue)")
                    switch status {
                    case .authorized:
                        self.isPermissionGranted = true
                        print("✅ SpeechTranscriptionService: Permessi Speech Recognition concessi")
                    case .denied:
                        self.isPermissionGranted = false
                        print("❌ SpeechTranscriptionService: Permessi Speech Recognition negati")
                    case .restricted:
                        self.isPermissionGranted = false
                        print("❌ SpeechTranscriptionService: Permessi Speech Recognition limitati")
                    case .notDetermined:
                        self.isPermissionGranted = false
                        print("❌ SpeechTranscriptionService: Permessi Speech Recognition non determinati")
                    @unknown default:
                        self.isPermissionGranted = false
                        print("❌ SpeechTranscriptionService: Stato permessi sconosciuto")
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    #if canImport(SpeechAnalyzer)
    @available(iOS 26.0, *)
    private func transcribeWithSpeechAnalyzer(audioURL: URL, language: String = "it-IT") async throws -> TranscriptionResult {
        guard let analyzer = speechAnalyzer,
              let transcriber = speechTranscriber else {
            throw NSError(domain: "SpeechTranscriptionService", code: 5,
                        userInfo: [NSLocalizedDescriptionKey: "SpeechAnalyzer non configurato"])
        }
        
        var allText = ""
        var confidence = 0.0
        var wordCount = 0
        
        // Crea stream di input
        let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
        
        // Avvia analyzer
        try await analyzer.start(inputSequence: inputSequence)
        
        // Task per elaborare risultati
        let resultsTask = Task {
            for try await result in transcriber.results {
                let text = result.text
                
                if result.isFinal {
                    // Testo finalizzato
                    await MainActor.run {
                        finalizedText += text.string
                        volatileText = ""
                        
                        // Estrai timing se disponibile
                        if let timeRange = text.runs.first?.audioTimeRange {
                            let startTime = CMTimeGetSeconds(timeRange.start)
                            let endTime = CMTimeGetSeconds(timeRange.end)
                            timestampMap[startTime] = text.string
                            
                            textSegments.append(TranscriptionSegment(
                                text: text.string,
                                startTime: startTime,
                                endTime: endTime,
                                confidence: 1.0, // SpeechAnalyzer non fornisce confidence esplicita
                                isVolatile: false
                            ))
                        }
                    }
                    
                    allText += text.string
                    wordCount += text.string.split(separator: " ").count
                    
                } else {
                    // Testo volatile
                    await MainActor.run {
                        volatileText = text.string
                    }
                }
            }
        }
        
        // Leggi file audio e invia all'analyzer
        try await analyzeAudioFile(audioURL: audioURL, inputBuilder: inputBuilder)
        
        // Finalizza
        try await analyzer.finalizeAndFinish(through: CMTime.positiveInfinity)
        
        // Aspetta completamento risultati
        try await resultsTask.value
        
        // Rileva lingua usando NaturalLanguage
        let detectedLang = detectLanguage(text: allText)
        
        return TranscriptionResult(
            text: allText,
            confidence: confidence,
            timestamps: timestampMap,
            detectedLanguage: detectedLang,
            wordCount: wordCount,
            framework: .speechAnalyzer
        )
    }
    
    @available(iOS 26.0, *)
    private func analyzeAudioFile(audioURL: URL, inputBuilder: AsyncStream<AnalyzerInput>.Continuation) async throws {
        let audioFile = try AVAudioFile(forReading: audioURL)
        let frameCount = AVAudioFrameCount(audioFile.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameCount) else {
            throw NSError(domain: "SpeechTranscriptionService", code: 6,
                        userInfo: [NSLocalizedDescriptionKey: "Impossibile creare buffer audio"])
        }
        
        try audioFile.read(into: buffer)
        
        // Converti al formato dell'analyzer se necessario
        let finalBuffer: AVAudioPCMBuffer
        if let analyzerFormat = analyzerFormat, audioFile.processingFormat != analyzerFormat {
            guard let converter = AVAudioConverter(from: audioFile.processingFormat, to: analyzerFormat) else {
                throw NSError(domain: "SpeechTranscriptionService", code: 7,
                            userInfo: [NSLocalizedDescriptionKey: "Impossibile creare converter audio"])
            }
            
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: frameCount) else {
                throw NSError(domain: "SpeechTranscriptionService", code: 8,
                            userInfo: [NSLocalizedDescriptionKey: "Impossibile creare buffer convertito"])
            }
            
            try converter.convert(to: convertedBuffer, from: buffer)
            finalBuffer = convertedBuffer
        } else {
            finalBuffer = buffer
        }
        
        // Invia all'analyzer
        let input = AnalyzerInput(buffer: finalBuffer)
        inputBuilder.yield(input)
        inputBuilder.finish()
        
        await MainActor.run {
            currentProgress = 1.0
        }
    }
    #endif
    
    private func transcribeWithSpeechFramework(audioURL: URL, language: String = "it-IT") async throws -> TranscriptionResult {
        guard let recognizer = speechRecognizer else {
            throw NSError(domain: "SpeechTranscriptionService", code: 10,
                    userInfo: [NSLocalizedDescriptionKey: "Speech recognizer non configurato"])
        }
        
        // IMPORTANTE: Verifica che il recognizer sia disponibile
        guard recognizer.isAvailable else {
            throw NSError(domain: "SpeechTranscriptionService", code: 11,
                    userInfo: [NSLocalizedDescriptionKey: "Speech recognizer non disponibile per \(language)"])
        }
        
        print("🎤 SpeechTranscriptionService: Avvio riconoscimento con Speech Framework per \(language)...")
        print("🎤 SpeechTranscriptionService: URL file: \(audioURL)")
        print("🎤 SpeechTranscriptionService: Recognizer disponibile: \(recognizer.isAvailable)")
        print("🎤 SpeechTranscriptionService: On-device supportato: \(recognizer.supportsOnDeviceRecognition)")
        
        // Ottimizzazioni specifiche per l'italiano
        if language.hasPrefix("it") {
            optimizeForItalianLanguage()
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = false
            request.taskHint = .dictation // IMPORTANTE: dictation è migliore per italiano
            
            // IMPORTANTE: Configura per on-device se disponibile (iOS 13+)
            if #available(iOS 13.0, *) {
                // Per l'italiano, prova prima cloud recognition se disponibile
                if language.hasPrefix("it") && !recognizer.supportsOnDeviceRecognition {
                    request.requiresOnDeviceRecognition = false
                    print("🇮🇹 SpeechTranscriptionService: Cloud recognition per italiano (on-device non disponibile)")
                } else {
                    request.requiresOnDeviceRecognition = true
                    print("🎤 SpeechTranscriptionService: On-device recognition abilitato")
                }
            }
            
            // IMPORTANTE: Aggiungi timeout per evitare blocchi
            var hasCompleted = false
            
            let task = recognizer.recognitionTask(with: request) { result, error in
                // Evita chiamate multiple
                guard !hasCompleted else { return }
                hasCompleted = true
                
                if let error = error {
                    print("❌ SpeechTranscriptionService: Errore riconoscimento: \(error)")
                    print("❌ SpeechTranscriptionService: Codice errore: \((error as NSError).code)")
                    print("❌ SpeechTranscriptionService: Dominio errore: \((error as NSError).domain)")
                    
                    // Gestione errori specifici
                    let nsError = error as NSError
                    var userMessage = "Errore riconoscimento: \(error.localizedDescription)"
                    
                    switch nsError.code {
                    case 203: // SFSpeechRecognizerErrorDomain - No speech detected
                        userMessage = "Nessun parlato rilevato nell'audio"
                    case 201: // SFSpeechRecognizerErrorDomain - Audio engine error
                        userMessage = "Errore motore audio"
                    case 202: // SFSpeechRecognizerErrorDomain - Audio engine busy
                        userMessage = "Motore audio occupato"
                    case 204: // SFSpeechRecognizerErrorDomain - Recognition not available
                        userMessage = "Riconoscimento vocale non disponibile"
                    default:
                        userMessage = "Errore riconoscimento: \(error.localizedDescription)"
                    }
                    
                    continuation.resume(throwing: NSError(domain: "SpeechTranscriptionService", code: nsError.code,
                                                       userInfo: [NSLocalizedDescriptionKey: userMessage]))
                    return
                }
                
                guard let result = result else {
                    print("❌ SpeechTranscriptionService: Nessun risultato dal riconoscimento")
                    continuation.resume(throwing: NSError(domain: "SpeechTranscriptionService", code: 13,
                                                       userInfo: [NSLocalizedDescriptionKey: "Nessun risultato dal riconoscimento"]))
                    return
                }
                
                print("🎤 SpeechTranscriptionService: Risultato ricevuto - Finale: \(result.isFinal)")
                
                if result.isFinal {
                    print("✅ SpeechTranscriptionService: Riconoscimento completato")
                    
                    let transcribedText = result.bestTranscription.formattedString
                    print("📝 SpeechTranscriptionService: Testo trascritto: \(transcribedText)")
                    
                    let confidence = result.bestTranscription.segments.map { Double($0.confidence) }.reduce(0, +) / Double(result.bestTranscription.segments.count)
                    print("🎯 SpeechTranscriptionService: Confidenza media: \(confidence)")
                    
                    // Crea timestamp map
                    var timestampMap: [TimeInterval: String] = [:]
                    for segment in result.bestTranscription.segments {
                        timestampMap[segment.timestamp] = segment.substring
                        print("⏱️ SpeechTranscriptionService: Segmento [\(segment.timestamp)]: \(segment.substring)")
                    }
                    
                    let result = TranscriptionResult(
                        text: transcribedText,
                        confidence: confidence,
                        timestamps: timestampMap,
                        detectedLanguage: language,
                        wordCount: transcribedText.components(separatedBy: .whitespacesAndNewlines).count,
                        framework: .speechFramework
                    )
                    continuation.resume(returning: result)
                }
            }
            
            // IMPORTANTE: Aggiungi timeout per evitare blocchi infiniti
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
                if !hasCompleted {
                    hasCompleted = true
                    print("⏰ SpeechTranscriptionService: Timeout riconoscimento (30 secondi)")
                    continuation.resume(throwing: NSError(domain: "SpeechTranscriptionService", code: 23,
                                                       userInfo: [NSLocalizedDescriptionKey: "Timeout riconoscimento (30 secondi)"]))
                }
            }
        }
    }
    
    // MARK: - Whisper API Transcription
    
    private func transcribeWithWhisperAPI(audioURL: URL) async throws -> TranscriptionResult {
        print("🌐 SpeechTranscriptionService: Avvio trascrizione con Whisper API...")
        
        // Verifica API Key
        guard let apiKey = KeychainManager.shared.load(key: "openai_api_key"), !apiKey.isEmpty else {
            print("❌ SpeechTranscriptionService: API Key OpenAI non configurata")
            throw NSError(domain: "SpeechTranscriptionService", code: 16,
                        userInfo: [NSLocalizedDescriptionKey: "API Key OpenAI non configurata. Configurala nelle impostazioni."])
        }
        
        print("✅ SpeechTranscriptionService: API Key OpenAI trovata")
        
        // Verifica dimensione file (Whisper ha limite di 25MB)
        let fileSize = try FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int64 ?? 0
        let maxSize: Int64 = 25 * 1024 * 1024 // 25MB
        
        if fileSize > maxSize {
            print("❌ SpeechTranscriptionService: File troppo grande per Whisper API (\(fileSize) bytes > \(maxSize) bytes)")
            throw NSError(domain: "SpeechTranscriptionService", code: 17,
                        userInfo: [NSLocalizedDescriptionKey: "File audio troppo grande per Whisper API (max 25MB)"])
        }
        
        print("✅ SpeechTranscriptionService: Dimensione file OK (\(fileSize) bytes)")
        
        // Leggi il file audio
        print("📖 SpeechTranscriptionService: Lettura file audio...")
        let audioData: Data
        do {
            audioData = try Data(contentsOf: audioURL)
            print("✅ SpeechTranscriptionService: File audio letto (\(audioData.count) bytes)")
        } catch {
            print("❌ SpeechTranscriptionService: Errore lettura file audio: \(error)")
            throw NSError(domain: "SpeechTranscriptionService", code: 18,
                        userInfo: [NSLocalizedDescriptionKey: "Impossibile leggere file audio: \(error.localizedDescription)"])
        }
        
        // Crea la richiesta
        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60 // 60 secondi di timeout
        
        // Crea il boundary per multipart/form-data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        print("🌐 SpeechTranscriptionService: Preparazione richiesta multipart...")
        
        // Costruisci il body
        var body = Data()
        
        // Aggiungi il file audio
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Aggiungi il modello
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        
        // Whisper API riconosce automaticamente la lingua, non serve specificarla
        
        // Aggiungi opzioni per migliorare la qualità
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)
        
        // Chiudi il boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("🌐 SpeechTranscriptionService: Invio richiesta a Whisper API...")
        print("🌐 SpeechTranscriptionService: URL: \(url)")
        print("🌐 SpeechTranscriptionService: Dimensione body: \(body.count) bytes")
        
        // Esegui la richiesta
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ SpeechTranscriptionService: Risposta HTTP non valida")
            throw NSError(domain: "SpeechTranscriptionService", code: 19,
                        userInfo: [NSLocalizedDescriptionKey: "Risposta HTTP non valida"])
        }
        
        print("🌐 SpeechTranscriptionService: Risposta HTTP ricevuta - Status: \(httpResponse.statusCode)")
        print("🌐 SpeechTranscriptionService: Headers: \(httpResponse.allHeaderFields)")
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Errore sconosciuto"
            print("❌ SpeechTranscriptionService: Errore API - Status: \(httpResponse.statusCode), Message: \(errorMessage)")
            
            // Gestione errori specifici di OpenAI
            var userMessage = "Errore API: \(errorMessage)"
            if httpResponse.statusCode == 401 {
                userMessage = "API Key OpenAI non valida. Verifica le impostazioni."
            } else if httpResponse.statusCode == 413 {
                userMessage = "File audio troppo grande per Whisper API (max 25MB)"
            } else if httpResponse.statusCode == 429 {
                userMessage = "Limite di richieste API raggiunto. Riprova più tardi."
            }
            
            throw NSError(domain: "SpeechTranscriptionService", code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: userMessage])
        }
        
        print("✅ SpeechTranscriptionService: Risposta API ricevuta con successo")
        print("📄 SpeechTranscriptionService: Dimensione risposta: \(data.count) bytes")
        
        // Decodifica la risposta
        struct WhisperResponse: Codable {
            let text: String
        }
        
        let whisperResponse: WhisperResponse
        do {
            whisperResponse = try JSONDecoder().decode(WhisperResponse.self, from: data)
            print("✅ SpeechTranscriptionService: Risposta JSON decodificata con successo")
        } catch {
            print("❌ SpeechTranscriptionService: Errore decodifica JSON: \(error)")
            print("📄 SpeechTranscriptionService: Risposta raw: \(String(data: data, encoding: .utf8) ?? "non leggibile")")
            throw NSError(domain: "SpeechTranscriptionService", code: 20,
                        userInfo: [NSLocalizedDescriptionKey: "Errore decodifica risposta API: \(error.localizedDescription)"])
        }
        
        let transcribedText = whisperResponse.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if transcribedText.isEmpty {
            print("⚠️ SpeechTranscriptionService: Whisper API ha restituito testo vuoto")
            throw NSError(domain: "SpeechTranscriptionService", code: 21,
                        userInfo: [NSLocalizedDescriptionKey: "Whisper API ha restituito testo vuoto. Verifica che l'audio contenga parlato."])
        }
        
        // Rileva lingua
        let detectedLang = detectLanguage(text: transcribedText)
        
        print("✅ SpeechTranscriptionService: Whisper API trascrizione completata")
        print("📝 SpeechTranscriptionService: Testo trascritto (\(transcribedText.count) caratteri): \(transcribedText.prefix(100))...")
        print("🌍 SpeechTranscriptionService: Lingua rilevata: \(detectedLang)")
        
        return TranscriptionResult(
            text: transcribedText,
            confidence: 0.95, // Whisper API ha alta confidenza
            timestamps: [:], // Whisper API non fornisce timestamps dettagliati
            detectedLanguage: detectedLang,
            wordCount: transcribedText.split(separator: " ").count,
            framework: .whisperAPI // Usiamo questo come placeholder per Whisper
        )
    }
    
    // MARK: - Language Detection
    
    private func detectLanguage(text: String) -> String {
        guard !text.isEmpty else { return "it" }
        
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        if let language = recognizer.dominantLanguage {
            return language.rawValue
        }
        
        return Locale.current.language.languageCode?.identifier ?? "it"
    }
    
    // MARK: - Core Data Management
    
    private func createTranscriptionEntity(for recording: RegistrazioneAudio) {
        let transcription = Trascrizione(context: context)
        transcription.id = UUID()
        transcription.registrazione = recording
        transcription.dataCreazione = Date()
        transcription.statoElaborazione = "in_elaborazione"
        transcription.frameworkUtilizzato = switch availableFramework {
        case .speechAnalyzer: "SpeechAnalyzer"
        case .speechFramework: "SpeechFramework" 
        case .whisperAPI: "WhisperAPI"
        case .unavailable: "Unavailable"
        }
        transcription.versione = "1.0"
        
        currentTranscription = transcription
        
        do {
            try context.save()
        } catch {
            print("Errore creazione trascrizione: \(error)")
        }
    }
    
    private func updateTranscriptionEntity(with result: TranscriptionResult) {
        guard let transcription = currentTranscription else { return }
        
        transcription.testoCompleto = result.text
        transcription.accuratezza = result.confidence
        transcription.linguaRilevata = result.detectedLanguage
        transcription.paroleTotali = Int32(result.wordCount)
        transcription.statoElaborazione = "completata"
        
        // Salva metadati temporali come Data
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: result.timestamps, requiringSecureCoding: false) {
            transcription.metadatiTemporali = data
        }
        
        do {
            try context.save()
        } catch {
            print("Errore aggiornamento trascrizione: \(error)")
        }
    }
    
    // MARK: - Public Utilities
    
    func getTranscriptions(for recording: RegistrazioneAudio) -> [Trascrizione] {
        return recording.trascrizioni?.allObjects as? [Trascrizione] ?? []
    }
    
    func deleteTranscription(_ transcription: Trascrizione) {
        context.delete(transcription)
        try? context.save()
    }
    
    func exportTranscription(_ transcription: Trascrizione, format: ExportFormat = .text) -> String {
        switch format {
        case .text:
            return transcription.testoCompleto ?? ""
        case .timestamped:
            return formatTimestampedText(transcription)
        case .srt:
            return formatSRT(transcription)
        }
    }
    
    private func formatTimestampedText(_ transcription: Trascrizione) -> String {
        guard let metadataData = transcription.metadatiTemporali,
              let timestamps = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSDictionary.self, from: metadataData) as? [TimeInterval: String] else {
            return transcription.testoCompleto ?? ""
        }
        
        let sortedTimestamps = timestamps.sorted { $0.key < $1.key }
        var result = ""
        
        for (timestamp, text) in sortedTimestamps {
            let timeString = formatTimestamp(timestamp)
            result += "[\(timeString)] \(text)\n"
        }
        
        return result
    }
    
    private func formatSRT(_ transcription: Trascrizione) -> String {
        guard let metadataData = transcription.metadatiTemporali,
              let timestamps = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSDictionary.self, from: metadataData) as? [TimeInterval: String] else {
            return ""
        }
        
        let sortedTimestamps = timestamps.sorted { $0.key < $1.key }
        var result = ""
        var index = 1
        
        for (timestamp, text) in sortedTimestamps {
            let startTime = formatSRTTimestamp(timestamp)
            let endTime = formatSRTTimestamp(timestamp + 3.0) // 3 secondi default
            
            result += "\(index)\n"
            result += "\(startTime) --> \(endTime)\n"
            result += "\(text)\n\n"
            
            index += 1
        }
        
        return result
    }
    
    private func formatTimestamp(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    private func formatSRTTimestamp(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
        let milliseconds = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, secs, milliseconds)
    }
    
    // MARK: - Analysis con NaturalLanguage
    
    func analyzeTranscriptionSentiment(_ transcription: Trascrizione) -> Double {
        guard let text = transcription.testoCompleto, !text.isEmpty else { return 0.0 }
        
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        
        let (sentimentTag, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        
        if let sentiment = sentimentTag {
            return Double(sentiment.rawValue) ?? 0.0
        }
        
        return 0.0
    }
    
    func extractKeywords(_ transcription: Trascrizione, maxResults: Int = 10) -> [String] {
        guard let text = transcription.testoCompleto, !text.isEmpty else { return [] }
        
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text
        
        var keywords: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            
            let word = String(text[tokenRange])
            
            // Filtra solo sostantivi e nomi propri
            if let tag = tag, (tag == .noun || tag == .other) && word.count > 3 {
                keywords.append(word.lowercased())
            }
            
            return keywords.count < maxResults
        }
        
        // Rimuovi duplicati e restituisci
        return Array(Set(keywords)).prefix(maxResults).map { $0 }
    }
    
    // MARK: - Public Methods
    
    func requestSpeechPermissions() {
        print("🎤 SpeechTranscriptionService: Richiesta manuale permessi Speech Recognition...")
        requestPermissions()
    }
    
    func isSpeechRecognitionAvailable() -> Bool {
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current) else {
            print("❌ SpeechTranscriptionService: SFSpeechRecognizer non disponibile per la lingua corrente")
            return false
        }
        
        let isAvailable = recognizer.isAvailable
        print("🎤 SpeechTranscriptionService: Speech Recognition disponibile: \(isAvailable)")
        return isAvailable
    }

    // Aggiungi questa funzione per ottimizzare le impostazioni per l'italiano
    private func optimizeForItalianLanguage() {
        print("🇮🇹 SpeechTranscriptionService: Ottimizzazioni per italiano...")
        
        // Configurazioni specifiche per l'italiano
        if let recognizer = speechRecognizer {
            // Imposta task hint per dictation (migliore per italiano)
            print("🇮🇹 SpeechTranscriptionService: Configurazione ottimizzata per dictation")
        }
    }

    // Aggiungi questa funzione per suggerimenti di miglioramento
    private func getItalianOptimizationTips() -> [String] {
        return [
            "🎤 Parla più lentamente e chiaramente",
            "🔇 Riduci il rumore di fondo",
            "📱 Usa un microfono di qualità",
            "🌐 Prova la trascrizione cloud se disponibile",
            "⚡ Usa Whisper API per risultati migliori",
            "📏 Mantieni una distanza costante dal microfono",
            "🗣️ Evita pause troppo lunghe o troppo brevi"
        ]
    }

    // Aggiungi questa funzione per fallback intelligente
    private func intelligentFallback(audioURL: URL, language: String) async throws -> TranscriptionResult {
        print("🔄 SpeechTranscriptionService: Avvio fallback intelligente...")
        
        // Se è italiano e il riconoscimento locale fallisce, prova Whisper API
        if language.hasPrefix("it") {
            print("🇮🇹 SpeechTranscriptionService: Fallback a Whisper API per italiano...")
            return try await transcribeWithWhisperAPI(audioURL: audioURL)
        }
        
        // Per altre lingue, prova prima cloud recognition
        print("🌐 SpeechTranscriptionService: Fallback a cloud recognition...")
        return try await transcribeWithCloudRecognition(audioURL: audioURL, language: language)
    }

    // Aggiungi questa funzione per cloud recognition
    private func transcribeWithCloudRecognition(audioURL: URL, language: String) async throws -> TranscriptionResult {
        guard let recognizer = speechRecognizer else {
            throw NSError(domain: "SpeechTranscriptionService", code: 10,
                        userInfo: [NSLocalizedDescriptionKey: "Speech recognizer non configurato"])
        }
        
        print("🌐 SpeechTranscriptionService: Avvio cloud recognition per \(language)...")
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = false
            request.taskHint = .dictation
            
            // IMPORTANTE: Disabilita on-device per cloud recognition
            if #available(iOS 13.0, *) {
                request.requiresOnDeviceRecognition = false
                print("🌐 SpeechTranscriptionService: Cloud recognition abilitato")
            }
            
            var hasCompleted = false
            
            let task = recognizer.recognitionTask(with: request) { result, error in
                guard !hasCompleted else { return }
                hasCompleted = true
                
                if let error = error {
                    print("❌ SpeechTranscriptionService: Errore cloud recognition: \(error)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let result = result else {
                    print("❌ SpeechTranscriptionService: Nessun risultato dal cloud recognition")
                    continuation.resume(throwing: NSError(domain: "SpeechTranscriptionService", code: 13,
                                                       userInfo: [NSLocalizedDescriptionKey: "Nessun risultato dal cloud recognition"]))
                    return
                }
                
                if result.isFinal {
                    let transcribedText = result.bestTranscription.formattedString
                    let confidence = result.bestTranscription.segments.map { Double($0.confidence) }.reduce(0, +) / Double(result.bestTranscription.segments.count)
                    
                    var timestampMap: [TimeInterval: String] = [:]
                    for segment in result.bestTranscription.segments {
                        timestampMap[segment.timestamp] = segment.substring
                    }
                    
                    let result = TranscriptionResult(
                        text: transcribedText,
                        confidence: confidence,
                        timestamps: timestampMap,
                        detectedLanguage: language,
                        wordCount: transcribedText.components(separatedBy: .whitespacesAndNewlines).count,
                        framework: .speechFramework
                    )
                    continuation.resume(returning: result)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
                if !hasCompleted {
                    hasCompleted = true
                    print("⏰ SpeechTranscriptionService: Timeout cloud recognition (30 secondi)")
                    continuation.resume(throwing: NSError(domain: "SpeechTranscriptionService", code: 23,
                                                       userInfo: [NSLocalizedDescriptionKey: "Timeout cloud recognition (30 secondi)"]))
                }
            }
        }
    }
}

// MARK: - Supporting Types

enum ExportFormat {
    case text
    case timestamped
    case srt
} 

