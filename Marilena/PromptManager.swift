import Foundation

// MARK: - Prompt Manager
// File centralizzato per tutti i prompt dell'applicazione
// Facilita la gestione e personalizzazione dei prompt

public class PromptManager {
    public static let shared = PromptManager()
    
    private init() {}
    
    // MARK: - AI Context Prompts
    
    /// Prompt per aggiornamento automatico del contesto AI
    static let contextUpdatePrompt = """
    Analizza i seguenti messaggi dell'utente e aggiorna il suo contesto personale.
    
    CONTESTO ATTUALE:
    {CONTESTO_ATTUALE}
    
    MESSAGGI RECENTI DELL'UTENTE:
    {MESSAGGI_RECENTI}
    
    INFORMAZIONI PROFILO:
    Nome: {NOME_UTENTE}
    Bio: {BIO_UTENTE}
    Username: {USERNAME_UTENTE}
    
    ISTRUZIONI:
    1. Analizza i messaggi per identificare interessi, preferenze, progetti, obiettivi
    2. Identifica pattern di comportamento, hobby, relazioni, lavoro
    3. Aggiorna il contesto esistente con nuove informazioni rilevanti
    4. Mantieni un tono naturale e personale
    5. Limita la risposta a 200-300 parole
    6. Rispondi SOLO con il nuovo contesto aggiornato, senza spiegazioni aggiuntive
    
    NUOVO CONTESTO AGGIORNATO:
    """
    
    /// Prompt per generazione suggerimenti profilo
    static let profileSuggestionsPrompt = """
    Analizza il profilo utente e genera suggerimenti per migliorarlo.
    
    PROFILO ATTUALE:
    Nome: {NOME_UTENTE}
    Bio: {BIO_UTENTE}
    Username: {USERNAME_UTENTE}
    Contesto AI: {CONTESTO_AI}
    
    ISTRUZIONI:
    1. Analizza il profilo per identificare aree di miglioramento
    2. Suggerisci modifiche specifiche e concrete
    3. Considera il contesto AI per personalizzare i suggerimenti
    4. Fornisci 3-5 suggerimenti prioritari
    5. Sii costruttivo e motivante
    6. Rispondi in formato lista numerata
    
    SUGGERIMENTI:
    """
    
    // MARK: - Chat & Conversation Prompts
    
    /// Prompt base per conversazioni con Marilena
    static let chatBasePrompt = """
    Sei Marilena, un assistente AI personale e amichevole.
    
    CONTESTO UTENTE:
    {CONTESTO_UTENTE}
    
    ISTRUZIONI:
    1. Rispondi sempre in italiano
    2. Sii naturale, amichevole e personale
    3. Usa il contesto dell'utente per personalizzare le risposte
    4. Sii utile, informativo e coinvolgente
    5. Mantieni conversazioni fluide e naturali
    6. Se non sai qualcosa, ammettilo onestamente
    
    RISPOSTA:
    """
    
    /// Prompt per domande specifiche
    static let specificQuestionPrompt = """
    Rispondi alla seguente domanda dell'utente:
    
    DOMANDA: {DOMANDA}
    
    CONTESTO UTENTE:
    {CONTESTO_UTENTE}
    
    ISTRUZIONI:
    1. Fornisci una risposta completa e accurata
    2. Personalizza la risposta basandoti sul contesto dell'utente
    3. Sii conciso ma esaustivo
    4. Se la domanda richiede ricerca online, suggeriscilo
    5. Mantieni un tono amichevole e personale
    
    RISPOSTA:
    """
    
    // MARK: - Transcription Analysis Prompts
    
    /// Prompt per analisi trascrizioni
    static let transcriptionAnalysisPrompt = """
    Analizza la seguente trascrizione audio:
    
    TRASCRIZIONE:
    {TRASCRIZIONE}
    
    DOMANDA UTENTE:
    {DOMANDA}
    
    ISTRUZIONI:
    1. Analizza il contenuto della trascrizione
    2. Rispondi alla domanda specifica dell'utente
    3. Fornisci insights rilevanti
    4. Sii specifico e dettagliato
    5. Se necessario, suggerisci ulteriori analisi
    
    ANALISI:
    """
    
