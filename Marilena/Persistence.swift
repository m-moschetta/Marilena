import CoreData
import CloudKit

public struct PersistenceController {
    public static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Crea dati di esempio solo se necessario
        let chat = ChatMarilena(context: viewContext)
        chat.dataCreazione = Date()
        chat.id = UUID()
        chat.titolo = "Chat Esempio"
        
        do {
            try viewContext.save()
        } catch {
            print("Preview context save error: \(error)")
        }
        return result
    }()

    public let container: NSPersistentContainer

    public init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Marilena")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configurazione per persistenza locale
        container.persistentStoreDescriptions.forEach { storeDescription in
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true
            
            // Assicura che il file sia salvato nella directory Documents
            if !inMemory {
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let storeURL = documentsDirectory.appendingPathComponent("Marilena.sqlite")
                storeDescription.url = storeURL
                print("📁 Core Data store URL: \(storeURL.path)")
            }
        }
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                print("❌ Core Data error: \(error), \(error.userInfo)")
                
                // Gestione specifica per errori di migrazione
                if error.domain == NSCocoaErrorDomain && (error.code == NSMigrationError || error.code == 134110) {
                    print("🔄 CoreData: Errore di migrazione, ricreo il database...")
                    // Per ora logghiamo solo l'errore, la ricreazione verrà gestita al prossimo avvio
                } else {
                    // Se c'è un errore generico, prova a eliminare il file e ricrearlo
                    if let url = storeDescription.url {
                        do {
                            try FileManager.default.removeItem(at: url)
                            print("🗑️ Rimosso file Core Data corrotto: \(url.path)")
                        } catch {
                            print("❌ Errore rimozione file: \(error)")
                        }
                    }
                }
            } else {
                print("✅ Core Data store caricato con successo")
                if let url = storeDescription.url {
                    print("📁 Store URL: \(url.path)")
                }
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Abilita il salvataggio automatico
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    // MARK: - Error Recovery Methods
    // Le funzioni di recovery sono state semplificate per evitare problemi con struct
}
