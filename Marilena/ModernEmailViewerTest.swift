import SwiftUI

// MARK: - Modern Email Viewer Test
/// Vista di test per verificare il funzionamento del ModernEmailViewer con diversi tipi di email

struct ModernEmailViewerTest: View {
    @StateObject private var emailService = EmailService()
    @StateObject private var aiService = EmailAIService()
    
    var body: some View {
        NavigationView {
            List {
                Section("Test Email Types") {
                    // Test Newsletter (HTML)
                    NavigationLink("Newsletter HTML (Supabase Style)") {
                        ModernEmailViewer(
                            email: createNewsletterEmail(),
                            emailService: emailService,
                            aiService: aiService
                        )
                    }
                    
                    // Test Plain Text
                    NavigationLink("Email Plain Text") {
                        ModernEmailViewer(
                            email: createPlainTextEmail(),
                            emailService: emailService,
                            aiService: aiService
                        )
                    }
                    
                    // Test HTML complesso
                    NavigationLink("Email HTML Complesso") {
                        ModernEmailViewer(
                            email: createComplexHTMLEmail(),
                            emailService: emailService,
                            aiService: aiService
                        )
                    }
                    
                    // Test email senza oggetto
                    NavigationLink("Email Senza Oggetto") {
                        ModernEmailViewer(
                            email: createNoSubjectEmail(),
                            emailService: emailService,
                            aiService: aiService
                        )
                    }
                }
                
                Section("Confronto Viewer") {
                    NavigationLink("Viewer Classico (AppleMailClone)") {
                        AppleMailCloneView(
                            email: createNewsletterEmail(),
                            emailService: emailService,
                            aiService: aiService
                        )
                    }
                    
                    NavigationLink("Viewer Moderno (ModernEmailViewer)") {
                        ModernEmailViewer(
                            email: createNewsletterEmail(),
                            emailService: emailService,
                            aiService: aiService
                        )
                    }
                }
            }
            .navigationTitle("Test Email Viewer")
        }
    }
    
    // MARK: - Test Email Creation
    
    private func createNewsletterEmail() -> EmailMessage {
        EmailMessage(
            id: "newsletter-test",
            from: "Ant at Supabase <ant@supabase.com>",
            to: ["test@example.com"],
            subject: "Supabase Update — August 2025",
            body: """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
            </head>
            <body style="font-family: -apple-system, BlinkMacSystemFont, sans-serif; line-height: 1.6; color: #333;">
                <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                    <div style="text-align: center; margin-bottom: 2em;">
                        <h1 style="color: #1a1a1a; font-size: 1.8em; margin-bottom: 0.5em;">Supabase Update — August 2025</h1>
                        <div style="color: #10b981; font-weight: 600; font-size: 1.1em;">🚀</div>
                    </div>
                    
                    <p style="font-size: 1.1em; margin-bottom: 1.5em;">Hey there 👋,</p>
                    
                    <p style="margin-bottom: 1.5em;">In addition to Launch Week 15, here's everything that happened with Supabase in the last month:</p>
                    
                    <div style="background: #f8f9fa; padding: 1.5em; border-radius: 8px; margin: 2em 0; border-left: 4px solid #10b981;">
                        <h2 style="color: #1a1a1a; font-size: 1.3em; margin-bottom: 1em;">🔑 New API Keys + JWT Signing Keys</h2>
                        <p style="margin-bottom: 1em;">Control the keys used to sign JSON Web Tokens for your project</p>
                        <div style="background: #1a1a1a; color: #fff; padding: 1em; border-radius: 6px; font-family: monospace; font-size: 0.9em;">
                            <div>JWT Keys</div>
                            <div>Control keys used to sign JSON Web Tokens for project</div>
                        </div>
                    </div>
                    
                    <h3 style="color: #1a1a1a; font-size: 1.2em; margin: 2em 0 1em 0;">✨ Feature Highlights</h3>
                    <ul style="margin-bottom: 2em;">
                        <li style="margin-bottom: 0.5em;">Enhanced authentication flows</li>
                        <li style="margin-bottom: 0.5em;">Improved database performance</li>
                        <li style="margin-bottom: 0.5em;">New edge functions capabilities</li>
                        <li style="margin-bottom: 0.5em;">Advanced security features</li>
                    </ul>
                    
                    <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 2em; border-radius: 12px; color: white; text-align: center; margin: 2em 0;">
                        <h3 style="margin-bottom: 1em; font-size: 1.3em;">🎯 What's Next?</h3>
                        <p style="margin-bottom: 1.5em; opacity: 0.9;">Stay tuned for more exciting updates coming your way.</p>
                        <a href="#" style="background: rgba(255,255,255,0.2); color: white; padding: 0.8em 1.5em; text-decoration: none; border-radius: 6px; font-weight: 600;">Learn More</a>
                    </div>
                    
                    <div style="text-align: center; margin-top: 3em; padding-top: 2em; border-top: 1px solid #e5e5e5; color: #666; font-size: 0.9em;">
                        <p>Best regards,<br><strong>The Supabase Team</strong></p>
                    </div>
                </div>
            </body>
            </html>
            """,
            date: Date(),
            isRead: false,
            category: .newsletter
        )
    }
    
