import Foundation
import CoreData
import UIKit

class ProfiloUtenteService {
    static let shared = ProfiloUtenteService()
    
    private init() {}
    
    // MARK: - Gestione Profilo
    
    func creaProfiloDefault(in context: NSManagedObjectContext) -> ProfiloUtente {
        let profilo = ProfiloUtente(context: context)
        profilo.uuid = UUID()
        profilo.nome = "Mario M."
        profilo.username = "mariomoschetta"
        profilo.cellulare = "+39 348 571 4055"
        profilo.bio = "Growth Hacker e Imprenditore. Pescara | Milano"
        profilo.dataNascita = Calendar.current.date(from: DateComponents(year: 1994, month: 1, day: 21))
        profilo.dataCreazione = Date()
        profilo.contestoAI = "Utente con interesse per la tecnologia e l'imprenditoria."
        profilo.profiliSocial = [:]
        
        return profilo
    }
    
    func ottieniProfiloUtente(in context: NSManagedObjectContext) -> ProfiloUtente? {
        let request = NSFetchRequest<ProfiloUtente>(entityName: "ProfiloUtente")
        request.fetchLimit = 1
        
        do {
            let risultati = try context.fetch(request)
            return risultati.first
        } catch {
            print("Errore nel recuperare il profilo utente: \(error)")
            return nil
        }
    }
    
