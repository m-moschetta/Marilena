import SwiftUI
import WebKit
import Combine

// MARK: - Unified Email HTML Renderer
/// Sistema unificato per il rendering delle email HTML
/// Risolve tutti i problemi di visualizzazione bianca e inconsistenze

public struct EmailHTMLRenderer: View {
    let htmlContent: String
    let email: EmailMessage
    
    @StateObject private var renderer = EmailHTMLWebViewManager()
    @Environment(\.colorScheme) private var colorScheme
    
    public init(email: EmailMessage) {
        self.htmlContent = email.body
        self.email = email
    }
    
    public var body: some View {
        EmailHTMLWebView(
            htmlContent: htmlContent,
            email: email,
            renderer: renderer,
            colorScheme: colorScheme
        )
        .frame(
            minHeight: 200,
            idealHeight: max(renderer.contentHeight, 200),
            maxHeight: min(max(renderer.contentHeight, 200), 2000)
        )
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .onAppear {
            print("📧 EmailHTMLRenderer: Rendering email - \(email.subject)")
            print("📧 EmailHTMLRenderer: HTML Content length: \(htmlContent.count)")
            print("📧 EmailHTMLRenderer: Color scheme: \(colorScheme)")
        }
    }
}

// MARK: - Email HTML WebView Manager
class EmailHTMLWebViewManager: NSObject, ObservableObject {
    @Published var contentHeight: CGFloat = 300
    @Published var isLoading = true
    @Published var hasError = false
    @Published var errorMessage = ""
    
    private var heightUpdateTimer: Timer?
    
    func updateContentHeight(_ height: CGFloat) {
        DispatchQueue.main.async {
            // Throttle updates per performance
            self.heightUpdateTimer?.invalidate()
            
            self.heightUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
                let minHeight: CGFloat = 200
                let maxHeight: CGFloat = 2000
                let safeHeight = max(min(height, maxHeight), minHeight)
                
                if abs(self.contentHeight - safeHeight) > 10 {
                    print("📧 EmailHTMLRenderer: Height update: \(height) → \(safeHeight)")
                    self.contentHeight = safeHeight
                }
                
                self.isLoading = false
            }
        }
    }
    
    func setError(_ message: String) {
        DispatchQueue.main.async {
            self.hasError = true
            self.errorMessage = message
            self.isLoading = false
            print("❌ EmailHTMLRenderer: Error - \(message)")
        }
    }
    
    func resetState() {
        DispatchQueue.main.async {
            self.contentHeight = 300
            self.isLoading = true
            self.hasError = false
            self.errorMessage = ""
        }
    }
}

// MARK: - Email HTML WebView
struct EmailHTMLWebView: UIViewRepresentable {
    let htmlContent: String
    let email: EmailMessage
    @ObservedObject var renderer: EmailHTMLWebViewManager
    let colorScheme: ColorScheme
    
    func makeCoordinator() -> Coordinator {
        Coordinator(renderer: renderer)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        print("📧 EmailHTMLWebView: Creating WKWebView")
        
        // Robust WebView configuration
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.suppressesIncrementalRendering = false
        configuration.allowsAirPlayForMediaPlayback = false
        configuration.dataDetectorTypes = [.phoneNumber, .link, .address]
        
        // JavaScript message handler for height calculation
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "heightHandler")
        contentController.add(context.coordinator, name: "errorHandler")
        configuration.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // Critical WebView settings for proper rendering
        webView.backgroundColor = UIColor.systemBackground
        webView.isOpaque = true  // Changed from false to true for better rendering
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.backgroundColor = UIColor.systemBackground
        
