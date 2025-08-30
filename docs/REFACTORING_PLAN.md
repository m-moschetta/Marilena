# Marilena – Piano di Refactoring

Documento operativo per pianificare e tracciare il refactoring del progetto. Obiettivo: rendere il codice più modulare, testabile e sicuro, mantenendo stabilità nei rilasci.

—

## Obiettivi
- Ridurre accoppiamento tra moduli (AI, Speech, Email, UI).
- Stabilizzare error handling, logging e retry/fallback.
- Chiarire confini tra dominio, persistenza (Core Data) e UI.
- Migliorare testabilità (unit + integrazione) e copertura.
- Rimuovere duplicazioni/esperimenti, centralizzare configurazioni.

—

## Principi
- Piccoli step, PR piccole e verificabili; feature flag se utile.
- API stabili per moduli riusabili (`Service`, `View`, `Model`).
- Concurrency con `async/await`; `@MainActor` solo su UI/state.
- Zero segreti in codice; uso di Keychain/Settings.

—

## Milestones (M0–M6)

### M0 – Stabilizzazione Baseline
- Pulizia convenzioni (naming, cartelle, suffissi `View`/`Service`).
- Centralizzazione costanti (timeouts, limiti token, feature flags).
- Rimozione codice morto/duplicato; separazione esperimenti.
- Acceptance: build + test passano su iOS/macOS; nessuna regressione funzionale.

### M1 – Boundaries di Dominio e Persistenza
- Introdurre layer `Repository` tra Core Data e servizi.
- DTO separati dai modelli di dominio; mapping esplicito.
- Acceptance: servizi non accedono più direttamente a Core Data; test unit repo.

### M2 – AI Services Unificati
- Protocollo comune per `OpenAIService`, `AnthropicService`, `PerplexityService`, `GroqService` (richiesta/risposta/usage/streaming).
- Rafforzare `AIProviderManager` (selezione, fallback, validazione chiavi, error mapping coerente).
- Acceptance: suite test che valida lo stesso scenario su tutti i provider.

### M3 – Pipeline Trascrizione Unica
- Unificare flussi Speech Framework, SpeechAnalyzer, Whisper in pipeline con modalità `.auto`/manuale.
- Contratto unico `TranscriptionResult` (testo, confidenza, segmenti, timestamp, lingua, sorgente, tempi).
- Gestione permessi/timeout/volatili vs finalizzati con stati chiari.
- Acceptance: test integrazione su trascrizioni simulate; UI reattiva a stati.

### M4 – Email: Cache e Offline
- Isolare `OfflineSyncService` con queue persistente (retry/backoff, dedup, ripresa).
- Politiche cache chiare (TTL, size cap) e invalidazioni; metriche minime.
- Indicatori UI standardizzati (online, pending, progress) e log strutturati.
- Acceptance: test integrazione con rete simulata; contatori e UI coerenti.

### M5 – UI e ViewModel
- Spostare business logic fuori dalle `View` in `ObservableObject`/servizi.
- Componenti UI condivisi (banners, indicators, modals) e tema unificato.
- Accessibilità by default; riduzione stato superfluo nelle `View`.
- Acceptance: snapshot test selettivi; nessun blocco su main thread.

### M6 – Osservabilità e QA
- Logging coerente con livelli (`debug`, `info`, `warn`, `error`) e categorie.
- Metriche essenziali in memoria: invii, fallimenti, retry, tempi.
- Matrice test: unit servizi, integrazione selettiva (AI, Speech, Email), UI smoke.
- Acceptance: report test stabile; log leggibili senza segreti.

—

## M7 – Performance
- KPI e budget prestazionali definiti, baseline misurata e regressioni monitorate.
- Ottimizzazioni mirate su avvio, rendering, memoria, rete, Core Data e pipeline AI.
- Acceptance: tutti i KPI rispettati su dispositivi target; nessuna regressione UX.

### KPI & Budget (target iniziali)
- Startup cold (simulatore iPhone 15): < 1.5s fino a prima vista interattiva.
- Frame pacing: 60 fps stabili (120 su device compatibili) su viste principali.
- Memoria: < 200 MB in scenari comuni; picchi transitori < 350 MB.
- Rete: richieste AI chat < 300 ms overhead locale (escluso tempo modello); batching dove possibile.
- Core Data: fetch principali < 50 ms; nessun blocco su main thread.

### Misurazione & Strumenti
- Instruments: Time Profiler, Allocations, Leaks, Energy Log, Network, SwiftUI.
- Metriche runtime leggere (counters e tempi) con log strutturato.
- Profili riproducibili: avvio app, lista registrazioni, trascrizione, chat, offline→online.

### Aree di Focus
- Avvio: lazy init servizi, ridurre lavoro in `Application/Scene` startup, defer asset pesanti.
- Rendering SwiftUI: evitare calcoli pesanti in `body`, usare memoization, ridurre `@MainActor` superfluo, preferire `@StateObject` su `@ObservedObject` quando opportuno.
- Concurrency: priorità task, cancellazione cooperativa, evitare hop inutili verso main.
- Memoria: cache con limiti e eviction (TTL/size), immagini/audio con downsampling, evitare retain cycle.
- Core Data: fetch limit/offset, predicati indicizzati, background contexts, batch updates/fetches.
- Rete: consolidare richieste, compressione opzionale, exponential backoff, streaming efficiente (chunking, backpressure).
- AI Pipeline: streaming risposta verso UI, ridurre serializzazioni, normalizzare payload.

