# AGENTS.md

Guida per AI agents che lavorano su questo progetto iOS Marilena.

## Build & Test

```bash
# Build (usa sempre workspace, non .xcodeproj)
xcodebuild -workspace Marilena.xcworkspace -scheme Marilena-iOS -destination "platform=iOS Simulator,name=iPhone 16" build

# Run tests
xcodebuild -workspace Marilena.xcworkspace -scheme Marilena-iOS -destination "platform=iOS Simulator,name=iPhone 16" test
```

- **Sempre iPhone 16 simulator** (non iPhone 15)
- **Sempre `.xcworkspace`** (non `.xcodeproj`) — include dipendenze SPM
- Deployment target: iOS 26.0+

## Architecture

Marilena è un'app iOS SwiftUI per produttività con AI chat, email, calendario, trascrizione audio e task planning.

### Struttura Cartelle

```
Core/                          # Infrastructure & services
├── AI/                        # Multi-provider AI system
├── Configuration/             # Model catalog, provider enums
├── Email/Services/            # Email modulari (auth, network, cache)
├── Calendar/                  # Calendario multi-provider
├── Data/Services/             # Chat, CRM, user profile
├── Domain/Entities/           # Modelli dati
├── Repository/                # Repository pattern
├── DependencyInjection/       # ServiceContainer (DI singleton)
└── Tooling/                   # AI tool calling

Features/                      # Feature modules
├── Chat/                      # UI Chat
├── Email/List/                # MVVM Email
├── NewCalendar/               # Calendario moderno
├── Planner/                   # Task planning
└── Profilo/                   # Profilo utente

Marilena/                      # Root: legacy + servizi specifici
```

### Pattern Chiave

**AI Provider System** — Multi-provider con protocollo:
- `AIServiceProtocol` per tutti i provider
- Fallback cascade: Apple → OpenAI → Anthropic → Groq → xAI
- Chiavi API in Keychain (`KeychainManager.shared`)
- UserDefaults: `selectedProvider`, `selectedChatModel`, `use_responses_api`

**Dependency Injection** — `ServiceContainer.shared`:
- Thread-safe singleton
- Register/resolve pattern
- Protocols in `ServiceProtocols.swift`

**Data Persistence** — Core Data:
- `PersistenceController.shared`
- Model: `Marilena.xcdatamodeld`
- Merge policy: `NSMergeByPropertyObjectTrumpMergePolicy`

## AI Providers

| Provider | Servizio | Modello Default |
|----------|----------|-----------------|
| Apple | `AppleIntelligenceService` | foundation-medium |
| OpenAI | `ModernOpenAIService` | gpt-4o |
| Anthropic | `AnthropicService` | claude-3-5-sonnet-20241022 |
| Groq | `GroqService` | llama-3.1-8b-instant |
| xAI | `ModernXAIService` | grok-4-1-fast |

## Convenzioni

- Segui pattern esistenti nel codice vicino alle modifiche
- Usa `ServiceContainer.shared` per dipendenze
- Preferisci Core Data per persistenza
- Aggiungi provider AI seguendo `AIServiceProtocol`
- Documenta breaking changes

## Dipendenze SPM

GoogleSignIn-iOS, GoogleUtilities, GTMAppAuth, AppAuth, Promises, GTMSessionFetcher, AppCheck
