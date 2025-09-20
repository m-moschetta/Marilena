import Foundation
import Combine

// MARK: - Model Catalog System

/// Sistema di catalogo dinamico per modelli AI
@MainActor
public final class ModelCatalog: ObservableObject {
    public static let shared = ModelCatalog()

    // MARK: - Published Properties

    @Published public private(set) var availableModels: [AIModelProvider: [AIModelInfo]] = [:]
    @Published public private(set) var isLoading: [AIModelProvider: Bool] = [:]
    @Published public private(set) var lastUpdate: [AIModelProvider: Date] = [:]
    @Published public private(set) var errors: [AIModelProvider: Error] = [:]

    // MARK: - Cache Management

    private var cache: [AIModelProvider: CachedModels] = [:]
    private let cacheValidity: TimeInterval = 3600 // 1 ora

    private struct CachedModels {
        let models: [AIModelInfo]
        let timestamp: Date
    }

    // MARK: - Initialization

    private init() {
        // Inizializza con valori vuoti per tutti i provider
        for provider in AIModelProvider.allCases {
            availableModels[provider] = []
            isLoading[provider] = false
        }
    }

    // MARK: - Public Methods

    /// Recupera modelli per un provider specifico
    public func fetchModels(for provider: AIModelProvider, forceRefresh: Bool = false) async {
        // Controlla se abbiamo dati in cache validi
        if !forceRefresh, let cached = cache[provider], isCacheValid(cached.timestamp) {
            availableModels[provider] = cached.models
            return
        }

        // Inizia caricamento
        setLoadingState(for: provider, loading: true)

        do {
            let models = try await fetchFromAPI(for: provider)
            let modelInfos = models.map { apiModel in
                // Usa sempre l'ID del provider come valore selezionato e inviato alle API
                AIModelInfo(
                    name: apiModel.id,
                    description: apiModel.description ?? apiModel.name,
                    contextTokens: getDefaultContextTokens(for: provider),
                    supportsStreaming: true
                )
            }

            // Aggiorna cache e stato
            cache[provider] = CachedModels(models: modelInfos, timestamp: Date())
            availableModels[provider] = modelInfos
            lastUpdate[provider] = Date()
            errors[provider] = nil

        } catch {
            errors[provider] = error
            print("❌ Errore recupero modelli per \(provider.displayName): \(error.localizedDescription)")

            // Fallback ai modelli statici se disponibile
            let staticModels = getStaticModels(for: provider)
            if !staticModels.isEmpty {
                let modelInfos = staticModels.map { apiModel in
                    AIModelInfo(
                        name: apiModel.id,
                        description: apiModel.description ?? apiModel.name,
                        contextTokens: getDefaultContextTokens(for: provider),
                        supportsStreaming: true
                    )
                }
                availableModels[provider] = modelInfos
                errors[provider] = nil
                print("✅ Fallback a modelli statici per \(provider.displayName): \(modelInfos.count) modelli")
            }
        }

        // Termina caricamento
        setLoadingState(for: provider, loading: false)
    }

    /// Recupera modelli per tutti i provider configurati
    public func fetchAllModels(forceRefresh: Bool = false) async {
        let providers = AIModelProvider.allCases.filter { hasValidAPIKey(for: $0) }

        await withTaskGroup(of: Void.self) { group in
            for provider in providers {
                group.addTask {
                    await self.fetchModels(for: provider, forceRefresh: forceRefresh)
                }
            }
        }
    }

    /// Ottiene modelli disponibili per un provider
    public func models(for provider: AIModelProvider) -> [AIModelInfo] {
        return availableModels[provider] ?? []
    }

    /// Ottiene tutti i modelli disponibili
    public func allModels() -> [AIModelInfo] {
        return AIModelProvider.allCases.flatMap { availableModels[$0] ?? [] }
    }

    /// Verifica se un provider ha API key valida
    private func hasValidAPIKey(for provider: AIModelProvider) -> Bool {
        let keyName: String
        switch provider {
        case .apple:
            return AppleIntelligenceService.shared.isAvailable
        case .openai: keyName = "openai"
        case .anthropic: keyName = "anthropic"
        case .groq: keyName = "groq"
        case .mistral: keyName = "mistral"
        case .perplexity: keyName = "perplexity"
        case .deepseek: keyName = "deepseek"
        case .xai: keyName = "xai"
        default: return false
        }

        guard let apiKey = KeychainManager.shared.getAPIKey(for: keyName),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return true
    }

    // MARK: - Private Methods

    private func isCacheValid(_ timestamp: Date) -> Bool {
        return Date().timeIntervalSince(timestamp) < cacheValidity
    }

    private func setLoadingState(for provider: AIModelProvider, loading: Bool) {
        Task { @MainActor in
            isLoading[provider] = loading
        }
    }

