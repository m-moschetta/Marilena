# 📴 Sistema Offline Completo

## 🎯 **Panoramica**

Il sistema offline completo garantisce un'esperienza email seamless anche senza connessione di rete, con sincronizzazione automatica quando la connessione viene ripristinata.

## ✅ **Caratteristiche Principali**

### **🌐 Network Monitoring**
- **Rilevamento automatico** dello stato di connessione
- **Indicatori visivi** in tempo reale (verde=online, rosso=offline)
- **Transizioni fluide** tra modalità online/offline

### **📝 Queue Operazioni Offline**
- **Invio email** in modalità offline
- **Eliminazione email** differita
- **Marcatura come letta** offline
- **Archiviazione** differita
- **Persistenza** delle operazioni tra riavvii app

### **🔄 Sincronizzazione Intelligente**
- **Auto-sync** quando la connessione viene ripristinata
- **Retry automatico** con backoff esponenziale
- **Gestione conflitti** server vs locale
- **Sync manuale** tramite pull-to-refresh

### **⚖️ Conflict Resolution**
- **Server wins** per stati di lettura
- **Timestamp più recente** per contenuti modificati
- **Merge intelligente** dei dati conflittuali
- **Logging dettagliato** per debugging

## 🏗 **Architettura**

### **OfflineSyncService**
```swift
@MainActor
public class OfflineSyncService: ObservableObject {
    @Published public var isOnline: Bool
    @Published public var syncStatus: SyncStatus
    @Published public var pendingOperationsCount: Int
}
```

### **Tipi di Operazioni**
```swift
public enum OperationType: String, Codable {
    case sendEmail
    case markAsRead
    case deleteEmail
    case archiveEmail
}
```

### **Stati di Sync**
```swift
public enum SyncStatus: Equatable {
    case idle
    case syncing
    case error(String)
}
```

## 📱 **Indicatori UI**

### **Toolbar EmailListView**
- **🟢 Pallino verde**: Online
- **🔴 Pallino rosso**: Offline
- **🕒 Badge arancione**: Operazioni pending (con conteggio)
- **⭕ Progress**: Sincronizzazione in corso

### **Feedback Utente**
- **Messaggi console** dettagliati per debugging
- **Feedback visivo** immediato per ogni operazione
- **Stati persistenti** tra sessioni app

## 🔧 **Integrazione EmailService**

### **Proprietà Sincronizzate**
```swift
// In EmailService
@Published public var isOnline = true
@Published public var syncStatus: SyncStatus = .idle
@Published public var pendingOperationsCount = 0
```

### **Metodi Enhancèd**
- `sendEmail()` - Supporto offline automatico
- `deleteEmail()` - Queue per operazioni offline
- `forceRefresh()` - Refresh manuale ottimizzato

## ⚡ **Performance**

### **Cache Intelligente** (già implementata)
- **1000 email** massimo in cache
- **5 minuti** validità cache
- **Timestamp persistenti** per efficienza

### **Network Efficiency**
- **Queue consolidation** per ridurre richieste
- **Batch operations** quando possibile
- **Rate limiting** rispettato

## 🛠 **Utilizzo**

### **Automatic Offline Detection**
```swift
// Il servizio rileva automaticamente quando sei offline
// e accoda le operazioni
await emailService.sendEmail(to: "test@example.com", 
                             subject: "Test", 
                             body: "Messaggio")
// Se offline → accodato automaticamente
// Se online → inviato immediatamente
```

### **Manual Sync**
```swift
// Forza sincronizzazione manuale
await emailService.forceRefresh()
```

### **Monitor Status**
```swift
// Osserva lo stato in SwiftUI
Text("Stato: \(emailService.isOnline ? "Online" : "Offline")")
Text("Pending: \(emailService.pendingOperationsCount)")
```

## 🔍 **Debugging**

### **Console Logs**
- `📱 OfflineSyncService: Servizio inizializzato`
- `🌐 OfflineSyncService: Connessione ripristinata, avvio sync...`
- `📴 OfflineSyncService: Connessione persa, modalità offline attiva`
- `📝 OfflineSyncService: Accodita operazione: sendEmail - Queue: 1`
- `✅ OfflineSyncService: Operazione eseguita: sendEmail`

### **Error Handling**
- **Retry automatico** (max 3 tentativi)
- **Fallback graceful** alla cache
- **Logging errori** dettagliato

## 🚀 **Future Enhancements**

- **Conflict resolution UI** per l'utente
- **Selective sync** per cartelle specifiche
- **Compression** per ridurre storage
- **Analytics** sulle performance offline

---

## 💡 **Note Tecniche**

- Utilizza `Network.framework` per monitoring rete
- **Thread-safe** con `@MainActor`
- **Codable compliance** per persistence
- **Memory efficient** con lazy loading