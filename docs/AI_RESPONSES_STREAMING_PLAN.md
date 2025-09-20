# Piano di migrazione alle Responses API e streaming multi-provider

## 1. Obiettivi e motivazione
- Uniformare tutte le integrazioni AI (OpenAI, Groq, xAI, Anthropic, Gateway Cloudflare, Apple) sul paradigma Responses API + streaming.
- Ridurre la latenza percepita in UI (chat, categorizzazione email, strumenti di scrittura) e abilitare funzionalità live (token-by-token, conteggio dinamico).
- Allinearsi alle roadmap ufficiali: OpenAI deprecazione `v1/chat/completions`, Groq/xAI compatibilità streaming, Anthropic SSE `messages/stream`.
- Migliorare l’osservabilità: logging strutturato per chunk, metriche di throughput, gestione backpressure.

## 2. Stato attuale sintetico
- **ChatService** (`Core/Data/Services/ChatService`): supporto streaming solo via `CloudflareGatewayClient.streamChat`. OpenAI locale usa `OpenAIService.sendMessage` (blocking). UI aggiorna i messaggi solo a completamento.
- **EmailCategorizationService**: invoca `OpenAIService`/`GroqService`/`AnthropicService` in modalità sincrona; non sfrutta streaming, ma beneficia dell’aggiornamento pipeline per uniformità.
- **Provider wrappers**:
  - `OpenAIService`: `POST /v1/chat/completions`, nessun streaming.
  - `GroqService`: API compatibili OpenAI; solo risposta completa.
  - `ModernXAIService`: `POST /chat/completions`, streaming non implementato (stub).
  - `AnthropicService`: `POST /v1/messages`, parsing custom; fallback gateway con formato OpenAI.
  - `AppleIntelligenceService`: locale, non richiede streaming (risposta rapida). Necessario solo per coerenza interfacce.
- **Gateway Cloudflare**: inoltra `/v1/chat/completions` e supporta streaming SSE già oggi (OpenAI-compatible protocol).
- **Worker/infra**: pipeline log e fallback assumono payload OpenAI Chat Completions.

## 3. Linee guida generali di migrazione
1. **Feature flag a doppio interruttore**: `use_responses_api` (per provider) e `enable_streaming` per UI/servizi per rollback rapido.
2. **Layer astratto unico**: introdurre una nuova interfaccia `StreamingChatClient` con metodi `streamResponses(...)` (AsyncThrowingStream) e `complete(...)` (await intero). Tutti i servizi provider-specifici implementano l’interfaccia.
3. **Gestione chunk**: creare modello dati unico:
   ```swift
   struct AIStreamChunk {
       let textDelta: String
       let finishReason: String?
       let provider: AIModelProvider
       let rawEvent: Data?
   }
   ```
4. **Backpressure**: utilizzare `MainActor` per aggiornare UI e `Task` isolati per pipeline. Debounce opzionale per ridurre re-render in UI (p.es. update ogni 30–50 ms).
5. **Persistenza**: salvare finale solo a completion, ma tracciare progressi per eventuale “live draft”.
6. **Telemetry**: log chunk (limitato) + metriche tempo al primo token, tokens/sec, completions.

## 4. Roadmap fasi

### Fase 0 – Preparazione
- [ ] Inventario completo endpoint/chiavi e versioni SDK.
- [ ] Definire tipologie di risposta per ciascun provider (Response API, SSE, WebSocket) e mappatura campi -> `AIStreamChunk`.
- [ ] Aggiornare documentazione interna (chiavi feature flag, fallback).
- [ ] Aggiornare `CloudflareGatewayClient` contract: nuova route `/v1/responses` da affiancare a legacy finché client non migrano completamente.

