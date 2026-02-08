# AI Models Integrator - Technical Reference

## Provider API Endpoints

### OpenAI
**Base URL:** `https://api.openai.com`
**Model List Endpoint:** `GET /v1/models`
**Response Format:**
```json
{
  "object": "list",
  "data": [
    {
      "id": "gpt-4o",
      "object": "model",
      "created": 1686588896,
      "owned_by": "openai",
      "permission": [{"id": "modelperm-123", "object": "model_permission"}],
      "root": "gpt-4o",
      "parent": null
    }
  ]
}
```

**Key Fields for Integration:**
- `id` - Model identifier (use as-is)
- `owned_by` - Owner indication (openai-dev, openai, system)
- `created` - Release timestamp

**Special Handling:**
- Vision models: contain "-vision" in ID (e.g., gpt-4-vision)
- Reasoning models: track separately (o1, o3, o1-mini)
- Turbo models: legacy, keep for backward compatibility

### Anthropic
**Base URL:** `https://api.anthropic.com`
**Model List Endpoint:** `GET /v1/models` (requires auth)
**Response Format:**
```json
{
  "type": "list",
  "data": [
    {
      "id": "claude-3-5-sonnet-20241022",
      "type": "model",
      "display_name": "Claude 3.5 Sonnet",
      "created_at": "2024-10-22T15:00:00Z"
    }
  ]
}
```

**Latest Models (2025):**
- `claude-opus-4-5-20251101` - Premium intelligence
- `claude-sonnet-4-5-20250929` - Best for real-world agents
- `claude-3-7-sonnet-20250219` - Extended thinking
- `claude-haiku-4-5-20251001` - Speed + thinking hybrid

**Key Fields for Integration:**
- `id` - Full model identifier with date
- `display_name` - Human-readable name
- `created_at` - ISO timestamp

**Special Handling:**
- All models support streaming natively
- Extended thinking models track reasoning tokens
- Context windows vary: check documentation per model

### Groq
**Base URL:** `https://api.groq.com`
**Model List Endpoint:** `GET /openai/v1/models` (OpenAI-compatible)
**Response Format:** Same as OpenAI (compatible API)

**Current Models (2025):**
- `llama-3.3-70b-versatile` - Large reasoning, best for complex
- `mixtral-8x7b-32768` - Multi-expert balanced
- `llama-3.1-8b-instant` - Fast, compact (default)
- `gemma-2-9b-it` - Google Gemma variant

**Key Fields for Integration:**
- `id` - Model ID (matches full name)
- `owned_by` - "groq"

**Special Handling:**
- OpenAI-compatible API - can reuse OpenAI request format
- Usage stats via `x_groq.usage` in stream responses
- No vision support yet
- Ultra-low latency - good for default fallback

### xAI (Grok)
**Base URL:** `https://api.x.ai`
**Model List Endpoint:** `GET /v1/models` (requires auth)
**Response Format:**
```json
{
  "object": "list",
  "data": [
    {
      "id": "grok-4-1-fast",
      "object": "model",
      "created": 1704067200,
      "owned_by": "xai"
    }
  ]
}
```

**Current Models (2025):**
- `grok-4-1-fast` - Reasoning model with tool use
- `grok-4-fast` - Faster variant
- `grok-4` / `grok-4-0709` - Standard
- `grok-4-vision` - Vision-capable

**Key Fields for Integration:**
- `id` - Model identifier
- `owned_by` - "xai"

**Special Handling:**
- Reasoning tokens tracked separately
- Tool support: web_search, x_search, code_execution, file_search
- Vision support via content arrays
- Citations returned in responses

## Integration File Locations

### Core Files to Update

#### 1. AIModelProvider.swift
**Purpose:** Define all provider enums and base URLs

```swift
enum AIModelProvider: String {
    case openai = "https://api.openai.com/v1"
    case anthropic = "https://api.anthropic.com/v1"
    case groq = "https://api.groq.com/openai/v1"
    case xai = "https://api.x.ai/v1"
    // ... other providers
}
```

