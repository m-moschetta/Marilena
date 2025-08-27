import Foundation

// MARK: - Test per i Modelli Anthropic Aggiornati 2025
// Questo file può essere usato per testare rapidamente i nuovi modelli

class AnthropicModelsTest {
    
    static func testAllModels() {
        let models = AnthropicService.claudeModels
        
        print("🚀 Testing Anthropic Models 2025:")
        print("=====================================")
        
        for model in models {
            if let info = AnthropicService.shared.getModelInfo(model: model) {
                print("✅ \(model)")
                print("   Name: \(info.name)")
                print("   Description: \(info.description)")
                print("   Context: \(info.contextTokens) tokens")
                print("   Streaming: \(info.supportsStreaming)")
                print("")
            }
        }
        
        print("🎯 Recommended Models:")
        print("• claude-4-opus: Per compiti complessi e ragionamento avanzato")
        print("• claude-4-sonnet: Per applicazioni di produzione (CONSIGLIATO)")
        print("• claude-3-7-sonnet: Per hybrid reasoning e pensiero esteso")
        print("• claude-3-5-sonnet: Per uso generale bilanciato")
        print("• claude-3-5-haiku: Per velocità e costi ridotti")
        
        print("\n💰 Pricing (per 1M tokens):")
        print("• claude-4-opus: $15 input / $75 output")
        print("• claude-4-sonnet: $3 input / $15 output")
        print("• claude-3-7-sonnet: $6 input / $22.5 output")
        print("• claude-3-5-sonnet: $3 input / $15 output")
        print("• claude-3-5-haiku: $0.25 input / $1.25 output")
    }
    
    static func getRecommendedModel(for useCase: String) -> String {
        switch useCase.lowercased() {
        case "coding", "development", "complex":
            return "claude-4-opus"
        case "production", "general", "balanced":
            return "claude-4-sonnet"
        case "reasoning", "analysis", "thinking":
            return "claude-3-7-sonnet"
        case "fast", "quick", "simple":
            return "claude-3-5-haiku"
        default:
            return "claude-4-sonnet" // Default più sicuro per produzione
        }
    }
    
    static func validateModelName(_ model: String) -> Bool {
        return AnthropicService.claudeModels.contains(model)
    }
}

// MARK: - Usage Example
/*
 // Per testare tutti i modelli:
 AnthropicModelsTest.testAllModels()
 
 // Per ottenere un modello raccomandato:
 let model = AnthropicModelsTest.getRecommendedModel(for: "coding")
 
 // Per validare un nome di modello:
 let isValid = AnthropicModelsTest.validateModelName("claude-4-sonnet")
 */