### Fase 1 – Refactor core layer
- [x] Creare `AIStreamingClientProtocol` nel core (p.es. `Core/AI/Protocols`). *(Implementato come `AIStreamingClientProtocol` e tipi ausiliari in `Core/AI/Streaming`)*
- [x] Implementare `StreamingChatClient` generico in `AIProviderManager` registrando provider disponibili. *(Metodo `streamingClient(for:)` con cache e gestione flag Responses)*
- [x] Aggiornare `ChatService` per lavorare su protocollo astratto (iniezione provider-specific client). Prevedere fallback: se streaming disabilitato, accumula chunk e restituisce al termine.
- [ ] Aggiornare `EmailCategorizationService` e servizi offline per utilizzare modalità “complete” ma attraverso nuovo protocollo (per future ottimizzazioni).

- [x] Creare `OpenAIResponsesClient`:
  - Request: `POST /v1/responses` con payload `input`, `model`, `modalities`, `metadata`. Supportare `response_format: { type: "text" }`.
  - Streaming: impostare `stream: { mode: "text" }` o `?stream=true`, leggere SSE `event: response.output_text.delta` / `response.completed`.
  - Parsing error events (`response.error`) e `response.output_text` finale.
- [x] Aggiornare `OpenAIService` mantenendo un adapter per retrocompatibilità (deprecate `sendMessage`).
- [x] Adeguare consumer principali (ChatService, EmailAIService, EmailCategorizationService) a usare il nuovo layer quando disponibile.
- [x] Gestire eventi streaming aggiuntivi (`tool_calls`, usage delta) per Responses API.
- [ ] Estendere Cloudflare worker (OpenAI Proxy) per accettare nuovi payload e inoltrarli a OpenAI Responses.
- [ ] QA: chat UI, email categorizzazione, funzioni prompt mail, test fallback worker.

### Fase 3 – Groq (OpenAI-compatible streaming)
- [ ] Verificare supporto `stream=true` sul loro endpoint `/openai/v1/chat/completions` (SSE standard `choices[].delta.content`).
- [ ] Implementare `GroqStreamingClient` che sfrutta stessa logica di parsing (riusare parser OpenAI SSE con binding minimi).
- [ ] Aggiornare fallback Cloudflare: passare header `x-provider=groq` e trasmettere chunk.
- [ ] QA: selezione modello Groq in chat, prestazioni streaming.

### Fase 4 – xAI (Grok)
- [ ] Adeguare `ModernXAIService`:
  - Endpoint `POST /v1/chat/completions` con `stream=true` supportato.
  - Gestire eventi SSE (verificare formato: `choices[].delta.content` / `choices[].delta.reasoning_content`).
  - Feature flag per modelli `grok-4-*`.
- [ ] Uniformare mapping modelli (evitare `mapToXAIModel` che forza `grok-beta` se non necessario, oppure mantenere come fallback).
- [ ] QA streaming UI + fallback gateway.

### Fase 5 – Anthropic
- [ ] Migrare da `POST /v1/messages` a `POST /v1/messages` con `stream=true` (richiede header `anthropic-version` >= 2023-06-01).
- [ ] Parser SSE: eventi `message_start`, `content_block_start`, `content_block_delta`, `message_delta`, `message_stop`.
- [ ] Integrare `ThinkingManager` affinché elabori stream incrementale (anthropic invia "thinking" separato). Possibile: accumulare reasoning separato e inviare chunk utente finale.
- [ ] Aggiornare fallback Cloudflare: se gateway inoltra verso Anthropic, convertire Response API -> formati SSE (valutare compatibilità o mantenere fallback in modalità non streaming per prime release).

### Fase 6 – Apple Intelligence
- [ ] FoundationModels attuale non espone streaming token-by-token. Prevedere due modalità: (a) mostrare spinner fino a completamento (come oggi), (b) se/quando API offre streaming, adattare.
- [ ] Garantire che `AIStreamingClientProtocol` consenta implementazioni che restituiscono singolo chunk.

### Fase 7 – Rifiniture & rollout
- [ ] Aggiornare `ModelCatalog`, `AIProviderManager` per salvare preferenze e sapere se provider supporta streaming.
- [ ] Aggiornare UI (`ModularChatView`, `EmailDetailView`, eventuali estensioni) con opzioni “streaming on/off”, indicatori token.
- [ ] Aggiornare documentazione per utenti (release notes, changelog interno).
- [ ] Rollout progressivo: prima flag interno, poi beta tester, infine default.

