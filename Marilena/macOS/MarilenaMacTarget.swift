import SwiftUI
import CoreData

// MARK: - macOS Target Configuration
// Questo file serve come punto di ingresso per il target macOS

#if os(macOS)
import AppKit

// MARK: - macOS App Entry Point
@main
struct MarilenaMacApp: App {
    // Rimuovo la dipendenza da PersistenceController per ora
    // let persistenceController = PersistenceController.shared
    
    init() {
        // Configurazione specifica per macOS
        NSApp.setActivationPolicy(.regular)
        setupMainMenu()
    }
    
    var body: some Scene {
        WindowGroup {
            MacRootView()
                // .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nuova Email") {
                    // TODO: Implementare nuova email
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(replacing: .appInfo) {
                Button("Informazioni su Marilena") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
            
            CommandGroup(after: .appInfo) {
                Button("Preferenze") {
                    // TODO: Aprire preferenze
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // App Menu
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Informazioni su Marilena", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Preferenze...", action: nil, keyEquivalent: ","))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Servizi", action: nil, keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Nascondi Marilena", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem(title: "Nascondi Altri", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem(title: "Mostra Tutti", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Esci da Marilena", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // File Menu
        let fileMenu = NSMenu()
        fileMenu.addItem(NSMenuItem(title: "Nuova Email", action: nil, keyEquivalent: "n"))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(NSMenuItem(title: "Chiudi", action: #selector(NSWindow.close), keyEquivalent: "w"))
        
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)
        
        // Edit Menu
        let editMenu = NSMenu()
        editMenu.addItem(NSMenuItem(title: "Annulla", action: #selector(UndoManager.undo), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Ripeti", action: #selector(UndoManager.redo), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Taglia", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copia", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Incolla", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        // Window Menu
        let windowMenu = NSMenu()
        windowMenu.addItem(NSMenuItem(title: "Minimizza", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: ""))
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(NSMenuItem(title: "Porta Tutto in Primo Piano", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: ""))
        
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
}

// MARK: - macOS Root View
struct MacRootView: View {
    @State private var selectedTab: Int? = 0
    
    var body: some View {
        NavigationView {
            // Sidebar
            List {
                NavigationLink(destination: MacEmailListView(), tag: 0, selection: $selectedTab) {
                    Label("Email", systemImage: "envelope")
                }
                
                NavigationLink(destination: Text("Chat - Funzionalità in sviluppo").font(.title).foregroundColor(.secondary), tag: 1, selection: $selectedTab) {
                    Label("Chat", systemImage: "message")
                }
                
                NavigationLink(destination: Text("Registrazioni - Funzionalità in sviluppo").font(.title).foregroundColor(.secondary), tag: 2, selection: $selectedTab) {
                    Label("Registrazioni", systemImage: "mic")
                }
                
                NavigationLink(destination: MacSettingsView(), tag: 3, selection: $selectedTab) {
                    Label("Impostazioni", systemImage: "gear")
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)
            
            // Content area
            VStack {
                switch selectedTab {
                case 0:
                    MacEmailListView()
                case 1:
                    Text("Chat - Funzionalità in sviluppo")
                        .font(.title)
                        .foregroundColor(.secondary)
                case 2:
                    Text("Registrazioni - Funzionalità in sviluppo")
                        .font(.title)
                        .foregroundColor(.secondary)
                case 3:
                    MacSettingsView()
                default:
                    MacEmailListView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Marilena")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                }
            }
        }
    }
    
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

// MARK: - macOS Specific Views
struct MacEmailListView: View {
    var body: some View {
        VStack {
            Text("Email - Funzionalità in sviluppo")
                .font(.title)
                .foregroundColor(.secondary)
            
            Text("Questa è la versione macOS di Marilena")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct MacSettingsView: View {
    var body: some View {
        VStack {
            Text("Impostazioni - Funzionalità in sviluppo")
                .font(.title)
                .foregroundColor(.secondary)
            
            Text("Configurazione specifica per macOS")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    MacRootView()
}

#endif
