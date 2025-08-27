# Guida alla Migrazione - Modelli Anthropic 2025

## ✅ Aggiornamenti Completati

### File Modificati:
1. **AnthropicService.swift** - Aggiornati nomi modelli e info
2. **SettingsView.swift** - Aggiornata lista modelli disponibili
3. **EmailAIService.swift** - Aggiornato modello di default
4. **EmailSettingsView.swift** - Aggiornata lista modelli email
5. **AIProviderManager.swift** - Aggiornato modello di default
6. **Marilena_SPM_Backup/** - Aggiornati tutti i file di backup

### Modelli Sostituiti:

| Vecchio Nome | Nuovo Nome | Note |
|--------------|------------|------|
| `claude-4-sonnet-20250200` | `claude-4-sonnet` | Nome ufficiale API |
| `claude-3-7-sonnet-20250219` | `claude-3-7-sonnet` | Nome ufficiale API |
| `claude-3-5-sonnet-20241022` | `claude-3-5-sonnet` | Nome ufficiale API |
| `claude-3-5-haiku-20241022` | `claude-3-5-haiku` | Nome ufficiale API |
| `claude-3-opus-20240229` | `claude-3-opus` | Nome ufficiale API |
| `claude-sonnet-4-20250514` | `claude-4-sonnet` | Corretto ordine nome |
| `claude-opus-4-20250514` | `claude-4-opus` | Aggiunto |

## 🆕 Nuovi Modelli Aggiunti

### Claude 4 Opus
- **Nome API**: `claude-4-opus`
- **Release**: Maggio 2025
- **Caratteristiche**: Il modello più potente di Anthropic
- **Uso consigliato**: Compiti estremamente complessi, ricerca avanzata
- **Prezzo**: $15/$75 per 1M tokens

### Claude 4 Sonnet  
- **Nome API**: `claude-4-sonnet`
- **Release**: Maggio 2025
- **Caratteristiche**: Ottimo bilanciamento prestazioni/costo
- **Uso consigliato**: Applicazioni di produzione (RACCOMANDATO)
- **Prezzo**: $3/$15 per 1M tokens

## 🔧 Cosa Controllare

### 1. Impostazioni Utente
Le preferenze utente salvate potrebbero ancora riferirsi ai vecchi nomi. L'app gestirà automaticamente il fallback ma è consigliabile:

```swift
// Resetta le preferenze se necessario
UserDefaults.standard.removeObject(forKey: "selectedAnthropicModel")
```

### 2. Test delle API Calls
Verifica che le chiamate API funzionino con i nuovi nomi:

```swift
// Test rapido
AnthropicService.shared.sendMessage(
    messages: testMessages, 
    model: "claude-4-sonnet", 
    maxTokens: 1000, 
    temperature: 0.7
) { result in
    // Gestisci risultato
}
```

### 3. Configurazioni Hardcoded
Cerca eventuali riferimenti hardcoded ai vecchi nomi nei file:
- Configurazioni
- File di test
- Documentazione

## 📋 Checklist Post-Migrazione

- [x] Aggiornati tutti i nomi dei modelli nei file Swift
- [x] Aggiornate le descrizioni dei modelli
- [x] Aggiornati i modelli di default
- [x] Creato file di backup con lista ufficiale
- [x] Aggiornati file di backup
- [ ] Testato funzionamento API con nuovi modelli
- [ ] Verificato che le impostazioni utente siano migrate correttamente
- [ ] Aggiornata documentazione se necessario

## 🚨 Problemi Potenziali

### API Errors
Se ricevi errori 400/404 dalle API:
1. Verifica che l'API key sia valida
2. Controlla che il nome del modello sia corretto
3. Assicurati di non aver lasciato vecchi nomi in qualche parte del codice

### Modelli Non Disponibili
Alcuni modelli potrebbero non essere immediatamente disponibili in tutte le regioni:
- Usa fallback ai modelli 3.5 se necessario
- Implementa retry logic con modelli alternativi

## 📞 Supporto
Per problemi con la migrazione:
1. Controlla i log delle API calls
2. Verifica la documentazione ufficiale Anthropic
3. Usa il file di test fornito per diagnosticare problemi

---
*Aggiornato: Gennaio 2025*
*Fonte: Documentazione ufficiale Anthropic 2025*