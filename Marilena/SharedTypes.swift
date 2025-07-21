import Foundation

// MARK: - Shared Types for AI Services

// Unified ModelInfo structure for all AI services
public struct AIModelInfo {
    let name: String
    let description: String
    let contextTokens: Int
    let supportsStreaming: Bool
    let supportsWebSearch: Bool? // for Perplexity models
    let maxFileSize: Int? // in MB, for transcription models
    
    // Convenience initializer for chat models
    init(name: String, description: String, contextTokens: Int, supportsStreaming: Bool, maxFileSize: Int? = nil) {
        self.name = name
        self.description = description
        self.contextTokens = contextTokens
        self.supportsStreaming = supportsStreaming
        self.supportsWebSearch = nil
        self.maxFileSize = maxFileSize
    }
    
    // Convenience initializer for Perplexity models
    init(name: String, description: String, contextTokens: Int, supportsWebSearch: Bool, maxFileSize: Int? = nil) {
        self.name = name
        self.description = description
        self.contextTokens = contextTokens
        self.supportsStreaming = true
        self.supportsWebSearch = supportsWebSearch
        self.maxFileSize = maxFileSize
    }
}

// Unified TranscriptionSegment structure
public struct AITranscriptionSegment: Codable {
    let id: Int
    let start: Double
    let end: Double
    let text: String
    let tokens: [Int]?
    let temperature: Double?
    let avgLogprob: Double?
    let compressionRatio: Double?
    let noSpeechProb: Double?
    let transient: Bool?
}

// Export format enum
public enum ExportFormat: String, CaseIterable {
    case text = "text"
    case json = "json"
    case csv = "csv"
    case srt = "srt"
    case timestamped = "timestamped"
    
    var displayName: String {
        switch self {
        case .text: return "Testo"
        case .json: return "JSON"
        case .csv: return "CSV"
        case .srt: return "SRT (Sottotitoli)"
        case .timestamped: return "Testo con Timestamp"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .text: return "txt"
        case .json: return "json"
        case .csv: return "csv"
        case .srt: return "srt"
        case .timestamped: return "txt"
        }
    }
} 