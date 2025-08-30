# Marilena

Assistente AI per iOS e macOS con trascrizione audio, chat multimodello (OpenAI, Anthropic, Perplexity, Groq), ricerca online e persistenza con Core Data.

—

## Panoramica
- SwiftUI per l’interfaccia, servizi modulari e Keychain per le credenziali.
- `AIProviderManager` seleziona dinamicamente il provider AI in base alle API key e alle preferenze.
- `SpeechTranscriptionService` sceglie automaticamente il miglior framework disponibile (Speech Framework, SpeechAnalyzer, Whisper API).

—

## Struttura Progetto
- iOS: `Marilena/`
- macOS: `Marilena-Mac/`
- Test: `MarilenaTests/`, `MarilenaUITests/`, `Marilena-MacTests/`
- Documentazione: `docs/`

—

## Requisiti e Configurazione
- Xcode aggiornato, iOS Simulator configurato.
- Inserisci le API key dai provider nell’app (memorizzazione in Keychain). Non inserire segreti nel codice.
- OAuth Google (se usi email/ricerca protetta): vedi guida in `docs/index.md`. In alternativa esegui lo script: `bash Marilena/scripts/setup_oauth.sh` e completa i passi indicati.

—

## Build e Test
Esegui da terminale o Xcode.

```bash
# Apri il progetto
open Marilena.xcodeproj

# iOS build + test
xcodebuild -scheme Marilena-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 16' build test

# macOS build + test
xcodebuild -scheme Marilena-Mac \
  -destination 'platform=macOS' build test
```

—

## Avvio Rapido
1) Apri in Xcode e configura le API key nelle impostazioni dell’app.
2) Opzionale: configura OAuth Google (solo se necessario per le integrazioni email/ricerca protetta).
3) Esegui l’app su simulatore. Prova: registrazione → trascrizione → chat AI → ricerca online.

—

## Contribuire
- Branch: `feature/<slug>`, `fix/<slug>`, `chore/<slug>`.
- Commits piccoli, in forma imperativa. Alza una PR con descrizione, screenshot se UI, e passi di validazione.

—

## Documentazione
La guida completa per sviluppatori, moduli (Chat, Transcription), OAuth, stile e test si trova in: `docs/index.md`.
