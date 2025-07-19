import CoreData
import CloudKit
struct PersistenceController {
    static let shared = PersistenceController()

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

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // Usa NSPersistentContainer normale (senza CloudKit)
        container = NSPersistentContainer(name: "Marilena")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configurazione CloudKit
        container.persistentStoreDescriptions.forEach { storeDescription in
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true
            
            // Configurazione CloudKit
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                // Sostituisci fatalError con un log per evitare crash in fase di sviluppo
                // per problemi di migrazione o altro.
                print("Core Data error: \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
