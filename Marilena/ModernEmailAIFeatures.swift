import SwiftUI

// MARK: - Modern Email AI Features
/// Sistema AI completo per il ModernEmailViewer
/// Include analisi, riassunti, suggerimenti di risposta e composizione assistita

// MARK: - Modern Email AI Panel
struct ModernEmailAIPanel: View {
    let email: EmailMessage
    @ObservedObject var aiService: EmailAIService
    @Binding var analysis: EmailAnalysis?
    @Binding var summary: String?
    @Binding var showingAI: Bool
    
    @State private var isAnalyzing = false
    @State private var showingCustomPrompt = false
    @State private var customPrompt = ""
    @State private var showingTranslation = false
    @State private var translatedText = ""
    @State private var selectedLanguage = "it"
    
    let onResponseGenerated: (EmailDraft) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // AI Header
            modernAIHeader
            
            if showingAI {
                VStack(spacing: 16) {
                    // Analysis Section
                    if let analysis = analysis {
                        modernAnalysisView(analysis)
                    }
                    
                    // Summary Section
                    if let summary = summary {
                        modernSummaryView(summary)
                    }
                    
                    // AI Actions
                    modernAIActions
                    
                    // Quick Responses
                    modernQuickResponses
                    
                    // Translation
                    modernTranslationView
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
        .animation(.easeInOut(duration: 0.3), value: showingAI)
        .onAppear {
            Task {
                await analyzeEmail()
            }
        }
        .sheet(isPresented: $showingCustomPrompt) {
            ModernCustomPromptView(
                email: email,
                prompt: $customPrompt,
                aiService: aiService,
                onResponseGenerated: onResponseGenerated
            )
        }
    }
    
    // MARK: - AI Header
    private var modernAIHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "brain")
                    .foregroundStyle(.blue)
                    .font(.system(size: 16, weight: .medium))
                
