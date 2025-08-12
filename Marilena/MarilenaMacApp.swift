import SwiftUI
import CoreData

#if os(macOS)
@main
struct MarilenaMacApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nuova Email") {
                    // TODO: Azione per nuova email su macOS
                }.keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
#endif


