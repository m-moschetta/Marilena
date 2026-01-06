# Claude Configuration

## Build Settings
- Always use iPhone 16 simulator for iOS builds instead of iPhone 15
- Default build command: `xcodebuild -workspace Marilena.xcworkspace -scheme Marilena-iOS -destination "platform=iOS Simulator,name=iPhone 16" build`

## Test Settings
- Use iPhone 16 simulator for running tests
- Test command: `xcodebuild -workspace Marilena.xcworkspace -scheme Marilena-iOS -destination "platform=iOS Simulator,name=iPhone 16" test`

## Development Notes
- Project uses SwiftUI and requires iOS 26.0 deployment target
- Main workspace file: Marilena.xcworkspace (not .xcodeproj)
- Scheme name: Marilena-iOS

---

## AI Provider System

### Supported Providers

Marilena supports **10 AI providers** with multi-tier architecture:

#### Primary Chat Providers (5 Active)
These providers are fully integrated for chat conversations:

1. **Apple Intelligence** - On-device, privacy-first
   - Service: `AppleIntelligenceService.swift`
   - Default model: `foundation-medium`
   - Models: foundation-medium, foundation-large, foundation-xlarge
   - Features: On-device processing, no API key required
   - Configuration key: `selectedAppleModel`

2. **OpenAI** - Cloud-based, feature-rich
   - Service: `OpenAIService.swift` (legacy), `ModernOpenAIService.swift` (current)
   - Supported models: GPT-5, GPT-4o, GPT-4 Turbo, o3, o1, o1-mini, o3-mini
   - Default model: `gpt-4o`
   - Features: Streaming, function calling, vision, reasoning models
   - **Two API approaches:**
     - **Chat Completions API** (POST /v1/chat/completions): Standard streaming with `stream: true`
     - **Responses API** (POST /responses): Recommended for reasoning models (GPT-5, o3), provides better performance
   - Streaming configuration: Enable via `use_responses_api` UserDefault for Responses API, or use standard streaming with Chat Completions
   - **Note:** Reasoning models (o3, GPT-5) perform better and demonstrate higher intelligence when used with Responses API
   - Configuration key: `selectedChatModel`
   - Fallback: Cloudflare Gateway when API key unavailable

3. **Anthropic** - Claude models
   - Service: `AnthropicService.swift`
   - **Latest models (2025):**
     - `claude-opus-4-5-20251101` - Premium, maximum intelligence with practical performance
     - `claude-sonnet-4-5-20250929` - Best for real-world agents and coding
     - `claude-3-7-sonnet-20250219` - High-performance with extended thinking
     - `claude-haiku-4-5-20251001` - Hybrid model, instant responses + extended thinking
     - `claude-3-5-haiku-latest` - Fastest and most compact
     - Plus: Claude 3.5 Sonnet, Claude 3 Opus, Claude 3 Haiku variants
   - Default model: `claude-3-5-sonnet-20241022` (can be updated to newer versions)
   - Context window: Up to 200K tokens (some models support even larger contexts)
   - Features: Long context, coding, reasoning, extended thinking, native streaming
   - Streaming: Fully supported via Messages API (`stream: true`)
   - Configuration key: `selectedAnthropicModel`
   - Fallback: Cloudflare Gateway when API key unavailable

4. **Groq** - Inference acceleration
   - Service: `GroqService.swift`
   - Supported models: DeepSeek R1 Distill, Qwen 2.5, Llama 3.3, Mixtral 8x7B, Gemma 2 9B
   - Default model: `llama-3.1-8b-instant`
   - Features: Ultra-fast inference, multiple model options
   - Configuration key: `selectedGroqChatModel`
   - Fallback: Cloudflare Gateway when API key unavailable

5. **xAI (Grok)** - Latest models
   - Service: `ModernXAIService.swift`
   - Supported models: Grok 4 Latest, Grok 4, Grok 3, Grok Code Fast, Grok Vision Beta
   - Default model: `grok-4-latest`
   - Features: Streaming, vision capabilities
   - Configuration key: `selectedXAIChatModel`

#### Secondary Providers (Defined but limited functionality)
- **Google Gemini** - Defined in `AIModelProvider.swift`, models available in catalog
- **Meta Llama** - Defined in `AIModelProvider.swift`, models available in catalog
- **Mistral** - Defined in `AIModelProvider.swift`, search provider support only
- **Perplexity** - Search provider only (not for chat)
- **DeepSeek** - Defined in `AIModelProvider.swift`, available via Groq

### Provider Architecture

**Core Files:**
- `Core/Configuration/AIModelProvider.swift` - Enum defining all 10 providers with baseURL
- `Core/Configuration/AIModelConfiguration.swift` - Per-model configuration
- `Core/Configuration/AIModelCapabilities.swift` - Capability enum (reasoning, coding, vision, etc.)
- `AIProviderManager.swift` - Runtime provider selection and ordering
- `ModelCatalog.swift` - Dynamic model fetching with 1-hour cache

