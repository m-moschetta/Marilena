import Foundation
import Combine

@MainActor
public class GroqService: ObservableObject {
    public static let shared = GroqService()
    
    private init() {}
    
    private var apiKey: String {
        return KeychainManager.shared.getAPIKey(for: "groq") ?? ""
    }
    
    private var selectedModel: String {
        return UserDefaults.standard.string(forKey: "selectedGroqChatModel") ?? "deepseek-r1-distill-qwen-32b"
    }
    
    // Modelli Groq supportati (2025 - Aggiornati da documentazione ufficiale)
    static let groqModels = [
        // DeepSeek R1 Distill (Advanced Reasoning - BEST CHOICE)
        "deepseek-r1-distill-llama-70b",   // 260 T/s, 131K context, CodeForces 1633, MATH 94.5%
        "deepseek-r1-distill-qwen-32b",    // 388 T/s, 128K context, CodeForces 1691, AIME 83.3%  
        "deepseek-r1-distill-qwen-14b",    // 500+ T/s, 64K context, AIME 69.7, MATH 93.9%
        "deepseek-r1-distill-qwen-1.5b",   // 800+ T/s, 32K context, ultra-fast reasoning
        
        // Qwen 2.5 (Fast General Purpose with Tool Use)
        "qwen2.5-72b-instruct",           // Enhanced capabilities, better reasoning
        "qwen2.5-32b-instruct",           // 397 T/s, 128K context, tool calling + JSON mode
        
        // LLaMA 3.3/3.1 (Meta - Versatile and Reliable)
        "llama-3.3-70b-versatile",        // General purpose, balanced performance
        "llama-3.1-405b-reasoning",       // Largest model, best for complex tasks
        "llama-3.1-70b-versatile",        // Good balance of size and performance
        "llama-3.1-8b-instant",           // Fast and efficient for simple tasks
        
        // Mixtral (Mistral AI - Multilingual and Coding)
        "mixtral-8x7b-32768",             // Mixture of Experts, multilingual
        
        // Gemma 2 (Google - Efficient and Fast)
        "gemma2-9b-it",                   // Efficient instruction-tuned model
        "gemma-7b-it"                     // Lightweight but capable
    ]
    
    private let baseURL = "https://api.groq.com/openai/v1"
    
    // MARK: - Public Methods
    
    public func testConnection() async throws -> Bool {
        guard !apiKey.isEmpty else {
            throw GroqError.missingAPIKey
        }
        
        let testMessages = [
            OpenAIMessage(role: "user", content: "Hello")
        ]
        
        do {
            let _ = try await sendMessage(messages: testMessages, model: selectedModel)
            return true
        } catch {
            throw error
        }
    }
    
    // MARK: - Chat Service Compatibility
    
    /// Invia messaggi a Groq (compatibile con ChatService)
    public func sendMessage(messages: [OpenAIMessage], model: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw GroqError.missingAPIKey
        }
        
        let requestBody = GroqRequest(
            model: model,
            messages: messages,
            temperature: 0.7,
            max_tokens: 1000
        )
        
        let jsonData = try JSONEncoder().encode(requestBody)
        
        var request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        let (data, groqResponse) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = groqResponse as? HTTPURLResponse else {
            throw GroqError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorMessage = String(data: data, encoding: .utf8) {
                throw GroqError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            } else {
                throw GroqError.apiError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        let response = try JSONDecoder().decode(GroqResponse.self, from: data)
        
        guard let firstChoice = response.choices.first else {
            throw GroqError.noResponse
        }
        
        // Parse thinking for reasoning models
        let thinkingResponse = ThinkingManager.shared.parseResponse(firstChoice.message.content, model: model)
        
        return thinkingResponse.finalAnswer
    }
}

// MARK: - Request/Response Models

struct GroqRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let max_tokens: Int
}

struct GroqResponse: Codable {
    let choices: [GroqChoice]
}

struct GroqChoice: Codable {
    let message: GroqMessage
}

struct GroqMessage: Codable {
    let content: String
}

struct GroqTranscriptionResponse: Codable {
    let text: String
}

// MARK: - Error Types

enum GroqError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case noResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Groq API key is missing"
        case .invalidResponse:
            return "Invalid response from Groq API"
        case .noResponse:
            return "No response from Groq API"
        case .apiError(let message):
            return "Groq API error: \(message)"
        }
    }
}
