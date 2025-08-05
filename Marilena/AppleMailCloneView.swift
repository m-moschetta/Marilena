import SwiftUI
import WebKit
import MessageUI
import Combine

// MARK: - Apple Mail Clone View
/// Vista che replica esattamente l'interfaccia di Apple Mail
/// con supporto HTML completo, altezza dinamica e UX nativa
struct AppleMailCloneView: View {
    let email: EmailMessage
    @ObservedObject var emailService: EmailService
    @ObservedObject var aiService: EmailAIService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // AI States
    @State private var analysis: EmailAnalysis?
    @State private var summary: String?
    @State private var showingAI = false
    @State private var isAnalyzing = false
    
    // UI States
    @State private var showingReplySheet = false
    @State private var showingForwardSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingCustomPrompt = false
    @State private var customPrompt = ""
    @State private var selectedDraft: EmailDraft?
    @State private var forwardData: (subject: String, body: String)?
    @State private var showingShareSheet = false
    
    // WebView State
    @StateObject private var webViewManager = AppleMailWebViewManager()
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // MARK: - Apple Mail Header
                AppleMailCloneHeader(
                    email: email,
                    showingAI: $showingAI,
                    analysis: analysis,
                    onReply: { showingReplySheet = true },
                    onForward: { 
                        forwardData = emailService.prepareForwardEmail(email)
                        showingForwardSheet = true 
                    },
                    onDelete: { showingDeleteAlert = true },
                    onShare: { showingShareSheet = true }
                )
                
