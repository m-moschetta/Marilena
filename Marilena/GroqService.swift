import Foundation
import Combine

@MainActor
public class GroqService: ObservableObject {
    public static let shared = GroqService()
    
    private init() {}
    
    private var apiKey: String {
        return UserDefaults.standard.string(forKey: "groqApiKey") ?? ""
    }
    
    private var selectedModel: String {
        return UserDefaults.standard.string(forKey: "selectedGroqChatModel") ?? "llama-3.3-70b-versatile"
    }
    
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
        
        return firstChoice.message.content
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