        // Set minimum frame to prevent zero-size issues
        webView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 300)
        
        print("📧 EmailHTMLWebView: WebView created successfully")
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        print("📧 EmailHTMLWebView: Updating WebView")
        print("📧 EmailHTMLWebView: HTML content length: \(htmlContent.count)")
        print("📧 EmailHTMLWebView: Color scheme: \(colorScheme)")
        
        let styledHTML = generateRobustHTML(content: htmlContent, colorScheme: colorScheme)
        
        print("📧 EmailHTMLWebView: Generated HTML length: \(styledHTML.count)")
        print("📧 EmailHTMLWebView: Generated HTML preview: \(String(styledHTML.prefix(300)))")
        
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }
    
    private func generateRobustHTML(content: String, colorScheme: ColorScheme) -> String {
        let isDark = colorScheme == .dark
        
        // Dynamic colors based on color scheme
        let textColor = isDark ? "#FFFFFF" : "#000000"
        let backgroundColor = isDark ? "#1C1C1E" : "#FFFFFF"
        let linkColor = isDark ? "#0A84FF" : "#007AFF"
        let secondaryColor = isDark ? "#8E8E93" : "#6D6D70"
        let borderColor = isDark ? "#38383A" : "#C6C6C8"
        
        return """
        <!DOCTYPE html>
        <html lang="it">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <meta name="color-scheme" content="\(isDark ? "dark" : "light")">
            <title>Email Content</title>
            <style>
                * {
                    box-sizing: border-box;
                    -webkit-text-size-adjust: 100%;
                    -webkit-tap-highlight-color: transparent;
                }
                
                html, body {
                    margin: 0;
                    padding: 0;
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', Arial, sans-serif;
                    font-size: 17px;
                    line-height: 1.5;
                    color: \(textColor) !important;
                    background-color: \(backgroundColor) !important;
                    word-wrap: break-word;
                    overflow-wrap: break-word;
                    -webkit-font-smoothing: antialiased;
                    text-rendering: optimizeLegibility;
                    min-height: 200px;
                }
                
                body {
                    padding: 20px;
                    max-width: 100%;
                    overflow-x: hidden;
                }
                
                /* Force text colors */
                p, div, span, td, th, h1, h2, h3, h4, h5, h6, li, blockquote {
                    color: \(textColor) !important;
                }
                
                /* Typography */
                p {
                    margin: 0 0 1em 0;
                    padding: 0;
                    color: \(textColor) !important;
                }
                
                h1, h2, h3, h4, h5, h6 {
                    font-weight: 600;
                    margin: 1.5em 0 0.5em 0;
                    line-height: 1.25;
                    color: \(textColor) !important;
                }
                
                h1 { font-size: 1.5em; }
                h2 { font-size: 1.3em; }
                h3 { font-size: 1.15em; }
                
                /* Links */
                a {
                    color: \(linkColor) !important;
                    text-decoration: none;
                }
                
                a:hover {
                    text-decoration: underline;
                }
                
                /* Images */
                img {
                    max-width: 100% !important;
                    height: auto !important;
                    display: block;
                    margin: 1em 0;
                    border-radius: 8px;
                }
                
                /* Lists */
                ul, ol {
                    margin: 1em 0;
                    padding-left: 1.5em;
                }
                
                li {
                    margin: 0.25em 0;
                    color: \(textColor) !important;
                }
                
                /* Tables */
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 1em 0;
                    border: 1px solid \(borderColor);
                    background-color: \(backgroundColor) !important;
                }
                
                th, td {
                    padding: 0.75em;
                    text-align: left;
                    border: 1px solid \(borderColor);
                    color: \(textColor) !important;
                    background-color: \(backgroundColor) !important;
                }
                
                th {
                    font-weight: 600;
                    background-color: \(isDark ? "#2C2C2E" : "#F2F2F7") !important;
                }
                
                /* Blockquotes */
                blockquote {
                    margin: 1em 0;
                    padding: 0.5em 0 0.5em 1em;
                    border-left: 3px solid \(linkColor);
                    color: \(secondaryColor) !important;
                    background-color: \(isDark ? "#1C1C1E" : "#F9F9F9") !important;
                    border-radius: 0 8px 8px 0;
                }
                
                /* Code */
                code {
                    font-family: 'SF Mono', Monaco, 'Cascadia Code', monospace;
                    font-size: 0.9em;
                    background-color: \(isDark ? "#2C2C2E" : "#F2F2F7") !important;
                    color: \(textColor) !important;
                    padding: 2px 6px;
                    border-radius: 4px;
                }
                
                pre {
                    font-family: 'SF Mono', Monaco, 'Cascadia Code', monospace;
                    font-size: 0.85em;
                    background-color: \(isDark ? "#1C1C1E" : "#F2F2F7") !important;
                    color: \(textColor) !important;
                    padding: 1em;
                    border-radius: 8px;
                    overflow-x: auto;
                    margin: 1em 0;
                    border: 1px solid \(borderColor);
                }
                
                /* Override any email-specific styles that might cause invisibility */
                .moz-text-html body,
                [data-ogsc],
                [style*="color: white"],
                [style*="color: #ffffff"],
                [style*="color: #fff"] {
                    color: \(textColor) !important;
                }
                
                /* Force visibility of hidden content */
                [style*="display: none"],
                [style*="visibility: hidden"] {
                    display: block !important;
                    visibility: visible !important;
                }
                
                /* Email signature styles */
                .email-signature {
                    margin-top: 2em;
                    padding-top: 1em;
                    border-top: 1px solid \(borderColor);
                    font-size: 0.9em;
                    color: \(secondaryColor) !important;
                }
                
                /* Responsive design */
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
                
                /* Debug styles - remove in production */
                .debug-info {
                    position: fixed;
                    top: 10px;
                    right: 10px;
                    background: rgba(255, 0, 0, 0.1);
                    padding: 5px;
                    font-size: 12px;
                    z-index: 9999;
                }
            </style>
            <script>
                console.log('📧 EmailHTML: DOM loading started');
                
                function calculateHeight() {
                    const height = Math.max(
                        document.body.scrollHeight,
                        document.body.offsetHeight,
                        document.documentElement.clientHeight,
                        document.documentElement.scrollHeight,
                        document.documentElement.offsetHeight
                    );
                    
                    console.log('📧 EmailHTML: Calculated height:', height);
                    
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.heightHandler) {
                        window.webkit.messageHandlers.heightHandler.postMessage(height);
                    }
                    
                    return height;
                }
                
                function reportError(message) {
                    console.error('📧 EmailHTML: Error:', message);
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.errorHandler) {
                        window.webkit.messageHandlers.errorHandler.postMessage(message);
                    }
                }
                
                document.addEventListener('DOMContentLoaded', function() {
                    console.log('📧 EmailHTML: DOM Content Loaded');
                    
                    // Initial height calculation
                    setTimeout(calculateHeight, 100);
                    
                    // Monitor for changes
                    const observer = new MutationObserver(function(mutations) {
                        console.log('📧 EmailHTML: DOM mutation detected');
                        setTimeout(calculateHeight, 50);
                    });
                    
                    observer.observe(document.body, {
                        childList: true,
                        subtree: true,
                        attributes: true,
                        attributeFilter: ['style', 'class']
                    });
                    
                    // Monitor image loads
                    const images = document.querySelectorAll('img');
                    console.log('📧 EmailHTML: Found', images.length, 'images');
                    
                    images.forEach(function(img, index) {
                        if (img.complete) {
                            console.log('📧 EmailHTML: Image', index, 'already loaded');
                            setTimeout(calculateHeight, 50);
                        } else {
                            img.addEventListener('load', function() {
                                console.log('📧 EmailHTML: Image', index, 'loaded');
                                setTimeout(calculateHeight, 50);
                            });
                            img.addEventListener('error', function() {
                                console.log('📧 EmailHTML: Image', index, 'failed to load');
                                setTimeout(calculateHeight, 50);
                            });
                        }
                    });
                    
                    // Handle window resize
                    let resizeTimeout;
                    window.addEventListener('resize', function() {
                        clearTimeout(resizeTimeout);
                        resizeTimeout = setTimeout(calculateHeight, 100);
                    });
                    
                    // Debug info
                    const debugInfo = document.createElement('div');
                    debugInfo.className = 'debug-info';
                    debugInfo.textContent = 'Color: \(colorScheme == .dark ? "Dark" : "Light")';
                    document.body.appendChild(debugInfo);
                    
                    // Remove debug info after 3 seconds
                    setTimeout(function() {
                        debugInfo.remove();
                    }, 3000);
                });
                
                window.addEventListener('load', function() {
                    console.log('📧 EmailHTML: Window fully loaded');
                    setTimeout(calculateHeight, 200);
                });
                
                // Error handling
                window.addEventListener('error', function(e) {
                    reportError('JavaScript error: ' + e.message);
                });
            </script>
        </head>
        <body>
            <!-- Email content injection -->
            \(content)
            
            <!-- Fallback content if email is empty -->
            <script>
                if (document.body.textContent.trim().length === 0) {
                    document.body.innerHTML = '<p style="color: \(textColor) !important; text-align: center; padding: 2em;">Contenuto email vuoto</p>';
                    calculateHeight();
                }
            </script>
        </body>
        </html>
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let renderer: EmailHTMLWebViewManager
        
        init(renderer: EmailHTMLWebViewManager) {
            self.renderer = renderer
        }
        
        // MARK: - Navigation Delegate
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("📧 EmailHTMLWebView: Navigation finished")
            
            // Backup height calculation if JavaScript fails
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, error in
                    if let height = result as? CGFloat, height > 0 {
                        print("📧 EmailHTMLWebView: Backup height calculation: \(height)")
                        self?.renderer.updateContentHeight(height)
                    } else if let error = error {
                        print("❌ EmailHTMLWebView: Backup height calculation failed: \(error)")
                        self?.renderer.setError("Height calculation failed")
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ EmailHTMLWebView: Navigation failed: \(error.localizedDescription)")
            renderer.setError("Failed to load email content: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ EmailHTMLWebView: Provisional navigation failed: \(error.localizedDescription)")
            renderer.setError("Failed to start loading email: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Handle external links
            if let url = navigationAction.request.url {
                if url.scheme == "http" || url.scheme == "https" {
                    print("📧 EmailHTMLWebView: Opening external URL: \(url)")
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
        
        // MARK: - Script Message Handler
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "heightHandler":
                if let height = message.body as? CGFloat, height > 0 {
                    print("📧 EmailHTMLWebView: Received height from JavaScript: \(height)")
                    renderer.updateContentHeight(height)
                }
            case "errorHandler":
                if let errorMessage = message.body as? String {
                    print("❌ EmailHTMLWebView: Received error from JavaScript: \(errorMessage)")
                    renderer.setError(errorMessage)
                }
            default:
                break
            }
        }
        
        // MARK: - UI Delegate
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Handle popup windows by opening in the same view
            if let url = navigationAction.request.url {
                UIApplication.shared.open(url)
            }
            return nil
        }
    }
}

// MARK: - HTML Content Detection (Unified)
public struct EmailContentAnalyzer {
    public static func isHTMLContent(_ content: String) -> Bool {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedContent.isEmpty else { return false }
        
        // 1. Check for complete HTML documents
        if trimmedContent.localizedCaseInsensitiveContains("<!DOCTYPE") ||
           trimmedContent.localizedCaseInsensitiveContains("<html") ||
           trimmedContent.localizedCaseInsensitiveContains("</html>") {
            return true
        }
        
        // 2. Check for common HTML tags
        let htmlTags = [
            "<html", "<body", "<div", "<p>", "<br", "<strong", "<em", "<ul", "<ol", "<li",
            "<h1", "<h2", "<h3", "<h4", "<h5", "<h6", "<span", "<a ", "<img", "<table",
            "<tr", "<td", "<th", "<blockquote", "<code", "<pre", "<b>", "<i>", "<u>",
            "<center", "<font", "<style", "<script", "<meta", "<link", "<head"
        ]
        
        let containsHTMLTags = htmlTags.contains { tag in
            trimmedContent.localizedCaseInsensitiveContains(tag)
        }
        
        // 3. Check for HTML entities
        let containsHTMLEntities = trimmedContent.contains("&") && (
            trimmedContent.contains("&#") ||
            trimmedContent.contains("&lt;") ||
            trimmedContent.contains("&gt;") ||
            trimmedContent.contains("&amp;") ||
            trimmedContent.contains("&nbsp;") ||
            trimmedContent.contains("&quot;")
        )
        
        // 4. Check for HTML attributes
        let containsHTMLAttrs = trimmedContent.contains("style=") ||
                               trimmedContent.contains("class=") ||
                               trimmedContent.contains("id=") ||
                               trimmedContent.contains("href=") ||
                               trimmedContent.contains("src=")
        
        // 5. Advanced pattern matching
        let htmlPatterns = [
            #"<\w+[^>]*>"#,  // Tags with attributes
            #"</\w+>"#       // Closing tags
        ]
        
        let containsHTMLPatterns = htmlPatterns.contains { pattern in
            trimmedContent.range(of: pattern, options: .regularExpression) != nil
        }
        
        let isHTML = containsHTMLTags || containsHTMLEntities || containsHTMLAttrs || containsHTMLPatterns
        
        print("📧 EmailContentAnalyzer: Content analysis for \(trimmedContent.count) chars")
        print("📧 EmailContentAnalyzer: Contains HTML tags: \(containsHTMLTags)")
        print("📧 EmailContentAnalyzer: Contains HTML entities: \(containsHTMLEntities)")
        print("📧 EmailContentAnalyzer: Contains HTML attributes: \(containsHTMLAttrs)")
        print("📧 EmailContentAnalyzer: Contains HTML patterns: \(containsHTMLPatterns)")
        print("📧 EmailContentAnalyzer: Final result: \(isHTML ? "HTML" : "Plain text")")
        
        return isHTML
    }
}