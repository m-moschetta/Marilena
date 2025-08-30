# Performance – Phase 1 (Startup, Render, Memory)

Riferimento: docs/REFACTORING_PLAN.md (M7 – Performance)

## KPI Target
- Startup cold < 1.5s (simulator iPhone 15)
- 60 fps stabili nelle viste principali
- Memoria < 200MB in scenari comuni

## Checklist Operativa
- [x] Lazy init servizi non critici (post-first-frame) — aggiunto `DeferredInitializationService` e defer per Google Sign-In & permessi Speech
- [x] Strumentazione leggera startup (AppPerformanceMetrics + os_signpost)
- [x] Signpost eventi viste principali (Home/Email/Chat/Registrazioni)
- [ ] Defer caricamento asset pesanti
- [ ] Profilo Instruments (Time Profiler, SwiftUI) – baseline
- [ ] Memoization calcoli costosi in body
- [ ] @StateObject vs @ObservedObject valutato nei container
- [ ] Riduzione hop su main thread
- [ ] Policy cache con TTL/size e eviction
- [ ] Downsampling media (immagini/audio)
- [ ] Report finale con confronti baseline vs ottimizzato

## Criteri di Accettazione
- KPI rispettati e profili Instruments allegati
- Nessuna regressione UX nei flussi principali

## Note Operative
- Per la misurazione: apri Instruments → Template "Time Profiler" e "SwiftUI"; aggiungi anche "Points of Interest" per visualizzare i signpost.
- I signpost AppInit marcano l'intervallo tra init app e first frame.

## Baseline Report (da compilare)
- Device/simulatore: (es. iPhone 16 sim iOS 26.0)
- Commit hash: 
- Startup (AppInit→FirstFrame): __ s
- Frame pacing (home/chat/registrazioni): __ fps medio, hitch >16ms: __
- Memoria (home/chat/registrazioni): medio __ MB, picco __ MB
- Core Data (fetch principali): __ ms
- Note hot paths (Time Profiler):
  - 
  - 
