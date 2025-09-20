import SwiftUI

/// Vista per selezionare il modello AI da usare per la categorizzazione delle email
struct ModelPickerForCategorizationView: View {
    @Binding var selectedModel: AIModelConfiguration?

    @State private var availableModels: [AIModelConfiguration] = []
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Caricamento modelli...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let error = error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Errore caricamento: \(error.localizedDescription)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Picker("Modello per categorizzazione", selection: $selectedModel) {
                    Text("Seleziona modello...")
                        .tag(AIModelConfiguration?.none)

                    ForEach(availableModels, id: \.id) { model in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(model.name)
                                    .font(.body)
                                Spacer()
                                Text("$\(model.pricing.inputTokens.price)")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(4)
                            }

                            HStack(spacing: 12) {
                                Text(model.provider.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("📏 \(model.contextWindow / 1000)K ctx")
                                    .font(.caption2)
                                    .foregroundColor(.orange)

                                if model.capabilities.contains(.reasoning) {
                                    Text("🧠")
                                        .font(.caption2)
                                }
                                if model.capabilities.contains(.coding) {
                                    Text("💻")
                                        .font(.caption2)
                                }
                            }
                        }
                        .tag(model as AIModelConfiguration?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: selectedModel) { newModel in
                    if let model = newModel {
                        // Salva la selezione nel servizio di categorizzazione
                        EmailCategorizationService().setSelectedModel(model)
                        print("📧 Modello categorizzazione selezionato: \(model.name) (\(model.provider.displayName))")
                    }
                }
            }
        }
        .onAppear {
            loadAvailableModels()
        }
    }

    private func loadAvailableModels() {
        isLoading = true
        error = nil

        Task {
            // Carica TUTTI i modelli disponibili dinamicamente dal web
            await ModelCatalog.shared.fetchAllModels(forceRefresh: true)

            // 1. Mappa i modelli dinamici in AIModelConfiguration
            let dynamicModels = ModelCatalog.shared.allModels().map { modelInfo -> AIModelConfiguration in
                let detectedProvider = detectProvider(for: modelInfo.name)
                let estimatedPricing = estimatePricing(for: detectedProvider, modelName: modelInfo.name)
                return AIModelConfiguration(
                    id: modelInfo.name.lowercased().replacingOccurrences(of: " ", with: "-"),
                    name: modelInfo.name,
                    provider: detectedProvider,
                    version: "dynamic",
                    releaseDate: Date(),
                    description: modelInfo.description,
                    contextWindow: modelInfo.contextTokens,
                    maxOutputTokens: 4096,
                    supportedModalities: [.text],
                    capabilities: [.reasoning],
                    pricing: estimatedPricing,
                    benchmarks: AIBenchmarks(),
                    availability: AIAvailability(
                        regions: ["Global"],
                        accessTiers: [.free, .api, .pro],
                        status: .available
                    ),
                    knowledgeCutoff: nil,
                    isExperimental: false,
                    requiresSpecialAccess: false,
                    tags: ["email-categorization", "dynamic"]
                )
            }

            // 2. Combina modelli statici e dinamici rimuovendo duplicati
            let staticModels = AIModelConfiguration.allModels
            let uniqueDynamicModels = dynamicModels.filter { dynamic in
                !staticModels.contains { staticModel in staticModel.id == dynamic.id }
            }
            let allModelsCombined = staticModels + uniqueDynamicModels

            // 3. Filtra i modelli adatti
            let filteredModels = allModelsCombined.filter { model in
                model.capabilities.contains(.reasoning) &&
                !model.isExperimental &&
                model.availability.status == .available
            }

            // 4. Ordina i modelli per prezzo e performance
            let sortedModels = filteredModels.sorted { (model1, model2) -> Bool in
                let price1 = model1.pricing.inputTokens.price
                let price2 = model2.pricing.inputTokens.price
                if price1 != price2 {
                    return price1 < price2
                }
                return (model1.benchmarks.overallScore ?? 0) > (model2.benchmarks.overallScore ?? 0)
            }

            await MainActor.run {
                self.availableModels = sortedModels
                self.isLoading = false

                // Se non è selezionato nessun modello, seleziona il più economico disponibile
                if self.selectedModel == nil, let cheapestModel = sortedModels.first {
                    self.selectedModel = cheapestModel
                    EmailCategorizationService().setSelectedModel(cheapestModel)
                }
            }
        }
    }

    // MARK: - Private Methods

    private func detectProvider(for modelName: String) -> AIModelProvider {
        let lowerName = modelName.lowercased()

        // Rilevamento provider basato sul nome del modello
        if lowerName.contains("foundation") || lowerName.contains("apple") {
            return .apple
        } else if lowerName.contains("gpt") || lowerName.contains("openai") {
            return .openai
        } else if lowerName.contains("claude") || lowerName.contains("anthropic") {
            return .anthropic
        } else if lowerName.contains("llama") || lowerName.contains("groq") || lowerName.contains("mixtral") {
            return .groq
        } else if lowerName.contains("deepseek") {
            return .deepseek
        } else if lowerName.contains("mistral") {
            return .mistral
        } else if lowerName.contains("sonar") || lowerName.contains("perplexity") {
            return .perplexity
        } else if lowerName.contains("gemini") || lowerName.contains("google") {
            return .google
        } else if lowerName.contains("grok") || lowerName.contains("xai") {
            return .xai
        } else {
            return .groq // Default fallback
        }
    }

    private func estimatePricing(for provider: AIModelProvider, modelName: String) -> AIPricing {
        let lowerName = modelName.lowercased()

        switch provider {
        case .apple:
            return AIPricing(
                inputTokens: PricingTier(price: 0, description: "On-device"),
                outputTokens: PricingTier(price: 0, description: "On-device"),
                currency: "USD",
                billingUnit: "on-device"
            )

        case .openai:
            if lowerName.contains("gpt-4o-mini") {
                return AIPricing(
                    inputTokens: PricingTier(price: 0.15, description: "per 1M tokens"),
                    outputTokens: PricingTier(price: 0.60, description: "per 1M tokens")
                )
            } else {
                return AIPricing(
                    inputTokens: PricingTier(price: 2.50, description: "per 1M tokens"),
                    outputTokens: PricingTier(price: 10.00, description: "per 1M tokens")
                )
            }

        case .anthropic:
            if lowerName.contains("haiku") {
                return AIPricing(
                    inputTokens: PricingTier(price: 0.80, description: "per 1M tokens"),
                    outputTokens: PricingTier(price: 4.00, description: "per 1M tokens")
                )
            } else {
                return AIPricing(
                    inputTokens: PricingTier(price: 3.00, description: "per 1M tokens"),
                    outputTokens: PricingTier(price: 15.00, description: "per 1M tokens")
                )
            }

        case .groq:
            if lowerName.contains("llama-3.1-8b") {
                return AIPricing(
                    inputTokens: PricingTier(price: 0.05, description: "per 1M tokens"),
                    outputTokens: PricingTier(price: 0.08, description: "per 1M tokens")
                )
            } else if lowerName.contains("70b") || lowerName.contains("405b") {
                return AIPricing(
                    inputTokens: PricingTier(price: 0.59, description: "per 1M tokens"),
                    outputTokens: PricingTier(price: 0.79, description: "per 1M tokens")
                )
            } else {
                return AIPricing(
                    inputTokens: PricingTier(price: 0.10, description: "per 1M tokens"),
                    outputTokens: PricingTier(price: 0.20, description: "per 1M tokens")
                )
            }

        case .deepseek:
            return AIPricing(
                inputTokens: PricingTier(price: 0.14, description: "per 1M tokens"),
                outputTokens: PricingTier(price: 0.28, description: "per 1M tokens")
            )

        case .mistral:
            if lowerName.contains("small") {
                return AIPricing(
                    inputTokens: PricingTier(price: 0.10, description: "per 1M tokens"),
                    outputTokens: PricingTier(price: 0.30, description: "per 1M tokens")
                )
            } else {
                return AIPricing(
                    inputTokens: PricingTier(price: 2.00, description: "per 1M tokens"),
                    outputTokens: PricingTier(price: 6.00, description: "per 1M tokens")
                )
            }

        default:
            return AIPricing(
                inputTokens: PricingTier(price: 0.50, description: "per 1M tokens"),
                outputTokens: PricingTier(price: 1.50, description: "per 1M tokens")
            )
        }
    }
}

#Preview {
    ModelPickerForCategorizationView(selectedModel: .constant(nil))
}