    private func fetchFromAPI(for provider: AIModelProvider) async throws -> [APIModel] {
        switch provider {
        case .apple:
            return getStaticModels(for: provider)
        case .openai:
            return try await fetchOpenAIModels()
        case .anthropic:
            return try await fetchAnthropicModels()
        case .groq:
            return try await fetchGroqModels()
        case .mistral:
            return try await fetchMistralModels()
        case .xai:
            return try await fetchXAIModels()
        default:
            // Per provider non supportati, usa modelli statici
            return getStaticModels(for: provider)
        }
    }
}

// MARK: - API Fetching Methods

extension ModelCatalog {

    private func fetchOpenAIModels() async throws -> [APIModel] {
        let forceGateway = UserDefaults.standard.bool(forKey: "force_gateway")
        let hasAPIKey = KeychainManager.shared.getAPIKey(for: "openai") != nil

        if forceGateway || !hasAPIKey {
            // Use Cloudflare Gateway
            let modelsData = try await CloudflareGatewayClient.shared.fetchModels(for: "openai")
            return modelsData.map { APIModel(id: $0.id, name: $0.id, description: nil) }
        }

        guard let apiKey = KeychainManager.shared.getAPIKey(for: "openai") else {
            throw ModelCatalogError.missingAPIKey
        }

        let url = URL(string: "https://api.openai.com/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ModelCatalogError.invalidResponse
        }

        let apiResponse = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
        return apiResponse.data.map { APIModel(id: $0.id, name: $0.id, description: nil) }
    }

    private func fetchAnthropicModels() async throws -> [APIModel] {
        let forceGateway = UserDefaults.standard.bool(forKey: "force_gateway")
        let hasAPIKey = KeychainManager.shared.getAPIKey(for: "anthropic") != nil

        if forceGateway || !hasAPIKey {
            // Use Cloudflare Gateway
            let modelsData = try await CloudflareGatewayClient.shared.fetchModels(for: "anthropic")
            return modelsData.map { APIModel(id: $0.id, name: $0.id, description: nil) }
        }

        guard let apiKey = KeychainManager.shared.getAPIKey(for: "anthropic") else {
            throw ModelCatalogError.missingAPIKey
        }

        let url = URL(string: "https://api.anthropic.com/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ModelCatalogError.invalidResponse
        }

        let apiResponse = try JSONDecoder().decode(AnthropicModelsResponse.self, from: data)
        return apiResponse.data.map { APIModel(id: $0.id, name: $0.display_name ?? $0.id, description: nil) }
    }

    private func fetchGroqModels() async throws -> [APIModel] {
        let forceGateway = UserDefaults.standard.bool(forKey: "force_gateway")
        let hasAPIKey = KeychainManager.shared.getAPIKey(for: "groq") != nil

        if forceGateway || !hasAPIKey {
            // Use Cloudflare Gateway
            let modelsData = try await CloudflareGatewayClient.shared.fetchModels(for: "groq")
            return modelsData.map { APIModel(id: $0.id, name: $0.id, description: nil) }
        }

        guard let apiKey = KeychainManager.shared.getAPIKey(for: "groq") else {
            throw ModelCatalogError.missingAPIKey
        }

        let url = URL(string: "https://api.groq.com/openai/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ModelCatalogError.invalidResponse
        }

        let apiResponse = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
        return apiResponse.data.map { APIModel(id: $0.id, name: $0.id, description: nil) }
    }

    private func fetchMistralModels() async throws -> [APIModel] {
        let forceGateway = UserDefaults.standard.bool(forKey: "force_gateway")
        let hasAPIKey = KeychainManager.shared.getAPIKey(for: "mistral") != nil

        if forceGateway || !hasAPIKey {
            // Use Cloudflare Gateway
            let modelsData = try await CloudflareGatewayClient.shared.fetchModels(for: "mistral")
            return modelsData.map { APIModel(id: $0.id, name: $0.id, description: nil) }
        }

        guard let apiKey = KeychainManager.shared.getAPIKey(for: "mistral") else {
            throw ModelCatalogError.missingAPIKey
        }

        let url = URL(string: "https://api.mistral.ai/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ModelCatalogError.invalidResponse
        }

        let apiResponse = try JSONDecoder().decode(MistralModelsResponse.self, from: data)
        return apiResponse.data.map { APIModel(id: $0.id, name: $0.id, description: $0.description) }
    }

