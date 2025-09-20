import SwiftUI

// MARK: - Model Picker View

/// Vista riutilizzabile per selezionare modelli AI dinamicamente
@MainActor
struct ModelPickerView: View {
    let provider: AIModelProvider
    @Binding var selectedModel: String
    @StateObject private var modelCatalog = ModelCatalog.shared

    var body: some View {
        VStack(spacing: 12) {
            // Header con stato caricamento
            HStack {
                Text("Modelli \(provider.displayName)")
                    .font(.headline)

                Spacer()

                if modelCatalog.isLoading[provider] ?? false {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else if modelCatalog.errors[provider] != nil {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                } else {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                }
            }

            // Picker dei modelli
            if modelCatalog.models(for: provider).isEmpty {
                // Nessun modello disponibile
                HStack {
                    Text("Nessun modello disponibile")
                        .foregroundColor(.secondary)
                        .font(.caption)

                    Spacer()

                    Button(action: {
                        Task {
                            await modelCatalog.fetchModels(for: provider, forceRefresh: true)
                        }
                    }) {
                        Label("Aggiorna", systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 8)
            } else {
                // Picker con modelli disponibili
                Picker("Seleziona Modello", selection: $selectedModel) {
                    ForEach(modelCatalog.models(for: provider), id: \.name) { modelInfo in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(getDisplayName(for: modelInfo))
                                .font(.body)

                            if !modelInfo.description.isEmpty {
                                Text(modelInfo.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            // Badge per stato disponibilità
                            if !modelInfo.supportsStreaming {
                                Text("Non disponibile")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                        .tag(modelInfo.name)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedModel) {
                    // Salva automaticamente la selezione solo se valida
                    let availableModels = modelCatalog.models(for: provider)
                    if availableModels.contains(where: { $0.name == selectedModel }) {
                        saveSelectedModel(selectedModel, for: provider)
                    }
                }
                .onChange(of: modelCatalog.availableModels[provider]) { newModels in
                    // Quando i modelli vengono aggiornati, verifica se la selezione corrente è valida
                    if let models = newModels, !models.isEmpty {
                        let isCurrentSelectionValid = models.contains { $0.name == selectedModel }
                        if !isCurrentSelectionValid {
                            // Seleziona automaticamente il primo modello disponibile
                            selectedModel = models.first!.name
                            saveSelectedModel(selectedModel, for: provider)
                        }
                    }
                }

                // Pulsanti specifici per provider con endpoint dinamici non standard
                if provider == .groq {
                    HStack {
                        Spacer()

                        Button(action: {
                            Task {
                                await modelCatalog.fetchModels(for: .groq, forceRefresh: true)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .foregroundColor(.purple)
                                Text("Aggiorna Groq")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.purple)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.top, 8)
                } else if provider == .xai {
                    HStack {
                        Spacer()

                        Button(action: {
                            Task {
                                await modelCatalog.fetchModels(for: .xai, forceRefresh: true)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .foregroundColor(.indigo)
                                Text("Aggiorna xAI")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.indigo)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.indigo.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.indigo.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.top, 8)
                }
            }

            // Informazioni aggiuntive
            if let lastUpdate = modelCatalog.lastUpdate[provider] {
                HStack {
                    Text("Ultimo aggiornamento:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(formatDate(lastUpdate))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Aggiorna") {
                        Task {
                            await modelCatalog.fetchModels(for: provider, forceRefresh: true)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 8)
        .task {
            // Carica modelli all'avvio se non sono già disponibili
            if modelCatalog.models(for: provider).isEmpty {
                await modelCatalog.fetchModels(for: provider)
            }
        }
    }

    // MARK: - Private Methods

    private func getDisplayName(for modelInfo: AIModelInfo) -> String {
        // Usa il nome dal modello o formatta il nome se necessario
        if modelInfo.name.isEmpty {
            return "Modello senza nome"
        }
        return modelInfo.name
    }

    private func formatModelName(_ modelId: String) -> String {
        // Formatta nomi dei modelli per una migliore leggibilità
        switch provider {
        case .openai:
            return formatOpenAIModelName(modelId)
        case .anthropic:
            return formatAnthropicModelName(modelId)
        case .groq:
            return formatGroqModelName(modelId)
        case .mistral:
            return formatMistralModelName(modelId)
        default:
            return modelId.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }

    private func formatOpenAIModelName(_ modelId: String) -> String {
        if modelId.contains("gpt-5") {
            if modelId.contains("mini") { return "GPT-5 Mini" }
            if modelId.contains("nano") { return "GPT-5 Nano" }
            return "GPT-5"
        } else if modelId.contains("gpt-4o") {
            if modelId.contains("mini") { return "GPT-4o Mini" }
            return "GPT-4o"
        } else if modelId.contains("gpt-4") {
            if modelId.contains("turbo") { return "GPT-4 Turbo" }
            return "GPT-4"
        } else if modelId.contains("o3") || modelId.contains("o4") {
            return modelId.uppercased().replacingOccurrences(of: "-", with: " ")
        }
        return modelId.replacingOccurrences(of: "-", with: " ").capitalized
    }

    private func formatAnthropicModelName(_ modelId: String) -> String {
        if modelId.contains("claude-3-5-sonnet") { return "Claude 3.5 Sonnet" }
        if modelId.contains("claude-3-5-haiku") { return "Claude 3.5 Haiku" }
        if modelId.contains("claude-3-sonnet") { return "Claude 3 Sonnet" }
        if modelId.contains("claude-3-haiku") { return "Claude 3 Haiku" }
        if modelId.contains("claude-3-opus") { return "Claude 3 Opus" }
        return modelId.replacingOccurrences(of: "-", with: " ").capitalized
    }

    private func formatGroqModelName(_ modelId: String) -> String {
        if modelId.contains("deepseek-r1-distill") {
            let parts = modelId.split(separator: "-")
            if parts.count >= 4 {
                let model = String(parts[4])
                let size = parts.count > 4 ? String(parts[5]) : ""
                return "DeepSeek R1 \(model.capitalized) \(size)"
            }
            return "DeepSeek R1 Distill"
        } else if modelId.contains("llama-3") {
            return "Llama 3 \(modelId.split(separator: "-").last?.capitalized ?? "")"
        } else if modelId.contains("qwen") {
            return "Qwen \(modelId.split(separator: "-").last?.capitalized ?? "")"
        } else if modelId.contains("mixtral") {
            return "Mixtral 8x7B"
        } else if modelId.contains("gemma") {
            return "Gemma \(modelId.split(separator: "-").last?.capitalized ?? "")"
        }
        return modelId.replacingOccurrences(of: "-", with: " ").capitalized
    }

    private func formatMistralModelName(_ modelId: String) -> String {
        if modelId.contains("mistral-large") { return "Mistral Large" }
        if modelId.contains("mistral-medium") { return "Mistral Medium" }
        if modelId.contains("mistral-small") { return "Mistral Small" }
        return modelId.replacingOccurrences(of: "-", with: " ").capitalized
    }

    private func saveSelectedModel(_ modelId: String, for provider: AIModelProvider) {
        let key: String
        switch provider {
        case .apple: key = "selectedAppleModel"
        case .openai:
            key = "selected_model"
            UserDefaults.standard.set(modelId, forKey: "selectedChatModel")
        case .anthropic: key = "selectedAnthropicModel"
        case .groq: key = "selectedGroqChatModel"
        case .mistral: key = "selectedMistralModel"
        case .perplexity: key = "selected_perplexity_model"
        default: return
        }

        UserDefaults.standard.set(modelId, forKey: key)
        UserDefaults.standard.synchronize()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
}

// MARK: - Preview

struct ModelPickerView_Previews: PreviewProvider {
    static var previews: some View {
        Form {
            ModelPickerView(provider: .openai, selectedModel: .constant("gpt-4o"))
            ModelPickerView(provider: .anthropic, selectedModel: .constant("claude-3-5-sonnet-20241022"))
            ModelPickerView(provider: .groq, selectedModel: .constant("deepseek-r1-distill-qwen-32b"))
        }
        .padding()
    }
}
