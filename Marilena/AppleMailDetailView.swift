import SwiftUI
import WebKit
#if canImport(MessageUI)
import MessageUI
#endif
import Combine

// MARK: - Apple Mail Style Detail View
struct AppleMailDetailView: View {
    let email: EmailMessage
    @ObservedObject var emailService: EmailService
    @ObservedObject var aiService: EmailAIService
    @Environment(\.dismiss) private var dismiss
    
    // AI States
    @State private var analysis: EmailAnalysis?
    @State private var summary: String?
    @State private var showingAI = false
    @State private var isAnalyzing = false
    
    // UI States
    @State private var showingReplySheet = false
    @State private var showingForwardSheet = false
    @State private var showingMoreMenu = false
    @State private var showingDeleteAlert = false
    @State private var showingCustomPrompt = false
    @State private var customPrompt = ""
    @State private var selectedDraft: EmailDraft?
    @State private var forwardData: (subject: String, body: String)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            AppleMailStyleHeader(email: email)
            
            Divider()
                .background(Color(UIColor.separator))
            
            // Content
            ScrollView {
                VStack(spacing: 0) {
                    // AI Section (collapsible)
                    AppleMailAISection(
                        analysis: analysis,
                        summary: summary,
                        showingAI: $showingAI,
                        onGenerateResponse: handleResponseType
                    )
                    
                    // Email Content
                    AppleMailContentView(htmlContent: email.body)
                        .padding(.horizontal)
                }
            }
            
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Email")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // NUOVO: Azioni nella navigation bar (stile Apple Mail)
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    // Archive
                    Button {
                        // TODO: Implementare archive
                    } label: {
                        Image(systemName: "archivebox")
                    }
                    
                    // Delete
                    Button {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .foregroundStyle(.red)
                    
                    // Reply
                    Button {
                        showingReplySheet = true
                    } label: {
                        Image(systemName: "arrowshape.turn.up.left")
                    }
                }
            }
            
            // NUOVO: Compose button nella bottom bar
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    Button {
                        // TODO: Move to folder
                    } label: {
                        Image(systemName: "folder")
                    }
                    
                    Spacer()
                    
                    Button {
                        // TODO: Compose new email
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
        .onAppear {
            Task {
                await emailService.markEmailAsRead(email.id)
                await analyzeEmail()
            }
        }
        .sheet(isPresented: $showingReplySheet) {
            if let draft = selectedDraft {
                ComposeEmailView(replyTo: email, preFilledDraft: draft)
            }
        }
        .sheet(isPresented: $showingForwardSheet) {
            if let forwardData = forwardData {
                ComposeEmailView(
                    initialSubject: forwardData.subject,
                    initialBody: forwardData.body
                )
            }
        }
        .sheet(isPresented: $showingCustomPrompt) {
            CustomPromptView(
                prompt: $customPrompt,
                onGenerate: generateCustomResponse,
                onCancel: { showingCustomPrompt = false }
            )
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
    }
    
    // MARK: - AI Functions
    private func analyzeEmail() async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        
        // Analyze
        if let result = await aiService.analyzeEmail(email) {
            await MainActor.run {
                self.analysis = result
            }
        }
        
        // Summarize
        if let summaryResult = await aiService.summarizeEmail(email) {
            await MainActor.run {
                self.summary = summaryResult
            }
        }
        
        isAnalyzing = false
    }
    
    private func handleResponseType(_ type: ResponseType) {
        Task {
            switch type {
            case .yes:
                if let draft = await aiService.generateDraft(
                    for: email,
                    context: "Genera una risposta professionale e positiva che accetta quanto proposto nell'email."
                ) {
                    selectedDraft = draft
                    showingReplySheet = true
                }
            case .no:
                if let draft = await aiService.generateDraft(
                    for: email,
                    context: "Genera una risposta professionale e cortese che rifiuta gentilmente quanto proposto nell'email."
                ) {
                    selectedDraft = draft
                    showingReplySheet = true
                }
            case .custom:
                showingCustomPrompt = true
            }
        }
    }
    
    private func generateCustomResponse() {
        Task {
            if let draft = await aiService.generateCustomResponse(
                for: email,
                basedOn: nil,
                withPrompt: customPrompt
            ) {
                selectedDraft = draft
                showingReplySheet = true
                showingCustomPrompt = false
                customPrompt = ""
            }
        }
    }
}

