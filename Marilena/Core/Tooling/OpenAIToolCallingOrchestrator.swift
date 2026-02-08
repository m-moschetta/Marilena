import Foundation
import os.log

// MARK: - Chat Completions Tool Calling Orchestrator

/// Coordina una richiesta Chat Completions con tool calling:
/// 1) manda i messaggi e ottiene eventuali `tool_calls`
/// 2) esegue i tool nativi
/// 3) ripete la richiesta includendo il messaggio assistant con i tool_calls e gli output dei tool
struct OpenAIToolCallingOrchestrator {
    let apiKeyProvider: () -> String?
    let model: String
    let temperature: Double
    let maxTokens: Int?
    let toolHandler: ToolHandlerProtocol
    private let baseURL: URL
    private let providerName: String
    
    private let logger = Logger(subsystem: "Marilena", category: "ToolCalling")
    
    init(
        apiKeyProvider: @escaping () -> String?,
        model: String,
        temperature: Double,
        maxTokens: Int?,
        toolHandler: ToolHandlerProtocol,
        baseURL: URL = URL(string: "https://api.openai.com/v1/chat/completions")!,
        providerName: String = "OpenAI"
    ) {
        self.apiKeyProvider = apiKeyProvider
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.toolHandler = toolHandler
        self.baseURL = baseURL
        self.providerName = providerName
    }
    
    /// Esegue la conversazione con tool calling. Restituisce il testo finale dell'assistente.
    func run(messages: [OpenAIMessage]) async throws -> String {
        var chatMessages = messages.map { ChatCompletionMessage(role: $0.role, content: $0.content) }
        
        // 1) Prima chiamata: lascia che il modello scelga i tool
        let initial = try await sendChatCompletion(
            messages: chatMessages,
            toolChoice: "auto",
            availableTools: toolHandler.availableTools
        )
        
        guard let toolCalls = initial.toolCalls, !toolCalls.isEmpty else {
            return initial.content ?? ""
        }
        
        // 2) Inserisci nel contesto il messaggio assistant con i tool_calls (fix replay)
        let assistantWithCalls = ChatCompletionMessage(
            role: "assistant",
            content: initial.content,
            toolCalls: toolCalls
        )
        chatMessages.append(assistantWithCalls)
        
        // 3) Esegui i tool nativi e aggiungi gli output alla history
        var toolOutputMessages: [ChatCompletionMessage] = []
        for toolCall in toolCalls {
            do {
                let output = try await toolHandler.executeToolCall(toolCall)
                toolOutputMessages.append(
                    ChatCompletionMessage(
                        role: "tool",
                        content: output,
                        toolCallId: toolCall.id
                    )
                )
            } catch {
                logger.error("Tool execution failed for \(toolCall.function.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
                toolOutputMessages.append(
                    ChatCompletionMessage(
                        role: "tool",
                        content: "Errore esecuzione tool \(toolCall.function.name): \(error.localizedDescription)",
                        toolCallId: toolCall.id
                    )
                )
            }
        }
        chatMessages.append(contentsOf: toolOutputMessages)
        
        // 4) Seconda chiamata: passa tool outputs + tool_calls, e disattiva ulteriori tool per ottenere la risposta finale
        let final = try await sendChatCompletion(
            messages: chatMessages,
            toolChoice: "none",
            availableTools: toolHandler.availableTools
        )
        return final.content ?? ""
    }
    
    // MARK: - Network
    
    private func sendChatCompletion(
        messages: [ChatCompletionMessage],
        toolChoice: String,
        availableTools: [AIToolDefinition]
    ) async throws -> ChatCompletionMessage {
        guard let apiKey = apiKeyProvider()?.trimmingCharacters(in: .whitespacesAndNewlines), !apiKey.isEmpty else {
            throw OpenAIToolCallingError.missingAPIKey
        }
        
        let payload = ChatCompletionRequest(
            model: model,
            messages: messages,
            tools: availableTools.compactMap { ChatCompletionRequest.ToolDefinition(definition: $0) },
            toolChoice: toolChoice,
            maxTokens: maxTokens,
            temperature: temperature
        )
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIToolCallingError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw OpenAIToolCallingError.httpStatus(code: httpResponse.statusCode, body: body)
        }
        
        let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let message = completion.choices.first?.message else {
            throw OpenAIToolCallingError.noChoices
        }
        return message
    }
}

