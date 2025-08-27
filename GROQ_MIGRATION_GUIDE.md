# Guida alla Migrazione - Modelli Groq 2025

## ✅ Aggiornamenti Completati

### File Modificati:
1. **GroqService.swift** - Aggiornati nomi modelli e supporto thinking
2. **SettingsView.swift** - Aggiornata lista modelli disponibili
3. **ModularChatView.swift** - Aggiornata lista modelli e UI thinking
4. **ThinkingManager.swift** - NUOVO: Gestione thinking/reasoning

### Modelli Sostituiti e Aggiunti:

| Categoria | Modello | Note |
|-----------|---------|------|
| **DeepSeek R1 Distill** | `deepseek-r1-distill-llama-70b` | AGGIUNTO - Miglior reasoning |
| **DeepSeek R1 Distill** | `deepseek-r1-distill-qwen-32b` | ESISTENTE - Aggiornato |
| **DeepSeek R1 Distill** | `deepseek-r1-distill-qwen-14b` | AGGIUNTO - Reasoning economico |
| **DeepSeek R1 Distill** | `deepseek-r1-distill-qwen-1.5b` | AGGIUNTO - Ultra veloce |
| **Qwen 2.5** | `qwen2.5-72b-instruct` | AGGIUNTO - Capabilities migliorati |
| **Qwen 2.5** | `qwen2.5-32b-instruct` | ESISTENTE - Confermato |

## 🆕 Nuovi Modelli Aggiunti

### DeepSeek R1 Distill Llama 70B (Flagship)
- **API Name**: `deepseek-r1-distill-llama-70b`
- **Speed**: 260 tokens/sec
- **Context**: 131K tokens
- **Performance**: CodeForces 1633, MATH 94.5%, AIME 70.0%
- **Features**: Chain-of-thought reasoning con `<think>` tags
- **Best for**: Compiti più complessi, coding avanzato, matematica

### DeepSeek R1 Distill Qwen 14B (Bilanciato)
- **API Name**: `deepseek-r1-distill-qwen-14b`
- **Speed**: 500+ tokens/sec
- **Context**: 64K tokens
- **Performance**: AIME 69.7, MATH 93.9%, CodeForces 1481
- **Features**: Reasoning veloce a costo ridotto
- **Best for**: Reasoning quotidiano, analisi rapide

### DeepSeek R1 Distill Qwen 1.5B (Ultra-Fast)
- **API Name**: `deepseek-r1-distill-qwen-1.5b`
- **Speed**: 800+ tokens/sec
- **Context**: 32K tokens
- **Features**: Reasoning istantaneo, ultra economico
- **Best for**: Reasoning semplice ad alta velocità

### Qwen 2.5 72B Instruct (Enhanced)
- **API Name**: `qwen2.5-72b-instruct`
- **Speed**: ~200 tokens/sec
- **Context**: 128K tokens
- **Features**: Capabilities migliorati, migliore reasoning
- **Best for**: Compiti complessi che richiedono bilancio velocità/capacità

## 🧠 Nuova Funzionalità: Thinking Management

### ThinkingManager.swift
- **Gestione Automatica**: Riconosce modelli di reasoning
- **UI Personalizzabile**: Thinking nascosto di default, espandibile
- **Parsing Intelligente**: Supporta `<think>` tags di DeepSeek R1
- **Configurazione**: Setting globale per mostrare/nascondere thinking

### Modelli con Thinking Support:
- **DeepSeek R1 Series**: Tutti i modelli `deepseek-r1-distill-*`
- **Claude 4/3.7**: `claude-4-opus`, `claude-4-sonnet`, `claude-3-7-sonnet`
- **OpenAI o1/o3**: `o1`, `o1-mini`, `o3`, `o3-mini`, `o3-pro`

### Come Funziona:
1. **Parsing**: Estrae `<think>...</think>` da DeepSeek R1
2. **UI Component**: `ThinkingView` collassabile
3. **Settings**: Toggle globale in Impostazioni
4. **Per-Message**: Toggle individuale per ogni messaggio

## 🎯 Modelli Raccomandati per Caso d'Uso

### Per Reasoning Avanzato:
1. **deepseek-r1-distill-llama-70b** - Massima capacità
2. **deepseek-r1-distill-qwen-32b** - Bilanciamento ottimo
3. **claude-4-opus** - Alternative premium

### Per Velocità + Reasoning:
1. **deepseek-r1-distill-qwen-14b** - Best value
2. **deepseek-r1-distill-qwen-1.5b** - Ultra veloce
3. **qwen2.5-32b-instruct** - Non-reasoning veloce

### Per Compiti Generali:
1. **qwen2.5-72b-instruct** - Enhanced capabilities
2. **llama-3.3-70b-versatile** - Affidabile
3. **qwen2.5-32b-instruct** - Tool use + JSON

### Per Budget Limitato:
1. **deepseek-r1-distill-qwen-1.5b** - $0.04/$0.04
2. **gemma2-9b-it** - Ultra economico
3. **llama-3.1-8b-instant** - Veloce e economico

## 🔧 Implementazione Thinking

### Configurazione Default:
```swift
// Thinking nascosto di default
ThinkingManager.shared.showThinkingByDefault = false

// Visibile solo su richiesta utente
let isVisible = ThinkingManager.shared.isThinkingVisible(for: messageId)
```

### Per Sviluppatori:
```swift
// Controlla se è un modello di reasoning
let isReasoning = ThinkingManager.shared.isReasoningModel("deepseek-r1-distill-llama-70b")

// Parse response con thinking
let thinkingResponse = ThinkingManager.shared.parseResponse(apiResponse, model: modelName)

// Mostra thinking nell'UI
ThinkingView(thinking: response.thinking, model: response.model)
```

## 📋 Checklist Post-Migrazione

- [x] Aggiornati tutti i modelli Groq nei file Swift
- [x] Aggiunto supporto DeepSeek R1 Distill series
- [x] Implementato ThinkingManager per reasoning
- [x] Aggiunta UI per thinking nascosto di default
- [x] Aggiornate configurazioni e impostazioni
- [x] Creato file di backup con modelli ufficiali
- [ ] Testato funzionamento API con nuovi modelli
- [ ] Verificato parsing thinking con DeepSeek R1
- [ ] Testato toggle thinking nell'UI

## 🚨 Note Importanti

### DeepSeek R1 Thinking Format:
```
<think>
Il ragionamento step-by-step del modello
appare qui dentro i tag <think>
</think>

La risposta finale appare qui fuori dai tag.
```

### Performance Expectations:
- **Reasoning Models**: Generano più token (thinking + answer)
- **Latency**: Thinking aggiunge tempo, ma Groq è ultra-veloce
- **Costs**: Thinking tokens contano nel pricing

### Best Practices:
1. Usa thinking nascosto di default per UX pulita
2. Abilita thinking per debugging e comprensione
3. DeepSeek R1 per math/coding, Qwen 2.5 per general use
4. Monitor token usage con reasoning models

---
*Aggiornato: Gennaio 2025*
*Fonte: Documentazione ufficiale Groq 2025*