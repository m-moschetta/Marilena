import SwiftUI
import WebKit
import MessageUI

// MARK: - Email Detail View
// Vista dettagliata per visualizzare e gestire singole email

public struct EmailDetailView: View {
    let email: EmailMessage
    @ObservedObject var aiService: EmailAIService
    @StateObject private var emailService = EmailService()
    
    @State private var showingDraft = false
    @State private var selectedDraft: EmailDraft?
    @State private var analysis: EmailAnalysis?
    @State private var summary: String?
    @State private var showingCompose = false
    @State private var showingEmailSettings = false
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // AI Analysis - Spostato sopra
                    if let analysis = analysis {
                        aiAnalysisSection(analysis)
                    }
                    
                    // AI Actions - Spostato sopra
                    aiActionsSection
                    
                    // Generated Drafts - Spostato sopra
                    if !aiService.generatedDrafts.isEmpty {
                        draftsSection
                    }
                    
                    // Content with HTML support - Senza limitazioni
                    emailContent
                }
                .padding()
            }
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
                        
                        Button {
                            showingEmailSettings = true
                        } label: {
                            Label("Prompt OpenAI", systemImage: "brain")
                        }
                        
                        Divider()
                        
                        Button {
                            // Dismiss
                        } label: {
                            Label("Indietro", systemImage: "chevron.left")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Rispondi") {
                        showingCompose = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear {
            // Marca l'email come letta
            Task {
                await emailService.markEmailAsRead(email.id)
            }
            
            analyzeEmail()
        }
        .sheet(isPresented: $showingCompose) {
            ComposeEmailView(replyTo: email, preFilledDraft: selectedDraft)
        }
        .sheet(isPresented: $showingEmailSettings) {
            EmailSettingsView()
        }
        .alert("Errore AI", isPresented: .constant(aiService.error != nil)) {
            Button("OK") {
                aiService.error = nil
            }
        } message: {
            Text(aiService.error ?? "")
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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Email Content with HTML Support (Senza limitazioni)
    
    private var emailContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contenuto")
                .font(.headline)
                .fontWeight(.semibold)
            
            if isHTMLContent(email.body) {
                HTMLWebView(htmlContent: email.body)
                    .frame(minHeight: 200)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
            } else {
                Text(email.body)
                    .font(.body)
                    .lineLimit(nil)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
            }
        }
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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
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
                    
                    HStack {
                        Button("Usa") {
                            selectedDraft = draft
                            showingDraft = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Rispondi") {
                            selectedDraft = draft
                            showingCompose = true
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Text(formatDate(draft.generatedAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
    
    private func isHTMLContent(_ content: String) -> Bool {
        let htmlTags = ["<html", "<body", "<div", "<p", "<br", "<strong", "<em", "<ul", "<ol", "<li", "<h1", "<h2", "<h3", "<h4", "<h5", "<h6"]
        return htmlTags.contains { content.localizedCaseInsensitiveContains($0) }
    }
}

// MARK: - HTML Web View

struct HTMLWebView: UIViewRepresentable {
    let htmlContent: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = UIColor.systemBackground
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = true
        webView.scrollView.showsVerticalScrollIndicator = true
        webView.scrollView.showsHorizontalScrollIndicator = true
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=yes">
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
                }
                p {
                    margin: 0 0 16px 0;
                }
                a {
                    color: #007AFF;
                    text-decoration: none;
                }
                img {
                    max-width: 100%;
                    height: auto;
                    display: block;
                    margin: 8px 0;
                }
                blockquote {
                    border-left: 4px solid #007AFF;
                    margin: 16px 0;
                    padding-left: 16px;
                    color: #666;
                    background-color: rgba(0, 122, 255, 0.05);
                }
                code {
                    background-color: #f5f5f5;
                    padding: 2px 4px;
                    border-radius: 4px;
                    font-family: 'SF Mono', Monaco, 'Cascadia Code', monospace;
                    font-size: 14px;
                }
                pre {
                    background-color: #f5f5f5;
                    padding: 16px;
                    border-radius: 8px;
                    overflow-x: auto;
                    margin: 16px 0;
                }
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 16px 0;
                }
                th, td {
                    border: 1px solid #ddd;
                    padding: 8px;
                    text-align: left;
                }
                th {
                    background-color: #f5f5f5;
                }
                ul, ol {
                    margin: 16px 0;
                    padding-left: 20px;
                }
                li {
                    margin: 4px 0;
                }
                h1, h2, h3, h4, h5, h6 {
                    margin: 24px 0 16px 0;
                    color: #222;
                }
                h1 { font-size: 24px; }
                h2 { font-size: 20px; }
                h3 { font-size: 18px; }
                h4 { font-size: 16px; }
                h5 { font-size: 14px; }
                h6 { font-size: 12px; }
            </style>
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
        
        webView.loadHTMLString(htmlString, baseURL: nil)
    }
}

// MARK: - Compose Email View

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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        Text("A:")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        TextField("Email destinatario", text: $to)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("Oggetto:")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        TextField("Oggetto email", text: $subject)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Body
                VStack(alignment: .leading, spacing: 12) {
                    Text("Messaggio")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    TextEditor(text: $emailBody)
                        .frame(minHeight: 300)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                Spacer()
            }
            .navigationTitle("Nuova Email")
            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Annulla") {
                            dismiss()
                        }
                        .disabled(isSending)
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if isSending {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Button("Invia") {
                                showingSendSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(to.isEmpty || subject.isEmpty || emailBody.isEmpty)
                        }
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
        .alert("Errore", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
                // Fallback: resetta sempre isSending se c'è un errore
                isSending = false
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .onDisappear {
            // Fallback: resetta sempre isSending quando la view scompare
            isSending = false
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