import SwiftUI

// MARK: - Email Settings View
// Vista per le impostazioni email con accesso ai prompt OpenAI

struct EmailSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var emailService = EmailService()
    @StateObject private var aiService = EmailAIService()
    
    @State private var selectedAIModel = "gpt-4o-mini"
    @State private var maxTokens: Double = 1000
    @State private var temperature: Double = 0.7
    @State private var showingPromptEditor = false
    @State private var selectedPromptType: EmailPromptType = .draft
    @State private var customPrompt = ""
    
    let availableModels = [
        "gpt-4o", "gpt-4o-mini", "gpt-4.1", "gpt-4.1-mini",
        "claude-3-5-sonnet-20241022", "claude-3-7-sonnet-20250219"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Account Section
                Section("Account Email") {
                    if let account = emailService.currentAccount {
                        HStack {
                            Image(systemName: account.provider.iconName)
                                .foregroundColor(.orange)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.email)
                                    .font(.headline)
                                Text("Account connesso")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Disconnetti") {
                                emailService.disconnect()
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                        }
                    } else {
                        HStack {
                            Image(systemName: "envelope.badge")
                                .foregroundColor(.gray)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Nessun account connesso")
                                    .font(.headline)
                                Text("Connetti un account per iniziare")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Connetti") {
                                // TODO: Implementare connessione
                            }
                            .foregroundColor(.blue)
                            .font(.caption)
                        }
                    }
                }
                
                // MARK: - AI Configuration Section
                Section("Configurazione AI") {
                    Picker("Modello AI", selection: $selectedAIModel) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    
                    VStack {
                        HStack {
                            Text("Temperature")
                            Spacer()
                            Text(String(format: "%.1f", temperature))
                        }
                        Slider(value: $temperature, in: 0...2, step: 0.1)
                    }
                    
                    VStack {
                        HStack {
                            Text("Max Tokens")
                            Spacer()
                            Text(String(format: "%.0f", maxTokens))
                        }
                        Slider(value: $maxTokens, in: 100...4000, step: 100)
                    }
                }
                
                // MARK: - Prompt Management Section
                Section("Gestione Prompt") {
                    ForEach(EmailPromptType.allCases, id: \.self) { promptType in
                        Button {
                            selectedPromptType = promptType
                            customPrompt = getCurrentPrompt(for: promptType)
                            showingPromptEditor = true
                        } label: {
                            HStack {
                                Image(systemName: promptType.iconName)
                                    .foregroundColor(promptType.color)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(promptType.displayName)
                                        .font(.headline)
                                    Text(promptType.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // MARK: - Email Features Section
                Section("Funzionalità Email") {
                    NavigationLink {
                        EmailFeaturesView()
                    } label: {
                        Label("Funzionalità Avanzate", systemImage: "gear")
                    }
                    
                    NavigationLink {
                        EmailTemplatesView()
                    } label: {
                        Label("Template Email", systemImage: "doc.text")
                    }
                    
                    NavigationLink {
                        EmailFiltersView()
                    } label: {
                        Label("Filtri e Categorizzazione", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                
                // MARK: - Privacy Section
                Section("Privacy e Sicurezza") {
                    NavigationLink {
                        EmailPrivacyView()
                    } label: {
                        Label("Impostazioni Privacy", systemImage: "lock.shield")
                    }
                    
                    NavigationLink {
                        EmailDataView()
                    } label: {
                        Label("Gestione Dati", systemImage: "externaldrive")
                    }
                }
            }
            .navigationTitle("Impostazioni Mail")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        saveSettings()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingPromptEditor) {
            PromptEditorView(
                promptType: selectedPromptType,
                prompt: $customPrompt
            )
        }
        .onAppear {
            loadSettings()
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadSettings() {
        selectedAIModel = UserDefaults.standard.string(forKey: "email_ai_model") ?? "gpt-4o-mini"
        temperature = UserDefaults.standard.double(forKey: "email_ai_temperature")
        if temperature == 0 { temperature = 0.7 }
        maxTokens = UserDefaults.standard.double(forKey: "email_ai_max_tokens")
        if maxTokens == 0 { maxTokens = 1000 }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(selectedAIModel, forKey: "email_ai_model")
        UserDefaults.standard.set(temperature, forKey: "email_ai_temperature")
        UserDefaults.standard.set(maxTokens, forKey: "email_ai_max_tokens")
        
        // Salva il prompt personalizzato se modificato
        if !customPrompt.isEmpty {
            UserDefaults.standard.set(customPrompt, forKey: "email_prompt_\(selectedPromptType.rawValue)")
        }
        
        UserDefaults.standard.synchronize()
        dismiss()
    }
    
    private func getCurrentPrompt(for type: EmailPromptType) -> String {
        return UserDefaults.standard.string(forKey: "email_prompt_\(type.rawValue)") ?? type.defaultPrompt
    }
}

// MARK: - Email Prompt Types

enum EmailPromptType: String, CaseIterable {
    case draft = "draft"
    case analysis = "analysis"
    case summary = "summary"
    case categorization = "categorization"
    case urgency = "urgency"
    
    var displayName: String {
        switch self {
        case .draft:
            return "Generazione Bozze"
        case .analysis:
            return "Analisi Email"
        case .summary:
            return "Riassunto Email"
        case .categorization:
            return "Categorizzazione"
        case .urgency:
            return "Valutazione Urgenza"
        }
    }
    
    var description: String {
        switch self {
        case .draft:
            return "Personalizza il prompt per la generazione di bozze di risposta"
        case .analysis:
            return "Personalizza l'analisi del tono e contenuto"
        case .summary:
            return "Personalizza la creazione di riassunti"
        case .categorization:
            return "Personalizza la categorizzazione automatica"
        case .urgency:
            return "Personalizza la valutazione dell'urgenza"
        }
    }
    
    var iconName: String {
        switch self {
        case .draft:
            return "pencil.and.outline"
        case .analysis:
            return "chart.bar.doc.horizontal"
        case .summary:
            return "text.quote"
        case .categorization:
            return "tag"
        case .urgency:
            return "exclamationmark.triangle"
        }
    }
    
    var color: Color {
        switch self {
        case .draft:
            return .blue
        case .analysis:
            return .purple
        case .summary:
            return .green
        case .categorization:
            return .orange
        case .urgency:
            return .red
        }
    }
    
    var defaultPrompt: String {
        switch self {
        case .draft:
            return PromptManager.emailDraftPrompt
        case .analysis:
            return PromptManager.emailAnalysisPrompt
        case .summary:
            return PromptManager.emailSummaryPrompt
        case .categorization:
            return PromptManager.emailCategorizationPrompt
        case .urgency:
            return PromptManager.emailUrgencyPrompt
        }
    }
}

// MARK: - Prompt Editor View

struct PromptEditorView: View {
    let promptType: EmailPromptType
    @Binding var prompt: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(promptType.displayName)
                        .font(.headline)
                    Text(promptType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Editor
                TextEditor(text: $prompt)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            .navigationTitle("Editor Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        UserDefaults.standard.set(prompt, forKey: "email_prompt_\(promptType.rawValue)")
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Placeholder Views

struct EmailFeaturesView: View {
    var body: some View {
        Text("Funzionalità Avanzate Email")
            .navigationTitle("Funzionalità")
    }
}

struct EmailTemplatesView: View {
    var body: some View {
        Text("Template Email")
            .navigationTitle("Template")
    }
}

struct EmailFiltersView: View {
    var body: some View {
        Text("Filtri Email")
            .navigationTitle("Filtri")
    }
}

struct EmailPrivacyView: View {
    var body: some View {
        Text("Privacy Email")
            .navigationTitle("Privacy")
    }
}

struct EmailDataView: View {
    var body: some View {
        Text("Gestione Dati Email")
            .navigationTitle("Dati")
    }
} 