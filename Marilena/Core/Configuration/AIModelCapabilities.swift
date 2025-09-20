import Foundation

public enum AIModality: String, Codable, CaseIterable {
    case text = "text"
    case vision = "vision"
    case audio = "audio"
    case video = "video"
    case code = "code"
    case multimodal = "multimodal"

    public var displayName: String {
        switch self {
        case .text: return "Text"
        case .vision: return "Vision"
        case .audio: return "Audio"
        case .video: return "Video"
        case .code: return "Code"
        case .multimodal: return "Multimodal"
        }
    }
}

public enum AICapability: String, Codable, CaseIterable {
    case reasoning = "reasoning"
    case coding = "coding"
    case math = "math"
    case science = "science"
    case creative = "creative"
    case analysis = "analysis"
    case summarization = "summarization"
    case translation = "translation"
    case conversation = "conversation"
    case functionCalling = "function_calling"
    case jsonMode = "json_mode"
    case streaming = "streaming"
    case hybridReasoning = "hybrid_reasoning"
    case toolUse = "tool_use"
    case webSearch = "web_search"
    case computerUse = "computer_use"

    public var displayName: String {
        switch self {
        case .reasoning: return "Advanced Reasoning"
        case .coding: return "Code Generation"
        case .math: return "Mathematical Problem Solving"
        case .science: return "Scientific Analysis"
        case .creative: return "Creative Writing"
        case .analysis: return "Data Analysis"
        case .summarization: return "Text Summarization"
        case .translation: return "Language Translation"
        case .conversation: return "Natural Conversation"
        case .functionCalling: return "Function Calling"
        case .jsonMode: return "JSON Mode"
        case .streaming: return "Streaming Responses"
        case .hybridReasoning: return "Hybrid Reasoning"
        case .toolUse: return "Tool Use"
        case .webSearch: return "Web Search"
        case .computerUse: return "Computer Use"
        }
    }
}