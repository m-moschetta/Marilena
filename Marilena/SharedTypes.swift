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

// MARK: - Compose Email Types

// Email Contact for auto-completion and chips
public struct EmailContact: Identifiable, Codable, Hashable {
    public let id = UUID()
    public let email: String
    public let name: String?
    public let isRecent: Bool
    
    public init(email: String, name: String? = nil, isRecent: Bool = false) {
        self.email = email
        self.name = name
        self.isRecent = isRecent
    }
    
    public var displayName: String {
        if let name = name, !name.isEmpty {
            return "\(name) <\(email)>"
        }
        return email
    }
    
    public var shortDisplayName: String {
        name ?? email
    }
}

// Email Attachment
public struct EmailAttachment: Identifiable, Codable {
    public let id = UUID()
    public let name: String
    public let size: Int64
    public let mimeType: String
    public let data: Data
    public let type: AttachmentType
    
    public init(name: String, size: Int64, mimeType: String, data: Data, type: AttachmentType) {
        self.name = name
        self.size = size
        self.mimeType = mimeType
        self.data = data
        self.type = type
    }
    
    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

public enum AttachmentType: String, Codable, CaseIterable {
    case photo = "photo"
    case document = "document"
    case video = "video"
    case audio = "audio"
    case other = "other"
    
    public var iconName: String {
        switch self {
        case .photo: return "photo"
        case .document: return "doc.text"
        case .video: return "video"
        case .audio: return "music.note"
        case .other: return "paperclip"
        }
    }
}

// Format State for Rich Text Editor
public struct FormatState {
    public var isBold: Bool = false
    public var isItalic: Bool = false
    public var isUnderlined: Bool = false
    
    public init(isBold: Bool = false, isItalic: Bool = false, isUnderlined: Bool = false) {
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderlined = isUnderlined
    }
} 