import SwiftUI
import CoreData
import Foundation
import WebKit
#if canImport(MessageUI)
import MessageUI
#endif
import Combine
#if canImport(PhotosUI)
import PhotosUI
#endif
import UniformTypeIdentifiers

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
                        
                        // HTML Content - Unified Email HTML Renderer
                        EmailHTMLRenderer(email: email)
                            .onAppear {
                                print("🔍 EmailDetailView: EmailHTMLRenderer caricato")
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
            if EmailContentAnalyzer.isHTMLContent(email.body) {
                EmailHTMLRenderer(email: email)
                    .onAppear {
                        print("🔍 EmailDetailView: EmailHTMLRenderer apparso")
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


// MARK: - Email Contact Model
public struct EmailContact: Identifiable, Hashable {
    public let id = UUID()
    public let email: String
    public let name: String?
    
    public var displayName: String {
        name ?? email
    }
    
    public var isValid: Bool {
        email.contains("@") && email.contains(".")
    }
    
    public init(email: String, name: String?) {
        self.email = email
        self.name = name
    }
}

// MARK: - Email Attachment Model
struct EmailAttachment: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let data: Data
    let mimeType: String
    let size: Int64
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var fileExtension: String {
        (name as NSString).pathExtension.lowercased()
    }
    
    var isImage: Bool {
        ["jpg", "jpeg", "png", "gif", "heic", "webp"].contains(fileExtension)
    }
    
    var isPDF: Bool {
        fileExtension == "pdf"
    }
    
    var icon: String {
        if isImage { return "photo" }
        if isPDF { return "doc.text" }
        return "paperclip"
    }
}

// MARK: - iOS 26 Enhanced Compose Email View

struct ComposeEmailView: View {
    let replyTo: EmailMessage?
    let preFilledDraft: EmailDraft?
    
    @StateObject private var emailService = EmailService()
    
    // NUOVO: Supporto contatti multipli e CC/BCC
    @State private var toRecipients: [EmailContact] = []
    @State private var ccRecipients: [EmailContact] = []
    @State private var bccRecipients: [EmailContact] = []
    @State private var subject: String = ""
    @State private var emailBody: String = ""
    @State private var showingCCBCC = false
    
    // NUOVO: Supporto allegati
    @State private var attachments: [EmailAttachment] = []
    @State private var showingAttachmentPicker = false
    @State private var showingImagePicker = false
    @State private var imageSelection: PhotosPickerItem?
    
    // UI States
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var richTextEditorFocused = false
    @State private var editorFocused = false
    
    @Environment(\.dismiss) private var dismiss
    
    // Computed properties
    private var isValidEmail: Bool {
        hasValidRecipients && hasValidSubject
    }
    
    private var hasValidRecipients: Bool {
        !toRecipients.isEmpty && toRecipients.allSatisfy { isValidEmailAddress($0.email) }
    }
    
    private var hasValidSubject: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func isValidEmailAddress(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
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
        // NUOVO: Converte stringa in EmailContact se presente
        if !initialTo.isEmpty {
            self._toRecipients = State(initialValue: [EmailContact(email: initialTo, name: nil)])
        }
        self._subject = State(initialValue: initialSubject)
        self._emailBody = State(initialValue: initialBody)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // NUOVO: Campi email - Stile Apple Mail Standard
                VStack(spacing: 0) {
                    // Campo "A:" 
                    ComposeFieldRow(label: "A:", isRequired: true, isValid: hasValidRecipients || toRecipients.isEmpty) {
                        RecipientFieldView(
                            recipients: $toRecipients,
                            placeholder: "Inserisci email destinatario",
                            showCCBCC: $showingCCBCC
                        )
                    }
                    
                    Divider()
                        .padding(.leading, 76)
                    
                    // Campi CC/BCC (espandibili)
                    if showingCCBCC {
                        ComposeFieldRow(label: "Cc:") {
                            RecipientFieldView(
                                recipients: $ccRecipients,
                                placeholder: "Email in copia (opzionale)"
                            )
                        }
                        
                        Divider()
                            .padding(.leading, 76)
                        
                        ComposeFieldRow(label: "Ccn:") {
                            RecipientFieldView(
                                recipients: $bccRecipients,
                                placeholder: "Email in copia nascosta (opzionale)"
                            )
                        }
                        
                        Divider()
                            .padding(.leading, 76)
                    }
                    
                    // Campo Oggetto
                    ComposeFieldRow(label: "Oggetto:", isRequired: true, isValid: hasValidSubject || subject.isEmpty) {
                        TextField("Inserisci oggetto email", text: $subject)
                            .textFieldStyle(.plain)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .submitLabel(.done)
                    }
                    
                    Divider()
                    
                    // NUOVO: Sezione Allegati
                    if !attachments.isEmpty {
                        AttachmentListView(attachments: $attachments)
                        Divider()
                    }
                }
                .background(.regularMaterial)
                
                // NUOVO: Rich Text Editor con formattazione avanzata
                RichTextEditor(
                    text: $emailBody,
                    isFirstResponder: $richTextEditorFocused,
                    placeholder: "Componi il tuo messaggio..."
                )
                .background(.background)
                .frame(minHeight: 200)
                .onTapGesture {
                    richTextEditorFocused = true
                }
                
                // Error message
                if let errorMessage = errorMessage {
                    VStack {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding()
                            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal)
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle(replyTo != nil ? "Rispondi" : "Nuovo Messaggio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                
                // Menu allegati nella toolbar
                ToolbarItem(placement: .principal) {
                    Menu {
                        Button {
                            showingImagePicker = true
                        } label: {
                            Label("Foto o Video", systemImage: "photo")
                        }
                        
                        Button {
                            showingAttachmentPicker = true
                        } label: {
                            Label("Scegli File", systemImage: "doc")
                        }
                    } label: {
                        Image(systemName: "paperclip")
                            .font(.title2)
                            .foregroundStyle(.blue)
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
                        .fontWeight(.semibold)
                        .disabled(!isValidEmail)
                    }
                }
            }
            .onAppear {
                setupInitialContent()
            }
            // NUOVO: Photo Picker per immagini
            .photosPicker(isPresented: $showingImagePicker, selection: $imageSelection, matching: .any(of: [.images, .videos]))
            .onChange(of: imageSelection) { _, newValue in
                Task {
                    await processImageSelection(newValue)
                }
            }
            // NUOVO: Document Picker per file
            .fileImporter(
                isPresented: $showingAttachmentPicker,
                allowedContentTypes: [.data, .pdf, .text, .spreadsheet, .presentation],
                allowsMultipleSelection: false
            ) { result in
                Task {
                    await processDocumentSelection(result)
                }
            }
        }
    }
    
    // NUOVO: Setup contenuto iniziale
    private func setupInitialContent() {
        if let preFilledDraft = preFilledDraft {
            // Usa la bozza pre-compilata
            toRecipients = [EmailContact(email: preFilledDraft.originalEmail.from, name: nil)]
            subject = "Re: \(preFilledDraft.originalEmail.subject)"
            emailBody = preFilledDraft.content
        } else if let replyTo = replyTo {
            // Risposta normale
            toRecipients = [EmailContact(email: replyTo.from, name: nil)]
            subject = "Re: \(replyTo.subject)"
            emailBody = "\n\n--- Messaggio originale ---\n\(replyTo.body)"
        }
    }
    
    private func sendEmail() async {
        print("📧 ComposeEmailView: ===== INIZIO INVIO =====")
        print("📧 ComposeEmailView: isAuthenticated = \(emailService.isAuthenticated)")
        print("📧 ComposeEmailView: toRecipients = \(toRecipients.map(\.email))")
        print("📧 ComposeEmailView: ccRecipients = \(ccRecipients.map(\.email))")
        print("📧 ComposeEmailView: bccRecipients = \(bccRecipients.map(\.email))")
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
            guard !toRecipients.isEmpty, !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                print("❌ ComposeEmailView: Campi vuoti - toRecipients: \(toRecipients.isEmpty), subject: \(subject.isEmpty)")
                throw EmailError.sendFailed
            }
            
            print("📧 ComposeEmailView: Invio email tramite EmailService...")
            
            // NUOVO: Invia l'email con supporto CC/BCC
            // Per ora usiamo solo il primo destinatario (backwards compatibility)
            let primaryRecipient = toRecipients.first!.email
            try await emailService.sendEmail(to: primaryRecipient, subject: subject, body: emailBody)
            print("✅ ComposeEmailView: Email inviata con successo")
            
            // Salva in CoreData se necessario
            saveEmailToCoreData()
            
            dismiss()
        } catch EmailError.notAuthenticated {
            // Fallback a MFMailComposeViewController
            await MainActor.run {
                presentNativeMailComposer()
            }
        } catch {
            await MainActor.run {
                print("❌ ComposeEmailView: Errore nell'invio email: \(error)")
                errorMessage = error.localizedDescription
            }
        }
        
        // IMPORTANTE: Sempre resetta isSending alla fine
        await MainActor.run {
            isSending = false
        }
        print("📧 ComposeEmailView: ===== FINE INVIO =====")
    }
    
    // NUOVO: Presenta il composer nativo di iOS
    private func presentNativeMailComposer() {
        guard MFMailComposeViewController.canSendMail() else {
            errorMessage = "Impossibile inviare email da questo dispositivo"
            return
        }
        
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = MailComposeDelegate.shared
        mailComposer.setToRecipients(toRecipients.map(\.email))
        mailComposer.setCcRecipients(ccRecipients.map(\.email))
        mailComposer.setBccRecipients(bccRecipients.map(\.email))
        mailComposer.setSubject(subject)
        mailComposer.setMessageBody(emailBody, isHTML: false)
        
        // NUOVO: Aggiungi allegati
        for attachment in attachments {
            mailComposer.addAttachmentData(
                attachment.data,
                mimeType: attachment.mimeType,
                fileName: attachment.name
            )
        }
        
        print("📎 Aggiunti \(attachments.count) allegati al composer nativo")
        
        // Presenta il composer di email
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            var topViewController = rootViewController
            while let presentedViewController = topViewController.presentedViewController {
                topViewController = presentedViewController
            }
            
            topViewController.present(mailComposer, animated: true)
        }
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
    
    // MARK: - Attachment Functions
    
    /// Processa immagine/video selezionata dal PhotosPicker
    @MainActor
    private func processImageSelection(_ selection: PhotosPickerItem?) async {
        guard let selection = selection else { return }
        
        do {
            // Carica i dati dell'immagine
            guard let data = try await selection.loadTransferable(type: Data.self) else {
                print("❌ Errore caricamento dati immagine")
                return
            }
            
            // Determina nome e tipo MIME
            let name = "IMG_\(Date().timeIntervalSince1970).jpg"
            let mimeType = "image/jpeg"
            
            // Crea allegato
            let attachment = EmailAttachment(
                name: name,
                data: data,
                mimeType: mimeType,
                size: Int64(data.count)
            )
            
            // Aggiungi alla lista
            attachments.append(attachment)
            print("✅ Allegato immagine aggiunto: \(name), size: \(attachment.formattedSize)")
            
        } catch {
            print("❌ Errore processamento immagine: \(error)")
            errorMessage = "Errore caricamento immagine: \(error.localizedDescription)"
        }
    }
    
    /// Processa documento selezionato dal DocumentPicker
    @MainActor
    private func processDocumentSelection(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            for url in urls {
                await processDocumentURL(url)
            }
        case .failure(let error):
            print("❌ Errore selezione documento: \(error)")
            errorMessage = "Errore selezione file: \(error.localizedDescription)"
        }
    }
    
    /// Processa singolo documento URL
    @MainActor
    private func processDocumentURL(_ url: URL) async {
        // Accesso sicuro al file
        guard url.startAccessingSecurityScopedResource() else {
            print("❌ Impossibile accedere al file: \(url)")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            // Carica dati file
            let data = try Data(contentsOf: url)
            let name = url.lastPathComponent
            let mimeType = url.mimeType
            
            // Crea allegato
            let attachment = EmailAttachment(
                name: name,
                data: data,
                mimeType: mimeType,
                size: Int64(data.count)
            )
            
            // Aggiungi alla lista
            attachments.append(attachment)
            print("✅ Allegato documento aggiunto: \(name), size: \(attachment.formattedSize)")
            
        } catch {
            print("❌ Errore caricamento documento: \(error)")
            errorMessage = "Errore caricamento file: \(error.localizedDescription)"
        }
    }
}

