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
                    initialTo: email.from, // Assuming email.from is the initial recipient for forward
                    initialSubject: "Re: \(email.subject)",
                    initialBody: "\n\n--- Messaggio originale ---\n\(email.body)"
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
    
    // MARK: - Helper Methods
    
    private func analyzeEmail() {
        Task {
            analysis = await aiService.analyzeEmail(email)
            summary = await aiService.summarizeEmail(email)
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
        
        return containsHTMLTags || containsHTMLChars || containsHTMLAttrs
    }
}

// MARK: - Dynamic HTML Web View

class HTMLWebViewCoordinator: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var contentHeight: CGFloat = 200
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Calcola l'altezza del contenuto
        webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, error in
            DispatchQueue.main.async {
                if let height = result as? CGFloat {
                    self?.contentHeight = max(height, 200) // Minimo 200
                }
            }
        }
    }
}

struct HTMLWebView: UIViewRepresentable {
    let htmlContent: String
    @StateObject private var coordinator = HTMLWebViewCoordinator()
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.backgroundColor = UIColor.systemBackground
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = coordinator
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
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
        
        webView.loadHTMLString(htmlString, baseURL: nil)
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
    }
}

// MARK: - iOS 26 Enhanced Compose Email View

struct ComposeEmailView: View {
    let replyTo: EmailMessage?
    let preFilledDraft: EmailDraft?
    
    @StateObject private var emailService = EmailService()
    @StateObject private var contactsService = ContactsService()
    
    // Recipients
    @State private var toRecipients: [EmailContact] = []
    @State private var ccRecipients: [EmailContact] = []
    @State private var bccRecipients: [EmailContact] = []
    @State private var showingCCBCC = false
    
    // Content
    @State private var subject: String = ""
    @State private var emailBody: String = ""
    
    // UI States
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showingAttachmentPicker = false
    @State private var attachments: [EmailAttachment] = []
    @State private var editorFocused = false
    
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
        self._subject = State(initialValue: initialSubject)
        self._emailBody = State(initialValue: initialBody)
        
