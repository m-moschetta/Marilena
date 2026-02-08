# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build (always use workspace, not .xcodeproj)
xcodebuild -workspace Marilena.xcworkspace -scheme Marilena-iOS -destination "platform=iOS Simulator,name=iPhone 16" build

# Run tests
xcodebuild -workspace Marilena.xcworkspace -scheme Marilena-iOS -destination "platform=iOS Simulator,name=iPhone 16" test

# Open in Xcode
open Marilena.xcworkspace
```

- **Always use iPhone 16 simulator** (not iPhone 15)
- **Always use `.xcworkspace`** (not `.xcodeproj`) — the workspace includes SPM dependencies
- Deployment target: iOS 26.0+
- Test plan: `Marilena-iOS.xctestplan`

## Architecture Overview

Marilena is a SwiftUI productivity assistant combining AI chat, email management, calendar, audio transcription, and task planning.

### Core Layers

```
Core/                          # Infrastructure & services
├── AI/                        # Multi-provider AI system
│   ├── AIServiceProtocol      # Common protocol for all providers
│   ├── AICoordinator          # Central orchestrator with health monitoring
│   ├── ModernOpenAIService    # OpenAI (Chat Completions + Responses API)
│   ├── ModernXAIService       # xAI/Grok with reasoning tokens
│   ├── Streaming/             # OpenAI Responses API streaming client
│   └── FoundationModels/      # Apple Intelligence (on-device)
├── Configuration/             # Model catalog, provider enums, capabilities
├── Email/Services/            # Refactored email (auth, network, cache, threading)
├── Calendar/                  # Multi-provider calendar (EventKit, Google, Microsoft)
├── Data/Services/             # Chat, CRM, user profile services
├── Domain/Entities/           # ChatMessage, Profilo
├── Repository/                # Repository pattern (Email, Chat, MemoryCache)
├── DependencyInjection/       # ServiceContainer (thread-safe singleton DI)
├── Performance/               # Deferred init, signposts, metrics
└── Tooling/                   # AI tool calling orchestration

Features/                      # Feature modules (self-contained)
├── Chat/                      # AI chat UI (ChatView, ModularChatView, ChatMessageRow)
├── Email/List/                # MVVM with EmailListViewModel
├── NewCalendar/               # Modern calendar (Models, Services, Views, Utils)
├── Planner/                   # Task planning
└── Profilo/                   # User profile

Root-level (Marilena/)         # Legacy + provider-specific services
├── *Service.swift             # OpenAI, Anthropic, Groq, Apple Intelligence services
├── AIProviderManager          # Provider selection & fallback cascade
├── ModelCatalog               # Dynamic model fetching with 1-hour cache
├── EmailService               # Legacy monolithic email (being replaced by Core/Email/)
├── KeychainManager            # Secure API key storage
└── CloudflareGatewayClient    # API gateway fallback
```

### Key Architectural Patterns

**AI Provider System** — Protocol-oriented multi-provider abstraction:
- `AIServiceProtocol` defines `sendMessage()` and `sendStreamMessage()` for all providers
- `AIProviderManager` handles selection with fallback cascade: Apple → OpenAI → Anthropic → Groq → xAI
- `ModelCatalog` fetches available models from provider APIs (cached 1 hour)
- All API keys stored in Keychain via `KeychainManager.shared`
- UserDefaults keys: `selectedProvider`, `selectedChatModel`, `selectedAnthropicModel`, `selectedGroqChatModel`, `selectedXAIChatModel`, `use_responses_api`, `force_gateway`

**Email System** — Recently refactored from monolithic to modular:
- Old: single `EmailService.swift` (2262 lines)
- New: `Core/Email/Services/` with `EmailAuthService`, `EmailNetworkService`, `EmailCacheManager`, `EmailThreadingManager`, `RefactoredEmailService` (orchestrator)
- MVVM: `Features/Email/List/EmailListViewModel` for UI logic
- Both old and new coexist during migration

**Calendar System** — Multi-provider via `CalendarServiceProtocol`:
- Implementations: `EventKitCalendarService` (Apple), `GoogleCalendarService`, `MicrosoftGraphCalendarService`
- `CalendarManager` orchestrates across providers
- `NewCalendarService` adds smart caching with merge strategy

**Dependency Injection** — `ServiceContainer.shared`:
- Thread-safe singleton at `Core/DependencyInjection/ServiceContainer.swift`
- Register/resolve pattern with protocol-based services
- Protocols defined in `ServiceProtocols.swift`

**Data Persistence** — Core Data via `PersistenceController.shared`:
- Model: `Marilena.xcdatamodeld`
- Merge policy: `NSMergeByPropertyObjectTrumpMergePolicy`
- Key entities: ChatMarilena, ChatMessage, EmailMessage, Recording, ProfiloUtente, CacheEntry

**Startup Flow** — `MarilenaApp.swift`:
- `@main` entry, initializes services with Core Data context
- Deferred initialization via `DeferredInitializationService` (staggered delays for Google Sign-In, speech permissions, etc.)
- URL scheme handling for widgets and OAuth redirects

### Adding a New AI Provider

1. Add case to `AIModelProvider` enum in `Core/Configuration/AIModelProvider.swift`
2. Create service implementing `AIServiceProtocol`
3. Register in `AIProviderManager.getOrderedChatProviders()`
4. Add API key to `KeychainManager`
5. Add models to `ModelCatalog` for dynamic fetching

### SPM Dependencies

GoogleSignIn-iOS, GoogleUtilities, GTMAppAuth, AppAuth, Promises, GTMSessionFetcher, AppCheck

## AI Provider Quick Reference

| Provider | Service File | Default Model | API Style |
|----------|-------------|---------------|-----------|
| Apple | `AppleIntelligenceService` | foundation-medium | On-device |
| OpenAI | `ModernOpenAIService` | gpt-4o | Chat Completions + Responses API |
| Anthropic | `AnthropicService` | claude-3-5-sonnet-20241022 | Messages API |
| Groq | `GroqService` | llama-3.1-8b-instant | OpenAI-compatible |
| xAI | `ModernXAIService` | grok-4-1-fast | OpenAI-compatible + reasoning tokens |

OpenAI Responses API (`POST /responses`) is recommended for reasoning models (o3, GPT-5) — enable via `use_responses_api` UserDefault. Cloudflare Gateway fallback available for OpenAI, Anthropic, Groq when API keys missing.
