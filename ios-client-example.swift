//
//  LLMGatewayClient.swift
//  Esempio di client iOS per il gateway LLM
//

import Foundation

// MARK: - Provider e Modelli

enum AIProvider: String, CaseIterable {
    case openai = "OpenAI"
    case groq = "Groq"
    case anthropic = "Anthropic"
    case mistral = "Mistral"
    
    var defaultModel: String {
        switch self {
        case .openai:
            return "gpt-4o"
        case .groq:
            return "llama-3.1-70b-versatile"
        case .anthropic:
            return "claude-3-sonnet-20240229"
        case .mistral:
            return "mistral-large-latest"
        }
    }
    
    var availableModels: [String] {
        switch self {
        case .openai:
            return ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo"]
        case .groq:
            return ["llama-3.1-70b-versatile", "llama-3.1-8b-instant", "mixtral-8x7b-32768"]
        case .anthropic:
            return ["claude-3-sonnet-20240229", "claude-3-haiku-20240307", "claude-3-opus-20240229"]
        case .mistral:
            return ["mistral-large-latest", "mistral-medium-latest", "mistral-small-latest"]
        }
    }
}

// MARK: - Modelli di dati

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let maxTokens: Int?
    let temperature: Double?
    let stream: Bool?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream
        case maxTokens = "max_tokens"
    }
}

struct ChatResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage?
}

struct Choice: Codable {
    let index: Int
    let message: ChatMessage?
    let delta: ChatMessage?
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, message, delta
        case finishReason = "finish_reason"
    }
}

struct Usage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - Client LLM Gateway

class LLMGatewayClient {
    private let baseURL: String
    private let session: URLSession
    
    init(baseURL: String) {
        self.baseURL = baseURL
        self.session = URLSession.shared
    }
    
    // MARK: - Metodi di convenienza per provider
    
    func getProviderForModel(_ model: String) -> AIProvider? {
        for provider in AIProvider.allCases {
            if provider.availableModels.contains(model) {
                return provider
            }
        }
        return nil
    }
    
    func sendChatCompletion(
        messages: [ChatMessage],
        provider: AIProvider,
        model: String? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil
    ) async throws -> ChatResponse {
        let selectedModel = model ?? provider.defaultModel
        return try await sendChatCompletion(
            messages: messages,
            model: selectedModel,
            maxTokens: maxTokens,
            temperature: temperature
        )
    }
    
    func sendStreamingChatCompletion(
        messages: [ChatMessage],
        provider: AIProvider,
        model: String? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        onChunk: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        let selectedModel = model ?? provider.defaultModel
        sendStreamingChatCompletion(
            messages: messages,
            model: selectedModel,
            maxTokens: maxTokens,
            temperature: temperature,
            onChunk: onChunk,
            onComplete: onComplete,
            onError: onError
        )
    }
    
    // MARK: - Chat Completion (Non-streaming)
    
    func sendChatCompletion(
        messages: [ChatMessage],
        model: String = "gpt-4o",
        maxTokens: Int? = nil,
        temperature: Double? = nil
    ) async throws -> ChatResponse {
        
        let request = ChatRequest(
            model: model,
            messages: messages,
            maxTokens: maxTokens,
            temperature: temperature,
            stream: false
        )
        
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw LLMError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw LLMError.encodingError(error)
        }
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw LLMError.httpError(httpResponse.statusCode)
            }
            
            let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
            return chatResponse
            
        } catch let error as LLMError {
            throw error
        } catch {
            throw LLMError.networkError(error)
        }
    }
    
    // MARK: - Chat Completion (Streaming)
    
    func sendStreamingChatCompletion(
        messages: [ChatMessage],
        model: String = "gpt-4o",
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        onChunk: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        
        let request = ChatRequest(
            model: model,
            messages: messages,
            maxTokens: maxTokens,
            temperature: temperature,
            stream: true
        )
        
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            onError(LLMError.invalidURL)
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            onError(LLMError.encodingError(error))
            return
        }
        
        let task = session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                onError(LLMError.networkError(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                onError(LLMError.invalidResponse)
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                onError(LLMError.httpError(httpResponse.statusCode))
                return
            }
            
            guard let data = data else {
                onError(LLMError.noData)
                return
            }
            
            // Processa i chunk SSE
            let dataString = String(data: data, encoding: .utf8) ?? ""
            let lines = dataString.components(separatedBy: .newlines)
            
            for line in lines {
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))
                    
                    if jsonString.trimmingCharacters(in: .whitespaces) == "[DONE]" {
                        DispatchQueue.main.async {
                            onComplete()
                        }
                        return
                    }
                    
                    if let jsonData = jsonString.data(using: .utf8),
                       let chunk = try? JSONDecoder().decode(ChatResponse.self, from: jsonData),
                       let delta = chunk.choices.first?.delta,
                       let content = delta.content {
                        
                        DispatchQueue.main.async {
                            onChunk(content)
                        }
                    }
                }
            }
        }
        
        task.resume()
    }
}

