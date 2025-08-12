## Piano dettagliato: Target macOS nativo per Marilena (stessa codebase, target separato)

### Obiettivi
- **Aggiungere un target macOS (SwiftUI App)** nello stesso progetto, riusando la codebase esistente senza rompere i target iPhone/iPad.
- **Build continue**: ad ogni step rilevante, build su iPhone 16 per garantire stabilità iOS; build macOS quando il target è pronto.
- **Compatibilità**: iOS 26 con retro-compatibilità iOS 18 già rispettata; per macOS puntiamo a macOS 14+ (regolabile).

### Strategia
1) Creare nuovo target `Marilena-macOS` (SwiftUI App) nello stesso `.xcodeproj`.
2) Separare i punti di ingresso: `MarilenaApp.swift` (solo iOS) e nuovo `MarilenaMacApp.swift` (solo macOS).
3) Plist/Entitlements separati per macOS, includendo sandbox, network, keychain, calendari, microfono, file access user-selected.
4) Minimi adattamenti condizionali (`#if os(iOS) / os(macOS)`) per API non portabili.
5) Adattamenti UX macOS: toolbar/menù, `NavigationSplitView` già ok; eventuali differenze con `NSWorkspace` al posto di `UIApplication`.

### Roadmap tecnica (con check build)
Fase 0 — Baseline
- [ ] Branch `macos` creato e pushato
- [ ] Build iOS baseline: iPhone 16 (xcodebuild) → deve essere verde

Fase 1 — Target e boot macOS
- [ ] Aggiunta target `Marilena-macOS` (SwiftUI App)
- [ ] Creazione `Marilena/MarilenaMacApp.swift` con entrypoint macOS
- [ ] Creazione `Marilena/Info-macOS.plist`
- [ ] Creazione `Marilena/Marilena-macOS.entitlements`
- [ ] Config build settings: `SUPPORTED_PLATFORMS=macosx`, `MACOSX_DEPLOYMENT_TARGET=14.0`, bundle id dedicato
- [ ] Build iOS (iPhone 16) → deve restare verde
- [ ] Build macOS (può fallire inizialmente per API iOS non ancora condizionate)

Fase 2 — Condizionali piattaforma (passo-1, build-safe)
- [ ] Isolare `@main` iOS con `#if os(iOS)` in `MarilenaApp.swift`
- [ ] Aggiungere `MarilenaMacApp.swift` con `@main` macOS
- [ ] Wrappers cross-platform minimi:
  - open URL: `NSWorkspace.shared.open` vs `UIApplication.shared.open`
  - settings deeplink: usare `NSWorkspace.open` Preferenze di Sistema equivalent o disabilitare su macOS
- [ ] Build iOS (iPhone 16)
- [ ] Build macOS: verificare errori residui

Fase 3 — Servizi e permessi
- [ ] Audio: rimuovere dipendenza `AVAudioSession` lato macOS, usare `AVAudioEngine` dove necessario
- [ ] Speech: `SFSpeechRecognizer` funziona su macOS con privacy strings dedicate
- [ ] OAuth: `ASWebAuthenticationSession` supportata su macOS; configurare URL schemes nel plist macOS
- [ ] Calendario: entitlement Calendars su macOS
- [ ] Keychain: entitlement keychain access su macOS
- [ ] Build iOS (iPhone 16)
- [ ] Build macOS

Fase 4 — UX/Desktop
- [ ] Toolbar/CommandMenu macOS (nuove scorciatoie)
- [ ] Verifica layout principali con `NavigationSplitView`
- [ ] Eventuali differenze per `UIPasteboard` → `NSPasteboard`
- [ ] Build iOS (iPhone 16)
- [ ] Build macOS

Fase 5 — Rifiniture e QA
- [ ] Icone/asset macOS
- [ ] Verifica sandbox file access (user-selected read/write)
- [ ] Test funzionali core: email viewer, chat AI, registrazioni, trascrizioni, calendari, OAuth
- [ ] Build finali: iPhone 16 e macOS

### File nuovi previsti
- `Marilena/MarilenaMacApp.swift` (entry macOS)
- `Marilena/Info-macOS.plist`
- `Marilena/Marilena-macOS.entitlements`

### Punti di attenzione
- API iOS-only: `UIApplication`, `UIDevice`, `UIScreen`, `UIPasteboard`, `AVAudioSession`, `UIWindowScene`
- Sostituzioni macOS: `NSWorkspace`, `NSScreen`, `NSPasteboard`, nessun `AVAudioSession`
- Garantire che i condizionali non modifichino il comportamento iOS

### Accettazione
- iOS: build verde su iPhone 16 in ogni fase
- macOS: app si avvia, navigazione principale funziona, OAuth/Calendario/Audio/Speech ok
- Nessuna regressione su iPhone/iPad


