//
//  TranscriptionContextService.swift
//  Marilena
//
//  Created by AI Assistant
//  Copyright © 2024. All rights reserved.
//

import Foundation
import CoreData
import Combine

/// Service per gestire il contesto delle trascrizioni per l'assistente AI
@MainActor
public class TranscriptionContextService: ObservableObject {
    private let context: NSManagedObjectContext
    
    public init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Public Methods
    
    /// Recupera le ultime N trascrizioni
    /// - Parameter limit: Numero massimo di trascrizioni da recuperare (default: 10)
    /// - Returns: Array di trascrizioni ordinate per data (più recenti prima)
    public func getRecentTranscriptions(limit: Int = 10) -> [Trascrizione] {
        let fetchRequest: NSFetchRequest<Trascrizione> = Trascrizione.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Trascrizione.dataCreazione, ascending: false)]
        fetchRequest.fetchLimit = limit
        fetchRequest.predicate = NSPredicate(format: "statoElaborazione == %@", "completata")
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("❌ Errore recupero trascrizioni recenti: \(error)")
            return []
        }
    }
    
    /// Recupera trascrizioni collegate a un evento calendario
    /// - Parameter eventTitle: Titolo dell'evento da cercare
    /// - Returns: Array di trascrizioni collegate
    public func getTranscriptionsForEvent(eventTitle: String) -> [Trascrizione] {
        // Cerca registrazioni che hanno il titolo dell'evento nel titolo
        let recordingFetchRequest: NSFetchRequest<RegistrazioneAudio> = RegistrazioneAudio.fetchRequest()
        recordingFetchRequest.predicate = NSPredicate(format: "titolo CONTAINS[cd] %@", eventTitle)
        
        do {
            let recordings = try context.fetch(recordingFetchRequest)
            var transcriptions: [Trascrizione] = []
            
            for recording in recordings {
                if let recordingTranscriptions = recording.trascrizioni?.allObjects as? [Trascrizione] {
                    transcriptions.append(contentsOf: recordingTranscriptions)
                }
            }
            
            return transcriptions.sorted { ($0.dataCreazione ?? Date.distantPast) > ($1.dataCreazione ?? Date.distantPast) }
        } catch {
            print("❌ Errore recupero trascrizioni per evento: \(error)")
            return []
        }
    }
    
    /// Recupera trascrizioni per un intervallo di date
    /// - Parameters:
    ///   - startDate: Data di inizio
    ///   - endDate: Data di fine
    /// - Returns: Array di trascrizioni nell'intervallo
    public func getTranscriptionsInDateRange(startDate: Date, endDate: Date) -> [Trascrizione] {
        let fetchRequest: NSFetchRequest<Trascrizione> = Trascrizione.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "dataCreazione >= %@ AND dataCreazione <= %@ AND statoElaborazione == %@",
            startDate as NSDate,
            endDate as NSDate,
            "completata"
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Trascrizione.dataCreazione, ascending: false)]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("❌ Errore recupero trascrizioni per intervallo: \(error)")
            return []
        }
    }
    
    /// Cerca trascrizioni per testo contenuto
    /// - Parameter searchText: Testo da cercare
    /// - Returns: Array di trascrizioni che contengono il testo
    public func searchTranscriptions(searchText: String) -> [Trascrizione] {
        let fetchRequest: NSFetchRequest<Trascrizione> = Trascrizione.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "testoCompleto CONTAINS[cd] %@ AND statoElaborazione == %@",
            searchText,
            "completata"
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Trascrizione.dataCreazione, ascending: false)]
        fetchRequest.fetchLimit = 20
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("❌ Errore ricerca trascrizioni: \(error)")
            return []
        }
    }
    
    /// Formatta una trascrizione per il contesto AI
    /// - Parameter transcription: Trascrizione da formattare
    /// - Returns: String formattata con informazioni rilevanti
    public func formatTranscriptionForContext(_ transcription: Trascrizione) -> String {
        var result = ""
        
        // Titolo/Data
        if let recording = transcription.registrazione,
           let title = recording.titolo {
            result += "📅 **\(title)**\n"
        }
        
        if let date = transcription.dataCreazione {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "it_IT")
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            result += "📆 Data: \(formatter.string(from: date))\n"
        }
        
        // Testo completo
        if let text = transcription.testoCompleto, !text.isEmpty {
            result += "\n**Trascrizione:**\n\(text)\n"
        }
        
        // Metadati
        if transcription.paroleTotali > 0 {
            result += "\n📊 Parole: \(transcription.paroleTotali)"
        }
        
        if let language = transcription.linguaRilevata {
            result += " | Lingua: \(language)"
        }
        
        return result
    }
    
    /// Estrae action items da una trascrizione usando analisi semplice
    /// - Parameter transcription: Trascrizione da analizzare
    /// - Returns: Array di possibili action items
    public func extractActionItems(from transcription: Trascrizione) -> [String] {
        guard let text = transcription.testoCompleto, !text.isEmpty else {
            return []
        }
        
        var actionItems: [String] = []
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
        
        // Cerca frasi che indicano azioni
        let actionKeywords = ["devo", "bisogna", "fare", "completare", "inviare", "rispondere", "chiamare", "incontrare", "preparare", "revisionare"]
        
        for sentence in sentences {
            let lowercased = sentence.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if lowercased.count > 10 && actionKeywords.contains(where: { lowercased.contains($0) }) {
                actionItems.append(sentence.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        return Array(actionItems.prefix(5)) // Massimo 5 action items
    }
    
    /// Formatta tutte le trascrizioni per il contesto AI
    /// - Parameter transcriptions: Array di trascrizioni
    /// - Returns: String formattata con tutte le trascrizioni
    public func formatTranscriptionsForContext(_ transcriptions: [Trascrizione]) -> String {
        guard !transcriptions.isEmpty else {
            return "Nessuna trascrizione disponibile."
        }
        
        var result = "## Trascrizioni Recenti\n\n"
        
        for (index, transcription) in transcriptions.enumerated() {
            result += "### Trascrizione \(index + 1)\n"
            result += formatTranscriptionForContext(transcription)
            result += "\n\n---\n\n"
        }
        
        return result
    }
}

