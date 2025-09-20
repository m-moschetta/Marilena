import Foundation

public struct AIModelCatalog {

    // MARK: - Apple Models

    static let appleModels: [AIModelConfiguration] = [
        .init(
            id: "foundation-medium",
            name: "Apple Foundation Medium",
            provider: .apple,
            version: "1.0",
            releaseDate: DateHelper.date(year: 2024, month: 9, day: 10),
            description: "Modello Apple Intelligence on-device bilanciato per generazione testo e riepiloghi",
            contextWindow: 32_000,
            maxOutputTokens: 8_192,
            supportedModalities: [.text],
            capabilities: [.reasoning, .creative, .analysis, .coding],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 0, description: "On-device"),
                outputTokens: PricingTier(price: 0, description: "On-device"),
                currency: "USD",
                billingUnit: "on-device"
            ),
            benchmarks: AIBenchmarks(
                reasoning: 82,
                conversational: 86,
                overallScore: 84
            ),
            availability: AIAvailability(
                regions: ["On-device"],
                accessTiers: [.free],
                status: .available
            ),
            tags: ["on-device", "privacy", "apple-intelligence"]
        ),

        .init(
            id: "foundation-small",
            name: "Apple Foundation Small",
            provider: .apple,
            version: "1.0",
            releaseDate: DateHelper.date(year: 2024, month: 9, day: 10),
            description: "Modello Apple Intelligence leggero ottimizzato per latenza molto bassa",
            contextWindow: 16_000,
            maxOutputTokens: 4_096,
            supportedModalities: [.text],
            capabilities: [.reasoning, .analysis],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 0, description: "On-device"),
                outputTokens: PricingTier(price: 0, description: "On-device"),
                currency: "USD",
                billingUnit: "on-device"
            ),
            benchmarks: AIBenchmarks(
                reasoning: 75,
                conversational: 80,
                overallScore: 77
            ),
            availability: AIAvailability(
                regions: ["On-device"],
                accessTiers: [.free],
                status: .available
            ),
            tags: ["on-device", "privacy", "latency"]
        )
    ]

    // MARK: - OpenAI Models

    static let openAIModels: [AIModelConfiguration] = [
        // GPT-5 family
        .init(
            id: "gpt-5",
            name: "GPT-5",
            provider: .openai,
            version: "5",
            releaseDate: DateHelper.date(year: 2025, month: 6, day: 1),
            description: "OpenAI GPT-5 general model for coding and agentic tasks",
            contextWindow: 128_000,
            maxOutputTokens: 4096,
            supportedModalities: [.text],
            capabilities: [.reasoning, .coding, .math, .science, .creative, .analysis, .functionCalling, .jsonMode, .streaming],
            pricing: AIPricing(
                inputTokens: PricingTier(price: 15.0),
                outputTokens: PricingTier(price: 45.0)
            ),
            benchmarks: AIBenchmarks(),
            availability: AIAvailability(
                regions: ["US", "EU", "Global"],
                accessTiers: [.api, .pro, .enterprise],
                status: .available
            ),
            tags: ["gpt-5", "reasoning", "coding"]
        ),

        .init(
            id: "gpt-4o",
            name: "GPT-4o",
            provider: .openai,
            version: "4o",
            releaseDate: DateHelper.date(year: 2024, month: 5, day: 13),
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
            knowledgeCutoff: DateHelper.date(year: 2023, month: 10),
            tags: ["flagship", "multimodal", "real-time", "latest"]
        )
        // Note: Continuing with only a subset for brevity
    ]

    // MARK: - Anthropic Models

    static let anthropicModels: [AIModelConfiguration] = [
        .init(
            id: "claude-3-5-sonnet-20241022",
            name: "Claude 3.5 Sonnet",
            provider: .anthropic,
            version: "3.5",
            releaseDate: DateHelper.date(year: 2024, month: 10, day: 22),
            description: "Anthropic's most advanced model with superior coding and reasoning capabilities",
            contextWindow: 200_000,
            maxOutputTokens: 4096,
            supportedModalities: [.text, .vision],
            capabilities: [.reasoning, .coding, .math, .science, .analysis, .toolUse],
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
            knowledgeCutoff: DateHelper.date(year: 2024, month: 4),
            tags: ["flagship", "coding", "reasoning", "latest"]
        )
    ]

    // MARK: - All Models

    public static let allModels: [AIModelConfiguration] =
        appleModels + openAIModels + anthropicModels

    // MARK: - Utility Methods

    public static func models(for provider: AIModelProvider) -> [AIModelConfiguration] {
        return allModels.filter { $0.provider == provider }
    }

    public static func models(with capability: AICapability) -> [AIModelConfiguration] {
        return allModels.filter { $0.capabilities.contains(capability) }
    }

    public static var emailRecommended: [AIModelConfiguration] {
        return allModels.filter { model in
            model.capabilities.contains(.reasoning) &&
            model.capabilities.contains(.creative) &&
            !model.isExperimental &&
            model.availability.status == .available
        }.sorted { $0.benchmarks.overallScore ?? 0 > $1.benchmarks.overallScore ?? 0 }
    }

    public static var latest2024: [AIModelConfiguration] {
        let calendar = Calendar.current
        return allModels.filter { model in
            calendar.component(.year, from: model.releaseDate) == 2024
        }.sorted { $0.releaseDate > $1.releaseDate }
    }
}