**Abstraction Layer:**
```
AIServiceProtocol (Core/AI/AIServiceProtocol.swift)
├── OpenAIService / ModernOpenAIService
├── AnthropicService
├── GroqService
├── AppleIntelligenceService
└── ModernXAIService
```

### Model Selection Logic

Provider selection follows this priority order:
1. User-selected provider (UserDefaults `selectedProvider`)
2. Fallback cascade: Apple → OpenAI → Anthropic → Groq → xAI

Model selection per provider:
- Checks UserDefaults for user preference
- Falls back to ModelCatalog (dynamically fetched)
- Final fallback to hardcoded default model

### Streaming Support

- **OpenAI**: Dual streaming support
  - Standard: Chat Completions API with `stream: true`
  - Recommended for reasoning models: Responses API (when `use_responses_api` enabled)
- **Anthropic**: Native streaming via Messages API (`stream: true`)
- **xAI**: Streaming supported via `ModernXAIService`
- **Groq**: Streaming support available via API

### Dynamic Model Catalog

`ModelCatalog.swift` provides:
- Live model fetching from provider APIs (requires API key)
- 1-hour cache validity
- Static fallback models if API fetch fails
- Automatic model refresh capability

Supported in live fetch: OpenAI, Anthropic, Groq, Mistral, xAI

### API Key Management

All API keys stored securely in Keychain via `KeychainManager.shared`:
- `openai` → OpenAI API key
- `anthropic` → Anthropic API key
- `groq` → Groq API key
- `xai` → xAI API key
- `mistral` → Mistral API key (secondary)
- `perplexity` → Perplexity API key (search only)

### Cloudflare Gateway Fallback

When `force_gateway` UserDefault is enabled or API key missing:
- Requests route through CloudflareGatewayClient.swift
- Supports: OpenAI, Anthropic, Groq fallback
- Useful for development or when direct API access limited

### Key Configuration UserDefaults

```
selectedProvider          # Currently selected provider (string)
selectedChatModel        # OpenAI model choice
selectedAppleModel       # Apple Intelligence model
selectedAnthropicModel   # Anthropic model choice
selectedGroqChatModel    # Groq model choice
selectedXAIChatModel     # xAI model choice
use_responses_api        # Enable OpenAI Responses API (boolean)
force_gateway            # Force Cloudflare Gateway (boolean)
```

### Directory Structure

```
Core/
  AI/
    AIServiceProtocol.swift
    AICoordinator.swift
    ModernOpenAIService.swift
    ModernXAIService.swift
    AICacheManager.swift
    Streaming/
      └── OpenAIResponsesClient.swift
    FoundationModels/
    Tooling/
  Configuration/
    AIModelProvider.swift (10 providers)
    AIModelConfiguration.swift
    AIModelCatalog.swift
    AIModelCapabilities.swift

Root/
  OpenAIService.swift (legacy)
  AnthropicService.swift
  GroqService.swift
  AppleIntelligenceService.swift
  AIProviderManager.swift
  ModelCatalog.swift
  CloudflareGatewayClient.swift
```

### API Implementation Details

#### OpenAI Integration

**Endpoints:**
- **Chat Completions**: `POST /v1/chat/completions`
  - Streaming: Set `stream: true` in request
  - Stream options: Use `stream_options` parameter for additional configuration
  - Request parameters: `model`, `messages`, `stream`, `max_tokens`, `temperature`

- **Responses API**: `POST /responses` (recommended for reasoning models)
  - Ideal for long-form content and reasoning models (o3, GPT-5)
  - Better performance on reasoning tasks
  - Stream events: `response.created`, `response.output_text.delta`, `response.completed`

**Request format:**
```json
{
  "model": "gpt-5",
  "messages": [{"role": "user", "content": "..."}],
  "stream": true,
  "stream_options": {"include_usage": true}
}
```

#### Anthropic/Claude Integration

**Endpoint:** `POST /v1/messages`

**Streaming:**
```
set stream = true
```

**Latest models to consider for ModelCatalog updates:**
- `claude-opus-4-5-20251101` - Premium intelligence
- `claude-sonnet-4-5-20250929` - Best for agents
- `claude-3-7-sonnet-20250219` - Extended thinking
- `claude-haiku-4-5-20251001` - Speed + thinking hybrid

**Request format:**
```json
{
  "model": "claude-opus-4-5-20251101",
  "max_tokens": 1024,
  "messages": [{"role": "user", "content": "..."}],
  "stream": true
}
```

### Knowledge Base Updates (as of 2025-01-06)

**From official OpenAI docs:**
- Responses API is the recommended path for all new implementations
- Reasoning models (o3, GPT-5) demonstrate higher intelligence with Responses API

**From official Anthropic docs:**
- Claude 4.5 family (opus, sonnet, haiku variants) are latest generation
- Native streaming support across all models
- Extended thinking capabilities in latest Sonnet and Haiku models

**Recommended next steps:**
1. Update default models in ModelCatalog to latest versions
2. Consider migrating OpenAI to Responses API for consistency
3. Implement Anthropic streaming in `AnthropicService.swift`
4. Consider adding Groq native streaming support