// MARK: - Errori

enum LLMError: Error, LocalizedError {
    case invalidURL
    case encodingError(Error)
    case networkError(Error)
    case invalidResponse
    case httpError(Int)
    case noData
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL non valido"
        case .encodingError(let error):
            return "Errore di codifica: \(error.localizedDescription)"
        case .networkError(let error):
            return "Errore di rete: \(error.localizedDescription)"
        case .invalidResponse:
            return "Risposta non valida"
        case .httpError(let code):
            return "Errore HTTP: \(code)"
        case .noData:
            return "Nessun dato ricevuto"
        case .decodingError(let error):
            return "Errore di decodifica: \(error.localizedDescription)"
        }
    }
}

// MARK: - Catalogo Modelli Dinamico

class ModelCatalog: ObservableObject {
    @Published var models: [AIProvider: [AIModel]] = [:]
    @Published var isLoading: [AIProvider: Bool] = [:]
    @Published var errorMessages: [AIProvider: String] = [:]
    
    var lastUpdated: [AIProvider: Date] = [:]
    
    private let client: LLMGatewayClient
    
    init(client: LLMGatewayClient? = nil) {
        self.client = client ?? LLMGatewayClient(baseURL: "https://llm-proxy-gateway.mariomos94.workers.dev")
        
        // Inizializza con modelli statici come fallback
        for provider in AIProvider.allCases {
            models[provider] = provider.availableModels.map { modelId in
                AIModel(id: modelId, displayName: modelId, isDeprecated: false)
            }
        }
    }
    
    func refreshAllModels() async {
        await withTaskGroup(of: Void.self) { group in
            for provider in AIProvider.allCases {
                group.addTask {
                    await self.refreshModels(for: provider)
                }
            }
        }
    }
    
    func refreshModels(for provider: AIProvider) async {
        DispatchQueue.main.async {
            self.isLoading[provider] = true
            self.errorMessages[provider] = nil
        }
        
        do {
            let fetchedModels = try await fetchModelsFromAPI(for: provider)
            DispatchQueue.main.async {
                self.models[provider] = fetchedModels
                self.lastUpdated[provider] = Date()
                self.isLoading[provider] = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessages[provider] = error.localizedDescription
                self.isLoading[provider] = false
            }
        }
    }
    
    private func fetchModelsFromAPI(for provider: AIProvider) async throws -> [AIModel] {
        // Simula chiamata API per ottenere modelli dinamici
        // In una implementazione reale, questo farebbe una chiamata al gateway
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 secondo di delay
        
        // Restituisce modelli con informazioni aggiuntive
        return provider.availableModels.map { modelId in
            AIModel(
                id: modelId,
                displayName: formatDisplayName(modelId),
                isDeprecated: isModelDeprecated(modelId)
            )
        }
    }
    
    private func formatDisplayName(_ modelId: String) -> String {
        return modelId.replacingOccurrences(of: "-", with: " ").capitalized
    }
    
    private func isModelDeprecated(_ modelId: String) -> Bool {
        // Logica per determinare se un modello è deprecato
        return modelId.contains("3.5") || modelId.contains("old")
    }
    
    // Metodi di convenienza per SwiftUI
    func getModels(for provider: AIProvider) async -> [AIModel] {
        return models[provider] ?? []
    }
    
    func getPickerModels(for provider: AIProvider) -> [AIModel] {
        return models[provider] ?? []
    }
    
    func isLoadingModels(for provider: AIProvider) -> Bool {
        return isLoading[provider] ?? false
    }
    
    func getErrorMessage(for provider: AIProvider) -> String? {
        return errorMessages[provider]
    }
}

struct AIModel: Identifiable, Hashable {
    let id: String
    let displayName: String?
    let isDeprecated: Bool
    
    var formattedName: String {
        return displayName ?? id
    }
}

// MARK: - Esempio di utilizzo con ModelCatalog