## 5. Modifiche Cloudflare Worker / Gateway
- Nuovi endpoint:
  - `/v1/responses` → inoltro trasparente a OpenAI `responses`.
  - `/v1/stream` (opzionale) come alias SSE per provider che non supportano `responses`.
- Header `x-provider` determina provider downstream (`openai`, `groq`, `xai`, `anthropic`).
- Necessario supporto SSE pass-through: usare `event.waitUntil` + `ReadableStream` per forward chunk.
- Logging: standardizzare event metadata (`provider`, `model`, `latency_first_token`, `total_duration`).
- Rate limiting: assicurarsi di propagare header downstream, gestire 429 con retry/backoff lato client.

## 6. Aggiornamento componenti applicativi
- **ChatService**: refactor per gestire `AsyncThrowingStream` generico. Mantenere storicizzazione chunk → aggiornare `messages[idx].content` incrementalmente, `saveCoreDataMessage` solo a completamento.
- **EmailCategorizationService**: per ora continuare a usare completamento. Prevedere flag `categorizationUsesStreaming` per future ottimizzazioni (es. gestione `thinking`).
- **EmailComposer / Draft tools**: se usano `OpenAIService`, passare al nuovo client.
- **Prompt manager**: aggiornare interfacce per includere eventuali metadati (p.es. `response_id`, `usage`).
- **Telemetry**: definire `AIEventLogger` per registrare chunk, errori, tempi. Possibile integrazione con `PerformanceSignpost` già usato in UI.

## 7. Testing & QA
- **Unit Test**: parser SSE (OpenAI, Groq, xAI, Anthropic) con sample reali.
- **Integration Test**:
  - Chat conversation end-to-end per ogni provider (flag streaming on/off).
  - Email categorizzazione (ai + tradizionale) verificando che fallback funzioni.
  - Gateway fallback (simulate API key missing) con streaming attivo.
- **UI Manual Test**:
  - Chat: latenza, interruzione manuale, errori (429, timeout) → conferma messaggi di errore non duplicati.
  - iOS background refresh: assicurarsi che stream venga cancellato correttamente quando view scompare.
- **Performance**: misurare TTFB (time-to-first-byte) pre/post migrazione, uso CPU/UI.
- **Regression**: assicurarsi che export conversazione, cronologia CoreData, session persistence funzionino.
- **Stato corrente**: build completa (`xcodebuild -workspace Marilena.xcworkspace -scheme Marilena-iOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' build`) superata con i nuovi flag Responses attivi.

## 8. Rischi e mitigazioni
- **Disallineamento formati SSE** → Mitigare con parser per provider e fallback a completa.
- **Timeout di rete più frequenti** (stream aperti) → aggiungere heartbeat/timeout custom, cancellare Task se nessun chunk in X secondi.
- **Aumento uso dati** → Considerare compressione/limitare chunk se UI non visibile.
- **Cloudflare Worker limitazioni** → monitorare CPU/ram; ottimizzare per streaming (evitare buffering totale).
- **Librerie FoundationModels** non supportano streaming → mantenere percorso sincrono con compat layer in protocollo.
- **Persistenza CoreData**: aggiornamenti frequenti potrebbero rallentare; salvare solo completamenti.

## 9. Dipendenze & Checklist pre-deploy
- [ ] Aggiornare SDK/headers provider (OpenAI 2024-12-01, Anthropic 2023-10-14, xAI docs).
- [ ] Verificare compatibilità minima iOS/macOS.
- [ ] Aggiornare provisioning worker (chiavi, secrets) per nuovi endpoint.
- [ ] Preparare script di migrazione UserDefaults (nuovi flag, salvataggio response_id).
- [ ] Documentare API limit/rate per streaming (p.es. 2 stream simultanei per account?).