    private func fetchXAIModels() async throws -> [APIModel] {
        let forceGateway = UserDefaults.standard.bool(forKey: "force_gateway")
        let hasAPIKey = KeychainManager.shared.getAPIKey(for: "xai") != nil

        if forceGateway || !hasAPIKey {
            // Use Cloudflare Gateway
            do {
                let modelsData = try await CloudflareGatewayClient.shared.fetchModels(for: "xai")
                return modelsData.map { APIModel(id: $0.id, name: $0.id, description: nil) }
            } catch {
                // Fallback to static models if Cloudflare fails
                return getStaticModels(for: .xai)
            }
        }

        guard let apiKey = KeychainManager.shared.getAPIKey(for: "xai") else {
            throw ModelCatalogError.missingAPIKey
        }

        let url = URL(string: "https://api.x.ai/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            // xAI risponde 400 se l'account non ha accesso; usa fallback statico
            let staticModels = getStaticModels(for: .xai)
            if !staticModels.isEmpty {
                return staticModels
            }
            throw ModelCatalogError.invalidResponse
        }

        // xAI usa lo stesso formato OpenAI per la risposta dei modelli
        let apiResponse = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
        return apiResponse.data.map { APIModel(id: $0.id, name: $0.id, description: nil) }
    }

    private func getStaticModels(for provider: AIModelProvider) -> [APIModel] {
        // Fallback per provider senza API dinamica
        switch provider {
        case .openai:
            return [
                // Rimuoviamo modelli duplicati che sono già in AIModelCatalog
                // APIModel(id: "gpt-4o", name: "GPT-4o", description: "Latest GPT-4o model"), // Duplicato
                APIModel(id: "gpt-4o-mini", name: "GPT-4o Mini", description: "Cost-effective GPT-4o"),
                APIModel(id: "chatgpt-4o-latest", name: "ChatGPT-4o Latest", description: "Latest ChatGPT-4o model"),
                APIModel(id: "gpt-4-turbo", name: "GPT-4 Turbo", description: "Enhanced GPT-4"),
                APIModel(id: "gpt-3.5-turbo", name: "GPT-3.5 Turbo", description: "Classic GPT-3.5"),
                APIModel(id: "o1", name: "o1", description: "Advanced reasoning model"),
                APIModel(id: "o1-mini", name: "o1 Mini", description: "Fast reasoning model"),
                APIModel(id: "o1-preview", name: "o1 Preview", description: "Preview reasoning model"),
                APIModel(id: "o3-mini", name: "o3 Mini", description: "Latest compact reasoning model")
            ]
        case .anthropic:
            return [
                APIModel(id: "claude-opus-4-20250514", name: "Claude 4 Opus", description: "Most capable Claude model"),
                APIModel(id: "claude-sonnet-4-20250514", name: "Claude 4 Sonnet", description: "High performance Claude model"),
                APIModel(id: "claude-3-7-sonnet-20250219", name: "Claude 3.7 Sonnet", description: "Enhanced Claude 3.7"),
                // APIModel(id: "claude-3-5-sonnet-20241022", name: "Claude 3.5 Sonnet", description: "Balanced Claude 3.5"), // Duplicato in AIModelCatalog
                APIModel(id: "claude-3-5-haiku-20241022", name: "Claude 3.5 Haiku", description: "Fast and cost-effective"),
                APIModel(id: "claude-3-opus-20240229", name: "Claude 3 Opus", description: "Legacy premium model"),
                APIModel(id: "claude-3-haiku-20240307", name: "Claude 3 Haiku", description: "Fast responses")
            ]
        case .groq:
            return [
                APIModel(id: "llama-3.3-70b-versatile", name: "Llama 3.3 70B Versatile", description: "Latest Llama model"),
                APIModel(id: "llama-3.1-405b-reasoning", name: "Llama 3.1 405B Reasoning", description: "Largest reasoning model"),
                APIModel(id: "llama-3.1-70b-versatile", name: "Llama 3.1 70B Versatile", description: "Most capable model"),
                APIModel(id: "llama-3.1-8b-instant", name: "Llama 3.1 8B Instant", description: "Ultra-fast inference"),
                APIModel(id: "mixtral-8x7b-32768", name: "Mixtral 8x7B", description: "Mixture of experts model"),
                APIModel(id: "gemma2-9b-it", name: "Gemma 2 9B", description: "Google's efficient model"),
                APIModel(id: "qwen2.5-72b-instruct", name: "Qwen 2.5 72B", description: "Enhanced capabilities model"),
                APIModel(id: "qwen2.5-32b-instruct", name: "Qwen 2.5 32B", description: "Fast general purpose model"),
                APIModel(id: "deepseek-r1-distill-llama-70b", name: "DeepSeek R1 Llama 70B", description: "Advanced reasoning model"),
                APIModel(id: "deepseek-r1-distill-qwen-32b", name: "DeepSeek R1 Qwen 32B", description: "Fast reasoning model")
            ]
        case .mistral:
            return [
                APIModel(id: "mistral-large-latest", name: "Mistral Large Latest", description: "Most capable Mistral model"),
                APIModel(id: "mistral-small-latest", name: "Mistral Small Latest", description: "Fast and efficient"),
                APIModel(id: "mistral-medium-latest", name: "Mistral Medium Latest", description: "Balanced performance")
            ]
        case .perplexity:
            return [
                APIModel(id: "sonar-pro", name: "Sonar Pro", description: "Advanced reasoning model"),
                APIModel(id: "sonar", name: "Sonar", description: "Fast and efficient model")
            ]
        case .deepseek:
            return [
                APIModel(id: "deepseek-chat", name: "DeepSeek Chat", description: "Advanced reasoning model")
            ]
        case .apple:
            // I modelli Apple sono ora definiti in AIModelCatalog per evitare duplicati
            return []
        case .google:
            return [
                APIModel(id: "gemini-1.5-pro", name: "Gemini 1.5 Pro", description: "Google's advanced multimodal model"),
                APIModel(id: "gemini-1.5-flash", name: "Gemini 1.5 Flash", description: "Fast and efficient multimodal model")
            ]
        case .meta:
            return [
                APIModel(id: "llama-3.2-70b-instruct", name: "Llama 3.2 70B", description: "Meta's most capable Llama model"),
                APIModel(id: "llama-3.2-3b-instruct", name: "Llama 3.2 3B", description: "Efficient and fast Llama model")
            ]
        case .xai:
            return [
                // Grok 4 - Most intelligent models (2025)
                APIModel(id: "grok-4-latest", name: "Grok 4 Latest", description: "Latest Grok 4 model with auto-updates"),
                APIModel(id: "grok-4", name: "Grok 4", description: "Most intelligent model with tool use and real-time search"),
                APIModel(id: "grok-4-fast", name: "Grok 4 Fast", description: "Cost-efficient reasoning model with high throughput"),
                APIModel(id: "grok-4-fast-non-reasoning-latest", name: "Grok 4 Fast Non-Reasoning", description: "Fast version without advanced reasoning"),
                APIModel(id: "grok-4-fast-reasoning-latest", name: "Grok 4 Fast Reasoning", description: "Fast version with enhanced reasoning"),

                // Grok 3 - Balanced performance
                APIModel(id: "grok-3", name: "Grok 3", description: "Balanced Grok 3 model"),
                APIModel(id: "grok-3-mini", name: "Grok 3 Mini", description: "Cost efficient Grok 3 variant"),

                // Specialized models
                APIModel(id: "grok-code-fast-1", name: "Grok Code Fast", description: "Specialized for rapid code generation"),
                APIModel(id: "grok-vision-beta", name: "Grok Vision Beta", description: "Beta version with enhanced visual understanding"),
                APIModel(id: "grok-beta", name: "Grok Beta", description: "General purpose beta model")
            ]
        }
    }

