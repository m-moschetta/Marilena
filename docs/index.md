# Marilena – Developer Guide

Guida unica e aggiornata per sviluppatori: architettura, moduli principali, configurazione OAuth, stile e testing.

—

## Architettura
- SwiftUI per UI modulare e reattiva.
- Core Data per persistenza di registrazioni, trascrizioni e conversazioni.
- `AIProviderManager` per selezione dinamica provider (OpenAI, Anthropic, Perplexity, Groq) con fallback.
- Servizi dedicati: `OpenAIService`, `AnthropicService`, `PerplexityService`, `GroqService`.
- `SpeechTranscriptionService` per trascrizione (Speech Framework, SpeechAnalyzer, Whisper API).
- `PromptManager` per gestione centralizzata dei prompt.

—

## Provider AI e Modelli
- OpenAI: modelli chat e trascrizione; supporto streaming; limiti token variabili.
- Anthropic: Claude per contesti grandi e risposte strutturate.
- Perplexity: ricerca online e modelli Sonar/Llama/Mixtral.
- Groq: esecuzione veloce di modelli open-source (es. Llama 3, Mixtral).

Imposta le API key nell’app (Keychain). Evita di inserirle in codice/sorgente.

—

## Chat Module (riusabile)
Funzionalità: chat in tempo reale, sessioni salvabili, statistiche token/tempi, esportazione conversazioni, fallback provider, UI moderna.

Uso base:
```swift
import SwiftUI

struct MyAppView: View {
    var body: some View {
        NavigationView {
            ModularChatView(title: "Chat AI")
        }
    }
}
```

Configurazione avanzata:
```swift
let config = ChatConfiguration(
    maxTokens: 8000,
    temperature: 0.7,
    model: "gpt-4o-mini",
    systemPrompt: "Sei un assistente esperto...",
    contextWindow: 16000
)

ModularChatView(title: "Chat Pro", configuration: config, showSettings: true)
```

Statistiche:
```swift
let stats = chatService.getConversationStats()
print(stats.totalMessages, stats.totalTokens)
```

—

## Transcription Module (riusabile)
Funzionalità: multi-framework (SpeechAnalyzer iOS 26+, Speech Framework, Whisper API), multilingua, risultati con confidenza/timestamp/segmenti, UI e statistiche.

Uso base:
```swift
import SwiftUI

struct MyTranscriber: View {
    var body: some View {
        ModularTranscriptionView(title: "Trascrizione")
    }
}
```

Configurazione:
```swift
let config = ModularTranscriptionConfiguration(
  mode: .auto, language: "it-IT",
  enableTimestamps: true, enableConfidence: true, enableSegments: true,
  maxProcessingTime: 300, retryCount: 3
)

ModularTranscriptionView(title: "Avanzata", configuration: config, showSettings: true)
```

Permessi Info.plist:
```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>Trascrizione dell'audio</string>
<key>NSMicrophoneUsageDescription</key>
<string>Registrazione dell'audio</string>
```

—

## Email: Cache e Offline
- Cache: limite elementi e durata configurati; riduce chiamate di rete.
- Offline Sync: accoda operazioni (es. invio/cancellazione), riprende al ripristino connessione; indicatori UI e log.

Uso tipico:
```swift
await emailService.sendEmail(to: "test@example.com", subject: "Ciao", body: "Messaggio")
// offline → accodato; online → inviato
```

—

## OAuth Google (passi sicuri)
Obiettivo: abilitare autenticazione Google per email/servizi protetti.

1) Google Cloud Console → configura OAuth consent screen (Testing o Publishing) e abilita Gmail API se necessario.
2) Aggiungi il tuo account come Test User oppure pubblica l’app (richiede revisione).
3) Imposta Client ID/Redirect URI coerenti con il bundle; non includere credenziali nel repo.
4) In app, aggiorna impostazioni OAuth e verifica il flusso.

Helper: `bash Marilena/scripts/setup_oauth.sh` (segui le istruzioni a terminale). Non inserire ID o segreti qui nel codice.

—

## Build e Test
```bash
# Apri in Xcode
open Marilena.xcodeproj

# iOS
xcodebuild -scheme Marilena \
  -destination 'platform=iOS Simulator,name=iPhone 15' build test

# macOS
xcodebuild -scheme Marilena-Mac -destination 'platform=macOS' build test
```

—

## Stile & Linee Guida
- Swift, indentazione 2 spazi; seguire Swift API Design Guidelines.
- Tipi `UpperCamelCase`; proprietà/metodi `lowerCamelCase`.
- Viste con suffisso `View`, servizi con suffisso `Service`.
- Preferire `struct` e `async/await`. Marcare `final` dove appropriato.
- File piccoli e focalizzati; test co-locati in `*Tests`.

—

## Testing
- Unit: Swift Testing (`import Testing`); UI: XCTest.
- Nomi test: `FeatureNameTests.swift`; un comportamento per `@Test`.
- Copertura significativa su servizi AI, speech e persistenza.

—

## Sicurezza
- Nessuna API key hard-coded; usa Keychain via impostazioni in-app.
- Non committare credenziali personali; rivedi sempre le modifiche a `Info.plist` (iOS/macOS).

—

## Contributi
- Branch: `feature/<slug>`, `fix/<slug>`, `chore/<slug>`.
- PR: descrizione chiara, issue collegate, screenshot/GIF per UI, passi di validazione, note su migrazioni o `Info.plist`.

Consulta il README alla radice per un Quick Start.

—

## Refactoring
- Piano operativo e aggiornato: `docs/REFACTORING_PLAN.md`.

## Performance
- Il piano performance è integrato nel refactoring (sezione M7 – Performance) con KPI, misurazione, aree di ottimizzazione e criteri di accettazione.
