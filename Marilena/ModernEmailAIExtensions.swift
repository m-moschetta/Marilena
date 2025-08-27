import SwiftUI

// MARK: - Email Analysis Extensions
/// Estensioni per supportare l'analisi AI nel ModernEmailViewer

// MARK: - Email Priority Extension
extension EmailPriority {
    var displayName: String {
        switch self {
        case .low: return "Bassa"
        case .normal: return "Normale"
        case .high: return "Alta"
        case .urgent: return "Urgente"
        }
    }
    
    var iconName: String {
        switch self {
        case .low: return "arrow.down.circle.fill"
        case .normal: return "minus.circle.fill"
        case .high: return "arrow.up.circle.fill"
        case .urgent: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .blue
        case .normal: return .gray
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

// MARK: - Email Category Extension
// Tutte le proprietà (displayName, icon, color) sono già definite in SharedTypes.swift

// MARK: - Email Sentiment Extension
extension EmailSentiment {
    var displayName: String {
        switch self {
        case .positive: return "Positivo"
        case .neutral: return "Neutrale"
        case .negative: return "Negativo"
        case .urgent: return "Urgente"
        case .friendly: return "Amichevole"
        case .formal: return "Formale"
        }
    }
    
    var iconName: String {
        switch self {
        case .positive: return "face.smiling.fill"
        case .neutral: return "face.dashed.fill"
        case .negative: return "face.frowning.fill"
        case .urgent: return "exclamationmark.triangle.fill"
        case .friendly: return "heart.fill"
        case .formal: return "doc.text.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .positive: return .green
        case .neutral: return .gray
        case .negative: return .red
        case .urgent: return .orange
        case .friendly: return .pink
        case .formal: return .blue
        }
    }
}

// MARK: - Modern AI Compose Assistant
struct ModernAIComposeAssistant: View {
    @Binding var emailBody: String
    @Binding var subject: String
    @ObservedObject var aiService: EmailAIService
    let recipientEmail: String
    let isReply: Bool
    let originalEmail: EmailMessage?
    
    @State private var showingAIPanel = false
    @State private var selectedTone: EmailTone = .professional
    @State private var selectedLength: EmailLength = .medium
    @State private var customPrompt = ""
    @State private var isGenerating = false
    @State private var suggestions: [String] = []
    @State private var showingSuggestions = false
    
    var body: some View {
        VStack(spacing: 0) {
            // AI Assistant Header
            aiAssistantHeader
            
            if showingAIPanel {
                VStack(spacing: 16) {
                    // Tone and Length Selection
                    toneAndLengthSelector
                    
                    // Quick Actions
                    quickActionsGrid
                    
                    // Suggestions
                    if showingSuggestions && !suggestions.isEmpty {
                        suggestionsView
                    }
                    
                    // Custom prompt
                    customPromptSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .background(Color(UIColor.secondarySystemBackground))
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingAIPanel)
    }
    
    // MARK: - AI Assistant Header
    private var aiAssistantHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(.purple)
                    .font(.system(size: 16, weight: .medium))
                
                Text("Assistente Composizione AI")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                
                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            
            Spacer()
            
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingAIPanel.toggle()
                }
            } label: {
                Image(systemName: showingAIPanel ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.purple)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Tone and Length Selector
    private var toneAndLengthSelector: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Stile e Lunghezza")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Tone
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tono")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Picker("Tono", selection: $selectedTone) {
                        ForEach(EmailTone.allCases, id: \.self) { tone in
                            Text(tone.displayName).tag(tone)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Length
                VStack(alignment: .leading, spacing: 8) {
                    Text("Lunghezza")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Picker("Lunghezza", selection: $selectedLength) {
                        ForEach(EmailLength.allCases, id: \.self) { length in
                            Text(length.displayName).tag(length)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Quick Actions Grid
    private var quickActionsGrid: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Azioni Rapide")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                quickActionButton(
                    title: "Migliora Testo",
                    icon: "textformat.alt",
                    color: .blue
                ) {
                    Task {
                        await improveText()
                    }
                }
                
                quickActionButton(
                    title: "Suggerisci Oggetto",
                    icon: "lightbulb.fill",
                    color: .yellow
                ) {
                    Task {
                        await suggestSubject()
                    }
                }
                
                quickActionButton(
                    title: "Espandi",
                    icon: "arrow.up.left.and.arrow.down.right",
                    color: .green
                ) {
                    Task {
                        await expandText()
                    }
                }
                
                quickActionButton(
                    title: "Riassumi",
                    icon: "arrow.down.right.and.arrow.up.left",
                    color: .orange
                ) {
                    Task {
                        await summarizeText()
                    }
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func quickActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(UIColor.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
    }
    
    // MARK: - Suggestions View
    private var suggestionsView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Suggerimenti AI")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                
                Button("Nascondi") {
                    withAnimation {
                        showingSuggestions = false
                    }
                }
                .font(.system(size: 14))
                .foregroundStyle(.blue)
            }
            
            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                Button {
                    emailBody = suggestion
                    showingSuggestions = false
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Suggerimento \(index + 1)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            
                            Text(suggestion)
                                .font(.system(size: 14))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.left")
                            .font(.system(size: 12))
                            .foregroundStyle(.blue)
                    }
                    .padding(12)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Custom Prompt Section
    private var customPromptSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Prompt Personalizzato")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                TextEditor(text: $customPrompt)
                    .font(.body)
                    .padding(8)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(minHeight: 80)
                
                Button {
                    Task {
                        await executeCustomPrompt()
                    }
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Esegui Prompt")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(customPrompt.isEmpty || isGenerating)
            }
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - AI Functions
    
    private func improveText() async {
        guard !emailBody.isEmpty else { return }
        
        isGenerating = true
        let prompt = """
        Migliora il seguente testo email mantenendo il significato ma rendendolo più \(selectedTone.description) e \(selectedLength.description):
        
        \(emailBody)
        """
        
        do {
            let improved = try await aiService.generateResponse(prompt: prompt)
            await MainActor.run {
                emailBody = improved
                isGenerating = false
            }
        } catch {
            await MainActor.run {
                isGenerating = false
            }
        }
    }
    
    private func suggestSubject() async {
        isGenerating = true
        let prompt = """
        Suggerisci 3 oggetti email appropriati per il seguente contenuto:
        
        \(emailBody.isEmpty ? "Email di risposta" : emailBody)
        
        Stile: \(selectedTone.description)
        Destinatario: \(recipientEmail)
        
        Formato: restituisci solo i 3 oggetti, uno per riga.
        """
        
        do {
            let response = try await aiService.generateResponse(prompt: prompt)
            let subjectSuggestions = response.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            await MainActor.run {
                if let firstSuggestion = subjectSuggestions.first {
                    subject = firstSuggestion
                }
                isGenerating = false
            }
        } catch {
            await MainActor.run {
                isGenerating = false
            }
        }
    }
    
    private func expandText() async {
        guard !emailBody.isEmpty else { return }
        
        isGenerating = true
        let prompt = """
        Espandi il seguente testo email aggiungendo dettagli pertinenti e mantenendo uno stile \(selectedTone.description):
        
        \(emailBody)
        """
        
        do {
            let expanded = try await aiService.generateResponse(prompt: prompt)
            await MainActor.run {
                emailBody = expanded
                isGenerating = false
            }
        } catch {
            await MainActor.run {
                isGenerating = false
            }
        }
    }
    
    private func summarizeText() async {
        guard !emailBody.isEmpty else { return }
        
        isGenerating = true
        let prompt = """
        Riassumi il seguente testo email mantenendo i punti chiave e uno stile \(selectedTone.description):
        
        \(emailBody)
        """
        
        do {
            let summarized = try await aiService.generateResponse(prompt: prompt)
            await MainActor.run {
                emailBody = summarized
                isGenerating = false
            }
        } catch {
            await MainActor.run {
                isGenerating = false
            }
        }
    }
    
    private func executeCustomPrompt() async {
        isGenerating = true
        let fullPrompt = """
        \(customPrompt)
        
        Contenuto email attuale:
        \(emailBody)
        
        Destinatario: \(recipientEmail)
        """
        
        do {
            let result = try await aiService.generateResponse(prompt: fullPrompt)
            await MainActor.run {
                emailBody = result
                isGenerating = false
            }
        } catch {
            await MainActor.run {
                isGenerating = false
            }
        }
    }
}

// MARK: - Email Tone
// EmailTone is now defined in ServiceProtocols.swift to avoid duplication

// MARK: - Email Length
enum EmailLength: String, CaseIterable {
    case short = "short"
    case medium = "medium"
    case long = "long"
    
    var displayName: String {
        switch self {
        case .short: return "Breve"
        case .medium: return "Medio"
        case .long: return "Lungo"
        }
    }
    
    var description: String {
        switch self {
        case .short: return "conciso e diretto"
        case .medium: return "di lunghezza moderata"
        case .long: return "dettagliato e completo"
        }
    }
}

// MARK: - Email Sentiment Definition
enum EmailSentiment: String, CaseIterable {
    case positive = "positive"
    case neutral = "neutral"
    case negative = "negative"
    case urgent = "urgent"
    case friendly = "friendly"
    case formal = "formal"
}

// MARK: - Email Priority Definition
enum EmailPriority: String, CaseIterable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
}