    private func getDefaultContextTokens(for provider: AIModelProvider) -> Int {
        // Token di contesto predefiniti per provider
        switch provider {
        case .apple: return 32_000
        case .openai: return 128_000
        case .anthropic: return 200_000
        case .groq: return 128_000
        case .mistral: return 128_000
        case .perplexity: return 128_000
        case .deepseek: return 32_768
        case .xai: return 256_000 // Grok 4 supports larger context windows
        default: return 4096
        }
    }
}

// MARK: - Data Structures

/// Estensione per AIModelInfo con supporto al catalogo dinamico
extension AIModelInfo {
    /// Crea AIModelInfo da un modello API
    fileprivate init(from apiModel: APIModel, provider: AIModelProvider, contextTokens: Int = 4096) {
        self.init(
            name: apiModel.name,
            description: apiModel.description ?? "Modello \(apiModel.name)",
            contextTokens: contextTokens,
            supportsStreaming: true
        )
    }
}

/// Modello API generico
private struct APIModel {
    let id: String
    let name: String
    let description: String?
}

// MARK: - API Response Structures

private struct OpenAIModelsResponse: Codable {
    let data: [OpenAIModel]

    struct OpenAIModel: Codable {
        let id: String
    }
}

private struct AnthropicModelsResponse: Codable {
    let data: [AnthropicModel]

    struct AnthropicModel: Codable {
        let id: String
        let display_name: String?
    }
}

private struct MistralModelsResponse: Codable {
    let data: [MistralModel]

    struct MistralModel: Codable {
        let id: String
        let description: String?
    }
}

// MARK: - Error Types

enum ModelCatalogError: Error {
    case missingAPIKey
    case invalidResponse
    case decodingError
    case networkError

    var localizedDescription: String {
        switch self {
        case .missingAPIKey:
            return "API key mancante"
        case .invalidResponse:
            return "Risposta API non valida"
        case .decodingError:
            return "Errore nella decodifica della risposta"
        case .networkError:
            return "Errore di rete"
        }
    }
}
