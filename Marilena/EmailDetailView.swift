import SwiftUI
import CoreData
import Foundation
import WebKit
import MessageUI
import Combine

// MARK: - Email Detail View
// Vista dettagliata per visualizzare e gestire singole email

public struct EmailDetailView: View {
    let email: EmailMessage
    @ObservedObject var aiService: EmailAIService
    @StateObject private var emailService = EmailService()
    @Environment(\.dismiss) private var dismiss
    
    // State per l'overlay AI
    @State private var showingFullSummary = false
    @State private var showingCustomPrompt = false
    @State private var customPrompt = ""
    @State private var selectedDraft: EmailDraft?
    @State private var selectedResponseType: ResponseType?
    @State private var analysis: EmailAnalysis?
    @State private var summary: String?
    @State private var showingComposeForReply = false
    @State private var showingComposeForForward = false
    @State private var showingShareSheet = false
    @State private var showingEmailSettings = false
    @State private var showingDeleteAlert = false
    @State private var forwardData: (subject: String, body: String)?
    
    enum ResponseType: String, CaseIterable {
        case yes = "Sì"
        case no = "No"
        case custom = "Personalizzato"
        
        var icon: String {
            switch self {
            case .yes: return "checkmark.circle.fill"
            case .no: return "xmark.circle.fill"
            case .custom: return "pencil.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .yes: return .green
            case .no: return .red
            case .custom: return .blue
            }
        }
    }
    
