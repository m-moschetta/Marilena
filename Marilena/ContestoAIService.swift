import Foundation
import BackgroundTasks
import CoreData

class ContestoAIService {
    static let shared = ContestoAIService()
    
    private init() {}
    
    // MARK: - Background Task
    
    func registraBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.marilena.contesto-update",
            using: nil
        ) { task in
            self.handleBackgroundTask(task as! BGAppRefreshTask)
        }
    }
    
    func pianificaAggiornamentoContesto() {
        let request = BGAppRefreshTaskRequest(identifier: "com.marilena.contesto-update")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60) // 24 ore
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Errore nella pianificazione del background task: \(error)")
        }
    }
    
    private func handleBackgroundTask(_ task: BGAppRefreshTask) {
        // Pianifica il prossimo aggiornamento
        pianificaAggiornamentoContesto()
        
        // Esegui l'aggiornamento del contesto
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        aggiornaContestoInBackground { success in
            task.setTaskCompleted(success: success)
        }
    }
    
    // MARK: - Aggiornamento Contesto
    
    func aggiornaContestoInBackground(completion: @escaping (Bool) -> Void) {
        let context = PersistenceController.shared.container.viewContext
        
        guard let profilo = ProfiloUtenteService.shared.ottieniProfiloUtente(in: context) else {
            completion(false)
            return
        }
        
        // Verifica se è necessario aggiornare
        guard ProfiloUtenteService.shared.dovrebbeAggiornareContesto(profilo: profilo) else {
            completion(true) // Non necessario, ma considerato successo
            return
        }
        
        // Raccoglie tutti i messaggi delle chat
        let chats = profilo.chats?.allObjects as? [ChatMarilena] ?? []
        let messaggi = chats.compactMap { $0.messaggi?.allObjects as? [MessaggioMarilena] }.flatMap { $0 }
        
        // Filtra solo i messaggi dell'utente
        let messaggiUtente = messaggi.filter { $0.isUser }
        
        guard !messaggiUtente.isEmpty else {
            completion(true)
            return
        }
        
        // Crea il prompt per l'aggiornamento
        let prompt = ProfiloUtenteService.shared.creaPromptPerAggiornamentoContesto(profiloAttuale: profilo, messaggi: messaggiUtente)
        
        // Esegue l'aggiornamento tramite OpenAI
        ProfiloUtenteService.shared.aggiornaContestoAI(profilo: profilo, prompt: prompt) { success in
            completion(success)
        }
    }
    
    // MARK: - Analisi Messaggi
    
    func analizzaTendenzaMessaggi(profilo: ProfiloUtente) -> TendenzaMessaggi {
        let chats = profilo.chats?.allObjects as? [ChatMarilena] ?? []
        let messaggi = chats.compactMap { $0.messaggi?.allObjects as? [MessaggioMarilena] }.flatMap { $0 }
        
        let messaggiUtente = messaggi.filter { $0.isUser }
        let _ = messaggi.filter { !$0.isUser }
        
        // Analizza la frequenza dei messaggi negli ultimi 7 giorni
        let setteGiorniFa = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let messaggiRecenti = messaggiUtente.filter { ($0.dataCreazione ?? Date.distantPast) >= setteGiorniFa }
        
        // Calcola la media giornaliera
        let mediaGiornaliera = Double(messaggiRecenti.count) / 7.0
        
        // Determina la tendenza
        let tendenza: TendenzaMessaggi.Tipo
        if mediaGiornaliera > 10 {
            tendenza = .alta
        } else if mediaGiornaliera > 5 {
            tendenza = .media
        } else {
            tendenza = .bassa
        }
        
        return TendenzaMessaggi(
            tipo: tendenza,
            mediaGiornaliera: mediaGiornaliera,
            messaggiTotali: messaggiUtente.count,
            messaggiRecenti: messaggiRecenti.count
        )
    }
    
    // MARK: - Suggerimenti Contesto
    
    func generaSuggerimentiContesto(profilo: ProfiloUtente) -> [SuggerimentoContesto] {
        var suggerimenti: [SuggerimentoContesto] = []
        
        // Suggerimento per aggiornamento manuale
        if ProfiloUtenteService.shared.dovrebbeAggiornareContesto(profilo: profilo) {
            suggerimenti.append(
                SuggerimentoContesto(
                    id: UUID(),
                    tipo: .aggiornamentoContesto,
                    titolo: "Aggiorna Contesto",
                    descrizione: "Il tuo contesto AI può essere aggiornato con le conversazioni recenti",
                    priorita: .alta,
                    azione: "Aggiorna Contesto"
                )
            )
        }
        
        // Suggerimento per completare il profilo
        if profilo.bio?.isEmpty ?? true {
            suggerimenti.append(
                SuggerimentoContesto(
                    id: UUID(),
                    tipo: .completaProfilo,
                    titolo: "Completa Profilo",
                    descrizione: "Aggiungi una bio per migliorare il contesto AI",
                    priorita: .media,
                    azione: "Completa Profilo"
                )
            )
        }
        
        // Suggerimento per foto profilo
        if profilo.fotoProfilo == nil {
            suggerimenti.append(
                SuggerimentoContesto(
                    id: UUID(),
                    tipo: .aggiungiFoto,
                    titolo: "Aggiungi Foto",
                    descrizione: "Personalizza il tuo profilo con una foto",
                    priorita: .bassa,
                    azione: "Aggiungi Foto"
                )
            )
        }
        
        return suggerimenti
    }
}

// MARK: - Strutture Dati

struct TendenzaMessaggi {
    enum Tipo {
        case alta
        case media
        case bassa
        
        var descrizione: String {
            switch self {
            case .alta:
                return "Alta attività"
            case .media:
                return "Attività moderata"
            case .bassa:
                return "Bassa attività"
            }
        }
        
        var colore: String {
            switch self {
            case .alta:
                return "green"
            case .media:
                return "orange"
            case .bassa:
                return "red"
            }
        }
    }
    
    let tipo: Tipo
    let mediaGiornaliera: Double
    let messaggiTotali: Int
    let messaggiRecenti: Int
}

struct SuggerimentoContesto {
    enum Tipo {
        case aggiornamentoContesto
        case completaProfilo
        case aggiungiFoto
        case social
    }
    
    enum Priorita {
        case alta
        case media
        case bassa
        
        var icona: String {
            switch self {
            case .alta:
                return "exclamationmark.triangle.fill"
            case .media:
                return "info.circle.fill"
            case .bassa:
                return "lightbulb.fill"
            }
        }
        
        var colore: String {
            switch self {
            case .alta:
                return "red"
            case .media:
                return "orange"
            case .bassa:
                return "blue"
            }
        }
    }
    
    let id: UUID
    let tipo: Tipo
    let titolo: String
    let descrizione: String
    let priorita: Priorita
    let azione: String
} 