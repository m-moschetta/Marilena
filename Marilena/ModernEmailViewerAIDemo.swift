import SwiftUI

// MARK: - Modern Email Viewer AI Demo
/// Demo completa di tutte le funzionalità AI integrate nel ModernEmailViewer

struct ModernEmailViewerAIDemo: View {
    @StateObject private var emailService = EmailService()
    @StateObject private var aiService = EmailAIService()
    
    var body: some View {
        NavigationView {
            List {
                Section("🤖 Funzionalità AI Complete") {
                    NavigationLink("Demo Email Aziendale") {
                        ModernEmailViewer(
                            email: createBusinessEmail(),
                            emailService: emailService,
                            aiService: aiService
                        )
                    }
                    
                    NavigationLink("Demo Newsletter Complessa") {
                        ModernEmailViewer(
                            email: createComplexNewsletter(),
                            emailService: emailService,
                            aiService: aiService
                        )
                    }
                    
                    NavigationLink("Demo Email Urgente") {
                        ModernEmailViewer(
                            email: createUrgentEmail(),
                            emailService: emailService,
                            aiService: aiService
                        )
                    }
                }
                
                Section("✍️ Composizione AI") {
                    NavigationLink("Nuovo Email con AI") {
                        ModernComposeView()
                    }
                    
                    NavigationLink("Risposta Assistita AI") {
                        ModernComposeView(
                            replyTo: createBusinessEmail(),
                            initialTo: "mario@company.com",
                            initialSubject: "Re: Proposta di Collaborazione",
                            initialBody: ""
                        )
                    }
                }
                
                Section("🎯 Test Specifici") {
                    NavigationLink("Analisi Sentiment") {
                        ModernEmailViewer(
                            email: createSentimentTestEmail(),
                            emailService: emailService,
                            aiService: aiService
                        )
                    }
                    
                    NavigationLink("Traduzione Multilingua") {
                        ModernEmailViewer(
                            email: createMultilingualEmail(),
                            emailService: emailService,
                            aiService: aiService
                        )
                    }
                    
                    NavigationLink("Email con Allegati") {
                        ModernEmailViewer(
                            email: createEmailWithAttachments(),
                            emailService: emailService,
                            aiService: aiService
                        )
                    }
                }
                
                Section("📊 Funzionalità Avanzate") {
                    aiFeatureCard(
                        title: "Analisi Automatica",
                        description: "Priorità, categoria, sentiment",
                        icon: "brain.head.profile",
                        color: .purple
                    )
                    
                    aiFeatureCard(
                        title: "Riassunto Intelligente",
                        description: "Riassunto automatico email lunghe",
                        icon: "doc.text.below.ecg",
                        color: .blue
                    )
                    
                    aiFeatureCard(
                        title: "Risposte Rapide",
                        description: "6 tipi di risposta preconfigurate",
                        icon: "bolt.fill",
                        color: .orange
                    )
                    
                    aiFeatureCard(
                        title: "Traduzione Istantanea",
                        description: "5 lingue supportate",
                        icon: "character.bubble",
                        color: .green
                    )
                    
                    aiFeatureCard(
                        title: "Composizione Assistita",
                        description: "Suggerimenti in tempo reale",
                        icon: "wand.and.stars",
                        color: .pink
                    )
                    
                    aiFeatureCard(
                        title: "Prompt Personalizzati",
                        description: "Crea le tue automazioni",
                        icon: "gearshape.fill",
                        color: .cyan
                    )
                }
            }
            .navigationTitle("Demo AI Complete")
        }
    }
    