/*
// Inizializza il client e il catalogo
let client = LLMGatewayClient(baseURL: "https://llm-proxy-gateway.mariomos94.workers.dev")
let modelCatalog = ModelCatalog(client: client)

// Esempio 1: Compatibilità tradizionale (usando stringa modello)
Task {
    do {
        let messages = [ChatMessage(role: "user", content: "Ciao! Come stai?")]
        let response = try await client.sendChatCompletion(messages: messages, model: "gpt-4o")
        print("Risposta: \(response.choices.first?.message?.content ?? "Nessuna risposta")")
    } catch {
        print("Errore: \(error)")
    }
}

// Esempio 2: Utilizzo del ModelCatalog per selezione dinamica
Task {
    // Carica tutti i modelli disponibili
    await modelCatalog.refreshAllModels()
    
    // Ottieni modelli disponibili per OpenAI
    let openAIModels = await modelCatalog.getModels(for: .openai)
    print("Modelli OpenAI disponibili: \(openAIModels.map { $0.id })")
    
    // Usa il primo modello disponibile
    if let firstModel = openAIModels.first {
        let messages = [ChatMessage(role: "user", content: "Spiegami l'informatica quantistica")]
        let response = try await client.sendChatCompletion(
            messages: messages,
            provider: .openai,
            model: firstModel.id
        )
        print("Risposta OpenAI: \(response.choices.first?.message?.content ?? "Nessuna risposta")")
    }
}

// Esempio 3: Utilizzo di Groq con modelli dinamici
Task {
    let groqModels = await modelCatalog.getModels(for: .groq)
    if let fastModel = groqModels.first(where: { $0.id.contains("mixtral") }) {
        let messages = [ChatMessage(role: "user", content: "Scrivi una poesia breve")]
        let response = try await client.sendChatCompletion(
            messages: messages,
            provider: .groq,
            model: fastModel.id
        )
        print("Risposta Groq: \(response.choices.first?.message?.content ?? "Nessuna risposta")")
    }
}

// Esempio 4: Utilizzo di Mistral con filtro modelli
Task {
    let mistralModels = await modelCatalog.getModels(for: .mistral)
    // Filtra solo modelli non deprecati
    let latestModels = mistralModels.filter { !$0.isDeprecated }
    
    if let latestModel = latestModels.first {
        let messages = [ChatMessage(role: "user", content: "Riassumi i vantaggi delle energie rinnovabili")]
        let response = try await client.sendChatCompletion(
            messages: messages,
            provider: .mistral,
            model: latestModel.id
        )
        print("Risposta Mistral: \(response.choices.first?.message?.content ?? "Nessuna risposta")")
    }
}

// Esempio 5: Streaming con selezione dinamica modelli
Task {
    let anthropicModels = await modelCatalog.getModels(for: .anthropic)
    if let claudeModel = anthropicModels.first(where: { $0.id.contains("claude-3") }) {
        let messages = [ChatMessage(role: "user", content: "Raccontami una storia")]
        client.sendStreamingChatCompletion(
            messages: messages,
            provider: .anthropic,
            model: claudeModel.id,
            onChunk: { chunk in
                print(chunk, terminator: "")
            },
            onComplete: {
                print("\n\nStreaming completato!")
            },
            onError: { error in
                print("Errore streaming: \(error)")
            }
        )
    }
}

// Esempio 6: Gestione stato e errori del catalogo
Task {
    // Controlla se i modelli stanno caricando
    if modelCatalog.isLoadingModels(for: .openai) {
        print("I modelli OpenAI stanno ancora caricando...")
    }
    
    // Controlla errori
    if let error = modelCatalog.getErrorMessage(for: .openai) {
        print("Errore caricamento modelli OpenAI: \(error)")
        
        // Riprova il caricamento
        await modelCatalog.refreshModels(for: .openai)
    }
    
    // Ottieni tempo ultimo aggiornamento
    if let lastUpdate = modelCatalog.lastUpdated[.openai] {
        print("Modelli OpenAI aggiornati l'ultima volta: \(lastUpdate)")
    }
}

// Esempio 7: Informazioni provider (fallback statico)
print("Modelli statici OpenAI: \(AIProvider.openai.availableModels)")
print("Modello predefinito Groq: \(AIProvider.groq.defaultModel)")

// Esempio 8: Rilevare provider da modello
if let provider = client.getProviderForModel("claude-3-sonnet-20240229") {
    print("Il modello claude-3-sonnet-20240229 appartiene a: \(provider.rawValue)")
}

// Esempio 9: Integrazione SwiftUI con ModelCatalog
/*
import SwiftUI

struct ContentView: View {
    @StateObject private var modelCatalog = ModelCatalog()
    @State private var selectedProvider: AIProvider = .openai
    @State private var selectedModel: AIModel?
    
    var body: some View {
        VStack {
            // Picker Provider
            Picker("Provider", selection: $selectedProvider) {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    Text(provider.rawValue.capitalized).tag(provider)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Picker Modello
            if modelCatalog.isLoadingModels(for: selectedProvider) {
                ProgressView("Caricamento modelli...")
            } else {
                Picker("Modello", selection: $selectedModel) {
                    ForEach(modelCatalog.getPickerModels(for: selectedProvider)) { model in
                        Text(model.formattedName).tag(model as AIModel?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            // Pulsante Aggiorna
            Button("Aggiorna Modelli") {
                Task {
                    await modelCatalog.refreshModels(for: selectedProvider)
                }
            }
            
            // Mostra errori
            if let error = modelCatalog.getErrorMessage(for: selectedProvider) {
                Text("Errore: \(error)")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .task {
            await modelCatalog.refreshAllModels()
        }
        .onChange(of: selectedProvider) { newProvider in
            Task {
                let models = await modelCatalog.getModels(for: newProvider)
                selectedModel = models.first
            }
        }
    }
}
*/
*/