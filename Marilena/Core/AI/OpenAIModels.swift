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
        "o1",
        "o1-mini",
        "o3-mini"
    ]

    // Placeholder GPT-5 variants (to be verified against official docs when available)
    static let gpt5SeriesPlaceholders: [String] = [
        "gpt-5",
        "gpt-5-mini",
        "gpt-5o",
        "gpt-5.1",
        "gpt-5.1-mini"
    ]

    static var availableModels: [String] {
        // Merge and keep unique order
        var seen = Set<String>()
        let merged = gpt5SeriesPlaceholders + gpt4Series + oSeries
        return merged.filter { seen.insert($0).inserted }
    }
}