### Task Operativi Performance
- Startup: spostare inizializzazioni non critiche post-first-frame; introdurre `DeferredInitializationService`.
- SwiftUI: profilare viste più frequenti; spezzare gerarchie pesanti; utilizzare `EquatableView` dove utile.
- Caching: definire policy per trascrizioni/conversazioni (TTL/size); invalidazione esplicita sugli eventi.
- Media: downsample immagini e audio; caricare on-demand; usare `AVAsset` reading progressivo.
- Core Data: introdurre repository con fetch configurati (limiti, sort, prefetch); salvare su background queue.
- Networking: abilitare HTTP/2 keep-alive; coalescenza richieste; ridurre header/payload; retry/backoff centralizzati.
- AI: pipeline streaming unificata con callback di chunk; parsers incrementali; ridurre copie di stringhe.

### Criteri di Accettazione Performance
- Report Instruments con punti caldi mitigati (>80% CPU su hot paths ridotto di almeno 30%).
- App responsiva (no hitch > 16 ms visibile) nei flussi critici.
- Budget memoria rispettato nei profili registrazione/trascrizione/chat.
- Nessun blocco su main thread per I/O pesante; confermato da Time Profiler.

—

## Task Operativi Dettagliati
- Config & Secrets: confermare uso Keychain per tutte le API key; rimuovere hard‑code.
- AI Provider API: normalizzare timeouts, error mapping, usage (tokens/time/cost se disponibile).
- Streaming Chat: interfaccia unica per stream/non‑stream con callback/cancellazione.
- Transcription: stati `idle/processing/completed/error`, progress e volatile text, timeouts configurabili.
- Offline Queue: persistenza sicura, backoff esponenziale, max retry, dedup per idempotenza.
- Repositories: introdurre `RecordingRepository`, `TranscriptionRepository`, `ChatRepository` con protocolli.
- Error Handling: definire `AIError`, `TranscriptionError`, `EmailError` con cause e remediation.
- Telemetria minima: contatori in memoria + log strutturato per analisi.

Performance add‑on:
- Budget e profili per avvio/render/memoria/rete/Core Data/AI.
- Test micro‑benchmark selettivi (parsing, mapping, serializzazione) dove ha senso.

—

## Mapping Aree/Moduli
- AI: `AIProviderManager.swift`, `OpenAIService.swift`, `AnthropicService.swift`, `PerplexityService.swift`, `GroqService.swift`.
- Speech: `SpeechTranscriptionService.swift` e moduli correlati.
- Email: servizi email + `OfflineSyncService`/cache.
- Persistenza: Core Data model (`*.xcdatamodeld`) + layer repository.
- UI: viste SwiftUI principali e componenti condivisi.

—

## Rischi & Migrazioni
- API interne: introdurre adapter temporanei, deprecazioni graduali.
- Core Data: valutare migrazioni leggere con test compatibilità.
- Provider limits (token/rate): fallback + backoff; circuit breaker se necessario.

—

## Criteri di Accettazione (per milestone)
- Build iOS/macOS verdi; comandi `xcodebuild ... test` passano.
- Copertura test aumentata sulle aree toccate (target minimo +10% rispetto baseline locale).
- Documentazione aggiornata (README, `docs/index.md`) e changelog breve in PR.
- Nessun segreto nei diff; `Info.plist` rivisi e validati.

—

## Strategia di Testing
- Unit: servizi AI, repository, error mapping, retry/backoff.
- Integrazione: pipeline trascrizione (mock/sim), AI round‑trip con stub, offline queue con rete simulata.
- UI: smoke/snapshot sulle viste chiave; verifica indicatori stato.
 - Performance: profili Instruments su scenari target e micro‑benchmark mirati.

—

## Breakdown in Issue/Branch
- M0: `chore/foundation-cleanup` (lint naming/struttura, config centrale).
- M1: `feature/repository-layer` (repo + mapping, test unit).
- M2: `feature/ai-service-protocol` (protocollo + adattatori provider + test).
- M3: `feature/transcription-pipeline` (contratto unico + stati + test).
- M4: `feature/email-offline-cache` (queue persistente + TTL + test integrazione).
- M5: `refactor/ui-viewmodels` (estrazione logica, componenti condivisi, snapshot test).
- M6: `chore/observability-qa` (logging, metriche, matrice test).
 - M7: `perf/phase-1` (startup/render/memoria) e `perf/phase-2` (rete/Core Data/AI pipeline).

—

## Checklist Consegna per Ogni Fase
- Build e test verdi (iOS/macOS) con comandi standard.
- Documentazione aggiornata e linkata.
- Test nuovi/aggiornati; regressioni controllate.
- Nessun segreto in diff; revisione `Info.plist` completata.

—

## Follow‑ups
- Roadmap feature (plugin, attachments, streaming avanzato).
- Telemetria estendibile (toggle remoto o SDK opzionale, in futuro).
