# Performance – Phase 2 (Network, Core Data, AI pipeline)

Riferimento: docs/REFACTORING_PLAN.md (M7 – Performance)

## KPI Target
- Overhead networking locale < 300ms (escluso tempo modello)
- Fetch Core Data principali < 50ms
- UI reattiva durante streaming AI (no hitch > 16ms)

## Checklist Operativa
- [ ] HTTP/2 keep-alive e coalescenza richieste
- [ ] Retry/backoff centralizzati (exponential)
- [ ] Riduzione header/payload (compressione opzionale)
- [ ] Repository con fetch limit/offset/prefetch su background
- [ ] Batch updates/fetches dove sensato
- [ ] Pipeline AI streaming con callback di chunk e backpressure
- [ ] Parser incrementali; ridurre copie stringhe
- [ ] Report finale con confronti baseline vs ottimizzato

## Criteri di Accettazione
- KPI rispettati e profili Instruments allegati
- Nessun blocco su main thread per I/O pesante

