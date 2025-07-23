import Foundation
import Speech
import AVFoundation

// MARK: - Modular Transcription Data Models
// Modelli dati riutilizzabili per il modulo di trascrizione

// MARK: - Enums

public enum ModularTranscriptionState {
    case idle
    case processing
    case completed
    case error(Error)
}

public enum ModularTranscriptionFramework {
    case speechAnalyzer  // iOS 26+
    case speechFramework // iOS 13-25
    case whisperAPI      // OpenAI Whisper API
    case unavailable
    
    public var displayName: String {
        switch self {
        case .speechAnalyzer: return "Speech Analyzer"
        case .speechFramework: return "Speech Framework"
        case .whisperAPI: return "Whisper API"
        case .unavailable: return "Non disponibile"
        }
    }
    
    public var color: String {
        switch self {
        case .speechAnalyzer: return "purple"
        case .speechFramework: return "orange"
        case .whisperAPI: return "green"
        case .unavailable: return "gray"
        }
    }
}

public enum ModularTranscriptionMode {
    case auto
    case speechAnalyzer
    case speechFramework
    case whisper
    case local
    
    public var displayName: String {
        switch self {
        case .auto: return "Automatico"
        case .speechAnalyzer: return "Speech Analyzer (iOS 26+)"
        case .speechFramework: return "Speech Framework"
        case .whisper: return "Whisper API"
        case .local: return "Locale"
        }
    }
    
    public var description: String {
        switch self {
        case .auto: return "Sceglie automaticamente il miglior framework disponibile"
        case .speechAnalyzer: return "Framework più avanzato per iOS 26+"
        case .speechFramework: return "Framework tradizionale per iOS 13+"
        case .whisper: return "Trascrizione tramite OpenAI Whisper API"
        case .local: return "Trascrizione locale con modelli integrati"
        }
    }
    
    public var icon: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .speechAnalyzer: return "brain.head.profile"
        case .speechFramework: return "waveform"
        case .whisper: return "cloud"
        case .local: return "device.phone.portrait"
        }
    }
}

// MARK: - Structs

public struct ModularTranscriptionResult {
    public let text: String
    public let confidence: Double
    public let timestamps: [TimeInterval: String]
    public let detectedLanguage: String
    public let wordCount: Int
    public let framework: ModularTranscriptionFramework
    public let processingTime: TimeInterval
    public let segments: [ModularTranscriptionSegment]
    
    public init(
        text: String,
        confidence: Double,
        timestamps: [TimeInterval: String],
        detectedLanguage: String,
        wordCount: Int,
        framework: ModularTranscriptionFramework,
        processingTime: TimeInterval,
        segments: [ModularTranscriptionSegment]
    ) {
        self.text = text
        self.confidence = confidence
        self.timestamps = timestamps
        self.detectedLanguage = detectedLanguage
        self.wordCount = wordCount
        self.framework = framework
        self.processingTime = processingTime
        self.segments = segments
    }
}

public struct ModularTranscriptionSegment {
    public let text: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let confidence: Double
    public let isVolatile: Bool
    
    public init(
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        confidence: Double,
        isVolatile: Bool
    ) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
        self.isVolatile = isVolatile
    }
}

public struct ModularTranscriptionConfiguration {
    public let mode: ModularTranscriptionMode
    public let language: String
    public let enableTimestamps: Bool
    public let enableConfidence: Bool
    public let enableSegments: Bool
    public let maxProcessingTime: TimeInterval
    public let retryCount: Int
    
    public init(
        mode: ModularTranscriptionMode = .auto,
        language: String = "it-IT",
        enableTimestamps: Bool = true,
        enableConfidence: Bool = true,
        enableSegments: Bool = true,
        maxProcessingTime: TimeInterval = 300.0,
        retryCount: Int = 3
    ) {
        self.mode = mode
        self.language = language
        self.enableTimestamps = enableTimestamps
        self.enableConfidence = enableConfidence
        self.enableSegments = enableSegments
        self.maxProcessingTime = maxProcessingTime
        self.retryCount = retryCount
    }
}

public struct ModularTranscriptionSession {
    public let id: UUID
    public let audioURL: URL
    public let configuration: ModularTranscriptionConfiguration
    public let createdAt: Date
    public var result: ModularTranscriptionResult?
    public var state: ModularTranscriptionState
    public var progress: Double
    public var error: Error?
    
    public init(
        id: UUID = UUID(),
        audioURL: URL,
        configuration: ModularTranscriptionConfiguration,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.audioURL = audioURL
        self.configuration = configuration
        self.createdAt = createdAt
        self.state = .idle
        self.progress = 0.0
    }
}

public struct ModularTranscriptionStats {
    public let totalSessions: Int
    public let successfulTranscriptions: Int
    public let averageProcessingTime: TimeInterval
    public let averageConfidence: Double
    public let mostUsedFramework: ModularTranscriptionFramework
    public let totalWords: Int
    public let averageWordsPerSession: Int
    
    public init(
        totalSessions: Int = 0,
        successfulTranscriptions: Int = 0,
        averageProcessingTime: TimeInterval = 0.0,
        averageConfidence: Double = 0.0,
        mostUsedFramework: ModularTranscriptionFramework = .speechFramework,
        totalWords: Int = 0,
        averageWordsPerSession: Int = 0
    ) {
        self.totalSessions = totalSessions
        self.successfulTranscriptions = successfulTranscriptions
        self.averageProcessingTime = averageProcessingTime
        self.averageConfidence = averageConfidence
        self.mostUsedFramework = mostUsedFramework
        self.totalWords = totalWords
        self.averageWordsPerSession = averageWordsPerSession
    }
}

// MARK: - Errors

public enum ModularTranscriptionError: Error, LocalizedError {
    case permissionDenied
    case audioFileNotFound
    case unsupportedAudioFormat
    case frameworkUnavailable
    case processingTimeout
    case networkError(Error)
    case transcriptionFailed(String)
    case invalidConfiguration
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permessi di riconoscimento vocale negati"
        case .audioFileNotFound:
            return "File audio non trovato"
        case .unsupportedAudioFormat:
            return "Formato audio non supportato"
        case .frameworkUnavailable:
            return "Framework di trascrizione non disponibile"
        case .processingTimeout:
            return "Timeout durante la trascrizione"
        case .networkError(let error):
            return "Errore di rete: \(error.localizedDescription)"
        case .transcriptionFailed(let reason):
            return "Trascrizione fallita: \(reason)"
        case .invalidConfiguration:
            return "Configurazione trascrizione non valida"
        }
    }
}

// MARK: - Extensions

extension ModularTranscriptionResult {
    public var formattedText: String {
        if timestamps.isEmpty {
            return text
        }
        
        var formatted = ""
        for (timestamp, segmentText) in timestamps.sorted(by: { $0.key < $1.key }) {
            let timeString = String(format: "[%.2f]", timestamp)
            formatted += "\(timeString) \(segmentText)\n"
        }
        return formatted.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public var duration: TimeInterval {
        guard let lastTimestamp = timestamps.keys.max() else { return 0 }
        return lastTimestamp
    }
}

extension ModularTranscriptionSession {
    public var isCompleted: Bool {
        if case .completed = state { return true }
        return false
    }
    
    public var isProcessing: Bool {
        if case .processing = state { return true }
        return false
    }
    
    public var hasError: Bool {
        if case .error = state { return true }
        return false
    }
} 