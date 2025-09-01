# Piano di Refactoring Completo Email (Marilena)

Questo documento definisce obiettivi, perimetro, architettura, UX, integrazioni e milestones per rifattorizzare completamente la gestione email in Marilena, incluse classificazione/categorie/filtri, navigazione, funzionalità operative, e integrazione con la chat (composizione assistita e conferma invio) e calendario.

## Obiettivi
- Affidabilità: sincronizzazione email robusta (inbox, sent, draft, labels), resiliente a retry e conflitti.
- Classificazione: categorizzazione solida (labels/filtri) con motore regole + segnali ML (estensibile), mappata ai filtri esistenti.
- UX moderna: navigazione per caselle/categorie/filtri, thread view, azioni rapide, ricerca.
- Chat-driven reply: composizione assistita della risposta basata su cronologia email, interazioni precedenti con il contatto, calendario e titoli registrazioni.
- Conferma in chat: apertura canvas con bozza pronta, invio e conferma/telemetria nella chat.
- Scalabilità: architettura modulare, testabile, separazione provider/transport, storage locale, sync layer.
- Privacy/permessi: consenso esplicito per lettura calendario/registrazioni e gestione sicura dei token.

## Perimetro (Scope)
- In: ingestione email, storage locale, sync IMAP/API provider, classificazione, filtri, UX inbox/thread, ricerca, composizione/invio, integrazione chat, lettura calendario/registrazioni (read-only iniziale), notifiche.
- Out (fase 1): training ML personalizzato, smart scheduling automatico, regole server-side avanzate, allegati >25MB con upload chunked multi-provider.

## Problemi attuali (ipotesi)
- Le mail non rispettano i filtri/categorie esistenti.
- Navigazione limitata (assenza di viste per categorie/labels, thread incompleti).
- Composizione da chat non collega cronologia/contesto/agenda.
- Mancanza di conferma invio in chat e tracking stato.

## Architettura proposta
- Data Sources
  - Provider: Gmail API (REST), Microsoft Graph, IMAP standard (fallback), SMTP/Send API per invio.
  - Calendario: EventKit (iOS) + mapping a contatti; in futuro legame registrazioni-calendario.
- Strati
  1) Transport/Provider: connettori per Gmail/Graph/IMAP con interfaccia comune (`MailProvider`).
  2) Sync Engine: incremental sync (deltas), backoff, dedup, reconciliation labels/flags.
  3) Storage: modello locale (Core Data/SQLite) per `Message`, `Thread`, `Participant`, `Label`, `FilterRule`, `SyncState`.
  4) Classification: Rules Engine + Signals; mapping a `Label` e `Filter` (priorità regole > ML).
  5) Domain Services: `MailService`, `ComposeService`, `ReplySuggester`, `CalendarContextService`.
  6) UI Layer: SwiftUI views (InboxView, ThreadView, ComposeCanvas, FiltersView, SearchView, SettingsView).
  7) Chat Bridge: API per aprire canvas con bozza, invio, e post conferma nella chat.

## Modello Dati (bozza)
- Message: id, threadId, subject, bodyPlain, bodyHTML, from, to/cc/bcc, date, labels[], flags (seen/starred/draft/sent), attachments[], providerId, providerThreadKey, snippet.
- Thread: id, subject, participants[], messageIds[], lastUpdated, unreadCount, labels[].
- Label: id, name, type (system|user), color?, parentId?, providerMapping.
- FilterRule: id, name, conditions (from/domain/keywords/recipient/hasAttachment/time-range), actions (applyLabel/move/archive/star/forward), priority.
- CalendarInteraction: personId/email, events[], recordings[], lastContactedAt.
- SyncState: per-account cursori/ETag/HistoryId, lastSyncAt, errorState.

## Classificazione e Filtri
- Rules Engine deterministico: valutazione sequenziale per priorità; condizioni composte AND/OR; azioni applicate atomicamente.
- Signals/Heuristics: parole chiave, domini aziendali, frequenza, destinatari multipli, ore invio.
- ML Hook (facoltativo): endpoint locale per scoring categoria (business, personale, fatture, notifiche, marketing). Non bloccante: regole vincono su ML in conflitto.
- Mapping: categorie → `Label`; filtri UI leggono `Label` e `FilterRule`; sincronizzazione con provider quando possibile (Gmail Labels).

## Navigazione e UX
- InboxView: tabs/switch per categorie (Tutte, Importanti, Da rispondere, Promozioni, Notifiche, Personalizzate).
- Sidebar/FiltersView: elenco `Label`/filtri; drag-and-drop per rietichettare.
- ThreadView: cronologia messaggi, avatar, abstract allegati, azioni rapide (Archivia, Posticipa, Cita, Rispondi a tutti).
- Bulk actions: selezione multipla con applicazione etichette/archiviazione.
- Ricerca: soggetto, mittente, parole chiave, label, data range; indexing locale con highlights.
- Stato: contatori non letti per label/categorie; indicatori di sync.