    private func aiFeatureCard(title: String, description: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Demo Email Creation
    
    private func createBusinessEmail() -> EmailMessage {
        EmailMessage(
            id: "business-demo",
            from: "Anna Rossi <anna.rossi@techcorp.it>",
            to: ["mario@company.com"],
            subject: "Proposta di Collaborazione - Progetto AI 2025",
            body: """
            Buongiorno Mario,
            
            Spero che questa email la trovi bene. Le scrivo per proporle una collaborazione molto interessante per il prossimo anno.
            
            La nostra azienda, TechCorp Italia, sta sviluppando una piattaforma di intelligenza artificiale innovativa e saremmo interessati a discutere una possibile partnership strategica con la sua società.
            
            **Dettagli del Progetto:**
            - Budget: €150.000 - €300.000
            - Timeline: Q1-Q2 2025
            - Tecnologie: SwiftUI, AI/ML, Cloud Computing
            - Team richiesto: 5-8 sviluppatori senior
            
            Sarebbe disponibile per una call esplorativa la prossima settimana? Possiamo organizzare un incontro virtuale o di persona presso i nostri uffici a Milano.
            
            Resto in attesa di un suo gentile riscontro.
            
            Cordiali saluti,
            Anna Rossi
            Business Development Manager
            TechCorp Italia
            +39 02 1234 5678
            anna.rossi@techcorp.it
            """,
            date: Date(),
            isRead: false,
            category: .work
        )
    }
    
    private func createComplexNewsletter() -> EmailMessage {
        EmailMessage(
            id: "complex-newsletter",
            from: "OpenAI Team <newsletter@openai.com>",
            to: ["subscribers@company.com"],
            subject: "🚀 GPT-5 Launch & Developer Updates - January 2025",
            body: """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <style>
                    body { font-family: -apple-system, sans-serif; line-height: 1.6; }
                    .header { background: linear-gradient(135deg, #667eea, #764ba2); color: white; padding: 2em; text-align: center; }
                    .content { max-width: 600px; margin: 0 auto; padding: 20px; }
                    .highlight { background: #f0f8ff; padding: 1em; border-left: 4px solid #4a90e2; margin: 1em 0; }
                    .cta { background: #4a90e2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; }
                </style>
            </head>
            <body>
                <div class="header">
                    <h1>🚀 GPT-5 is Here!</h1>
                    <p>Revolutionary AI capabilities now available</p>
                </div>
                
                <div class="content">
                    <h2>What's New in GPT-5</h2>
                    <ul>
                        <li><strong>Multimodal Reasoning:</strong> Advanced image, video, and audio understanding</li>
                        <li><strong>Longer Context:</strong> Up to 1M tokens in a single conversation</li>
                        <li><strong>Better Coding:</strong> 40% improvement in programming tasks</li>
                        <li><strong>Scientific Research:</strong> PhD-level reasoning in mathematics and sciences</li>
                    </ul>
                    
                    <div class="highlight">
                        <h3>🎯 For Developers</h3>
                        <p>New API endpoints, improved rate limits, and better pricing structure. Early access starting today!</p>
                    </div>
                    
                    <h2>Pricing Updates</h2>
                    <table style="width: 100%; border-collapse: collapse;">
                        <tr style="background: #f5f5f5;">
                            <th style="padding: 8px; text-align: left;">Model</th>
                            <th style="padding: 8px; text-align: left;">Input</th>
                            <th style="padding: 8px; text-align: left;">Output</th>
                        </tr>
                        <tr>
                            <td style="padding: 8px;">GPT-5</td>
                            <td style="padding: 8px;">$10.00 / 1M tokens</td>
                            <td style="padding: 8px;">$30.00 / 1M tokens</td>
                        </tr>
                        <tr style="background: #f9f9f9;">
                            <td style="padding: 8px;">GPT-4 Turbo</td>
                            <td style="padding: 8px;">$5.00 / 1M tokens</td>
                            <td style="padding: 8px;">$15.00 / 1M tokens</td>
                        </tr>
                    </table>
                    
                    <p style="text-align: center; margin: 2em 0;">
                        <a href="#" class="cta">Get Early Access</a>
                    </p>
                    
                    <h2>🔬 Research Highlights</h2>
                    <p>GPT-5 achieves state-of-the-art performance on:</p>
                    <ul>
                        <li>Mathematical reasoning (MATH benchmark: 95.2%)</li>
                        <li>Code generation (HumanEval: 96.4%)</li>
                        <li>Scientific QA (MMLU: 94.8%)</li>
                    </ul>
                    
                    <div style="text-align: center; margin-top: 3em; padding-top: 2em; border-top: 1px solid #eee;">
                        <p><strong>The OpenAI Team</strong></p>
                        <p>Building AGI that benefits all of humanity</p>
                    </div>
                </div>
            </body>
            </html>
            """,
            date: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
            isRead: false,
            category: .newsletter
        )
    }
    
    private func createUrgentEmail() -> EmailMessage {
        EmailMessage(
            id: "urgent-demo",
            from: "System Admin <admin@company.com>",
            to: ["team@company.com"],
            subject: "🚨 URGENTE: Vulnerabilità di Sicurezza Critica",
            body: """
            ATTENZIONE: AZIONE RICHIESTA IMMEDIATAMENTE
            
            È stata identificata una vulnerabilità critica nel nostro sistema che richiede un intervento immediato.
            
            DETTAGLI:
            - Severità: CRITICA (CVSS 9.8)
            - Sistema interessato: Server di produzione
            - Impatto: Potenziale accesso non autorizzato ai dati
            - Finestra di attacco: Attiva da 4 ore
            
            AZIONI RICHIESTE:
            1. Applicare immediatamente la patch di sicurezza
            2. Riavviare tutti i servizi entro 30 minuti
            3. Verificare i log per accessi sospetti
            4. Confermare l'applicazione delle misure
            
            TIMELINE:
            - Entro 30 min: Patch applicata
            - Entro 1 ora: Sistemi riavviati
            - Entro 2 ore: Audit di sicurezza completato
            
            Per assistenza immediata contattare il SOC:
            📞 +39 02 Emergency
            📧 security@company.com
            
            Non ignorare questo messaggio.
            
            Team Sicurezza IT
            """,
            date: Calendar.current.date(byAdding: .minute, value: -15, to: Date()) ?? Date(),
            isRead: false,
            category: .work
        )
    }
    
    private func createSentimentTestEmail() -> EmailMessage {
        EmailMessage(
            id: "sentiment-test",
            from: "Cliente Insoddisfatto <cliente@email.com>",
            to: ["support@company.com"],
            subject: "Problema GRAVE con il vostro servizio - Richiedo Rimborso",
            body: """
            Sono estremamente deluso e arrabbiato per il servizio pessimo che ho ricevuto.
            
            Ho ordinato il vostro prodotto 3 settimane fa e ancora non è arrivato. Quando ho contattato l'assistenza, mi hanno dato risposte evasive e poco professionali.
            
            Questo è inaccettabile! Ho speso €500 e non ho ricevuto nulla in cambio. 
            
            PRETENDO:
            - Rimborso immediato del 100%
            - Spiegazioni dettagliate del ritardo
            - Compenso per il disagio causato
            
            Se non riceverò una risposta entro 24 ore, procederò con azioni legali.
            
            Distinti saluti (ma non troppo),
            Marco Arrabbiato
            """,
            date: Calendar.current.date(byAdding: .hour, value: -6, to: Date()) ?? Date(),
            isRead: false,
            category: .personal
        )
    }
    
    private func createMultilingualEmail() -> EmailMessage {
        EmailMessage(
            id: "multilingual-test",
            from: "International Partner <partner@global.com>",
            to: ["mario@company.com"],
            subject: "Multilingual Business Proposal - Propuesta Comercial",
            body: """
            Dear Mario,
            
            I hope this email finds you well. We are writing to propose an exciting international collaboration opportunity.
            
            **English Section:**
            Our company has been following your work in the Italian market and we're impressed by your innovative solutions.
            
            **Sección en Español:**
            Queremos proponerle una asociación estratégica que beneficie a ambas empresas en el mercado latinoamericano.
            
            **Section Française:**
            Nous serions ravis de discuter des opportunités de collaboration dans le marché européen francophone.
            
            **Deutsche Sektion:**
            Wir möchten gerne über Möglichkeiten einer Zusammenarbeit in Deutschland und Österreich sprechen.
            
            Key Benefits:
            - Expanded market reach
            - Shared technology resources  
            - Cost optimization
            - Risk mitigation
            
            Would you be available for a video conference next week? We can accommodate different time zones and languages.
            
            Best regards,
            Sarah International
            Global Business Development
            """,
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            isRead: false,
            category: .work
        )
    }
    
    private func createEmailWithAttachments() -> EmailMessage {
        EmailMessage(
            id: "attachments-test",
            from: "Design Team <design@studio.com>",
            to: ["mario@company.com"],
            subject: "📎 Materiali del Progetto - Revisione Final",
            body: """
            Ciao Mario,
            
            In allegato trovi tutti i materiali per la revisione finale del progetto.
            
            ALLEGATI INCLUSI:
            📄 Specifica_Tecnica_v3.2.pdf (2.4 MB)
            🎨 Design_Mockups_Final.sketch (15.8 MB)  
            📊 Budget_Analysis.xlsx (890 KB)
            🖼️ Logo_Variations.zip (4.2 MB)
            📹 Demo_Video.mp4 (45.6 MB)
            
            Ti prego di revisionare tutto entro venerdì e farmi sapere se ci sono modifiche da apportare.
            
            PUNTI DI ATTENZIONE:
            • Verificare la palette colori nel mockup
            • Controllare i calcoli nel budget
            • Testare il video su dispositivi mobili
            
            Per qualsiasi domanda sono disponibile su Slack o via email.
            
            Grazie!
            
            Alessia Design
            Creative Director
            +39 333 123 4567
            """,
            date: Calendar.current.date(byAdding: .hour, value: -4, to: Date()) ?? Date(),
            isRead: false,
            category: .work
        )
    }
}

// MARK: - Preview
#Preview {
    ModernEmailViewerAIDemo()
}