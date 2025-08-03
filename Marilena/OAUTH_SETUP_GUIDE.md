# 🔧 **GUIDA COMPLETA OAUTH - MARILENA**

## 🚨 **PROBLEMA ATTUALE**
Errore: "OAuth access is restricted to the test users listed on your OAuth consent screen"

## 🎯 **SOLUZIONI DISPONIBILI**

### **Opzione A: Aggiungere Utenti di Test (Soluzione Rapida)**

1. **Vai su Google Cloud Console**
   - Apri [Google Cloud Console](https://console.cloud.google.com/)
   - Seleziona il progetto: `774947872067-h5edpv1rgirar19mn240dnhd0sr3ml7o`

2. **Configura OAuth Consent Screen**
   - Vai su "APIs & Services" > "OAuth consent screen"
   - Clicca su "EDIT APP"

3. **Aggiungi Utenti di Test**
   - Nella sezione "Test users"
   - Clicca "ADD USERS"
   - Aggiungi il tuo indirizzo email: `[TUA_EMAIL@gmail.com]`
   - Clicca "SAVE"

4. **Verifica Configurazione**
   - Assicurati che l'app sia in "Testing" mode
   - Verifica che il tuo email sia nella lista degli utenti di test

### **Opzione B: Pubblicare l'App (Soluzione Definitiva)**

1. **Prepara l'App per la Pubblicazione**
   - Vai su "OAuth consent screen"
   - Clicca "PUBLISH APP"
   - Compila tutte le informazioni richieste:
     - App name: "Marilena"
     - User support email: `[TUA_EMAIL@gmail.com]`
     - Developer contact information: `[TUA_EMAIL@gmail.com]`

2. **Verifica Richiesta**
   - Google esaminerà la richiesta (può richiedere 6-8 settimane)
   - Nel frattempo, usa l'Opzione A

## 🔧 **CONFIGURAZIONE APP**

### **Credenziali Attuali**
```
Client ID: 774947872067-h5edpv1rgirar19mn240dnhd0sr3ml7o.apps.googleusercontent.com
Bundle ID: Mario.Marilena
Redirect URI: com.marilena.email://oauth/callback
```

### **Verifica Configurazione in App**

1. **Apri l'app Marilena**
2. **Vai su Impostazioni > OAuth Configuration**
3. **Verifica che le credenziali siano corrette**
4. **Testa la configurazione Google**

## 🚀 **ATTIVAZIONE CHAT**

### **Passo 1: Configura OAuth**
- Segui l'Opzione A sopra per aggiungere il tuo email come utente di test

### **Passo 2: Testa l'Autenticazione**
- Apri l'app Marilena
- Vai su "Email" > "Aggiungi Account"
- Seleziona "Google"
- Completa il flusso OAuth

### **Passo 3: Attiva la Chat**
- Una volta autenticato con Google
- Vai su "Chat" nel menu principale
- La chat dovrebbe essere ora disponibile

## 🔍 **TROUBLESHOOTING**

### **Errore Persistente**
Se l'errore persiste dopo aver aggiunto l'utente di test:

1. **Verifica Email**
   - Assicurati di aver aggiunto l'email corretto
   - L'email deve essere quello che usi per accedere a Google

2. **Attendi Sincronizzazione**
   - Google può richiedere fino a 24 ore per sincronizzare
   - Prova di nuovo dopo qualche ora

3. **Verifica Configurazione**
   - Controlla che il Client ID sia corretto
   - Verifica che il Bundle ID corrisponda

### **Log di Debug**
L'app include log dettagliati per il debug OAuth:
- Apri la console di Xcode
- Cerca messaggi che iniziano con "🔧 OAuth Debug"

## 📱 **TEST SU SIMULATORE**

### **Avvia Simulatore iPhone 16**
```bash
cd /Users/mariomoschetta/Downloads/Marilena
xcodebuild -project Marilena.xcodeproj -scheme Marilena -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### **Esegui App**
```bash
xcrun simctl boot "iPhone 16"
open -a Simulator
```

## ✅ **VERIFICA FINALE**

1. ✅ App compila correttamente
2. ✅ OAuth configurato con utenti di test
3. ✅ Autenticazione Google funzionante
4. ✅ Chat attivata e funzionante

## 🆘 **SUPPORTO**

Se hai problemi:
1. Controlla i log di debug in Xcode
2. Verifica la configurazione OAuth
3. Assicurati di aver aggiunto l'email corretto come utente di test 