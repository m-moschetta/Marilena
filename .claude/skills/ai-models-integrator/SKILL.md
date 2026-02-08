---
name: ai-models-integrator
description: Fetch latest AI models from providers (OpenAI, Anthropic, Groq, xAI), integrate them into Marilena's model catalog, and update configuration. Use when adding new models, updating provider support, or syncing the latest available models.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# AI Models Integrator

Fetch and integrate the latest AI models from multiple providers into the Marilena application's model catalog system.

## Purpose

This skill automates the process of:
- **Discovering** latest available models from AI providers (OpenAI, Anthropic, Groq, xAI)
- **Fetching** model details including capabilities, context windows, and pricing
- **Integrating** new models into `ModelCatalog.swift` and `AIModelConfiguration.swift`
- **Updating** provider configurations and default model selections
- **Documenting** changes in `CLAUDE.md`

## Supported Providers

- **OpenAI**: GPT-4o, GPT-5, o3, reasoning models
- **Anthropic**: Claude 3.5+ family (Opus, Sonnet, Haiku)
- **Groq**: Llama, Mixtral, Gemma models with ultra-fast inference
- **xAI (Grok)**: Grok-4 series with reasoning and tool support

## When to Use This Skill

Use this skill when you need to:
- **Add new AI models** from any supported provider
- **Update the model catalog** with latest available models
- **Sync provider configurations** after API changes
- **Document model capabilities** and integration details
- **Configure API keys and endpoints** for new providers

## How It Works

### Step 1: Fetch Available Models
Run the provided `fetch_models.py` script with provider API keys to get:
```
python scripts/fetch_models.py --provider openai --api-key YOUR_KEY
```

Returns JSON with all available models, their capabilities, and metadata.

### Step 2: Analyze Integration Points
The skill identifies where to integrate:
- `AIModelProvider.swift` - Provider enum definitions
- `AIModelConfiguration.swift` - Per-model configuration
- `AIModelCapabilities.swift` - Model capability flags
- `ModelCatalog.swift` - Runtime model fetching
- `CLAUDE.md` - Documentation updates

### Step 3: Generate Integration Code
Create Swift code blocks that:
- Define new model enums
- Add capability mappings
- Configure provider endpoints
- Update default selections

### Step 4: Apply Changes
Integrate changes into source files with proper Swift formatting and validation.

### Step 5: Test and Document
- Verify model availability via API
- Update `CLAUDE.md` with latest provider info
- Test model selection in app

## Usage Examples

### Example 1: Add latest OpenAI models
```
Integrate the latest OpenAI models (GPT-5, o3) into Marilena
```

The skill will:
1. Fetch current OpenAI models from official API
2. Identify new models (GPT-5, o3, etc.)
3. Update `AIModelProvider.swift` with new model IDs
4. Configure reasoning model support in `AIModelCapabilities.swift`
5. Update `ModelCatalog.swift` to prefer reasoning models
6. Document in `CLAUDE.md`

### Example 2: Sync Groq models
```
Update Marilena's model catalog with latest Groq Llama models
```

The skill will:
1. Fetch available Groq models
2. Check for new model versions (e.g., `llama-3.3-70b-versatile`)
3. Update default model if newer version available
4. Verify OpenAI-compatible API compatibility
5. Update usage statistics tracking

### Example 3: Integrate xAI Grok tools
```
Add xAI Grok web search and code execution tool support to chat
```

The skill will:
1. Fetch Grok models with tool capabilities
2. Configure `ModernXAIService.swift` for tool support
3. Add reasoning token tracking setup
4. Document agentic tool patterns in `CLAUDE.md`

## Configuration

The skill requires API keys for the providers you want to sync:

```bash
# Set environment variables
export OPENAI_API_KEY=sk-...
export ANTHROPIC_API_KEY=sk-ant-...
export GROQ_API_KEY=gsk-...
export XAI_API_KEY=xai-...
```

Or provide keys directly during the skill execution.

## Output Files

After running this skill, you'll get:

1. **Updated Swift files** with new model definitions
2. **fetch_models.py output** - JSON with all available models
3. **Integration report** - Summary of changes made
4. **CLAUDE.md updates** - Latest provider documentation

## Advanced: Custom Model Mapping

For complex provider integrations, the skill can:
- Map provider-specific model IDs to standard names
- Configure capability flags per model
- Set provider-specific parameters (max_tokens, temperature defaults)
- Configure fallback chains for unavailable models

## Notes

- The skill respects existing model configurations and doesn't overwrite customizations
- Model fetching requires valid API keys for each provider
- Some providers (Groq, xAI) use OpenAI-compatible APIs - the skill detects this
- Reasoning models have special token tracking requirements - automatically configured
- Vision models detected and properly configured in capabilities