    func salvaProfilo(_ profilo: ProfiloUtente, in context: NSManagedObjectContext) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            print("Errore nel salvare il profilo: \(error)")
            return false
        }
    }
    
    // MARK: - Aggiornamento Contesto AI
    
    func creaPromptPerAggiornamentoContesto(profiloAttuale: ProfiloUtente, messaggi: [MessaggioMarilena]) -> String {
        let messaggiRecenti = messaggi
            .sorted { (msg1: MessaggioMarilena, msg2: MessaggioMarilena) in 
                return (msg1.dataCreazione ?? Date.distantPast) > (msg2.dataCreazione ?? Date.distantPast) 
            }
            .prefix(50) // Ultimi 50 messaggi per evitare token eccessivi
        
        let messaggiTesto = messaggiRecenti
            .compactMap { $0.contenuto }
            .joined(separator: "\n")
        
        let contestoAttuale = profiloAttuale.contestoAI ?? "Nessun contesto disponibile"
        
        return """
        Analizza i seguenti messaggi dell'utente e aggiorna il suo contesto personale.
        
        CONTESTO ATTUALE:
        \(contestoAttuale)
        
        MESSAGGI RECENTI DELL'UTENTE:
        \(messaggiTesto)
        
        INFORMAZIONI PROFILO:
        Nome: \(profiloAttuale.nome ?? "Non specificato")
        Bio: \(profiloAttuale.bio ?? "")
        Username: \(profiloAttuale.username ?? "")
        
        ISTRUZIONI:
        1. Analizza i messaggi per identificare interessi, preferenze, progetti, obiettivi
        2. Identifica pattern di comportamento, hobby, relazioni, lavoro
        3. Aggiorna il contesto esistente con nuove informazioni rilevanti
        4. Mantieni un tono naturale e personale
        5. Limita la risposta a 200-300 parole
        6. Rispondi SOLO con il nuovo contesto aggiornato, senza spiegazioni aggiuntive
        
        NUOVO CONTESTO AGGIORNATO:
        """
    }
    
    func aggiornaContestoAI(profilo: ProfiloUtente, prompt: String, completion: @escaping (Bool) -> Void) {
        guard let apiKey = KeychainManager.shared.load(key: "openai_api_key"), !apiKey.isEmpty else {
            completion(false)
            return
        }
        
        let selectedModel = UserDefaults.standard.string(forKey: "selected_model") ?? "gpt-4o-mini"
        
        let messages = [
            OpenAIMessage(role: "system", content: "Sei un assistente specializzato nell'analisi del comportamento umano e nell'aggiornamento di profili personali. Rispondi sempre in italiano."),
            OpenAIMessage(role: "user", content: prompt)
        ]
        
        OpenAIService.shared.sendMessage(messages: messages, model: selectedModel) { result in
            switch result {
            case .success(let nuovoContesto):
                // Salva la versione precedente nella cronologia
                if let contestoPrecedente = profilo.contestoAI, !contestoPrecedente.isEmpty {
                    self.salvaContestoInCronologia(profilo: profilo, contesto: contestoPrecedente, tipo: "Automatico")
                }

                // Aggiorna il profilo con il nuovo contesto
                profilo.contestoAI = nuovoContesto
                profilo.dataUltimoAggiornamentoContesto = Date()
                
                // Salva nel Core Data
                if let context = profilo.managedObjectContext {
                    do {
                        try context.save()
                        
                        // Invia notifica di successo se l'app è in background
                        if UIApplication.shared.applicationState == .background {
                            NotificationService.shared.notificaContestoAggiornato()
                        }
                        
                        completion(true)
                    } catch {
                        print("Errore nel salvare il contesto aggiornato: \(error)")
                        completion(false)
                    }
                } else {
                    completion(false)
                }
                
            case .failure(let error):
                print("Errore nell'aggiornamento del contesto AI: \(error)")
                
                // Invia notifica di errore se l'app è in background
                if UIApplication.shared.applicationState == .background {
                    NotificationService.shared.notificaErroreAggiornamentoContesto()
                }
                
                completion(false)
            }
        }
    }

    func salvaContestoInCronologia(profilo: ProfiloUtente, contesto: String, tipo: String) {
        guard let context = profilo.managedObjectContext else { return }
        
        let historyEntry = CronologiaContesto(context: context)
        historyEntry.id = UUID()
        historyEntry.dataSalvataggio = Date()
        historyEntry.contenuto = contesto
        historyEntry.tipoAggiornamento = tipo
        profilo.addToCronologia(historyEntry)
    }
    
    // MARK: - Aggiornamento Automatico
    
    func dovrebbeAggiornareContesto(profilo: ProfiloUtente) -> Bool {
        guard let ultimoAggiornamento = profilo.dataUltimoAggiornamentoContesto else {
            return true // Prima volta
        }
        
        let oreTrascorse = Calendar.current.dateComponents([.hour], from: ultimoAggiornamento, to: Date()).hour ?? 0
        return oreTrascorse >= 24 // Aggiorna ogni 24 ore
    }
    
    func aggiornaContestoSeNecessario(profilo: ProfiloUtente, messaggi: [MessaggioMarilena], completion: @escaping (Bool) -> Void) {
        guard dovrebbeAggiornareContesto(profilo: profilo) else {
            completion(false) // Non necessario
            return
        }
        
        // Aggiorna il contesto AI del profilo
        let testoMessaggi = messaggi.compactMap { $0.contenuto }.joined(separator: " ")
        if !testoMessaggi.isEmpty {
            profilo.contestoAI = testoMessaggi
            profilo.dataUltimoAggiornamentoContesto = Date()
            
            do {
                try profilo.managedObjectContext?.save()
                completion(true)
            } catch {
                completion(false)
            }
        } else {
            completion(false)
        }
    }
    
    // MARK: - Gestione Foto Profilo
    
    func ottieniSuggerimenti(profilo: ProfiloUtente) -> [String] {
        var suggerimenti: [String] = []
        
        // Suggerimento per bio vuota
        if profilo.bio?.isEmpty ?? true {
            suggerimenti.append("Aggiungi una bio per personalizzare il tuo profilo")
        }
        
        // Suggerimento per foto profilo mancante
        if profilo.fotoProfilo == nil {
            suggerimenti.append("Carica una foto profilo per completare il tuo profilo")
        }
        
        // Suggerimento per contesto AI non aggiornato
        if dovrebbeAggiornareContesto(profilo: profilo) {
            suggerimenti.append("Aggiorna il tuo contesto AI con le conversazioni recenti")
        }
        
        // Suggerimento per cellulare mancante
        if profilo.cellulare?.isEmpty ?? true {
            suggerimenti.append("Aggiungi il numero di cellulare per essere contattato")
        }
        
        if suggerimenti.isEmpty {
            suggerimenti.append("Il tuo profilo è completo! Continua a usare Marilena per migliorare il contesto AI.")
        }
        
        return suggerimenti
    }
    
    func salvaFotoProfilo(_ imageData: Data, per profilo: ProfiloUtente) -> Bool {
        profilo.fotoProfilo = imageData
        
        if let context = profilo.managedObjectContext {
            do {
                try context.save()
                return true
            } catch {
                print("Errore nel salvare la foto profilo: \(error)")
                return false
            }
        }
        return false
    }
    
    func caricaFotoProfilo(per profilo: ProfiloUtente) -> Data? {
        return profilo.fotoProfilo
    }
    
    // MARK: - Statistiche Profilo
    
    func ottieniStatisticheProfilo(profilo: ProfiloUtente) -> ProfiloStatistiche {
        let chats = profilo.chats?.allObjects as? [ChatMarilena] ?? []
        let messaggiTotali = chats.compactMap { $0.messaggi?.allObjects as? [MessaggioMarilena] }.flatMap { $0 }
        
        let messaggiUtente = messaggiTotali.filter { $0.isUser }
        let messaggiAI = messaggiTotali.filter { !$0.isUser }
        
        let dataPrimaChat = chats.map { $0.dataCreazione ?? Date.distantFuture }.min() ?? Date()
        let giorniAttivo = Calendar.current.dateComponents([.day], from: dataPrimaChat, to: Date()).day ?? 0
        
        return ProfiloStatistiche(
            numeroChat: chats.count,
            messaggiInviati: messaggiUtente.count,
            messaggiRicevuti: messaggiAI.count,
            giorniAttivo: giorniAttivo,
            ultimoAggiornamentoContesto: profilo.dataUltimoAggiornamentoContesto
        )
    }
}

// MARK: - Strutture Dati

struct ProfiloStatistiche {
    let numeroChat: Int
    let messaggiInviati: Int
    let messaggiRicevuti: Int
    let giorniAttivo: Int
    let ultimoAggiornamentoContesto: Date?
    
    var messaggiTotali: Int {
        return messaggiInviati + messaggiRicevuti
    }
    
    var mediaMessaggiPerChat: Double {
        guard numeroChat > 0 else { return 0 }
        return Double(messaggiTotali) / Double(numeroChat)
    }
} 