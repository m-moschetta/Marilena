import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

class NotificationService {
    static let shared = NotificationService()
    
    private init() {}
    
    // MARK: - Setup Notifiche
    
    func richiedePermessoNotifiche() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notifiche autorizzate")
            } else if let error = error {
                print("Errore autorizzazione notifiche: \(error)")
            }
        }
    }
    
    // MARK: - Notifiche Contesto AI
    
    func notificaContestoAggiornato() {
        let content = UNMutableNotificationContent()
        content.title = "Contesto AI Aggiornato"
        content.body = "Il tuo profilo è stato aggiornato con le conversazioni recenti"
        content.sound = .default
        content.badge = 1
        
        // Trigger immediato
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "contesto-aggiornato",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Errore invio notifica: \(error)")
            }
        }
    }
    
    func notificaErroreAggiornamentoContesto() {
        let content = UNMutableNotificationContent()
        content.title = "Errore Aggiornamento"
        content.body = "Non è stato possibile aggiornare il contesto AI. Riprova più tardi."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "errore-contesto",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Errore invio notifica errore: \(error)")
            }
        }
    }
    
    // MARK: - Notifiche Promemoria
    
    func programmaSuggereimentoAggiornamentoContesto() {
        let content = UNMutableNotificationContent()
        content.title = "Aggiorna il tuo Profilo"
        content.body = "È passato del tempo dall'ultimo aggiornamento del contesto AI. Vuoi aggiornarlo?"
        content.sound = .default
        content.categoryIdentifier = "CONTESTO_REMINDER"
        
        // Notifica tra 7 giorni se il contesto non viene aggiornato
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 7 * 24 * 60 * 60, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "reminder-contesto",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Errore programmazione reminder: \(error)")
            }
        }
    }
    
    func annullaSuggereimentoAggiornamentoContesto() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["reminder-contesto"])
    }
    
    // MARK: - Gestione Badge
    
    func aggiornaBadge(numero: Int) {
        DispatchQueue.main.async {
            if #available(iOS 16.0, *) {
                // Nuova API per iOS 16+
                UNUserNotificationCenter.current().setBadgeCount(numero) { error in
                    if let error = error {
                        print("❌ Errore impostazione badge (iOS 16+): \(error)")
                    } else {
                        print("✅ Badge impostato a \(numero) (iOS 16+)")
                    }
                }
            } else {
                // Fallback per iOS < 16 (deprecato ma ancora funzionante)
                UIApplication.shared.applicationIconBadgeNumber = numero
                print("⚠️ Badge impostato con API deprecata (iOS < 16)")
            }
        }
    }
    
    func azzeraBadge() {
        aggiornaBadge(numero: 0)
    }
    
    // MARK: - Setup Categorie Notifiche
    
    func setupCategories() {
        let aggiornamentoAction = UNNotificationAction(
            identifier: "AGGIORNA_CONTESTO",
            title: "Aggiorna Ora",
            options: [.foreground]
        )
        
        let rifiutaAction = UNNotificationAction(
            identifier: "RIFIUTA_AGGIORNAMENTO",
            title: "Non Ora",
            options: []
        )
        
        let contestoCategory = UNNotificationCategory(
            identifier: "CONTESTO_REMINDER",
            actions: [aggiornamentoAction, rifiutaAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([contestoCategory])
    }
}

// MARK: - Estensioni per UserDefaults

extension UserDefaults {
    private enum Keys {
        static let ultimaNotificaContesto = "ultima_notifica_contesto"
        static let notificheAbilitate = "notifiche_abilitate"
    }
    
    var ultimaNotificaContesto: Date? {
        get { object(forKey: Keys.ultimaNotificaContesto) as? Date }
        set { set(newValue, forKey: Keys.ultimaNotificaContesto) }
    }
    
    var notificheAbilitate: Bool {
        get { bool(forKey: Keys.notificheAbilitate) }
        set { set(newValue, forKey: Keys.notificheAbilitate) }
    }
} 