// MARK: - URL Extension for MIME Type
extension URL {
    var mimeType: String {
        let pathExtension = self.pathExtension.lowercased()
        
        switch pathExtension {
        case "pdf":
            return "application/pdf"
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls":
            return "application/vnd.ms-excel"
        case "xlsx":
            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt":
            return "application/vnd.ms-powerpoint"
        case "pptx":
            return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "txt":
            return "text/plain"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "mov":
            return "video/quicktime"
        case "mp4":
            return "video/mp4"
        default:
            return "application/octet-stream"
        }
    }
}

// MARK: - Attachment List View
struct AttachmentListView: View {
    @Binding var attachments: [EmailAttachment]
    
    var body: some View {
        ForEach(attachments) { attachment in
            HStack(spacing: 12) {
                // Icona tipo file
                Image(systemName: attachment.icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                
                // Informazioni file
                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(attachment.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Pulsante rimuovi
                Button {
                    removeAttachment(attachment)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    private func removeAttachment(_ attachment: EmailAttachment) {
        withAnimation(.easeInOut(duration: 0.2)) {
            attachments.removeAll { $0.id == attachment.id }
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

// MARK: - Apple Mail Standard Components

// Campo compositore standard Apple Mail
struct ComposeFieldRow<Content: View>: View {
    let label: String
    let isRequired: Bool
    let isValid: Bool
    let content: Content
    
    init(label: String, isRequired: Bool = false, isValid: Bool = true, @ViewBuilder content: () -> Content) {
        self.label = label
        self.isRequired = isRequired
        self.isValid = isValid
        self.content = content()
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                if isRequired {
                    Text("*")
                        .font(.body)
                        .foregroundStyle(.red)
                }
                
                // Indicatore validazione
                if isRequired && !isValid {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .frame(width: 60, alignment: .leading)
            .padding(.leading, 16)
            .padding(.vertical, 12)
            
            content
                .padding(.trailing, 16)
                .padding(.vertical, 12)
        }
        .frame(minHeight: 44)
        .background(isRequired && !isValid ? Color.red.opacity(0.05) : Color.clear)
    }
}

// Campo destinatari con supporto CC/BCC e auto-completamento
struct RecipientFieldView: View {
    @Binding var recipients: [EmailContact]
    let placeholder: String
    var showCCBCC: Binding<Bool>? = nil
    
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    
    // NUOVO: Auto-completamento contatti
    @StateObject private var autoCompleteService = ContactAutoCompleteService.shared
    @State private var showingSuggestions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                // Chips dei contatti selezionati + campo input
                VStack(alignment: .leading, spacing: 4) {
                    if !recipients.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(recipients) { recipient in
                                ContactChip(
                                    contact: recipient,
                                    onRemove: { removeRecipient($0) }
                                )
                            }
                        }
                    }
                    
                    // Campo input
                    HStack {
                        TextField(placeholder, text: $inputText)
                            .textFieldStyle(.plain)
                            .focused($isInputFocused)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .onSubmit {
                                addRecipientFromText()
                            }
                            .onChange(of: inputText) { oldValue, newValue in
                                // NUOVO: Auto-completamento intelligente
                                if newValue.isEmpty {
                                    showingSuggestions = false
                                } else {
                                    autoCompleteService.searchSuggestions(for: newValue)
                                    showingSuggestions = !autoCompleteService.suggestions.isEmpty
                                }
                            }
                            .onChange(of: isInputFocused) { oldValue, newValue in
                                if !newValue {
                                    // Nasconde suggerimenti quando perde focus
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        showingSuggestions = false
                                    }
                                }
                            }
                        
                        if let showCCBCC = showCCBCC {
                            Button("Cc/Ccn") {
                                showCCBCC.wrappedValue.toggle()
                            }
                            .font(.callout)
                            .foregroundStyle(.blue)
                        }
                    }
                }
                
                Spacer(minLength: 0)
            }
            
            // NUOVO: Overlay suggerimenti auto-completamento
            if showingSuggestions && !autoCompleteService.suggestions.isEmpty {
                ContactSuggestionsView(
                    suggestions: autoCompleteService.suggestions,
                    onSuggestionSelected: { suggestion in
                        selectSuggestion(suggestion)
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
                .animation(.easeInOut(duration: 0.2), value: showingSuggestions)
            }
        }
    }
    
    private func removeRecipient(_ contact: EmailContact) {
        recipients.removeAll { $0.id == contact.id }
    }
    
    private func addRecipientFromText() {
        let email = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, email.contains("@") else { return }
        
        let contact = EmailContact(email: email, name: nil)
        if !recipients.contains(contact) {
            recipients.append(contact)
            // NUOVO: Registra utilizzo contatto
            autoCompleteService.recordContactUsage(contact)
        }
        inputText = ""
        showingSuggestions = false
    }
    
    // NUOVO: Seleziona un suggerimento dall'auto-completamento
    private func selectSuggestion(_ suggestion: ContactSuggestion) {
        let contact = suggestion.toEmailContact()
        if !recipients.contains(contact) {
            recipients.append(contact)
            // Registra utilizzo del contatto selezionato
            autoCompleteService.recordContactUsage(contact)
        }
        inputText = ""
        showingSuggestions = false
        
        // Mantieni il focus per continuare l'inserimento
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isInputFocused = true
        }
    }
}

// Chip per contatto selezionato
struct ContactChip: View {
    let contact: EmailContact
    let onRemove: (EmailContact) -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(contact.displayName)
                .font(.callout)
                .lineLimit(1)
            
            Button {
                onRemove(contact)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.blue.opacity(0.1), in: Capsule())
        .foregroundStyle(.blue)
    }
}

// Layout per chips che vanno a capo automaticamente
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.bounds
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(
                x: result.positions[index].x + bounds.origin.x,
                y: result.positions[index].y + bounds.origin.y
            ), proposal: .unspecified)
        }
    }
}