    /// Prompt per riassunto trascrizione
    static let transcriptionSummaryPrompt = """
    Crea un riassunto della seguente trascrizione:
    
    TRASCRIZIONE:
    {TRASCRIZIONE}
    
    ISTRUZIONI:
    1. Identifica i punti chiave
    2. Crea un riassunto strutturato
    3. Mantieni le informazioni più importanti
    4. Usa un linguaggio chiaro e conciso
    5. Organizza in sezioni se appropriato
    
    RIASSUNTO:
    """
    
    /// Prompt per analisi sentiment
    static let sentimentAnalysisPrompt = """
    Analizza il sentiment della seguente trascrizione:
    
    TRASCRIZIONE:
    {TRASCRIZIONE}
    
    ISTRUZIONI:
    1. Identifica il tono generale
    2. Analizza le emozioni espresse
    3. Rileva cambiamenti di mood
    4. Fornisci esempi specifici
    5. Suggerisci interpretazioni
    
    ANALISI SENTIMENT:
    """
    

    
    /// Prompt per ricerca tecnica
    static let technicalSearchPrompt = """
    Cerca informazioni tecniche su: {QUERY}
    
    ISTRUZIONI:
    1. Fornisci dettagli tecnici accurati
    2. Includi esempi pratici se possibile
    3. Cita fonti autorevoli
    4. Spiega concetti complessi in modo chiaro
    5. Se appropriato, includi codice o formule
    
    RISULTATO TECNICO:
    """
    
    // MARK: - Error Handling Prompts
    
    /// Prompt per gestione errori
    static let errorHandlingPrompt = """
    Si è verificato un errore: {ERRORE}
    
    CONTESTO:
    {CONTESTO}
    
    ISTRUZIONI:
    1. Spiega l'errore in modo comprensibile
    2. Suggerisci possibili soluzioni
    3. Mantieni un tono rassicurante
    4. Offri supporto per risolvere il problema
    
    RISPOSTA:
    """
    
    // MARK: - Utility Methods
    
    /// Sostituisce i placeholder nel prompt
    static func formatPrompt(_ prompt: String, replacements: [String: String]) -> String {
        var formattedPrompt = prompt
        
        for (key, value) in replacements {
            let placeholder = "{\(key)}"
            formattedPrompt = formattedPrompt.replacingOccurrences(of: placeholder, with: value)
        }
        
        return formattedPrompt
    }
    
    /// Ottiene il prompt per il tipo specificato
    public static func getPrompt(for type: PromptType, replacements: [String: String] = [:]) -> String {
        let basePrompt: String
        
        switch type {
        case .contextUpdate:
            basePrompt = contextUpdatePrompt
        case .profileSuggestions:
            basePrompt = profileSuggestionsPrompt
        case .chatBase:
            basePrompt = chatBasePrompt
        case .specificQuestion:
            basePrompt = specificQuestionPrompt
        case .transcriptionAnalysis:
            basePrompt = transcriptionAnalysisPrompt
        case .transcriptionSummary:
            basePrompt = transcriptionSummaryPrompt
        case .sentimentAnalysis:
            basePrompt = sentimentAnalysisPrompt
        case .technicalSearch:
            basePrompt = technicalSearchPrompt
        case .errorHandling:
            basePrompt = errorHandlingPrompt
        }
        
        return formatPrompt(basePrompt, replacements: replacements)
    }
}

// MARK: - Prompt Types

public enum PromptType {
    case contextUpdate
    case profileSuggestions
    case chatBase
    case specificQuestion
    case transcriptionAnalysis
    case transcriptionSummary
    case sentimentAnalysis
    case technicalSearch
    case errorHandling
}

// MARK: - Prompt Constants

struct PromptConstants {
    // Limiti e configurazioni
    static let maxContextLength = 300
    static let maxSummaryLength = 200
    static let maxSearchResults = 5
    
    // Template comuni
    static let userContextTemplate = """
    Nome: {NOME}
    Bio: {BIO}
    Interessi: {INTERESSI}
    Contesto: {CONTESTO}
    """
    
    static let errorTemplate = """
    ❌ Errore: {ERRORE}
    🔧 Soluzione: {SOLUZIONE}
    📞 Supporto: {SUPPORTO}
    """
} 