        if !initialTo.isEmpty {
            self._toRecipients = State(initialValue: [EmailContact(email: initialTo)])
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Recipients Section - Apple Mail Style
                recipientsSection
                
                // Attachments Preview (if any)
                if !attachments.isEmpty {
                    attachmentsPreview
                }
                
                // Email Body Editor
                emailBodyEditor
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") { 
                        dismiss() 
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button("Invia") { 
                            Task {
                                await sendEmail()
                            }
                        }
                        .disabled(!isValidEmail)
                        .fontWeight(.semibold)
                    }
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    keyboardToolbar
                }
            }
            .onAppear {
                setupInitialContent()
            }
        }
        .alert("Errore Invio", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    // MARK: - Recipients Section (Apple Mail Style)
    
    private var recipientsSection: some View {
        VStack(spacing: 0) {
            // Campo "A:"
            ComposeFieldRow(label: "A:") {
                RecipientFieldView(
                    recipients: $toRecipients,
                    placeholder: "destinatario",
                    contactsService: contactsService,
                    showCCBCC: $showingCCBCC
                )
            }
            
            Divider()
                .padding(.leading, 50)
            
            // Campi CC/BCC (espandibili)
            if showingCCBCC {
                ComposeFieldRow(label: "Cc:") {
                    RecipientFieldView(
                        recipients: $ccRecipients,
                        placeholder: "cc",
                        contactsService: contactsService
                    )
                }
                
                Divider()
                    .padding(.leading, 50)
                
                ComposeFieldRow(label: "Ccn:") {
                    RecipientFieldView(
                        recipients: $bccRecipients,
                        placeholder: "ccn",
                        contactsService: contactsService
                    )
                }
                
                Divider()
                    .padding(.leading, 50)
            }
            
            // Campo Oggetto
            ComposeFieldRow(label: "Oggetto:") {
                TextField("Oggetto", text: $subject)
                    .textFieldStyle(.plain)
            }
            
            Divider()
        }
        .background(.regularMaterial)
    }
    
    // MARK: - Attachments Preview
    
    private var attachmentsPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Allegati (\(attachments.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(attachments) { attachment in
                        AttachmentThumbView(
                            attachment: attachment,
                            onRemove: { removeAttachment($0) }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 8)
            
            Divider()
        }
        .background(.regularMaterial)
    }
    
    // MARK: - Email Body Editor
    
    private var emailBodyEditor: some View {
        VStack(spacing: 0) {
            // Rich Text Formatting Toolbar (when editor is focused)
            if editorFocused {
                formattingToolbar
                Divider()
            }
            
            // Text Editor
            TextEditor(text: $emailBody)
                .font(.body)
                .padding(.horizontal)
                .padding(.top, 8)
                .frame(minHeight: 200)
                .background(.background)
                .onTapGesture {
                    editorFocused = true
                }
        }
    }
    
    // MARK: - Formatting Toolbar
    
    private var formattingToolbar: some View {
        HStack {
            Button {
                // Toggle bold
            } label: {
                Image(systemName: "bold")
                    .foregroundStyle(.primary)
            }
            
            Button {
                // Toggle italic
            } label: {
                Image(systemName: "italic")
                    .foregroundStyle(.primary)
            }
            
            Button {
                // Toggle underline
            } label: {
                Image(systemName: "underline")
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            Button {
                // Insert link
            } label: {
                Image(systemName: "link")
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
    
    // MARK: - Keyboard Toolbar
    
    private var keyboardToolbar: some View {
        HStack {
            Button {
                showingAttachmentPicker = true
            } label: {
                Image(systemName: "camera")
                    .foregroundStyle(.blue)
            }
            
            Button {
                // Document picker
            } label: {
                Image(systemName: "doc")
                    .foregroundStyle(.blue)
            }
            
            Spacer()
            
            Button("Fine") {
                editorFocused = false
                hideKeyboard()
            }
            .foregroundStyle(.blue)
        }
    }
    
    // MARK: - Computed Properties
    
    private var navigationTitle: String {
        if replyTo != nil {
            return "Rispondi"
        } else {
            return "Nuovo Messaggio"
        }
    }
    
    private var isValidEmail: Bool {
        !toRecipients.isEmpty && !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialContent() {
        if let preFilledDraft = preFilledDraft {
            // Usa la bozza pre-compilata
            toRecipients = [EmailContact(email: preFilledDraft.originalEmail.from)]
            subject = "Re: \(preFilledDraft.originalEmail.subject)"
            emailBody = preFilledDraft.content
        } else if let replyTo = replyTo {
            // Risposta normale
            toRecipients = [EmailContact(email: replyTo.from)]
            subject = "Re: \(replyTo.subject)"
            emailBody = "\n\n--- Messaggio originale ---\n\(replyTo.body)"
        }
    }
    
    private func removeAttachment(_ attachment: EmailAttachment) {
        attachments.removeAll { $0.id == attachment.id }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func sendEmail() async {
        guard isValidEmail else { return }
        
        isSending = true
        
        do {
            try await emailService.sendEmail(
                to: toRecipients.map(\.email).joined(separator: ", "),
                subject: subject,
                body: emailBody
            )
            
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSending = false
    }
}

// MARK: - Support Components for Apple Mail Compose Layout

// Compose Field Row - Apple Mail Style
struct ComposeFieldRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: 40, alignment: .leading)
                .padding(.top, 8)
            
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
    }
}

// Recipient Field with Auto-completion
struct RecipientFieldView: View {
    @Binding var recipients: [EmailContact]
    let placeholder: String
    let contactsService: ContactsService
    @Binding var showCCBCC: Bool?
    
    @State private var inputText = ""
    @State private var suggestions: [EmailContact] = []
    @State private var showingSuggestions = false
    
    init(recipients: Binding<[EmailContact]>, placeholder: String, contactsService: ContactsService, showCCBCC: Binding<Bool>? = nil) {
        self._recipients = recipients
        self.placeholder = placeholder
        self.contactsService = contactsService
        
        if let showCCBCC = showCCBCC {
            self._showCCBCC = showCCBCC
        } else {
            self._showCCBCC = .constant(false)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Recipients chips
            if !recipients.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(recipients) { recipient in
                        ContactChipView(
                            contact: recipient,
                            onRemove: { removeRecipient(recipient) }
                        )
                    }
                }
                .padding(.bottom, 4)
            }
            
            // Input field
            HStack {
                TextField(placeholder, text: $inputText)
                    .textFieldStyle(.plain)
                    .onChange(of: inputText) { newValue in
                        searchContacts(newValue)
                    }
                    .onSubmit {
                        addRecipientFromText()
                    }
                
                if showCCBCC != nil && recipients.count > 0 {
                    Button {
                        showCCBCC?.toggle()
                    } label: {
                        Text("Cc/Ccn")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
            
            // Suggestions dropdown
            if showingSuggestions && !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions.prefix(5)) { suggestion in
                        ContactSuggestionRow(
                            contact: suggestion,
                            searchText: inputText,
                            onTap: { addRecipient(suggestion) }
                        )
                    }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private func searchContacts(_ query: String) {
        guard !query.isEmpty else {
            suggestions = []
            showingSuggestions = false
            return
        }
        
        Task {
            let results = await contactsService.searchContacts(query: query)
            await MainActor.run {
                suggestions = results
                showingSuggestions = !results.isEmpty
            }
        }
    }
    
    private func addRecipientFromText() {
        guard !inputText.isEmpty else { return }
        
        let contact = EmailContact(email: inputText.trimmingCharacters(in: .whitespacesAndNewlines))
        addRecipient(contact)
    }
    
    private func addRecipient(_ contact: EmailContact) {
        guard !recipients.contains(where: { $0.email == contact.email }) else { return }
        
        recipients.append(contact)
        inputText = ""
        suggestions = []
        showingSuggestions = false
    }
    
    private func removeRecipient(_ contact: EmailContact) {
        recipients.removeAll { $0.id == contact.id }
    }
}

// Contact Chip View
struct ContactChipView: View {
    let contact: EmailContact
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(contact.shortDisplayName)
                .font(.caption)
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.blue.opacity(0.1))
        .foregroundStyle(.blue)
        .clipShape(Capsule())
    }
}

// Contact Suggestion Row
struct ContactSuggestionRow: View {
    let contact: EmailContact
    let searchText: String
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let name = contact.name {
                        Text(name)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    Text(contact.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// Flow Layout for Chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let totalHeight = rows.reduce(0) { $0 + $1.maxHeight } + CGFloat(max(0, rows.count - 1)) * spacing
        return CGSize(width: proposal.width ?? 0, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        
        for row in rows {
            var x = bounds.minX
            
            for subview in row.subviews {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            
            y += row.maxHeight + spacing
        }
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let width = proposal.width ?? .infinity
        var rows: [Row] = []
        var currentRow = Row()
        var x: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > width && !currentRow.subviews.isEmpty {
                rows.append(currentRow)
                currentRow = Row()
                x = 0
            }
            
            currentRow.subviews.append(subview)
            currentRow.maxHeight = max(currentRow.maxHeight, size.height)
            x += size.width + spacing
        }
        
        if !currentRow.subviews.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
    
    private struct Row {
        var subviews: [LayoutSubview] = []
        var maxHeight: CGFloat = 0
    }
}

// Attachment Thumbnail View
struct AttachmentThumbView: View {
    let attachment: EmailAttachment
    let onRemove: (EmailAttachment) -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: attachment.type.iconName)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    )
                
                Button {
                    onRemove(attachment)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .background(.white, in: Circle())
                }
                .offset(x: 8, y: -8)
            }
            
            Text(attachment.name)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: 60)
            
            Text(attachment.formattedSize)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// Contacts Service (Mock implementation)
@MainActor
class ContactsService: ObservableObject {
    @Published var recentContacts: [EmailContact] = []
    
    func searchContacts(query: String) async -> [EmailContact] {
        // Mock implementation - in real app would search device contacts
        let mockContacts = [
            EmailContact(email: "mario.rossi@example.com", name: "Mario Rossi", isRecent: true),
            EmailContact(email: "laura.bianchi@example.com", name: "Laura Bianchi", isRecent: false),
            EmailContact(email: "francesco.verdi@example.com", name: "Francesco Verdi", isRecent: true),
            EmailContact(email: "giulia.ferrari@example.com", name: "Giulia Ferrari", isRecent: false),
            EmailContact(email: "marco.colombo@example.com", name: "Marco Colombo", isRecent: true),
            EmailContact(email: "alessia.russo@example.com", name: "Alessia Russo", isRecent: false)
        ]
        
        return mockContacts.filter { contact in
            contact.email.localizedCaseInsensitiveContains(query) ||
            (contact.name?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
    
    func addRecentContact(_ contact: EmailContact) {
        recentContacts.removeAll { $0.email == contact.email }
        recentContacts.insert(contact, at: 0)
        if recentContacts.count > 10 {
            recentContacts = Array(recentContacts.prefix(10))
        }
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