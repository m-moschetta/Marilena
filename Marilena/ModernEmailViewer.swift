import SwiftUI
import WebKit
import Combine
#if canImport(MessageUI)
import MessageUI
#endif

// MARK: - Modern Email Viewer
/// Nuovo visualizzatore email moderno ispirato al design della newsletter Supabase
/// Design pulito, semplice e affidabile

struct ModernEmailViewer: View {
    let email: EmailMessage
    @ObservedObject var emailService: EmailService
    @ObservedObject var aiService: EmailAIService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // States
    @State private var showingReplySheet = false
    @State private var showingForwardSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var showingComposeWithDraft = false
    
    // AI States
    @State private var analysis: EmailAnalysis?
    @State private var summary: String?
    @State private var showingAI = false  // AI panel collapsed by default
    @State private var selectedDraft: EmailDraft?
    
    // HTML rendered via Core/EmailHTMLRenderer
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - AI Panel
            ModernEmailAIPanel(
                email: email,
                aiService: aiService,
                analysis: $analysis,
                summary: $summary,
                showingAI: $showingAI
            ) { draft in
                selectedDraft = draft
                showingComposeWithDraft = true
            }
            
            // MARK: - Content
            ScrollView {
                VStack(spacing: 0) {
                    // Email metadata
                    ModernEmailMetadata(email: email)
                    
                    Divider()
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    
                    // Email content
                    ModernEmailContent(email: email)
                    
                    // Bottom spacing
                    Color.clear.frame(height: 100)
                }
            }
        }
        .background(Color(UIColor.systemBackground))
        .navigationBarBackButtonHidden(false)
        .toolbar {
            // Optional: minimal trailing actions (share)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .onAppear {
            Task {
                do {
                    try await emailService.markEmailAsRead(email.id)
                } catch {
                    print("Failed to mark email as read: \(error.localizedDescription)")
                }
            }
        }
        // MARK: - Sheets
        .sheet(isPresented: $showingReplySheet) {
            ModernComposeView(
                replyTo: email,
                initialTo: email.from,
                initialSubject: "Re: \(email.subject)"
            )
        }
        .sheet(isPresented: $showingForwardSheet) {
            let forwardData = emailService.prepareForwardEmail(email)
            ModernComposeView(
                initialSubject: forwardData.subject,
                initialBody: forwardData.body
            )
        }
        .sheet(isPresented: $showingComposeWithDraft) {
            if let draft = selectedDraft {
                ModernComposeView(
                    replyTo: draft.originalEmail,
                    initialTo: draft.originalEmail.from,
                    initialSubject: "Re: \(draft.originalEmail.subject)",
                    initialBody: draft.content
                )
            }
        }
        .confirmationDialog("Elimina Email", isPresented: $showingDeleteAlert) {
            Button("Elimina", role: .destructive) {
                Task {
                    do {
                        try await emailService.deleteEmail(email.id)
                        dismiss()
                    } catch {
                        print("Failed to delete email: \(error.localizedDescription)")
                    }
                }
            }
            Button("Annulla", role: .cancel) { }
        } message: {
            Text("Sei sicuro di voler eliminare questa email?")
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [email.subject, email.body])
        }
    }
}