struct FlowResult {
    var bounds = CGSize.zero
    var positions: [CGPoint] = []
    
    init(in maxWidth: CGFloat, subviews: LayoutSubviews, spacing: CGFloat) {
        var currentPosition = CGPoint.zero
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentPosition.x + size.width > maxWidth && currentPosition.x > 0 {
                // Nuova riga
                currentPosition.x = 0
                currentPosition.y += rowHeight + spacing
                rowHeight = 0
            }
            
            positions.append(currentPosition)
            currentPosition.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        
        bounds = CGSize(
            width: maxWidth,
            height: currentPosition.y + rowHeight
        )
    }
}

// MARK: - Contact Auto-Complete Components

/// Vista per mostrare i suggerimenti di auto-completamento contatti
struct ContactSuggestionsView: View {
    let suggestions: [ContactSuggestion]
    let onSuggestionSelected: (ContactSuggestion) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Suggerimenti
            ForEach(suggestions.prefix(6)) { suggestion in
                ContactSuggestionRow(
                    suggestion: suggestion,
                    onTap: { onSuggestionSelected(suggestion) }
                )
                
                if suggestion.id != suggestions.prefix(6).last?.id {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.separator, lineWidth: 0.5)
        )
        .padding(.top, 8)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

/// Riga singola suggerimento contatto
struct ContactSuggestionRow: View {
    let suggestion: ContactSuggestion
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar con iniziali
                Circle()
                    .fill(.blue.gradient)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(suggestion.initials)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    // Nome principale
                    Text(suggestion.shortDisplayName)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    // Email (se diversa dal nome)
                    if suggestion.name != nil {
                        Text(suggestion.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Badge frequenza se alta
                if suggestion.frequency > 5 {
                    Text("\(suggestion.frequency)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.1), in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .hoverEffect()
    }
} 