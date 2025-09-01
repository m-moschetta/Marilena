---
name: "Performance – Phase 1 (Startup, Render, Memory)"
about: Ottimizzazioni mirate su avvio, rendering SwiftUI e memoria
title: "perf: phase 1 – startup/render/memory"
labels: [performance]
assignees: []
---

## Contesto
Obiettivo migliorare startup time, frame pacing SwiftUI e footprint memoria.

## KPI Target
- Startup cold < 1.5s (simulator iPhone 15)
- 60 fps stabili nelle viste principali
- Memoria < 200MB in scenari comuni

## Checklist
- [ ] Lazy init servizi non critici (post-first-frame)
- [ ] Defer caricamento asset pesanti
- [ ] Profilo Instruments (Time Profiler, SwiftUI) – baseline
- [ ] Memoization calcoli costosi in `body`
- [ ] `@StateObject` vs `@ObservedObject` valutato
- [ ] Riduzione hop su main thread
- [ ] Policy cache con TTL/size e eviction
- [ ] Downsampling media (immagini/audio)
- [ ] Report finale con confronti baseline vs ottimizzato

## Criteri di Accettazione
- KPI rispettati e profili Instruments allegati
- Nessuna regressione UX nei flussi principali