## 10. Rollout suggerito
1. **Dev Feature Flag**: attivare streaming solo per account di test.
2. **Beta**: abilitare su TestFlight, monitorare metriche.
3. **GA**: attivare per tutti gli utenti; mantenere fallback flag per 1 release.
4. **Cleanup**: rimuovere vecchi endpoint `chat/completions` e codice legacy dopo 2 release stabili.

## 11. Appendice – Mappatura eventi SSE
| Provider | Endpoint | Evento testo | Evento fine | Errori |
|----------|----------|--------------|-------------|--------|
| OpenAI | `/v1/responses` | `response.output_text.delta` | `response.completed` | `response.error` |
| Groq | `/openai/v1/chat/completions` | `data: { choices[].delta.content }` | `data: [DONE]` | status HTTP + eventuale payload `error` |
| xAI | `/v1/chat/completions` | `choices[].delta.content` | `[DONE]` | `error` field |
| Anthropic | `/v1/messages?stream=true` | `content_block_delta` (text) | `message_stop` | `error` event / HTTP |
| Gateway | `/v1/chat/completions` (legacy) / `/v1/responses` (nuovo) | Pass-through coerente col provider | Dipende dal provider | Pass-through |

## 12. Prossimi passi immediati
- Validare piano con stakeholder (Mario, team AI).
- Stimare effort per ogni fase e assegnare owner.
- Preparare proof-of-concept Responses API (branch sperimentale) per valutare eventuali incompatibilità.

## 13. Stima effort (indicativa)
| Fase | Attività principali | Effort stimato | Note |
|------|--------------------|----------------|------|
| 0 | Analisi dettagli fornitori, aggiornamento documentazione interna, definizione flag | 1 dev-giorno | Coinvolge engineering + devops per inventory chiavi |
| 1 | Refactor core layer (`AIStreamingClientProtocol`, adattamento ChatService/EmailCategorizationService) | 3 dev-giorni | Richiede pair review: impatto critico su chat & CoreData |
| 2 | Implementazione OpenAI Responses API + aggiornamento gateway + QA mirato | 3 dev-giorni + 1 QA | Include POC tool use, test su categorizzazione email |
| 3 | Groq streaming client + fallback gateway | 1.5 dev-giorni | Condivisione parser con OpenAI riduce effort |
| 4 | xAI streaming client + pulizia mapping modelli | 1.5 dev-giorni | Necessario coordinamento con team integrazione xAI |
| 5 | Anthropic streaming + adattamento ThinkingManager | 2 dev-giorni | Parsing eventi complessi, QA approfondito |
| 6 | Apple Intelligence compat layer (no streaming) | 0.5 dev-giorni | Solo adeguamento protocollo comune |
| 7 | UI/telemetry updates, rollout, docs | 2 dev-giorni + 1 QA | Include TestFlight, metrics, release notes |
| **Totale** |  | **14 dev-giorni + 2 QA** | Stima lineare; riduzione possibile con parallelizzazione |

## 14. Supporto Tool Use nelle Responses API
- Le Responses API permettono di dichiarare strumenti tramite proprietà `tools` (`function`/`json_schema`) e controllare la chiamata con `tool_choice`.
- Il modello di streaming emette eventi intermedi (`response.tool_calls.delta`) che possono essere mappati nella stessa infrastruttura `AIStreamChunk` aggiungendo campi opzionali per `toolCallId` e `argumentsDelta`.
- **Piano di integrazione**:
  1. Estendere il protocollo comune con un oggetto `AIToolCallChunk` facoltativo.
  2. Ripristinare/aggiornare i tool esistenti (es. actions calendario, CRM) traslando il vecchio formato Chat Completions.
  3. Aggiornare UI per mostrare quando l'AI invoca un tool e gestire callback asincrone.
- Il worker Cloudflare dovrà propagare il payload `tools` e forwardare gli eventi `tool_calls` senza buffering.
- Per Groq/xAI verificare roadmap pubblica: ad oggi replicano il formato OpenAI, quindi i tool saranno supportabili con minima traduzione; Anthropic richiede mapping verso `tools`/`tool_choice` nella forma prevista da Claude 3.
