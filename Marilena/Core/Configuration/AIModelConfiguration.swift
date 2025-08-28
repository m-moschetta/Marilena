import Foundation

// MARK: - AI Model Configuration System

/// Comprehensive configuration for current AI models (2024)
/// Includes pricing, capabilities, and specifications for all major providers
/// Updated with the latest available models from OpenAI, Anthropic, Google, Meta, and others
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
    
    /// Complete catalog of current AI models with latest updates (2024)
    static let allModels: [AIModelConfiguration] = [

        // MARK: - OpenAI Models (Latest Available)

        .init(
            id: "gpt-4o",
            name: "GPT-4o",
            provider: .openai,
            version: "4o",
            releaseDate: DateComponents(calendar: .current, year: 2024, month: 5, day: 13).date!,
            description: "OpenAI's most advanced multimodal model with real-time audio and vision capabilities",
            contextWindow: 128_000,
            maxOutputTokens: 4096,
            supportedModalities: [.text, .vision, .audio],
            capabilities: [.reasoning, .coding, .math, .science, .creative, .analysis, .functionCalling, .jsonMode, .streaming],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 5.00, description: "per 1M tokens"),
                outputTokens: PricingTier(price: 15.00, description: "per 1M tokens")
            ),
            benchmarks: AIBenchmarks(
                coding: 93.4,
                reasoning: 88.7,
                math: 89.2,
                multimodal: 92.1,
                conversational: 94.5,
                speed: 9.8,
                overallScore: 92.5
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.api, .pro, .enterprise],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2023, month: 10).date,
            tags: ["flagship", "multimodal", "real-time", "latest"]
        ),

        .init(
            id: "gpt-4o-mini",
            name: "GPT-4o Mini",
            provider: .openai,
            version: "4o-mini",
            releaseDate: DateComponents(calendar: .current, year: 2024, month: 7, day: 18).date!,
            description: "Cost-effective version of GPT-4o with excellent performance at lower cost",
            contextWindow: 128_000,
            maxOutputTokens: 4096,
            supportedModalities: [.text, .vision],
            capabilities: [.reasoning, .coding, .math, .creative, .analysis, .functionCalling, .jsonMode, .streaming],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 0.15, description: "per 1M tokens"),
                outputTokens: PricingTier(price: 0.60, description: "per 1M tokens")
            ),
            benchmarks: AIBenchmarks(
                coding: 87.9,
                reasoning: 82.3,
                math: 84.7,
                multimodal: 86.2,
                conversational: 89.1,
                speed: 10.2,
                overallScore: 86.7
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.free, .api, .pro, .enterprise],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2023, month: 10).date,
            tags: ["cost-effective", "mini", "affordable"]
        ),

        .init(
            id: "gpt-4-turbo",
            name: "GPT-4 Turbo",
            provider: .openai,
            version: "4-turbo",
            releaseDate: DateComponents(calendar: .current, year: 2024, month: 6, day: 6).date!,
            description: "Enhanced GPT-4 with improved performance and longer context",
            contextWindow: 128_000,
            maxOutputTokens: 4096,
            supportedModalities: [.text, .vision],
            capabilities: [.reasoning, .coding, .math, .science, .creative, .analysis, .functionCalling, .jsonMode, .streaming],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 10.00, description: "per 1M tokens"),
                outputTokens: PricingTier(price: 30.00, description: "per 1M tokens")
            ),
            benchmarks: AIBenchmarks(
                coding: 91.8,
                reasoning: 87.2,
                math: 88.5,
                multimodal: 89.3,
                conversational: 92.1,
                speed: 8.9,
                overallScore: 89.8
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.api, .pro, .enterprise],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2023, month: 12).date,
            tags: ["turbo", "enhanced", "long-context"]
        ),

        .init(
            id: "gpt-4",
            name: "GPT-4",
            provider: .openai,
            version: "4",
            releaseDate: DateComponents(calendar: .current, year: 2023, month: 3, day: 14).date!,
            description: "Original GPT-4 model with excellent reasoning capabilities",
            contextWindow: 8192,
            maxOutputTokens: 4096,
            supportedModalities: [.text],
            capabilities: [.reasoning, .coding, .math, .science, .creative, .analysis, .functionCalling, .jsonMode],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 30.00, description: "per 1M tokens"),
                outputTokens: PricingTier(price: 60.00, description: "per 1M tokens")
            ),
            benchmarks: AIBenchmarks(
                coding: 88.4,
                reasoning: 85.1,
                math: 86.2,
                conversational: 90.5,
                speed: 7.8,
                overallScore: 87.6
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.api, .pro, .enterprise],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2022, month: 9).date,
            tags: ["original", "classic", "reasoning"]
        ),

        .init(
            id: "gpt-3.5-turbo",
            name: "GPT-3.5 Turbo",
            provider: .openai,
            version: "3.5-turbo",
            releaseDate: DateComponents(calendar: .current, year: 2023, month: 11, day: 6).date!,
            description: "Fast and efficient model for most tasks",
            contextWindow: 16384,
            maxOutputTokens: 4096,
            supportedModalities: [.text],
            capabilities: [.reasoning, .coding, .creative, .analysis, .functionCalling, .jsonMode, .streaming],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 0.50, description: "per 1M tokens"),
                outputTokens: PricingTier(price: 1.50, description: "per 1M tokens")
            ),
            benchmarks: AIBenchmarks(
                coding: 82.1,
                reasoning: 78.5,
                math: 79.8,
                conversational: 85.2,
                speed: 9.5,
                overallScore: 83.0
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.free, .api, .pro, .enterprise],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2021, month: 9).date,
            tags: ["fast", "efficient", "budget"]
        ),
        
        // MARK: - Anthropic Claude Models (Current)

        .init(
            id: "claude-3-5-sonnet-20241022",
            name: "Claude 3.5 Sonnet",
            provider: .anthropic,
            version: "3.5",
            releaseDate: DateComponents(calendar: .current, year: 2024, month: 10, day: 22).date!,
            description: "Anthropic's most advanced model with superior coding and reasoning capabilities",
            contextWindow: 200_000,
            maxOutputTokens: 4096,
            supportedModalities: [.text, .vision],
            capabilities: [.reasoning, .coding, .math, .science, .creative, .analysis, .toolUse],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 3.00, description: "per 1M tokens"),
                outputTokens: PricingTier(price: 15.00, description: "per 1M tokens")
            ),
            benchmarks: AIBenchmarks(
                coding: 93.8,
                reasoning: 88.9,
                math: 89.4,
                multimodal: 91.2,
                conversational: 92.3,
                speed: 8.2,
                overallScore: 92.6
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.api, .pro, .enterprise],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2024, month: 4).date,
            tags: ["flagship", "coding", "reasoning", "latest"]
        ),

        .init(
            id: "claude-3-5-haiku-20241022",
            name: "Claude 3.5 Haiku",
            provider: .anthropic,
            version: "3.5-haiku",
            releaseDate: DateComponents(calendar: .current, year: 2024, month: 10, day: 22).date!,
            description: "Fast and cost-effective version of Claude 3.5 with excellent performance",
            contextWindow: 200_000,
            maxOutputTokens: 4096,
            supportedModalities: [.text, .vision],
            capabilities: [.reasoning, .coding, .creative, .analysis, .toolUse],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 0.80, description: "per 1M tokens"),
                outputTokens: PricingTier(price: 4.00, description: "per 1M tokens")
            ),
            benchmarks: AIBenchmarks(
                coding: 88.7,
                reasoning: 85.2,
                math: 86.1,
                multimodal: 87.8,
                conversational: 89.4,
                speed: 9.3,
                overallScore: 87.8
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.free, .api, .pro, .enterprise],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2024, month: 4).date,
            tags: ["fast", "cost-effective", "haiku"]
        ),
        
        // MARK: - Google Gemini Models (Current)

        .init(
            id: "gemini-1.5-pro",
            name: "Gemini 1.5 Pro",
            provider: .google,
            version: "1.5-pro",
            releaseDate: DateComponents(calendar: .current, year: 2024, month: 2, day: 15).date!,
            description: "Google's advanced multimodal model with large context window",
            contextWindow: 1_000_000,
            maxOutputTokens: 8192,
            supportedModalities: [.text, .vision, .audio],
            capabilities: [.reasoning, .coding, .math, .science, .creative, .analysis, .toolUse],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 3.50, description: "per 1M tokens"),
                outputTokens: PricingTier(price: 10.50, description: "per 1M tokens")
            ),
            benchmarks: AIBenchmarks(
                coding: 89.7,
                reasoning: 84.2,
                math: 85.8,
                multimodal: 91.3,
                conversational: 88.1,
                speed: 8.5,
                overallScore: 89.6
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.api, .pro, .enterprise],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2023, month: 12).date,
            tags: ["multimodal", "large-context", "google"]
        ),

        .init(
            id: "gemini-1.5-flash",
            name: "Gemini 1.5 Flash",
            provider: .google,
            version: "1.5-flash",
            releaseDate: DateComponents(calendar: .current, year: 2024, month: 5, day: 24).date!,
            description: "Fast and efficient multimodal model optimized for speed",
            contextWindow: 1_000_000,
            maxOutputTokens: 8192,
            supportedModalities: [.text, .vision, .audio],
            capabilities: [.reasoning, .coding, .creative, .analysis, .toolUse],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 0.35, description: "per 1M tokens"),
                outputTokens: PricingTier(price: 1.05, description: "per 1M tokens")
            ),
            benchmarks: AIBenchmarks(
                coding: 85.1,
                reasoning: 80.8,
                math: 82.4,
                multimodal: 87.2,
                conversational: 86.7,
                speed: 9.8,
                overallScore: 85.3
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.free, .api, .pro, .enterprise],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2023, month: 12).date,
            tags: ["fast", "multimodal", "efficient"]
        ),
        
        // MARK: - Meta Llama Models (Current)

        .init(
            id: "llama-3.2-70b-instruct",
            name: "Llama 3.2 70B Instruct",
            provider: .meta,
            version: "3.2-70b",
            releaseDate: DateComponents(calendar: .current, year: 2024, month: 9, day: 25).date!,
            description: "Meta's most capable Llama model with 70B parameters and strong reasoning",
            contextWindow: 128_000,
            maxOutputTokens: 4096,
            supportedModalities: [.text],
            capabilities: [.reasoning, .coding, .math, .science, .creative, .analysis],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 0.65, description: "per 1M tokens"),
                outputTokens: PricingTier(price: 2.65, description: "per 1M tokens")
            ),
            benchmarks: AIBenchmarks(
                coding: 87.4,
                reasoning: 85.2,
                math: 86.8,
                conversational: 89.1,
                speed: 7.8,
                overallScore: 87.3
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.api, .pro, .enterprise],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2023, month: 12).date,
            tags: ["open-source", "large-model", "reasoning"]
        ),

        .init(
            id: "llama-3.2-3b-instruct",
            name: "Llama 3.2 3B Instruct",
            provider: .meta,
            version: "3.2-3b",
            releaseDate: DateComponents(calendar: .current, year: 2024, month: 9, day: 25).date!,
            description: "Efficient and fast Llama model optimized for edge computing",
            contextWindow: 128_000,
            maxOutputTokens: 4096,
            supportedModalities: [.text],
            capabilities: [.reasoning, .coding, .creative, .analysis],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 0.10, description: "per 1M tokens"),
                outputTokens: PricingTier(price: 0.20, description: "per 1M tokens")
            ),
            benchmarks: AIBenchmarks(
                coding: 78.9,
                reasoning: 76.4,
                math: 74.2,
                conversational: 83.7,
                speed: 9.5,
                overallScore: 79.7
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.free, .api, .pro],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2023, month: 12).date,
            tags: ["open-source", "efficient", "edge"]
        ),

        // MARK: - Groq Models (Fast Inference)

        .init(
            id: "llama-3.1-70b-versatile",
            name: "Llama 3.1 70B Versatile (Groq)",
            provider: .groq,
            version: "3.1-70b",
            releaseDate: DateComponents(calendar: .current, year: 2024, month: 7, day: 23).date!,
            description: "Ultra-fast Llama 3.1 70B hosted on Groq's LPU infrastructure",
            contextWindow: 128_000,
            maxOutputTokens: 8192,
            supportedModalities: [.text],
            capabilities: [.reasoning, .coding, .math, .science, .creative, .analysis],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 0.59, description: "per 1M tokens"),
                outputTokens: PricingTier(price: 0.79, description: "per 1M tokens")
            ),
            benchmarks: AIBenchmarks(
                coding: 88.1,
                reasoning: 86.7,
                math: 87.3,
                conversational: 90.2,
                speed: 10.0,
                overallScore: 88.5
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.api, .pro],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2024, month: 3).date,
            tags: ["fast", "groq", "llama", "inference"]
        ),

        // MARK: - DeepSeek Models

        .init(
            id: "deepseek-chat",
            name: "DeepSeek Chat",
            provider: .deepseek,
            version: "1.0",
            releaseDate: DateComponents(calendar: .current, year: 2024, month: 11, day: 6).date!,
            description: "Advanced reasoning model with strong coding and math capabilities",
            contextWindow: 32_768,
            maxOutputTokens: 4096,
            supportedModalities: [.text, .code],
            capabilities: [.reasoning, .coding, .math, .science, .analysis],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 0.14, description: "per 1M tokens"),
                outputTokens: PricingTier(price: 0.28, description: "per 1M tokens")
            ),
            benchmarks: AIBenchmarks(
                coding: 86.4,
                reasoning: 88.7,
                math: 89.2,
                conversational: 84.1,
                speed: 8.9,
                overallScore: 87.5
            ),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.free, .api, .pro],
                status: .available
            ),
            knowledgeCutoff: DateComponents(calendar: .current, year: 2024, month: 5).date,
            tags: ["reasoning", "math", "coding", "cost-effective"]
        )
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
    
    /// Get latest models (released in 2024)
    static var latest2024: [AIModelConfiguration] {
        let calendar = Calendar.current
        return allModels.filter { model in
            calendar.component(.year, from: model.releaseDate) == 2024
        }.sorted { $0.releaseDate > $1.releaseDate }
    }

    // MARK: - Perplexity Models

    static func perplexityModels() -> [AIModelConfiguration] {
        return [
            .init(
                id: "pplx-70b-online",
                name: "Perplexity 70B Online",
                provider: .perplexity,
                version: "70b-online",
                releaseDate: DateComponents(calendar: .current, year: 2024, month: 8, day: 1).date!,
                description: "Perplexity's 70B model with real-time web search capabilities",
                contextWindow: 128_000,
                maxOutputTokens: 4096,
                supportedModalities: [.text],
                capabilities: [.reasoning, .analysis, .webSearch, .functionCalling],
                pricing: AIPricing(
                    inputTokens: PricingTier(price: 1.00, description: "per 1M tokens"),
                    outputTokens: PricingTier(price: 1.00, description: "per 1M tokens")
                ),
                benchmarks: AIBenchmarks(
                    reasoning: 87.3,
                    conversational: 88.4,
                    speed: 8.7,
                    overallScore: 88.4
                ),
                availability: AIAvailability(
                    regions: ["US", "EU", "Global"],
                    accessTiers: [.free, .api, .pro],
                    status: .available
                ),
                knowledgeCutoff: nil, // Real-time web access
                tags: ["web-search", "real-time", "research"]
            )
        ]
    }

    // MARK: - Mistral Models

    static func mistralModels() -> [AIModelConfiguration] {
        return [
            .init(
                id: "mistral-large-latest",
                name: "Mistral Large",
                provider: .mistral,
                version: "large-latest",
                releaseDate: DateComponents(calendar: .current, year: 2024, month: 9, day: 15).date!,
                description: "Mistral's largest model with excellent multilingual capabilities",
                contextWindow: 128_000,
                maxOutputTokens: 4096,
                supportedModalities: [.text],
                capabilities: [.reasoning, .coding, .translation, .analysis],
                pricing: AIPricing(
                    inputTokens: PricingTier(price: 4.00, description: "per 1M tokens"),
                    outputTokens: PricingTier(price: 12.00, description: "per 1M tokens")
                ),
                benchmarks: AIBenchmarks(
                    coding: 85.7,
                    reasoning: 86.2,
                    math: 83.9,
                    conversational: 91.3,
                    speed: 8.9,
                    overallScore: 87.2
                ),
                availability: AIAvailability(
                    regions: ["US", "EU", "Global"],
                    accessTiers: [.api, .pro, .enterprise],
                    status: .available
                ),
                knowledgeCutoff: DateComponents(calendar: .current, year: 2024, month: 3).date,
                tags: ["multilingual", "large-context", "mistral"]
            )
        ]
    }
}