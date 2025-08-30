import Foundation

struct OpenAIModels {
    // Current known families (keep existing names to avoid regressions)
    static let gpt4Series: [String] = [
        "gpt-4o",
        "gpt-4o-mini",
        "chatgpt-4o-latest",
        "gpt-4.1",
        "gpt-4.1-mini",
        "gpt-4.1-nano",
        "gpt-4.5-preview",
        "gpt-4-turbo",
        "gpt-3.5-turbo"
    ]

    // Reasoning/o-series (kept for compatibility)
    static let oSeries: [String] = [
        "o3",
        "o3-pro",
        "o3-deep-research",
        "o3-mini",
        "o4-mini",
        "o4-mini-deep-research"
    ]

    // GPT-5 family
    static let gpt5Series: [String] = [
        "gpt-5",
        "gpt-5-mini",
        "gpt-5-nano"
    ]

    static var availableModels: [String] {
        // Merge and keep unique order
        var seen = Set<String>()
        let merged = gpt5Series + gpt4Series + oSeries + ["gpt-realtime", "gpt-audio", "gpt-image-1", "text-embedding-3-large", "text-embedding-3-small"]
        return merged.filter { seen.insert($0).inserted }
    }
}