## Chat → Mail (composizione assistita)
- Trigger: arrivo nuova email o richiesta manuale dalla chat.
- Context Builder:
  - Cronologia thread + ultime n interazioni con contatto.
  - Calendario: eventi con quel contatto (match via email/nome) dentro finestra temporale configurabile.
  - Registrazioni: titoli e metadati; in futuro link al calendario (id evento ↔ recording).
- Reply Suggester:
  - Genera bozza coerente con tono/stile del thread, includendo riferimenti a eventi/registrazioni pertinenti.
  - Suggerisce oggetto (RE: <subject> o adattivo) e firma.
- Compose Canvas (UI):
  - Apertura in overlay dalla chat con bozza precompilata, campi editabili (to/cc/bcc, subject, body), allegati suggeriti.
  - Pulsanti: Invia, Salva bozza, Scarta.
  - Validazioni: destinatari validi, reply-to corretta, quote selettiva.
- Conferma in Chat:
  - Dopo invio con successo, post automatico nella chat con: destinatari, oggetto, estratto, stato (inviata), link al thread.
  - In caso di errore, messaggio di errore con retry.

## Integrazione Calendario/Registrazioni
- Permessi: richiesta esplicita (EventKit) e consenso GDPR per associazione registrazioni.
- Matching contatti: normalizzazione email/nome, rubrica locale opzionale.
- Cache: `CalendarInteraction` aggiornata periodicamente (es. all’avvio e ogni X ore) o on-demand al trigger reply.
- Roadmap: legare registrazioni agli eventi (campo custom/URL) per navigazione rapida dal thread.

## Error Handling e Sync
- Retries con exponential backoff per API provider e invio SMTP.
- Idempotenza su create/send (messageIdempotencyKey).
- Conflitti di label: risoluzione last-writer-wins + merge.
- Offline-first: coda invii; UI stato (in attesa, inviando, inviato/fallito).

## Sicurezza e Privacy
- Token provider salvati in keychain; scadenza/refresh gestito.
- Scoping minimo per API (principio del minimo privilegio).
- Dati calendario/registrazioni usati solo per suggerimenti; opt-out disponibile.

## Testing e Telemetria
- Unit: Rules Engine, Sync, ComposeService, ReplySuggester, CalendarContextService.
- Integration: provider fake (Gmail/Graph) e DB in-memory.
- UI: snapshot test per Inbox/Thread/ComposeCanvas.
- Telemetria: eventi (email_suggested, email_sent, rule_applied, sync_error); no contenuti sensibili in log.

## Migrazioni
- Script di migrazione schema locale (Core Data/SQLite) per nuove entità.
- Backfill labels da provider esistenti.

## Strategia Branching
- Branch: `feature/mail-refactor-phase-1` (base: `perf/phase-1` o `main` secondo aggiornamento).
- PR incrementali per moduli: provider + storage → sync → rules → UI inbox/thread → compose/chat → calendario.

## Milestones e Criteri di Accettazione
1) Fondamenta Dati (provider + storage + sync)
   - CA: account connesso; inbox scaricata; non letti corretti; retry funzionante.
2) Classificazione/Filtri
   - CA: regole utente applicate; categorie visibili; mapping labels; test rules passano.
3) UX Inbox/Thread
   - CA: navigazione categorie, thread completo, azioni rapide, ricerca base.
4) Compose/Invio
   - CA: compose, invio SMTP/API, stati offline.
5) Chat Integration
   - CA: apertura canvas da chat con bozza; invio; conferma in chat con link.
6) Calendario/Registrazioni (read-only)
   - CA: suggerimenti che includono eventi/registrazioni pertinenti; permessi corretti.

## Rischi e Mitigazioni
- Diversità provider: astrazione `MailProvider` + test con fakes.
- Rate limits: caching, backoff, sync delta.
- Privacy: opt-in calendario/registrazioni; redazione dati nei log.
- Complessità UI: iterazioni PR piccole; snapshot test.

## Deliverables
- Codice modulare con servizi e viste descritte.
- Documentazione: README modulo email, guida setup provider, guida permessi calendario.
- Script migrazioni dati.
- Suite test unit/integration/UI.

## Sequenza Operativa (Fase 1)
1) Setup branch e skeleton moduli (provider/storage/sync).
2) Implementazione Rules Engine + UI filtri/labels.
3) Inbox/Thread UI e ricerca.
4) ComposeService + invio.
5) Chat Bridge + Compose Canvas + conferma invio.
6) CalendarContextService + suggerimenti.
7) Telemetria + rifiniture + QA.

## Note Implementative (Swift/iOS)
- State management: ObservableObject/SwiftData o Composable Architecture (se già in uso).
- Background sync: `BackgroundTasks` o refresh app; indicatori UI.
- Accessibilità: Dynamic Type, VoiceOver, colori label contrastati.

## Prossimi Passi
- Alla tua conferma: creo il branch `feature/mail-refactor-phase-1`, apro la struttura base e propongo il primo PR con skeleton + storage + interfacce provider.