// MARK: - Tool Handler Protocol

protocol ToolHandlerProtocol {
    var availableTools: [AIToolDefinition] { get }
    func executeToolCall(_ toolCall: ChatCompletionToolCall) async throws -> String
}

// MARK: - Request/Response Models

private struct ChatCompletionRequest: Encodable {
    struct ToolDefinition: Encodable {
        let type: String = "function"
        let function: Function
        
        init?(definition: AIToolDefinition) {
            guard let parameters = JSONValue(jsonString: definition.jsonSchema) else {
                return nil
            }
            self.function = Function(
                name: definition.name,
                description: definition.description,
                parameters: parameters
            )
        }
        
        struct Function: Encodable {
            let name: String
            let description: String
            let parameters: JSONValue
        }
    }
    
    let model: String
    let messages: [ChatCompletionMessage]
    let tools: [ToolDefinition]?
    let toolChoice: String
    let maxTokens: Int?
    let temperature: Double
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case tools
        case toolChoice = "tool_choice"
        case maxTokens = "max_tokens"
        case temperature
    }
}

struct ChatCompletionMessage: Codable {
    let role: String
    let content: String?
    let name: String?
    let toolCallId: String?
    let toolCalls: [ChatCompletionToolCall]?
    
    init(
        role: String,
        content: String?,
        name: String? = nil,
        toolCallId: String? = nil,
        toolCalls: [ChatCompletionToolCall]? = nil
    ) {
        self.role = role
        self.content = content
        self.name = name
        self.toolCallId = toolCallId
        self.toolCalls = toolCalls
    }
    
    enum CodingKeys: String, CodingKey {
        case role
        case content
        case name
        case toolCallId = "tool_call_id"
        case toolCalls = "tool_calls"
    }
}

struct ChatCompletionToolCall: Codable {
    struct Function: Codable {
        let name: String
        let arguments: String
    }
    let id: String
    let type: String
    let function: Function
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        let message: ChatCompletionMessage
    }
    
    let choices: [Choice]
}

// MARK: - JSONValue helper

/// Piccola rappresentazione Encodable di un JSON arbitrario (per il campo `parameters`)
enum JSONValue: Encodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null
    
    init?(jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        self.init(any: obj)
    }
    
    init?(any: Any) {
        switch any {
        case let value as String:
            self = .string(value)
        case let value as NSNumber:
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                self = .bool(value.boolValue)
            } else {
                self = .number(value.doubleValue)
            }
        case let value as [String: Any]:
            var mapped: [String: JSONValue] = [:]
            for (key, val) in value {
                guard let jsonValue = JSONValue(any: val) else { continue }
                mapped[key] = jsonValue
            }
            self = .object(mapped)
        case let value as [Any]:
            let mapped = value.compactMap { JSONValue(any: $0) }
            self = .array(mapped)
        default:
            return nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let dict):
            try container.encode(dict)
        case .array(let array):
            try container.encode(array)
        case .null:
            try container.encodeNil()
        }
    }
}

// MARK: - Errors

enum OpenAIToolCallingError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpStatus(code: Int, body: String)
    case noChoices
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key OpenAI mancante per il tool calling"
        case .invalidResponse:
            return "Risposta OpenAI non valida"
        case .httpStatus(let code, let body):
            return "Errore HTTP \(code): \(body)"
        case .noChoices:
            return "Nessuna risposta dal modello"
        }
    }
}
