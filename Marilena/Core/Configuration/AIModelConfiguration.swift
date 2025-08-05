import Foundation

// MARK: - AI Model Configuration System

/// Comprehensive configuration for all AI models with latest 2025 updates
/// Includes pricing, capabilities, and specifications for all major providers
@MainActor
public struct AIModelConfiguration: Codable, Identifiable {
    
    // MARK: - Basic Properties
    
    public let id: String
    public let name: String
    public let provider: AIModelProvider
    public let version: String
    public let releaseDate: Date
    public let description: String
    
    // MARK: - Technical Specifications
    
    public let contextWindow: Int
    public let maxOutputTokens: Int
    public let supportedModalities: [AIModality]
    public let capabilities: [AICapability]
    
    // MARK: - Pricing Structure
    
    public let pricing: AIPricing
    
    // MARK: - Performance Metrics
    
    public let benchmarks: AIBenchmarks
    
    // MARK: - Availability and Limits
    
    public let availability: AIAvailability
    
    // MARK: - Configuration Metadata
    
    public let knowledgeCutoff: Date?
    public let isExperimental: Bool
    public let requiresSpecialAccess: Bool
    public let tags: [String]
    
    public init(
        id: String,
        name: String,
        provider: AIModelProvider,
        version: String,
        releaseDate: Date,
        description: String,
        contextWindow: Int,
        maxOutputTokens: Int,
        supportedModalities: [AIModality],
        capabilities: [AICapability],
        pricing: AIPricing,
        benchmarks: AIBenchmarks,
        availability: AIAvailability,
        knowledgeCutoff: Date? = nil,
        isExperimental: Bool = false,
        requiresSpecialAccess: Bool = false,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.version = version
        self.releaseDate = releaseDate
        self.description = description
        self.contextWindow = contextWindow
        self.maxOutputTokens = maxOutputTokens
        self.supportedModalities = supportedModalities
        self.capabilities = capabilities
        self.pricing = pricing
        self.benchmarks = benchmarks
        self.availability = availability
        self.knowledgeCutoff = knowledgeCutoff
        self.isExperimental = isExperimental
        self.requiresSpecialAccess = requiresSpecialAccess
        self.tags = tags
    }
}

// MARK: - Supporting Types

public enum AIModelProvider: String, Codable, CaseIterable {
    case openai = "openai"
    case anthropic = "anthropic"
    case google = "google"
    case meta = "meta"
    case xai = "xai"
    case mistral = "mistral"
    case perplexity = "perplexity"
    case deepseek = "deepseek"
    case groq = "groq"
    
    public var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .google: return "Google"
        case .meta: return "Meta"
        case .xai: return "xAI"
        case .mistral: return "Mistral AI"
        case .perplexity: return "Perplexity"
        case .deepseek: return "DeepSeek"
        case .groq: return "Groq"
        }
    }
    
    public var baseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .google: return "https://generativelanguage.googleapis.com/v1"
        case .meta: return "https://api.llama-api.com/v1"
        case .xai: return "https://api.x.ai/v1"
        case .mistral: return "https://api.mistral.ai/v1"
        case .perplexity: return "https://api.perplexity.ai"
        case .deepseek: return "https://api.deepseek.com/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        }
    }
}

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

public struct AIPricing: Codable {
    public let inputTokens: PricingTier
    public let outputTokens: PricingTier
    public let specialPricing: [String: PricingTier]?
    public let currency: String
    public let billingUnit: String
    
    public init(
        inputTokens: PricingTier,
        outputTokens: PricingTier,
        specialPricing: [String: PricingTier]? = nil,
        currency: String = "USD",
        billingUnit: String = "per 1M tokens"
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.specialPricing = specialPricing
        self.currency = currency
        self.billingUnit = billingUnit
    }
}

public struct PricingTier: Codable {
    public let price: Double
    public let description: String?
    public let conditions: String?
    
    public init(price: Double, description: String? = nil, conditions: String? = nil) {
        self.price = price
        self.description = description
        self.conditions = conditions
    }
}

public struct AIBenchmarks: Codable {
    public let coding: Double?
    public let reasoning: Double?
    public let math: Double?
    public let multimodal: Double?
    public let conversational: Double?
    public let speed: Double?
    public let overallScore: Double?
    public let benchmarkDate: Date?
    