**Integration Pattern:**
- Add new provider if needed
- Update baseURL if provider API changes
- Add provider-specific configuration

#### 2. AIModelConfiguration.swift
**Purpose:** Per-model configuration and capabilities

```swift
struct AIModelConfiguration {
    let modelId: String
    let displayName: String
    let provider: AIModelProvider
    let capabilities: AIModelCapabilities
    let maxTokens: Int
    let contextWindow: Int
    let costPer1k: Double?
}
```

**Integration Pattern:**
- Create configuration entry for each model
- Set appropriate capability flags
- Update cost/token estimates from provider docs

#### 3. AIModelCapabilities.swift
**Purpose:** Feature flags per model

```swift
struct AIModelCapabilities {
    var supportsStreaming: Bool = true
    var supportsVision: Bool = false
    var supportsReasoning: Bool = false
    var supportsToolUse: Bool = false
    var supportsCaching: Bool = false
    var supportsExtendedThinking: Bool = false
}
```

**Integration Pattern:**
- Set capability flags based on model features
- Reasoning models: set `supportsReasoning`
- Vision models: set `supportsVision`
- Tool-capable: set `supportsToolUse`

#### 4. ModelCatalog.swift
**Purpose:** Runtime model fetching and caching

```swift
class ModelCatalog {
    static let shared = ModelCatalog()

    func fetchModels(for provider: AIModelProvider) async -> [AIModelConfiguration]
    func getDefaultModel(for provider: AIModelProvider) -> String
    func refreshCache(maxAge: TimeInterval = 3600)
}
```

**Integration Pattern:**
- Add fetch logic for new providers
- Configure cache validity (default: 1 hour)
- Set fallback models if API fails

#### 5. CLAUDE.md
**Purpose:** Documentation of providers and models

**Integration Pattern:**
- Update "Supported Providers" section
- Add new model to provider list with capabilities
- Update "Knowledge Base Updates" section with new info

## Model Metadata Structure

When fetching models, extract and structure:

```json
{
  "model_id": "gpt-4o",
  "display_name": "GPT-4 Omni",
  "provider": "openai",
  "capabilities": {
    "streaming": true,
    "vision": true,
    "reasoning": false,
    "tool_use": true
  },
  "context_window": 128000,
  "max_output_tokens": 4096,
  "training_data_cutoff": "April 2024",
  "pricing": {
    "input_per_1k": 0.005,
    "output_per_1k": 0.015
  },
  "release_date": "2024-05-13",
  "status": "available"
}
```

## API Authentication

### Headers Required

**OpenAI:**
```
Authorization: Bearer {OPENAI_API_KEY}
```

**Anthropic:**
```
x-api-key: {ANTHROPIC_API_KEY}
anthropic-version: 2023-06-01
```

**Groq:**
```
Authorization: Bearer {GROQ_API_KEY}
```

**xAI:**
```
Authorization: Bearer {XAI_API_KEY}
```

## Fallback Chain

When a model is unavailable, Marilena follows this priority:

```
Apple Intelligence → OpenAI → Anthropic → Groq → xAI
```

**Integration Point:** `AIProviderManager.swift`

Update fallback order if new providers added.

## Testing Integration

After adding new models, verify:

1. **Model availability** - Call each provider's model endpoint
2. **API authentication** - Verify keys are correct
3. **Model selection** - Test default model selection logic
4. **Streaming** - Test streaming response handling
5. **Capability detection** - Verify capability flags match model behavior

## Version Updates

Keep track of:
- Provider API version (e.g., Anthropic: 2023-06-01)
- Model release dates
- Breaking changes in provider APIs

Update `CLAUDE.md` "Knowledge Base Updates" section when:
- New provider documentation is available
- Models are deprecated
- API endpoints change
- New capabilities are introduced