                Text("Assistente AI")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                
                if isAnalyzing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            Spacer()
            
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingAI.toggle()
                }
            } label: {
                Image(systemName: showingAI ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Analysis View
    private func modernAnalysisView(_ analysis: EmailAnalysis) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Analisi Email")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // Urgency (previously Priority)
                analysisCard(
                    title: "Urgenza",
                    value: analysis.urgency.displayName,
                    icon: analysis.urgency.icon,
                    color: Color(analysis.urgency.color)
                )
                
                // Category
                analysisCard(
                    title: "Categoria",
                    value: analysis.category.displayName,
                    icon: analysis.category.icon,
                    color: analysis.category.color
                )
                
                // Sentiment
                analysisCard(
                    title: "Sentiment",
                    value: analysis.sentiment,
                    icon: sentimentIcon(analysis.sentiment),
                    color: sentimentColor(analysis.sentiment)
                )
                
                // Urgency
                analysisCard(
                    title: "Urgenza",
                    value: analysis.urgency.displayName,
                    icon: analysis.urgency.icon,
                    color: Color(analysis.urgency.color)
                )
            }
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func analysisCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(UIColor.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // Helper functions for sentiment visualization
    private func sentimentIcon(_ sentiment: String) -> String {
        switch sentiment.lowercased() {
            case "positivo": return "face.smiling.fill"
            case "negativo": return "face.frowning.fill"
            default: return "face.dashed.fill"
        }
    }
    
    private func sentimentColor(_ sentiment: String) -> Color {
        switch sentiment.lowercased() {
            case "positivo": return .green
            case "negativo": return .red
            default: return .gray
        }
    }
    
    // MARK: - Summary View
    private func modernSummaryView(_ summary: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(.blue)
                Text("Riassunto AI")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            Text(summary)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - AI Actions
    private var modernAIActions: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Azioni AI")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                aiActionButton(
                    title: "Riassumi",
                    icon: "doc.text.below.ecg",
                    color: .blue
                ) {
                    Task {
                        await generateSummary()
                    }
                }
                
                aiActionButton(
                    title: "Analizza",
                    icon: "brain.head.profile",
                    color: .purple
                ) {
                    Task {
                        await analyzeEmail()
                    }
                }
                
                aiActionButton(
                    title: "Traduci",
                    icon: "character.bubble",
                    color: .green
                ) {
                    showingTranslation.toggle()
                }
                
                aiActionButton(
                    title: "Prompt Custom",
                    icon: "wand.and.stars",
                    color: .orange
                ) {
                    showingCustomPrompt = true
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func aiActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(UIColor.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Quick Responses
    private var modernQuickResponses: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Risposte Rapide")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    quickResponseButton("👍 Conferma", type: .positive)
                    quickResponseButton("❌ Rifiuta", type: .negative)
                    quickResponseButton("📝 Professionale", type: .professional)
                    quickResponseButton("😊 Amichevole", type: .friendly)
                    quickResponseButton("❓ Richiedi Info", type: .inquiry)
                    quickResponseButton("⏰ Programma", type: .scheduling)
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func quickResponseButton(_ title: String, type: ResponseStyle) -> some View {
        Button {
            Task {
                await generateQuickResponse(type: type)
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: type.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Translation View
    @ViewBuilder
    private var modernTranslationView: some View {
        if showingTranslation {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "character.bubble")
                        .foregroundStyle(.green)
                    Text("Traduzione")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    
                    Button("Chiudi") {
                        showingTranslation = false
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)
                }
                
                Picker("Lingua", selection: $selectedLanguage) {
                    Text("Italiano").tag("it")
                    Text("English").tag("en")
                    Text("Español").tag("es")
                    Text("Français").tag("fr")
                    Text("Deutsch").tag("de")
                }
                .pickerStyle(.segmented)
                
                Button("Traduci Email") {
                    Task {
                        await translateEmail()
                    }
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.green)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                if !translatedText.isEmpty {
                    ScrollView {
                        Text(translatedText)
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                    .padding(12)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(16)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                removal: .opacity.combined(with: .scale(scale: 0.95))
            ))
        } else {
            EmptyView()
        }
    }
    
    // MARK: - AI Functions
    
    private func analyzeEmail() async {
        isAnalyzing = true
        do {
            let newAnalysis = try await aiService.analyzeEmail(email)
            await MainActor.run {
                analysis = newAnalysis
                isAnalyzing = false
            }
        } catch {
            await MainActor.run {
                isAnalyzing = false
            }
        }
    }
    
    private func generateSummary() async {
        summary = await aiService.summarizeEmail(email)
    }
    
    private func generateQuickResponse(type: ResponseStyle) async {
        do {
            let response = try await aiService.generateQuickResponse(for: email, type: type)
            let draft = EmailDraft(
                originalEmail: email,
                content: response,
                generatedAt: Date(),
                context: "Quick Response: \(type.prompt)"
            )
            await MainActor.run {
                onResponseGenerated(draft)
            }
        } catch {
            print("Error generating quick response: \(error)")
        }
    }
    
    private func translateEmail() async {
        do {
            let translation = try await aiService.translateText(email.body, to: selectedLanguage)
            await MainActor.run {
                translatedText = translation
            }
        } catch {
            print("Error translating email: \(error)")
        }
    }
}

// MARK: - Quick Response Types
enum ResponseStyle: String, CaseIterable {
    case positive, negative, professional, friendly, inquiry, scheduling
    
    var gradientColors: [Color] {
        switch self {
        case .positive: return [.green, .mint]
        case .negative: return [.red, .pink]
        case .professional: return [.blue, .cyan]
        case .friendly: return [.orange, .yellow]
        case .inquiry: return [.purple, .indigo]
        case .scheduling: return [.teal, .blue]
        }
    }
    
    var prompt: String {
        switch self {
        case .positive:
            return "Genera una risposta positiva e di conferma a questa email"
        case .negative:
            return "Genera una risposta educata ma che rifiuta la richiesta"
        case .professional:
            return "Genera una risposta professionale e formale"
        case .friendly:
            return "Genera una risposta amichevole e cordiale"
        case .inquiry:
            return "Genera una risposta che richiede maggiori informazioni"
        case .scheduling:
            return "Genera una risposta per programmare un incontro o chiamata"
        }
    }
}

// MARK: - Modern Custom Prompt View
struct ModernCustomPromptView: View {
    let email: EmailMessage
    @Binding var prompt: String
    @ObservedObject var aiService: EmailAIService
    let onResponseGenerated: (EmailDraft) -> Void
    
    @State private var isGenerating = false
    @State private var generatedResponse = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Email preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email di Riferimento")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Da: \(email.from)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text("Oggetto: \(email.subject)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Custom prompt input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prompt Personalizzato")
                        .font(.headline)
                    
                    TextEditor(text: $prompt)
                        .font(.body)
                        .padding(8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(minHeight: 100)
                }
                
                // Generate button
                Button {
                    Task {
                        await generateCustomResponse()
                    }
                } label: {
                    HStack {
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "wand.and.stars")
                        }
                        Text(isGenerating ? "Generando..." : "Genera Risposta")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(prompt.isEmpty || isGenerating)
                
                // Generated response
                if !generatedResponse.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Risposta Generata")
                                .font(.headline)
                            Spacer()
                            
                            Button("Usa Risposta") {
                                let draft = EmailDraft(
                                    originalEmail: email,
                                    content: generatedResponse,
                                    generatedAt: Date(),
                                    context: "Custom Prompt: \(prompt)"
                                )
                                onResponseGenerated(draft)
                                dismiss()
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.blue)
                        }
                        
                        ScrollView {
                            Text(generatedResponse)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(maxHeight: 200)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Prompt AI Personalizzato")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func generateCustomResponse() async {
        isGenerating = true
        do {
            if let draft = try await aiService.generateCustomResponse(for: email, basedOn: nil, withPrompt: prompt) {
                await MainActor.run {
                    generatedResponse = draft.content
                }
            }
        } catch {
            // Error handled in service
        }
        await MainActor.run {
            isGenerating = false
        }
    }
}

// MARK: - AI Service Extensions
extension EmailAIService {
    func generateQuickResponse(for email: EmailMessage, type: ResponseStyle) async throws -> String {
        return try await generateCustomResponse(for: email, prompt: type.prompt)
    }
    
    func generateCustomResponse(for email: EmailMessage, prompt: String) async throws -> String {
        let fullPrompt = """
        \(prompt)
        
        Email originale:
        Da: \(email.from)
        Oggetto: \(email.subject)
        Contenuto: \(email.body.prefix(500))
        
        Genera una risposta appropriata e professionale.
        """
        
        // Usa il servizio AI esistente per generare la risposta
        return try await generateResponse(prompt: fullPrompt)
    }
    
    func translateText(_ text: String, to language: String) async throws -> String {
        let prompt = """
        Traduci il seguente testo in \(languageName(for: language)):
        
        \(text)
        
        Mantieni il tono e lo stile originale.
        """
        
        return try await generateResponse(prompt: prompt)
    }
    
    private func languageName(for code: String) -> String {
        switch code {
        case "it": return "italiano"
        case "en": return "inglese"
        case "es": return "spagnolo"
        case "fr": return "francese"
        case "de": return "tedesco"
        default: return "la lingua richiesta"
        }
    }
}