// MARK: - Apple Mail Content View
struct AppleMailContentView: View {
    let htmlContent: String
    @StateObject private var webViewModel = WebViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            if isHTMLContent(htmlContent) {
                AppleMailWebView(
                    htmlContent: htmlContent,
                    viewModel: webViewModel
                )
                .frame(height: webViewModel.contentHeight)
                .onAppear {
                    print("📧 AppleMailContentView: Loading HTML content")
                }
            } else {
                Text(htmlContent)
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical)
            }
        }
    }
    
    private func isHTMLContent(_ content: String) -> Bool {
        let htmlTags = ["<html", "<body", "<div", "<p>", "<br", "<table", "<h1", "<h2", "<h3"]
        return htmlTags.contains { content.localizedCaseInsensitiveContains($0) }
    }
}

// MARK: - Web View Model
class WebViewModel: NSObject, ObservableObject {
    @Published var contentHeight: CGFloat = 300
    
    func updateHeight(_ height: CGFloat) {
        DispatchQueue.main.async {
            self.contentHeight = max(height + 50, 300) // Add padding
        }
    }
}

// MARK: - Apple Mail Web View
struct AppleMailWebView: UIViewRepresentable {
    let htmlContent: String
    @ObservedObject var viewModel: WebViewModel
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .systemBackground
        webView.isOpaque = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * {
                    -webkit-text-size-adjust: 100%;
                    -webkit-tap-highlight-color: transparent;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    font-size: 16px;
                    line-height: 1.5;
                    color: #000;
                    margin: 0;
                    padding: 0;
                    background: transparent;
                    word-wrap: break-word;
                }
                @media (prefers-color-scheme: dark) {
                    body { color: #fff; }
                    a { color: #0A84FF; }
                }
                p { margin: 1em 0; }
                img { 
                    max-width: 100%; 
                    height: auto; 
                    display: block;
                    margin: 16px 0;
                }
                blockquote {
                    margin: 16px 0;
                    padding-left: 16px;
                    border-left: 3px solid #007AFF;
                    color: #666;
                }
                @media (prefers-color-scheme: dark) {
                    blockquote { color: #999; }
                }
                pre {
                    background: #f5f5f5;
                    padding: 12px;
                    border-radius: 8px;
                    overflow-x: auto;
                }
                @media (prefers-color-scheme: dark) {
                    pre { background: #1c1c1e; }
                }
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 16px 0;
                }
                th, td {
                    padding: 8px;
                    text-align: left;
                    border-bottom: 1px solid #e0e0e0;
                }
                @media (prefers-color-scheme: dark) {
                    th, td { border-color: #38383a; }
                }
            </style>
            <script>
                function notifyHeight() {
                    const height = document.body.scrollHeight;
                    window.webkit.messageHandlers.heightHandler.postMessage(height);
                }
                
                window.onload = function() {
                    notifyHeight();
                    // Observer for dynamic content
                    const observer = new MutationObserver(notifyHeight);
                    observer.observe(document.body, { 
                        childList: true, 
                        subtree: true,
                        attributes: true
                    });
                }
            </script>
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
        
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let viewModel: WebViewModel
        
        init(viewModel: WebViewModel) {
            self.viewModel = viewModel
            super.init()
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Get content height via JavaScript
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, error in
                if let height = result as? CGFloat {
                    self?.viewModel.updateHeight(height)
                }
            }
        }
    }
} 

 