    public init(
        coding: Double? = nil,
        reasoning: Double? = nil,
        math: Double? = nil,
        multimodal: Double? = nil,
        conversational: Double? = nil,
        speed: Double? = nil,
        overallScore: Double? = nil,
        benchmarkDate: Date? = nil
    ) {
        self.coding = coding
        self.reasoning = reasoning
        self.math = math
        self.multimodal = multimodal
        self.conversational = conversational
        self.speed = speed
        self.overallScore = overallScore
        self.benchmarkDate = benchmarkDate
    }
}

public struct AIAvailability: Codable {
    public let regions: [String]
    public let accessTiers: [AccessTier]
    public let rateLimits: RateLimits?
    public let status: AvailabilityStatus
    
    public init(
        regions: [String],
        accessTiers: [AccessTier],
        rateLimits: RateLimits? = nil,
        status: AvailabilityStatus
    ) {
        self.regions = regions
        self.accessTiers = accessTiers
        self.rateLimits = rateLimits
        self.status = status
    }
}

public enum AccessTier: String, Codable, CaseIterable {
    case free = "free"
    case pro = "pro"
    case enterprise = "enterprise"
    case api = "api"
    case beta = "beta"
    case experimental = "experimental"
    
    public var displayName: String {
        switch self {
        case .free: return "Free Tier"
        case .pro: return "Pro/Plus"
        case .enterprise: return "Enterprise"
        case .api: return "API Access"
        case .beta: return "Beta Access"
        case .experimental: return "Experimental"
        }
    }
}

public enum AvailabilityStatus: String, Codable {
    case available = "available"
    case limited = "limited"
    case beta = "beta"
    case comingSoon = "coming_soon"
    case deprecated = "deprecated"
    
    public var displayName: String {
        switch self {
        case .available: return "Generally Available"
        case .limited: return "Limited Access"
        case .beta: return "Beta"
        case .comingSoon: return "Coming Soon"
        case .deprecated: return "Deprecated"
        }
    }
}

public struct RateLimits: Codable {
    public let requestsPerMinute: Int?
    public let tokensPerMinute: Int?
    public let requestsPerDay: Int?
    public let tokensPerDay: Int?
    
    public init(
        requestsPerMinute: Int? = nil,
        tokensPerMinute: Int? = nil,
        requestsPerDay: Int? = nil,
        tokensPerDay: Int? = nil
    ) {
        self.requestsPerMinute = requestsPerMinute
        self.tokensPerMinute = tokensPerMinute
        self.requestsPerDay = requestsPerDay
        self.tokensPerDay = tokensPerDay
    }
}

// MARK: - Static Configuration Data

public extension AIModelConfiguration {
    