    public var body: some View {
        mainContent
            .navigationTitle("Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            showingEmailSettings = true
                        } label: {
                            Label("Impostazioni Mail", systemImage: "gear")
                        }
                        
                        Button(role: .destructive) {
                            // Disconnetti
                            Task {
                                await emailService.disconnect()
                            }
                        } label: {
                            Label("Disconnetti", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Forward
                        Button {
                            forwardData = emailService.prepareForwardEmail(email)
                            showingComposeForForward = true
                        } label: {
                            Image(systemName: "arrowshape.turn.up.right")
                        }
                        
                        // Delete
                        Button {
                            showingDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .foregroundColor(.red)
                        
                        // Reply
                        Button("Rispondi") {
                            showingComposeForReply = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .onAppear {
                print("🔍 EmailDetailView: View principale caricata")
                // Marca l'email come letta
                Task {
                    await emailService.markEmailAsRead(email.id)
                }
                analyzeEmail()
            }
        .sheet(isPresented: $showingComposeForReply) {
            ComposeEmailView(replyTo: email, preFilledDraft: selectedDraft)
        }
        .sheet(isPresented: $showingComposeForForward) {
            if let forwardData = forwardData {
                ComposeEmailView(
                    initialSubject: forwardData.subject,
                    initialBody: forwardData.body
                )
            }
        }
        .sheet(isPresented: $showingEmailSettings) {
            EmailSettingsView()
        }
        .alert("Genera risposta personalizzata", isPresented: $showingCustomPrompt) {
            TextField("Inserisci istruzioni per la risposta", text: $customPrompt)
            Button("Genera") {
                Task {
                    await generateResponseWithPrompt(customPrompt)
                }
            }
            Button("Annulla", role: .cancel) {}
        }
        .alert("Elimina Email", isPresented: $showingDeleteAlert) {
            Button("Elimina", role: .destructive) {
                Task {
                    do {
                        try await emailService.deleteEmail(email.id)
                        dismiss()
                    } catch {
                        print("❌ Errore eliminazione email: \(error)")
                    }
                }
            }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Sei sicuro di voler eliminare questa email?")
        }
        .alert("Errore AI", isPresented: .constant(aiService.error != nil)) {
            Button("OK") {
                aiService.error = nil
            }
        } message: {
            Text(aiService.error ?? "")
        }
    }
    
    private var mainContent: some View {
        Group {
            // Se l'email è HTML, mostra direttamente l'HTML a tutto schermo
            if isHTMLContent(email.body) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Sezione AI Analysis e Azioni PRIMA dell'HTML
                        if let analysis = analysis {
                            VStack(alignment: .leading, spacing: 12) {
                                // Analisi AI compatta
                                HStack(spacing: 8) {
                                    Label(analysis.category.displayName, systemImage: analysis.category.icon)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Label(analysis.urgency.displayName, systemImage: analysis.urgency.icon)
                                        .font(.caption)
                                        .foregroundColor(Color(analysis.urgency.color))
                                }
                                
                                // Riassunto espandibile
                                if let summary = summary, !summary.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Button(action: { showingFullSummary.toggle() }) {
                                            HStack {
                                                Text("Riassunto")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                Spacer()
                                                Image(systemName: showingFullSummary ? "chevron.up" : "chevron.down")
                                                    .font(.caption)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Text(showingFullSummary ? summary : String(summary.prefix(80)) + "...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(showingFullSummary ? nil : 2)
                                            .animation(.easeInOut(duration: 0.3), value: showingFullSummary)
                                    }
                                }
                                
                                // Pulsanti di risposta rapida iOS 26 style
                                HStack(spacing: 12) {
                                    Button("Sì") {
                                        handleResponseType(.yes)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.primary)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    
                                    Button("No") {
                                        handleResponseType(.no)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.primary)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    
                                    Button("Personalizzato") {
                                        showingCustomPrompt = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                }
                                
                                // Drafts se presenti
                                if !aiService.generatedDrafts.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(aiService.generatedDrafts.indices, id: \.self) { index in
                                                let draft = aiService.generatedDrafts[index]
                                                Button("Bozza \(index + 1)") {
                                                    selectedDraft = draft
                                                    showingComposeForReply = true
                                                }
                                                .buttonStyle(.bordered)
                                                .font(.caption)
                                            }
                                        }
                                        .padding(.horizontal, 4)
                                    }
                                }
                            }
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                        }
                        
                        // HTML Content - ora completamente libero di espandersi
                        DynamicHTMLWebView(htmlContent: email.body)
                            .onAppear {
                                print("🔍 EmailDetailView: DynamicHTMLWebView caricato nello ScrollView")
                            }
                    }
                    .padding(.vertical)
                }
            } else {
                // Vista normale per email non HTML
                ScrollView {
                    VStack(spacing: 16) {
                        // AI Analysis e Summary in cima
                        if let analysis = analysis {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Label(analysis.category.displayName, systemImage: analysis.category.icon)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Label(analysis.urgency.displayName, systemImage: analysis.urgency.icon)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Riassunto con toggle
                                if let summary = summary {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Riassunto")
                                                .font(.headline)
                                                .fontWeight(.semibold)
                                            
                                            Spacer()
                                            
                                            Button(showingFullSummary ? "Comprimi" : "Espandi") {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    showingFullSummary.toggle()
                                                }
                                            }
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                        }
                                        
                                        Text(showingFullSummary ? summary : String(summary.prefix(80)) + (summary.count > 80 ? "..." : ""))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(showingFullSummary ? nil : 2)
                                            .animation(.easeInOut(duration: 0.3), value: showingFullSummary)
                                    }
                                }
                                
                                // Pulsanti di risposta rapida
                                HStack(spacing: 12) {
                                    // Sì
                                    Button("Sì") {
                                        handleResponseType(.yes)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.primary)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    
                                    // No
                                    Button("No") {
                                        handleResponseType(.no)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.primary)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    
                                    // Personalizzato
                                    Button("Personalizzato") {
                                        showingCustomPrompt = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                }
                                
                                // Drafts section se presenti
                                if !aiService.generatedDrafts.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(aiService.generatedDrafts.indices, id: \.self) { index in
                                                let draft = aiService.generatedDrafts[index]
                                                Button("Bozza \(index + 1)") {
                                                    selectedDraft = draft
                                                    showingComposeForReply = true
                                                }
                                                .buttonStyle(.bordered)
                                                .font(.caption)
                                            }
                                        }
                                        .padding(.horizontal, 4)
                                    }
                                }
                            }
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                        }
                        
                        // Email header e contenuto
                        emailHeader
                        
                        Text(email.body)
                            .font(.body)
                            .lineLimit(nil)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
        }
    }
    
    // MARK: - Email Header (Semplificato)
    
    private var emailHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(email.subject)
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Da:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(email.from)
                        .font(.body)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Data:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDate(email.date))
                        .font(.body)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Email Content with HTML Support (Senza limitazioni)
    
    private var emailContent: some View {
        Group {
            if isHTMLContent(email.body) {
                HTMLWebView(htmlContent: email.body)
                    .background(Color(.systemBackground))
                    .onAppear {
                        print("🔍 EmailDetailView: HTMLWebView apparso")
                        debugEmailContent()
                    }
            } else {
                Text(email.body)
                    .font(.body)
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal)
                    .onAppear {
                        print("🔍 EmailDetailView: Text view apparso")
                        debugEmailContent()
                    }
            }
        }
    }
    
    private func debugEmailContent() {
        let isHTML = isHTMLContent(email.body)
        let contentLength = email.body.count
        let contentPreview = String(email.body.prefix(100))
        
        print("🔍 EmailDetailView: === DEBUG CONTENUTO EMAIL ===")
        print("🔍 EmailDetailView: Lunghezza contenuto: \(contentLength)")
        print("🔍 EmailDetailView: Anteprima contenuto: \(contentPreview)")
        print("🔍 EmailDetailView: È HTML? \(isHTML)")
        print("🔍 EmailDetailView: Contenuto completo: \(email.body)")
        print("🔍 EmailDetailView: =================================")
    }
    
    // MARK: - AI Analysis Section
    
    private func aiAnalysisSection(_ analysis: EmailAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analisi AI")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Tono:")
                    Spacer()
                    Text(analysis.tone)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Sentimento:")
                    Spacer()
                    Text(analysis.sentiment)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Urgenza:")
                    Spacer()
                    Text(analysis.urgency.rawValue)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Complessità:")
                    Spacer()
                    Text(analysis.complexity)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - AI Actions Section
    
    private var aiActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Azioni AI")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                Button("Genera Bozza") {
                    generateDraft()
                }
                .buttonStyle(.borderedProminent)
                .disabled(aiService.isGenerating)
                
                Button("Genera Multiple") {
                    generateMultipleDrafts()
                }
                .buttonStyle(.bordered)
                .disabled(aiService.isGenerating)
                
                Spacer()
            }
            
            if let summary = summary {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Riassunto")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(summary)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Drafts Section
    
    private var draftsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bozze Generate")
                .font(.headline)
            
            ForEach(aiService.generatedDrafts) { draft in
                VStack(alignment: .leading, spacing: 8) {
                    Text(draft.content)
                        .font(.body)
                        .lineLimit(6)
                    
                    VStack(spacing: 8) {
                        // Opzioni di risposta multiple
                        HStack(spacing: 8) {
                            ForEach(ResponseType.allCases, id: \.self) { responseType in
                                Button(action: {
                            selectedDraft = draft
                                    handleResponseType(responseType)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: responseType.icon)
                                            .font(.caption)
                                        Text(responseType.rawValue)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(responseType.color.opacity(0.1))
                                    .foregroundColor(responseType.color)
                                    .cornerRadius(16)
                                }
                            }
                        }
                        
                        // Data e pulsante Usa
                        HStack {
                            Button("Usa Bozza") {
                                selectedDraft = draft
                                showingComposeForReply = true
                            }
                            .buttonStyle(.borderedProminent)
                        
                        Spacer()
                        
                        Text(formatDate(draft.generatedAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func analyzeEmail() {
        Task {
            analysis = await aiService.analyzeEmail(email)
            summary = await aiService.summarizeEmail(email)
        }
    }
    
    private func generateDraft() {
        Task {
            _ = await aiService.generateDraft(for: email)
        }
    }
    
    private func generateMultipleDrafts() {
        Task {
            _ = await aiService.generateMultipleDrafts(for: email, count: 3)
        }
    }
    
    private func handleResponseType(_ responseType: ResponseType) {
        switch responseType {
        case .yes:
            // Genera risposta positiva
            Task {
                await generateResponseWithPrompt("Genera una risposta positiva e accettante a questa email. Sii cordiale e professionale.")
            }
        case .no:
            // Genera risposta negativa
            Task {
                await generateResponseWithPrompt("Genera una risposta negativa ma educata a questa email. Spiega gentilmente perché non puoi accettare.")
            }
        case .custom:
            // Mostra dialog per prompt personalizzato
            showingCustomPrompt = true
        }
    }
    
    private func generateResponseWithPrompt(_ prompt: String) async {
        guard let draft = selectedDraft else { return }
        
        let customDraft = await aiService.generateCustomResponse(
            for: email,
            basedOn: draft,
            withPrompt: prompt
        )
        
        if let newDraft = customDraft {
            selectedDraft = newDraft
            showingComposeForReply = true
        }
    }
    
    private func generateCustomResponse() {
        guard !customPrompt.isEmpty else { return }
        
        Task {
            let customDraft = await aiService.generateCustomResponse(
                for: email,
                basedOn: selectedDraft,
                withPrompt: customPrompt
            )
            
            if let newDraft = customDraft {
                selectedDraft = newDraft
                showingComposeForReply = true
            }
            
            customPrompt = ""
            showingCustomPrompt = false
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
    
    private func isHTMLContent(_ content: String) -> Bool {
        let htmlTags = [
            "<html", "<body", "<div", "<p", "<br", "<strong", "<em", "<ul", "<ol", "<li", 
            "<h1", "<h2", "<h3", "<h4", "<h5", "<h6", "<span", "<a", "<img", "<table", 
            "<tr", "<td", "<th", "<blockquote", "<code", "<pre", "<b", "<i", "<u", "<s"
        ]
        
        // Controlla se contiene tag HTML
        let containsHTMLTags = htmlTags.contains { content.localizedCaseInsensitiveContains($0) }
        
        // Controlla se contiene caratteri HTML comuni
        let containsHTMLChars = content.contains("&") || content.contains("&#") || content.contains("&lt;") || content.contains("&gt;")
        
        // Controlla se contiene attributi HTML
        let containsHTMLAttrs = content.contains("style=") || content.contains("class=") || content.contains("id=")
        
        // Debug: stampa il contenuto per vedere cosa contiene
        print("🔍 EmailDetailView: Contenuto email:")
        print("🔍 EmailDetailView: Primi 200 caratteri: \(String(content.prefix(200)))")
        print("🔍 EmailDetailView: Contiene tag HTML: \(containsHTMLTags)")
        print("🔍 EmailDetailView: Contiene caratteri HTML: \(containsHTMLChars)")
        print("🔍 EmailDetailView: Contiene attributi HTML: \(containsHTMLAttrs)")
        
        return containsHTMLTags || containsHTMLChars || containsHTMLAttrs
    }
}

// MARK: - Dynamic HTML Web View

class HTMLWebViewCoordinator: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var contentHeight: CGFloat = 200
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("🔍 HTMLWebView: didFinish navigation")
        
        // Calcola l'altezza del contenuto
        webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, error in
            DispatchQueue.main.async {
                if let height = result as? CGFloat {
                    print("🔍 HTMLWebView: Altezza contenuto calcolata: \(height)")
                    self?.contentHeight = max(height, 200) // Minimo 200
                } else {
                    print("🔍 HTMLWebView: Errore nel calcolo altezza: \(error?.localizedDescription ?? "unknown")")
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        print("🔍 HTMLWebView: decidePolicyFor navigationAction - URL: \(navigationAction.request.url?.absoluteString ?? "nil")")
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        print("🔍 HTMLWebView: decidePolicyFor navigationResponse - MIME type: \(navigationResponse.response.mimeType ?? "nil")")
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("🔍 HTMLWebView: didStartProvisionalNavigation")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("🔍 HTMLWebView: didFail navigation - Errore: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("🔍 HTMLWebView: didFailProvisionalNavigation - Errore: \(error.localizedDescription)")
    }
}

struct HTMLWebView: UIViewRepresentable {
    let htmlContent: String
    @StateObject private var coordinator = HTMLWebViewCoordinator()
    
    func makeUIView(context: Context) -> WKWebView {
        print("🔍 HTMLWebView: Creando WKWebView")
        print("🔍 HTMLWebView: Contenuto HTML ricevuto: \(String(htmlContent.prefix(200)))")
        
        // Configurazione semplificata per maggiore stabilità
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.backgroundColor = UIColor.systemBackground
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false // Disabilito scroll interno
        webView.scrollView.bounces = false
        
        // Configura il delegate
        webView.navigationDelegate = coordinator
        
        print("🔍 HTMLWebView: WKWebView creato con successo")
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        print("🔍 HTMLWebView: Aggiornando WKWebView")
        print("🔍 HTMLWebView: Contenuto da caricare: \(String(htmlContent.prefix(200)))")
        
        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    font-size: 16px;
                    line-height: 1.6;
                    color: #333;
                    margin: 0;
                    padding: 16px;
                    background-color: transparent;
                    word-wrap: break-word;
                    overflow-wrap: break-word;
                    box-sizing: border-box;
                    width: 100%;
                }
                p { margin: 0 0 16px 0; }
                a { color: #007AFF; text-decoration: none; }
                img { max-width: 100%; height: auto; display: block; margin: 8px 0; border-radius: 4px; }
                blockquote { margin: 16px 0; padding-left: 16px; color: #666; }
                code { padding: 2px 4px; font-family: 'SF Mono', Monaco, monospace; font-size: 14px; }
                pre { padding: 12px; font-family: 'SF Mono', Monaco, monospace; font-size: 14px; overflow-x: auto; border-radius: 8px; }
                table { width: 100%; border-collapse: collapse; margin: 16px 0; }
                th, td { padding: 8px 12px; text-align: left; }
                th { font-weight: 600; }
            </style>
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
        
        print("🔍 HTMLWebView: HTML completo generato: \(String(htmlString.prefix(300)))")
        webView.loadHTMLString(htmlString, baseURL: nil)
        print("🔍 HTMLWebView: loadHTMLString chiamato")
    }
    
    func makeCoordinator() -> HTMLWebViewCoordinator {
        return coordinator
    }
}

struct DynamicHTMLWebView: View {
    let htmlContent: String
    @StateObject private var coordinator = HTMLWebViewCoordinator()
    
    var body: some View {
        HTMLWebView(htmlContent: htmlContent)
            .frame(height: coordinator.contentHeight)
            .onAppear {
                print("🔍 DynamicHTMLWebView: Caricato con altezza iniziale: \(coordinator.contentHeight)")
            }
            .onReceive(coordinator.$contentHeight) { newHeight in
                print("🔍 DynamicHTMLWebView: Nuova altezza ricevuta: \(newHeight)")
            }
    }
}

// MARK: - iOS 26 Enhanced Compose Email View

struct ComposeEmailView: View {
    let replyTo: EmailMessage?
    let preFilledDraft: EmailDraft?
    
    @StateObject private var emailService = EmailService()
    
    @State private var to: String = ""
    @State private var subject: String = ""
    @State private var emailBody: String = ""
    @State private var showingSendSheet = false
    @State private var isSending = false
    @State private var errorMessage: String?
    
    @Environment(\.dismiss) private var dismiss
    
    // Init per nuovo messaggio vuoto
    init() {
        self.replyTo = nil
        self.preFilledDraft = nil
    }
    
    // Init per reply con draft
    init(replyTo: EmailMessage?, preFilledDraft: EmailDraft?) {
        self.replyTo = replyTo
        self.preFilledDraft = preFilledDraft
    }
    
    // Init per forward o nuovo messaggio
    init(initialTo: String = "", initialSubject: String = "", initialBody: String = "") {
        self.replyTo = nil
        self.preFilledDraft = nil
        self._to = State(initialValue: initialTo)
        self._subject = State(initialValue: initialSubject)
        self._emailBody = State(initialValue: initialBody)
    }
    
    var body: some View {
            VStack(spacing: 0) {
            // Header iOS 26 style
                VStack(spacing: 16) {
                    HStack {
                        Text("A:")
                            .font(.headline)
                        .foregroundStyle(.secondary)
                        TextField("Email destinatario", text: $to)
                            .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    }
                    
                    HStack {
                        Text("Oggetto:")
                            .font(.headline)
                        .foregroundStyle(.secondary)
                        TextField("Oggetto email", text: $subject)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .liquidGlass(.subtle)
            .padding()
            
            // Body editor - iOS 26 style
            VStack(alignment: .leading, spacing: 8) {
                Text("Messaggio:")
                        .font(.headline)
                    .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    TextEditor(text: $emailBody)
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .liquidGlass(.subtle)
                    .frame(minHeight: 200)
            }
                        .padding(.horizontal)
                
                Spacer()
            
            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
            }
        }
        .navigationTitle(replyTo != nil ? "Rispondi" : "Nuovo Messaggio")
            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Annulla") {
                            dismiss()
                        }
                .foregroundStyle(.blue)
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if isSending {
                            ProgressView()
                                .scaleEffect(0.8)
                        .foregroundStyle(.blue)
                        } else {
                            Button("Invia") {
                                showingSendSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(to.isEmpty || subject.isEmpty || emailBody.isEmpty)
                    .foregroundStyle(.white)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 8))
                    .liquidGlass(.prominent)
                    }
                }
        }
        .onAppear {
            if let preFilledDraft = preFilledDraft {
                // Usa la bozza pre-compilata
                to = preFilledDraft.originalEmail.from
                subject = "Re: \(preFilledDraft.originalEmail.subject)"
                emailBody = preFilledDraft.content
            } else if let replyTo = replyTo {
                // Risposta normale
                to = replyTo.from
                subject = "Re: \(replyTo.subject)"
                emailBody = "\n\n--- Messaggio originale ---\n\(replyTo.body)"
            }
        }
        .alert("Invia Email", isPresented: $showingSendSheet) {
            Button("Invia Direttamente") {
                Task {
                    await sendEmailDirectly()
                }
            }
            Button("Usa App Mail") {
                if MFMailComposeViewController.canSendMail() {
                    sendEmailWithMessageUI()
                } else {
                    errorMessage = "Impossibile inviare email da questo dispositivo. Verifica che sia configurato un account email."
                }
            }
            Button("Annulla", role: .cancel) { }
        } message: {
            Text("Scegli come inviare l'email:")
        }
        .alert("Errore Invio", isPresented: .constant(errorMessage != nil && !showingSendSheet)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private func sendEmail() async {
        print("📧 ComposeEmailView: ===== INIZIO INVIO =====")
        print("📧 ComposeEmailView: isAuthenticated = \(emailService.isAuthenticated)")
        print("📧 ComposeEmailView: to = \(to)")
        print("📧 ComposeEmailView: subject = \(subject)")
        print("📧 ComposeEmailView: body length = \(emailBody.count)")
        
        isSending = true
        
        do {
            // Verifica che l'utente sia autenticato
            guard emailService.isAuthenticated else {
                print("❌ ComposeEmailView: Utente non autenticato")
                throw EmailError.notAuthenticated
            }
            
            // Verifica che i campi non siano vuoti
            guard !to.isEmpty, !subject.isEmpty, !emailBody.isEmpty else {
                print("❌ ComposeEmailView: Campi vuoti - to: \(to.isEmpty), subject: \(subject.isEmpty), body: \(emailBody.isEmpty)")
                throw EmailError.sendFailed
            }
            
            print("📧 ComposeEmailView: Invio email tramite EmailService...")
            
            // Invia l'email
            try await emailService.sendEmail(to: to, subject: subject, body: emailBody)
            print("✅ ComposeEmailView: Email inviata con successo")
            
            // Salva in CoreData se necessario
            saveEmailToCoreData()
            
            dismiss()
        } catch {
            print("❌ ComposeEmailView: Errore nell'invio email: \(error)")
            errorMessage = error.localizedDescription
        }
        
        // IMPORTANTE: Sempre resetta isSending alla fine
        await MainActor.run {
            isSending = false
        }
        print("📧 ComposeEmailView: ===== FINE INVIO =====")
    }
    
    // MARK: - Real Email Sending with MessageUI
    
    private func sendEmailWithMessageUI() {
        guard MFMailComposeViewController.canSendMail() else {
            errorMessage = "Impossibile inviare email da questo dispositivo"
            return
        }
        
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = MailComposeDelegate.shared
        mailComposer.setToRecipients([to])
        mailComposer.setSubject(subject)
        mailComposer.setMessageBody(emailBody, isHTML: true)
        
        // Presenta il composer di email
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            // Cerca il view controller più in alto nella gerarchia
            var topViewController = rootViewController
            while let presentedViewController = topViewController.presentedViewController {
                topViewController = presentedViewController
            }
            
            topViewController.present(mailComposer, animated: true) {
                print("📧 EmailDetailView: MFMailComposeViewController presentato con successo")
            }
        } else {
            print("❌ EmailDetailView: Impossibile trovare il root view controller")
            errorMessage = "Errore nell'apertura del composer email"
        }
    }
    
    private func sendEmailDirectly() async {
        print("📧 ComposeEmailView: ===== INIZIO INVIO DIRETTO =====")
        print("📧 ComposeEmailView: isAuthenticated = \(emailService.isAuthenticated)")
        print("📧 ComposeEmailView: to = \(to)")
        print("📧 ComposeEmailView: subject = \(subject)")
        print("📧 ComposeEmailView: body length = \(emailBody.count)")
        
        isSending = true
        
        do {
            guard emailService.isAuthenticated else {
                print("❌ ComposeEmailView: Utente non autenticato per invio diretto")
                throw EmailError.notAuthenticated
            }
            
            guard !to.isEmpty, !subject.isEmpty, !emailBody.isEmpty else {
                print("❌ ComposeEmailView: Campi vuoti per invio diretto - to: \(to.isEmpty), subject: \(subject.isEmpty), body: \(emailBody.isEmpty)")
                throw EmailError.sendFailed
            }
            
            print("📧 ComposeEmailView: Invio email tramite EmailService (Diretto)...")
            
            try await emailService.sendEmail(to: to, subject: subject, body: emailBody)
            print("✅ ComposeEmailView: Email inviata con successo (Diretto)")
            
            saveEmailToCoreData()
            dismiss()
        } catch {
            print("❌ ComposeEmailView: Errore nell'invio email (Diretto): \(error)")
            errorMessage = error.localizedDescription
        }
        
        await MainActor.run {
        isSending = false
        }
        print("📧 ComposeEmailView: ===== FINE INVIO DIRETTO =====")
    }
    
    private struct EmptyView: View {
        var body: some View {
            EmptyView()
        }
    }
    
    private func saveEmailToCoreData() {
        // TODO: Implementare salvataggio in CoreData
        print("📧 Salvataggio email in CoreData...")
    }
}

// MARK: - Mail Compose Delegate

class MailComposeDelegate: NSObject, MFMailComposeViewControllerDelegate {
    static let shared = MailComposeDelegate()
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        print("📧 MailComposeDelegate: Risultato invio email = \(result.rawValue)")
        
        switch result {
        case .sent:
            print("✅ Email inviata con successo")
        case .saved:
            print("💾 Email salvata come bozza")
        case .cancelled:
            print("❌ Invio email annullato")
        case .failed:
            print("❌ Invio email fallito: \(error?.localizedDescription ?? "Errore sconosciuto")")
        @unknown default:
            print("❓ Risultato invio email sconosciuto")
        }
        
        controller.dismiss(animated: true)
    }
}

// MARK: - Custom Prompt View

struct CustomPromptView: View {
    @Binding var prompt: String
    let onGenerate: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Prompt Personalizzato")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Descrivi come vuoi che sia generata la risposta. Puoi specificare il tono, lo stile, il contenuto specifico che vuoi includere.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Il tuo prompt:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextEditor(text: $prompt)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
                
                VStack(spacing: 12) {
                    Button("Genera Risposta") {
                        onGenerate()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button("Annulla") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Prompt Personalizzato")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Annulla") {
                        onCancel()
                    }
                }
            }
        }
    }
} 