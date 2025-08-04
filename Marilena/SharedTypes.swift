import Foundation
import SwiftUI

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

// MARK: - Gmail API Types

// Gmail Message List Response
struct GmailMessageList: Codable {
    let messages: [GmailMessageSummary]
    let nextPageToken: String?
    let resultSizeEstimate: Int?
}

// Gmail Message Summary
struct GmailMessageSummary: Codable {
    let id: String
    let threadId: String
}

// Gmail Message Detail
struct GmailMessage: Codable {
    let id: String
    let threadId: String
    let labelIds: [String]
    let snippet: String?
    let payload: GmailMessagePayload?
    let sizeEstimate: Int?
    let historyId: String?
    let internalDate: String?
}

// Gmail Message Payload
struct GmailMessagePayload: Codable {
    let partId: String?
    let mimeType: String?
    let filename: String?
    let headers: [GmailHeader]?
    let body: GmailBody?
    let parts: [GmailMessagePayload]?
}

// Gmail Header
struct GmailHeader: Codable {
    let name: String
    let value: String
}

// Gmail Body
struct GmailBody: Codable {
    let attachmentId: String?
    let size: Int?
    let data: String?
}

// MARK: - Email Categorization

// Email Categories for AI Classification
public enum EmailCategory: String, Codable, CaseIterable {
    case work = "work"
    case personal = "personal"
    case notifications = "notifications"
    case promotional = "promotional"
    
    var displayName: String {
        switch self {
        case .work: return "Lavoro"
        case .personal: return "Personale"
        case .notifications: return "Notifiche"
        case .promotional: return "Promo/Spam"
        }
    }
    
    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .personal: return "person.fill"
        case .notifications: return "bell.fill"
        case .promotional: return "megaphone.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .work: return .blue
        case .personal: return .green
        case .notifications: return .orange
        case .promotional: return .red
        }
    }
} 