    private func createPlainTextEmail() -> EmailMessage {
        EmailMessage(
            id: "plain-test",
            from: "Mario Moschetta <mario@example.com>",
            to: ["recipient@example.com"],
            subject: "Messaggio di testo semplice",
            body: """
            Ciao,
            
            Questo è un esempio di email in formato testo semplice.
            
            Caratteristiche:
            - Nessun formatting HTML
            - Solo testo normale
            - Facile da leggere
            - Compatibile con tutti i client email
            
            Il nuovo ModernEmailViewer dovrebbe visualizzare questo contenuto in modo pulito e leggibile, mantenendo la formattazione del testo originale.
            
            Cordiali saluti,
            Mario
            
            P.S. Questo è un test per verificare come viene gestito il testo lungo e i paragrafi multipli.
            """,
            date: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
            isRead: true,
            category: .personal
        )
    }
    
    private func createComplexHTMLEmail() -> EmailMessage {
        EmailMessage(
            id: "complex-html-test",
            from: "Newsletter Service <newsletter@company.com>",
            to: ["user@example.com"],
            subject: "Email HTML con tabelle e immagini",
            body: """
            <html>
            <body>
                <div style="max-width: 600px; margin: 0 auto; font-family: Arial, sans-serif;">
                    <h1 style="color: #2563eb; text-align: center;">Newsletter Aziendale</h1>
                    
                    <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
                        <thead>
                            <tr style="background-color: #f3f4f6;">
                                <th style="padding: 12px; text-align: left; border: 1px solid #d1d5db;">Prodotto</th>
                                <th style="padding: 12px; text-align: left; border: 1px solid #d1d5db;">Prezzo</th>
                                <th style="padding: 12px; text-align: left; border: 1px solid #d1d5db;">Disponibilità</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr>
                                <td style="padding: 12px; border: 1px solid #d1d5db;">iPhone 15 Pro</td>
                                <td style="padding: 12px; border: 1px solid #d1d5db;">€1299</td>
                                <td style="padding: 12px; border: 1px solid #d1d5db;">✅ Disponibile</td>
                            </tr>
                            <tr style="background-color: #f9fafb;">
                                <td style="padding: 12px; border: 1px solid #d1d5db;">MacBook Air M3</td>
                                <td style="padding: 12px; border: 1px solid #d1d5db;">€1599</td>
                                <td style="padding: 12px; border: 1px solid #d1d5db;">⏳ Limitato</td>
                            </tr>
                            <tr>
                                <td style="padding: 12px; border: 1px solid #d1d5db;">AirPods Pro</td>
                                <td style="padding: 12px; border: 1px solid #d1d5db;">€299</td>
                                <td style="padding: 12px; border: 1px solid #d1d5db;">✅ Disponibile</td>
                            </tr>
                        </tbody>
                    </table>
                    
                    <blockquote style="margin: 20px 0; padding: 15px; background-color: #fef3c7; border-left: 4px solid #f59e0b;">
                        <p style="margin: 0; font-style: italic;">"Il nuovo ModernEmailViewer offre una visualizzazione pulita e moderna per tutti i tipi di contenuto email."</p>
                    </blockquote>
                    
                    <h2 style="color: #1f2937;">Funzionalità principali:</h2>
                    <ul>
                        <li>Rendering HTML semplificato e affidabile</li>
                        <li>Design ispirato alle newsletter moderne</li>
                        <li>Gestione automatica dell'altezza del contenuto</li>
                        <li>Supporto per modalità chiara e scura</li>
                    </ul>
                    
                    <div style="text-align: center; margin-top: 30px;">
                        <a href="#" style="background-color: #2563eb; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px;">Call to Action</a>
                    </div>
                </div>
            </body>
            </html>
            """,
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            isRead: false,
            category: .promotional
        )
    }
    
    private func createNoSubjectEmail() -> EmailMessage {
        EmailMessage(
            id: "no-subject-test",
            from: "Test User <test@example.com>",
            to: ["recipient@example.com"],
            subject: "",
            body: "Questa è un'email senza oggetto. Il ModernEmailViewer dovrebbe gestire questo caso mostrando 'Nessun oggetto' nell'header.",
            date: Calendar.current.date(byAdding: .minute, value: -30, to: Date()) ?? Date(),
            isRead: false,
            category: .personal
        )
    }
}

// MARK: - Preview
#Preview {
    ModernEmailViewerTest()
}