// MARK: - Modern Email Header
struct ModernEmailHeader: View {
    let email: EmailMessage
    let onBack: () -> Void
    let onReply: () -> Void
    let onForward: () -> Void
    let onDelete: () -> Void
    let onShare: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Back button
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                    Text("Indietro")
                        .font(.system(size: 17))
                }
                .foregroundStyle(.blue)
            }
            .padding(.leading, 16)
            
            Spacer()
            
            // Subject (truncated)
            Text(email.subject.isEmpty ? "Nessun oggetto" : email.subject)
                .font(.system(size: 17, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.primary)
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 20) {
                Button(action: onReply) {
                    Image(systemName: "arrowshape.turn.up.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.blue)
                }
                
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.blue)
                }
                
                Menu {
                    Button(action: onForward) {
                        Label("Inoltra", systemImage: "arrowshape.turn.up.right")
                    }
                    
                    Button(action: onDelete) {
                        Label("Elimina", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.trailing, 16)
        }
        .frame(height: 44)
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Modern Email Metadata
struct ModernEmailMetadata: View {
    let email: EmailMessage
    
    var body: some View {
        VStack(spacing: 12) {
            // From section with avatar placeholder
            HStack(spacing: 12) {
                // Avatar placeholder
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(String(email.from.prefix(1).uppercased()))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    // From
                    Text(extractDisplayName(from: email.from))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    // Email address (if different from display name)
                    if extractDisplayName(from: email.from) != email.from {
                        Text(email.from)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Date
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatDate(email.date))
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                    
                    Text(formatTime(email.date))
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Subject
            if !email.subject.isEmpty {
                HStack {
                    Text(email.subject)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func extractDisplayName(from email: String) -> String {
        // Simple display name extraction
        if let range = email.range(of: "<") {
            let displayName = String(email[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            return displayName.isEmpty ? email : displayName
        }
        return email
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Modern Email Content
struct ModernEmailContent: View {
    let email: EmailMessage

    var body: some View {
        VStack(spacing: 0) {
            if EmailContentAnalyzer.isHTMLContent(email.body) {
                EmailHTMLRenderer(email: email)
                    .padding(.horizontal, 16)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text(email.body)
                        .font(.system(size: 17))
                        .lineSpacing(4)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Modern HTML Renderer
@MainActor
class ModernHTMLRenderer: ObservableObject {
    @Published var contentHeight: CGFloat = 300
    @Published var isLoading = true
    
    func updateHeight(_ height: CGFloat) {
        let newHeight = max(height, 200)
        if abs(self.contentHeight - newHeight) > 10 {
            self.contentHeight = newHeight
        }
        self.isLoading = false
    }
}

// MARK: - Modern HTML WebView
struct ModernHTMLWebView: UIViewRepresentable {
    let htmlContent: String
    @ObservedObject var renderer: ModernHTMLRenderer
    @Environment(\.colorScheme) private var colorScheme
    
    func makeCoordinator() -> Coordinator {
        Coordinator(renderer: renderer)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.suppressesIncrementalRendering = false
        
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "heightHandler")
        config.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = UIColor.clear
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let styledHTML = generateModernHTML(content: htmlContent, colorScheme: colorScheme)
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }
    
    private func generateModernHTML(content: String, colorScheme: ColorScheme) -> String {
        let isDark = colorScheme == .dark
        let textColor = isDark ? "#FFFFFF" : "#000000"
        let backgroundColor = isDark ? "#000000" : "#FFFFFF"
        let linkColor = isDark ? "#0A84FF" : "#007AFF"
        let secondaryColor = isDark ? "#8E8E93" : "#6D6D70"
        
        return """
        <!DOCTYPE html>
        <html lang="it">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
            <style>
                * {
                    box-sizing: border-box;
                    -webkit-text-size-adjust: 100%;
                }
                
                html, body {
                    margin: 0;
                    padding: 0;
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', system-ui, sans-serif;
                    font-size: 17px;
                    line-height: 1.6;
                    color: \(textColor) !important;
                    background-color: \(backgroundColor) !important;
                    word-wrap: break-word;
                    -webkit-font-smoothing: antialiased;
                }
                
                body {
                    padding: 0;
                    max-width: 100%;
                    overflow-x: hidden;
                }
                
                /* Newsletter-style spacing inspired by Supabase */
                p {
                    margin: 0 0 1.2em 0;
                    color: \(textColor) !important;
                }
                
                h1, h2, h3, h4, h5, h6 {
                    font-weight: 600;
                    margin: 1.8em 0 0.8em 0;
                    line-height: 1.3;
                    color: \(textColor) !important;
                }
                
                h1 { font-size: 1.6em; }
                h2 { font-size: 1.4em; }
                h3 { font-size: 1.2em; }
                
                a {
                    color: \(linkColor) !important;
                    text-decoration: none;
                }
                
                a:hover {
                    text-decoration: underline;
                }
                
                img {
                    max-width: 100% !important;
                    height: auto !important;
                    display: block;
                    margin: 1.5em 0;
                    border-radius: 8px;
                }
                
                /* Clean table styling */
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 1.5em 0;
                }
                
                th, td {
                    padding: 0.8em;
                    text-align: left;
                    color: \(textColor) !important;
                }
                
                /* Newsletter-style blockquotes */
                blockquote {
                    margin: 1.5em 0;
                    padding: 1em 1.2em;
                    border-left: 4px solid \(linkColor);
                    background-color: \(isDark ? "#1C1C1E" : "#F8F9FA") !important;
                    border-radius: 0 8px 8px 0;
                    color: \(textColor) !important;
                }
                
                /* Clean list styling */
                ul, ol {
                    margin: 1.2em 0;
                    padding-left: 1.5em;
                }
                
                li {
                    margin: 0.5em 0;
                    color: \(textColor) !important;
                }
                
                /* Override any email-specific styles */
                * {
                    color: \(textColor) !important;
                }
                
                /* Force link colors */
                a, a * {
                    color: \(linkColor) !important;
                }
            </style>
            <script>
                function calculateHeight() {
                    const height = Math.max(
                        document.body.scrollHeight,
                        document.body.offsetHeight,
                        document.documentElement.scrollHeight
                    );
                    
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.heightHandler) {
                        window.webkit.messageHandlers.heightHandler.postMessage(height);
                    }
                }
                
                document.addEventListener('DOMContentLoaded', function() {
                    setTimeout(calculateHeight, 100);
                    
                    // Monitor for content changes
                    const observer = new MutationObserver(function() {
                        setTimeout(calculateHeight, 50);
                    });
                    
                    observer.observe(document.body, {
                        childList: true,
                        subtree: true,
                        attributes: true
                    });
                    
                    // Handle image loads
                    document.querySelectorAll('img').forEach(function(img) {
                        if (img.complete) {
                            setTimeout(calculateHeight, 50);
                        } else {
                            img.addEventListener('load', function() {
                                setTimeout(calculateHeight, 50);
                            });
                        }
                    });
                });
                
                window.addEventListener('load', function() {
                    setTimeout(calculateHeight, 200);
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
        let renderer: ModernHTMLRenderer
        
        init(renderer: ModernHTMLRenderer) {
            self.renderer = renderer
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Backup height calculation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, error in
                    if let height = result as? CGFloat, height > 0 {
                        Task { @MainActor in
                            self?.renderer.updateHeight(height)
                        }
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Handle external links
            if let url = navigationAction.request.url,
               (url.scheme == "http" || url.scheme == "https") {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightHandler",
               let height = message.body as? CGFloat {
                Task { @MainActor in
                    renderer.updateHeight(height)
                }
            }
        }
    }
}

// MARK: - Share Sheet Helper
// ShareSheet è già definita in EmailCategorizationStatsView.swift