                // MARK: - AI Quick Actions (se abilitato)
                if showingAI, let analysis = analysis {
                    AppleMailCloneAIActions(
                        analysis: analysis,
                        summary: summary,
                        onResponseType: handleResponseType
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .bottom))
                    ))
                }
                
                // MARK: - Content Area (HTML + Native)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Contenuto Email
                        AppleMailCloneContent(
                            email: email,
                            webViewManager: webViewManager
                        )
                        .frame(maxWidth: .infinity)
                        
                        // Spacer per evitare che il contenuto sia troppo vicino al bottom
                        Color.clear.frame(height: 60)
                    }
                }
                .refreshable {
                    await analyzeEmail()
                }
            }
        }
        .navigationBarHidden(true)
        .background(Color(UIColor.systemBackground))
        .onAppear {
            Task {
                await emailService.markEmailAsRead(email.id)
                await analyzeEmail()
            }
        }
        .sheet(isPresented: $showingReplySheet) {
            if let draft = selectedDraft {
                ComposeEmailView(replyTo: email, preFilledDraft: draft)
            } else {
                ComposeEmailView(replyTo: email, preFilledDraft: nil)
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
        .sheet(isPresented: $showingShareSheet) {
            AppleMailShareSheet(email: email)
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

// MARK: - Apple Mail Clone Header
struct AppleMailCloneHeader: View {
    let email: EmailMessage
    @Binding var showingAI: Bool
    let analysis: EmailAnalysis?
    let onReply: () -> Void
    let onForward: () -> Void
    let onDelete: () -> Void
    let onShare: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                // Back Button
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.title2.weight(.medium))
                        Text("Casella")
                            .font(.body)
                    }
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                // AI Toggle
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingAI.toggle()
                    }
                } label: {
                    Image(systemName: showingAI ? "brain.head.profile.fill" : "brain.head.profile")
                        .font(.title2)
                        .foregroundColor(showingAI ? .purple : .secondary)
                }
                
                // Action Buttons
                HStack(spacing: 20) {
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                    
                    Menu {
                        Button("Risposta", action: onReply)
                        Button("Risposta a tutti") { /* TODO */ }
                        Button("Inoltra", action: onForward)
                        Divider()
                        Button("Contrassegna") { /* TODO */ }
                        Button("Sposta") { /* TODO */ }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            // Email Metadata
            VStack(alignment: .leading, spacing: 12) {
                // Subject
                Text(email.subject)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Sender Info
                HStack(spacing: 12) {
                    // Avatar
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(email.from.prefix(1)).uppercased())
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(email.from)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 8) {
                            Text("a me")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Status badges
                            if let analysis = analysis {
                                HStack(spacing: 4) {
                                    Image(systemName: analysis.urgency.icon)
                                        .font(.caption2)
                                    Text(analysis.urgency.displayName)
                                        .font(.caption2.weight(.medium))
                                }
                                .foregroundColor(Color(analysis.urgency.color))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(analysis.urgency.color).opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatDate(email.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Note: isUnread not available in EmailMessage
                        // if email.isUnread {
                        //     Circle()
                        //         .fill(.blue)
                        //         .frame(width: 8, height: 8)
                        // }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            
            // Divider
            Divider()
                .background(Color(UIColor.separator))
        }
        .background(.regularMaterial)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDate(date, inSameDayAs: now) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
                  calendar.isDate(date, inSameDayAs: yesterday) {
            return "Ieri"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Apple Mail Clone AI Actions
struct AppleMailCloneAIActions: View {
    let analysis: EmailAnalysis
    let summary: String?
    let onResponseType: (ResponseType) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Summary
            if let summary = summary {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "brain.head.profile.fill")
                            .foregroundColor(.purple)
                        Text("Riassunto AI")
                            .font(.headline.weight(.semibold))
                        Spacer()
                    }
                    
                    Text(summary)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            
            // Quick Response Buttons
            HStack(spacing: 12) {
                Button("✅ Accetta") {
                    onResponseType(.yes)
                }
                .buttonStyle(AppleMailQuickActionButtonStyle(color: .green))
                
                Button("❌ Rifiuta") {
                    onResponseType(.no)
                }
                .buttonStyle(AppleMailQuickActionButtonStyle(color: .red))
                
                Button("✏️ Personalizza") {
                    onResponseType(.custom)
                }
                .buttonStyle(AppleMailQuickActionButtonStyle(color: .blue))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(.regularMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(UIColor.separator)),
            alignment: .bottom
        )
    }
}

// MARK: - Apple Mail Clone Content
struct AppleMailCloneContent: View {
    let email: EmailMessage
    @ObservedObject var webViewManager: AppleMailWebViewManager
    
    var body: some View {
        VStack(spacing: 0) {
            if isHTMLContent(email.body) {
                // HTML Content
                AppleMailCloneWebView(
                    htmlContent: email.body,
                    webViewManager: webViewManager
                )
                .frame(
                    minHeight: 300,
                    maxHeight: webViewManager.contentHeight > 0 ? webViewManager.contentHeight : .infinity
                )
                .clipped()
            } else {
                // Plain Text Content
                VStack(alignment: .leading, spacing: 16) {
                    Text(email.body)
                        .font(.body)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }
    
    private func isHTMLContent(_ content: String) -> Bool {
        let htmlTags = [
            "<html", "<body", "<div", "<p", "<br", "<strong", "<em", "<ul", "<ol", "<li",
            "<h1", "<h2", "<h3", "<h4", "<h5", "<h6", "<span", "<a", "<img", "<table",
            "<tr", "<td", "<th", "<blockquote", "<code", "<pre", "<b", "<i", "<u", "<s"
        ]
        
        return htmlTags.contains { content.localizedCaseInsensitiveContains($0) }
    }
}

// MARK: - Apple Mail Web View Manager
class AppleMailWebViewManager: NSObject, ObservableObject {
    @Published var contentHeight: CGFloat = 0
    @Published var isLoading = true
    
    func updateContentHeight(_ height: CGFloat) {
        DispatchQueue.main.async {
            // Aggiungi padding e assicurati che non sia troppo piccolo
            let adjustedHeight = max(height + 40, 300)
            if abs(self.contentHeight - adjustedHeight) > 10 {
                self.contentHeight = adjustedHeight
            }
            self.isLoading = false
        }
    }
}

// MARK: - Apple Mail Clone Web View
struct AppleMailCloneWebView: UIViewRepresentable {
    let htmlContent: String
    @ObservedObject var webViewManager: AppleMailWebViewManager
    
    func makeCoordinator() -> Coordinator {
        Coordinator(webViewManager: webViewManager)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.suppressesIncrementalRendering = false
        
        // Message handler per comunicazione con JavaScript
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "heightHandler")
        configuration.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.backgroundColor = .systemBackground
        webView.isOpaque = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let styledHTML = generateAppleMailHTML(content: htmlContent)
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }
    
    private func generateAppleMailHTML(content: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * {
                    box-sizing: border-box;
                    -webkit-text-size-adjust: 100%;
                    -webkit-tap-highlight-color: transparent;
                }
                
                html, body {
                    margin: 0;
                    padding: 0;
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'SF Pro Display', system-ui, sans-serif;
                    font-size: 17px;
                    line-height: 1.47;
                    color: #000;
                    background: transparent;
                    word-wrap: break-word;
                    overflow-wrap: break-word;
                    -webkit-font-smoothing: antialiased;
                    text-rendering: optimizeLegibility;
                }
                
                body {
                    padding: 20px;
                    max-width: 100%;
                    overflow-x: hidden;
                }
                
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #ffffff;
                    }
                    
                    a {
                        color: #0A84FF;
                    }
                    
                    blockquote {
                        color: #98989d;
                        border-left-color: #48484a;
                    }
                    
                    pre, code {
                        background-color: #1c1c1e;
                        color: #ffffff;
                    }
                    
                    table th, table td {
                        border-color: #38383a;
                    }
                }
                
                /* Typography */
                p {
                    margin: 0 0 1em 0;
                    padding: 0;
                }
                
                h1, h2, h3, h4, h5, h6 {
                    font-weight: 600;
                    margin: 1.5em 0 0.5em 0;
                    line-height: 1.25;
                }
                
                h1 { font-size: 1.5em; }
                h2 { font-size: 1.3em; }
                h3 { font-size: 1.15em; }
                
                /* Links */
                a {
                    color: #007AFF;
                    text-decoration: none;
                }
                
                a:hover {
                    text-decoration: underline;
                }
                
                /* Images */
                img {
                    max-width: 100%;
                    height: auto;
                    display: block;
                    margin: 1em 0;
                    border-radius: 8px;
                    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
                }
                
                /* Lists */
                ul, ol {
                    margin: 1em 0;
                    padding-left: 1.5em;
                }
                
                li {
                    margin: 0.25em 0;
                }
                
                /* Blockquotes */
                blockquote {
                    margin: 1em 0;
                    padding: 0.5em 0 0.5em 1em;
                    border-left: 3px solid #007AFF;
                    color: #666;
                    font-style: italic;
                    background-color: rgba(0, 122, 255, 0.05);
                    border-radius: 0 8px 8px 0;
                }
                
                /* Code */
                code {
                    font-family: 'SF Mono', Monaco, 'Cascadia Code', monospace;
                    font-size: 0.9em;
                    background-color: #f5f5f5;
                    color: #d73a49;
                    padding: 2px 4px;
                    border-radius: 3px;
                }
                
                pre {
                    font-family: 'SF Mono', Monaco, 'Cascadia Code', monospace;
                    font-size: 0.85em;
                    background-color: #f5f5f5;
                    color: #333;
                    padding: 1em;
                    border-radius: 8px;
                    overflow-x: auto;
                    margin: 1em 0;
                    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
                }
                
                pre code {
                    background: none;
                    color: inherit;
                    padding: 0;
                }
                
                /* Tables */
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 1em 0;
                    border-radius: 8px;
                    overflow: hidden;
                    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
                }
                
                th, td {
                    padding: 0.75em;
                    text-align: left;
                    border-bottom: 1px solid #e0e0e0;
                }
                
                th {
                    background-color: #f8f9fa;
                    font-weight: 600;
                }
                
                tr:last-child td {
                    border-bottom: none;
                }
                
                /* Email-specific styles */
                .email-signature {
                    margin-top: 2em;
                    padding-top: 1em;
                    border-top: 1px solid #e0e0e0;
                    font-size: 0.9em;
                    color: #666;
                }
                
                /* Responsive adjustments */
                @media (max-width: 480px) {
                    body {
                        padding: 16px;
                        font-size: 16px;
                    }
                    
                    h1 { font-size: 1.4em; }
                    h2 { font-size: 1.25em; }
                    h3 { font-size: 1.1em; }
                    
                    table {
                        font-size: 0.9em;
                    }
                    
                    th, td {
                        padding: 0.5em;
                    }
                }
            </style>
            <script>
                function notifyHeight() {
                    const height = Math.max(
                        document.body.scrollHeight,
                        document.body.offsetHeight,
                        document.documentElement.clientHeight,
                        document.documentElement.scrollHeight,
                        document.documentElement.offsetHeight
                    );
                    
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.heightHandler) {
                        window.webkit.messageHandlers.heightHandler.postMessage(height);
                    }
                }
                
                document.addEventListener('DOMContentLoaded', function() {
                    // Notify initial height
                    setTimeout(notifyHeight, 100);
                    
                    // Monitor for changes
                    const observer = new MutationObserver(function(mutations) {
                        setTimeout(notifyHeight, 50);
                    });
                    
                    observer.observe(document.body, {
                        childList: true,
                        subtree: true,
                        attributes: true,
                        attributeFilter: ['style', 'class']
                    });
                    
                    // Monitor for image loads
                    const images = document.querySelectorAll('img');
                    images.forEach(function(img) {
                        if (img.complete) {
                            setTimeout(notifyHeight, 50);
                        } else {
                            img.addEventListener('load', function() {
                                setTimeout(notifyHeight, 50);
                            });
                        }
                    });
                    
                    // Handle window resize
                    let resizeTimeout;
                    window.addEventListener('resize', function() {
                        clearTimeout(resizeTimeout);
                        resizeTimeout = setTimeout(notifyHeight, 100);
                    });
                });
            </script>
        </head>
        <body>
            \(content)
        </body>
        </html>
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let webViewManager: AppleMailWebViewManager
        
        init(webViewManager: AppleMailWebViewManager) {
            self.webViewManager = webViewManager
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Backup height calculation se il JavaScript fallisce
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, error in
                    if let height = result as? CGFloat {
                        self?.webViewManager.updateContentHeight(height)
                    }
                }
            }
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightHandler", let height = message.body as? CGFloat {
                webViewManager.updateContentHeight(height)
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Permetti la navigazione locale, apri link esterni in Safari
            if let url = navigationAction.request.url {
                if url.scheme == "http" || url.scheme == "https" {
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}

// MARK: - Apple Mail Quick Action Button Style
struct AppleMailQuickActionButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Apple Mail Share Sheet
struct AppleMailShareSheet: UIViewControllerRepresentable {
    let email: EmailMessage
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let items: [Any] = [
            "Email: \(email.subject)",
            "Da: \(email.from)",
            "Data: \(formatDate(email.date))",
            "",
            email.body
        ]
        
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        activityViewController.excludedActivityTypes = [
            .assignToContact,
            .saveToCameraRoll,
            .postToFlickr,
            .postToVimeo
        ]
        
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
}

// ResponseType già definito in EmailDetailView - non ridefinire