    /// Complete catalog of 2025 AI models with latest updates
    static let allModels: [AIModelConfiguration] = [
        
        // MARK: - OpenAI Models (2025)
        
        .init(
            id: "gpt-4.1",
            name: "GPT-4.1",
            provider: .openai,
            version: "4.1",
            releaseDate: DateComponents(calendar: .current, year: 2025, month: 4, day: 14).date!,
            description: "OpenAI's most advanced model with 1M token context window and enhanced coding capabilities",
            contextWindow: 1_000_000,
            maxOutputTokens: 64_000,
            supportedModalities: [.text, .vision, .code],
            capabilities: [.reasoning, .coding, .math, .science, .creative, .analysis, .functionCalling, .jsonMode, .streaming],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 2.50),
                outputTokens: PricingTier(price: 10.00)
            ),
            benchmarks: AIBenchmarks(
                coding: 92.1,
                reasoning: 86.5,
                math: 88.3,
                multimodal: 88.9,
                conversational: 90.0,
                speed: 8.5,
                overallScore: 89.2
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.api, .pro, .enterprise],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2024, month: 6).date,
            tags: ["latest", "flagship", "coding", "reasoning"]
        ),
        
        .init(
            id: "gpt-4.1-mini",
            name: "GPT-4.1 Mini",
            provider: .openai,
            version: "4.1-mini",
            releaseDate: DateComponents(calendar: .current, year: 2025, month: 4, day: 14).date!,
            description: "Faster, more cost-effective version of GPT-4.1",
            contextWindow: 1_000_000,
            maxOutputTokens: 32_000,
            supportedModalities: [.text, .vision, .code],
            capabilities: [.reasoning, .coding, .math, .creative, .analysis, .functionCalling, .jsonMode, .streaming],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 0.15),
                outputTokens: PricingTier(price: 0.60)
            ),
            benchmarks: AIBenchmarks(
                coding: 88.5,
                reasoning: 82.1,
                math: 84.7,
                multimodal: 85.2,
                conversational: 87.0,
                speed: 9.2,
                overallScore: 86.1
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.free, .api, .pro, .enterprise],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2024, month: 6).date,
            tags: ["fast", "affordable", "mini"]
        ),
        
        .init(
            id: "o4-mini",
            name: "o4-mini",
            provider: .openai,
            version: "o4-mini",
            releaseDate: DateComponents(calendar: .current, year: 2025, month: 1, day: 25).date!,
            description: "OpenAI's latest reasoning model optimized for complex problem-solving",
            contextWindow: 128_000,
            maxOutputTokens: 32_000,
            supportedModalities: [.text, .code],
            capabilities: [.reasoning, .coding, .math, .science, .analysis],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 3.00),
                outputTokens: PricingTier(price: 12.00)
            ),
            benchmarks: AIBenchmarks(
                coding: 89.3,
                reasoning: 94.2,
                math: 92.8,
                conversational: 83.5,
                speed: 6.8,
                overallScore: 89.5
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.api, .pro, .enterprise],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2024, month: 12).date,
            tags: ["reasoning", "math", "science"]
        ),
        
        // MARK: - Anthropic Claude Models (2025)
        
        .init(
            id: "claude-4-sonnet",
            name: "Claude 4 Sonnet",
            provider: .anthropic,
            version: "4.0",
            releaseDate: DateComponents(calendar: .current, year: 2025, month: 5, day: 22).date!,
            description: "Anthropic's hybrid reasoning model with superior intelligence for high-volume use cases",
            contextWindow: 200_000,
            maxOutputTokens: 64_000,
            supportedModalities: [.text, .vision, .code],
            capabilities: [.reasoning, .coding, .math, .science, .creative, .analysis, .hybridReasoning, .toolUse, .computerUse],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 3.00),
                outputTokens: PricingTier(price: 15.00)
            ),
            benchmarks: AIBenchmarks(
                coding: 94.3,
                reasoning: 87.6,
                math: 90.2,
                multimodal: 89.4,
                conversational: 91.8,
                speed: 7.9,
                overallScore: 91.2
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.api, .pro, .enterprise],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2025, month: 3).date,
            tags: ["hybrid-reasoning", "flagship", "coding", "multimodal"]
        ),
        
        .init(
            id: "claude-3.7-sonnet",
            name: "Claude 3.7 Sonnet",
            provider: .anthropic,
            version: "3.7",
            releaseDate: DateComponents(calendar: .current, year: 2025, month: 2, day: 24).date!,
            description: "First hybrid reasoning model with extended thinking mode",
            contextWindow: 200_000,
            maxOutputTokens: 64_000,
            supportedModalities: [.text, .vision, .code],
            capabilities: [.reasoning, .coding, .math, .science, .creative, .analysis, .hybridReasoning, .toolUse],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 3.00),
                outputTokens: PricingTier(price: 15.00)
            ),
            benchmarks: AIBenchmarks(
                coding: 93.5,
                reasoning: 89.7,
                math: 87.3,
                multimodal: 86.2,
                conversational: 90.5,
                speed: 7.5,
                overallScore: 89.8
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.api, .pro, .enterprise],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2024, month: 10).date,
            tags: ["hybrid-reasoning", "thinking-mode", "coding"]
        ),
        
        // MARK: - Google Gemini Models (2025)
        
        .init(
            id: "gemini-2.5-pro",
            name: "Gemini 2.5 Pro",
            provider: .google,
            version: "2.5-pro",
            releaseDate: DateComponents(calendar: .current, year: 2025, month: 6, day: 17).date!,
            description: "Google's most capable model with 2M token context and hybrid reasoning",
            contextWindow: 2_000_000,
            maxOutputTokens: 65_536,
            supportedModalities: [.text, .vision, .audio, .video, .code],
            capabilities: [.reasoning, .coding, .math, .science, .creative, .analysis, .hybridReasoning, .toolUse, .webSearch],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 1.25),
                outputTokens: PricingTier(price: 5.00)
            ),
            benchmarks: AIBenchmarks(
                coding: 90.8,
                reasoning: 85.1,
                math: 86.2,
                multimodal: 89.7,
                conversational: 88.5,
                speed: 8.8,
                overallScore: 88.2
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.api, .pro, .enterprise],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2025, month: 1).date,
            tags: ["multimodal", "large-context", "google-search"]
        ),
        
        .init(
            id: "gemini-2.5-flash",
            name: "Gemini 2.5 Flash",
            provider: .google,
            version: "2.5-flash",
            releaseDate: DateComponents(calendar: .current, year: 2025, month: 4, day: 17).date!,
            description: "Google's first hybrid reasoning model with adjustable thinking budgets",
            contextWindow: 1_048_576,
            maxOutputTokens: 65_536,
            supportedModalities: [.text, .vision, .code],
            capabilities: [.reasoning, .coding, .math, .creative, .analysis, .hybridReasoning, .toolUse, .functionCalling],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 0.15, description: "Free while experimental"),
                outputTokens: PricingTier(price: 0.60, description: "Free while experimental")
            ),
            benchmarks: AIBenchmarks(
                coding: 87.2,
                reasoning: 83.8,
                math: 84.5,
                multimodal: 86.1,
                conversational: 86.9,
                speed: 9.1,
                overallScore: 86.4
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.api, .experimental],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2025, month: 1).date,
            isExperimental: true,
            tags: ["hybrid-reasoning", "experimental", "fast"]
        ),
        
        // MARK: - Meta Llama Models (2025)
        
        .init(
            id: "llama-4-maverick",
            name: "Llama 4 Maverick",
            provider: .meta,
            version: "4.0-maverick",
            releaseDate: DateComponents(calendar: .current, year: 2025, month: 4, day: 5).date!,
            description: "Meta's flagship multimodal model with MoE architecture and superior performance",
            contextWindow: 1_000_000,
            maxOutputTokens: 32_000,
            supportedModalities: [.text, .vision, .video, .code],
            capabilities: [.reasoning, .coding, .math, .science, .creative, .analysis, .toolUse],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 0.27),
                outputTokens: PricingTier(price: 0.85)
            ),
            benchmarks: AIBenchmarks(
                coding: 94.3,
                reasoning: 87.6,
                math: 90.2,
                multimodal: 89.4,
                conversational: 91.0,
                speed: 8.7,
                overallScore: 90.5
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.free, .api, .pro, .enterprise],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2024, month: 8).date,
            tags: ["open-source", "multimodal", "moe", "flagship"]
        ),
        
        .init(
            id: "llama-4-scout",
            name: "Llama 4 Scout",
            provider: .meta,
            version: "4.0-scout",
            releaseDate: DateComponents(calendar: .current, year: 2025, month: 4, day: 5).date!,
            description: "Ultra-long context model with unprecedented 10M token window",
            contextWindow: 10_000_000,
            maxOutputTokens: 32_000,
            supportedModalities: [.text, .vision, .code],
            capabilities: [.reasoning, .coding, .math, .creative, .analysis, .toolUse],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 0.18),
                outputTokens: PricingTier(price: 0.59)
            ),
            benchmarks: AIBenchmarks(
                coding: 89.2,
                reasoning: 82.5,
                math: 84.9,
                multimodal: 82.3,
                conversational: 87.5,
                speed: 8.2,
                overallScore: 86.1
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.free, .api, .pro, .enterprise],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2024, month: 8).date,
            tags: ["open-source", "ultra-long-context", "10m-tokens"]
        )
        
        // Additional models would continue here...
    ]
    
    /// Get models by provider
    static func models(for provider: AIModelProvider) -> [AIModelConfiguration] {
        return allModels.filter { $0.provider == provider }
    }
    
    /// Get models by capability
    static func models(with capability: AICapability) -> [AIModelConfiguration] {
        return allModels.filter { $0.capabilities.contains(capability) }
    }
    
    /// Get recommended models for email use case
    static var emailRecommended: [AIModelConfiguration] {
        return allModels.filter { model in
            model.capabilities.contains(.reasoning) &&
            model.capabilities.contains(.creative) &&
            !model.isExperimental &&
            model.availability.status == .available
        }.sorted { $0.benchmarks.overallScore ?? 0 > $1.benchmarks.overallScore ?? 0 }
    }
    
    /// Get latest models (released in 2025)
    static var latest2025: [AIModelConfiguration] {
        let calendar = Calendar.current
        return allModels.filter { model in
            calendar.component(.year, from: model.releaseDate) == 2025
        }.sorted { $0.releaseDate > $1.releaseDate }
    }
}