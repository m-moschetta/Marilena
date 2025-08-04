import Foundation

/// Servizio per la categorizzazione automatica delle email tramite OpenAI GPT-4o mini
@MainActor
public class EmailCategorizationService {
    
    // MARK: - Properties
    
    private let openAIService = OpenAIService.shared
    private let model = "gpt-4o-mini" // GPT-4o mini model
    
    // MARK: - Public Methods
    
    /// Categorizza una singola email utilizzando OpenAI
    public func categorizeEmail(_ email: EmailMessage) async -> EmailCategory {
        print("📧 EmailCategorizationService: Categorizzazione email da \(email.from)")
        
        // Crea il prompt per la categorizzazione
        let prompt = createCategorizationPrompt(
            from: email.from,
            subject: email.subject,
            preview: getEmailPreview(email.body)
        )
        
        // Invia la richiesta a OpenAI
        let messages = [
            OpenAIMessage(role: "system", content: getSystemPrompt()),
            OpenAIMessage(role: "user", content: prompt)
        ]
        
        return await withCheckedContinuation { continuation in
            openAIService.sendMessage(messages: messages, model: model) { result in
                switch result {
                case .success(let response):
                    let category = self.parseCategory(from: response)
                    print("✅ EmailCategorizationService: Email categorizzata come \(category.displayName)")
                    continuation.resume(returning: category)
                    
                case .failure(let error):
                    print("❌ EmailCategorizationService: Errore categorizzazione - \(error.localizedDescription)")
                    // Fallback alla categoria notifiche in caso di errore
                    continuation.resume(returning: .notifications)
                }
            }
        }
    }
    
    /// Categorizza un array di email in batch
    public func categorizeEmails(_ emails: [EmailMessage]) async -> [EmailMessage] {
        print("📧 EmailCategorizationService: Categorizzazione di \(emails.count) email")
        
        var categorizedEmails: [EmailMessage] = []
        
        // Processa le email in piccoli batch per evitare rate limiting
        let batchSize = 5
        let batches = emails.chunked(into: batchSize)
        
        for (index, batch) in batches.enumerated() {
            print("📧 EmailCategorizationService: Processando batch \(index + 1)/\(batches.count)")
            
            // Processa il batch corrente
            let batchResults = await withTaskGroup(of: EmailMessage.self) { group in
                for email in batch {
                    group.addTask {
                        let category = await self.categorizeEmail(email)
                        return EmailMessage(
                            id: email.id,
                            from: email.from,
                            to: email.to,
                            subject: email.subject,
                            body: email.body,
                            date: email.date,
                            isRead: email.isRead,
                            hasAttachments: email.hasAttachments,
                            emailType: email.emailType,
                            category: category
                        )
                    }
                }
                
                var results: [EmailMessage] = []
                for await result in group {
                    results.append(result)
                }
                return results
            }
            
            categorizedEmails.append(contentsOf: batchResults)
            
            // Piccola pausa tra i batch per rispettare i rate limit
            if index < batches.count - 1 {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 secondo
            }
        }
        
        print("✅ EmailCategorizationService: Categorizzazione completata per \(categorizedEmails.count) email")
        return categorizedEmails
    }
    
    // MARK: - Private Methods
    
    /// Crea il prompt system per guidare la categorizzazione
    private func getSystemPrompt() -> String {
        return """
        Sei un assistente AI specializzato nella categorizzazione automatica delle email.
        
        Le categorie disponibili sono:
        1. LAVORO - Email professionali, riunioni, progetti, clienti, colleghi
        2. PERSONALE - Email da amici, famiglia, comunicazioni personali
        3. NOTIFICHE - Newsletter, conferme, notifiche da servizi, aggiornamenti automatici
        4. PROMO - Email promozionali, marketing, offerte, spam
        
        ISTRUZIONI:
        - Analizza mittente, oggetto e anteprima del contenuto
        - Rispondi SOLO con una delle parole: LAVORO, PERSONALE, NOTIFICHE, o PROMO
        - Usa il contesto per determinare la categoria più appropriata
        - In caso di dubbio, scegli la categoria più conservativa (NOTIFICHE)
        """
    }
    
    /// Crea il prompt per categorizzare una specifica email
    private func createCategorizationPrompt(from: String, subject: String, preview: String) -> String {
        return """
        Categorizza questa email:
        
        MITTENTE: \(from)
        OGGETTO: \(subject)
        ANTEPRIMA: \(preview)
        
        Categoria:
        """
    }
    
    /// Estrae un'anteprima del contenuto dell'email (primi 200 caratteri)
    private func getEmailPreview(_ body: String) -> String {
        // Rimuovi tag HTML se presenti
        let cleanBody = body.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Limita a 200 caratteri
        let preview = String(cleanBody.prefix(200))
        
        return preview.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Converte la risposta di OpenAI in una categoria
    private func parseCategory(from response: String) -> EmailCategory {
        let cleanResponse = response.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if cleanResponse.contains("LAVORO") || cleanResponse.contains("WORK") {
            return .work
        } else if cleanResponse.contains("PERSONALE") || cleanResponse.contains("PERSONAL") {
            return .personal
        } else if cleanResponse.contains("PROMO") || cleanResponse.contains("PROMOTIONAL") {
            return .promotional
        } else {
            // Default a notifiche se non riconosce la categoria
            return .notifications
        }
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}