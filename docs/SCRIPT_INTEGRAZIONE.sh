#!/bin/bash

# MARK: - Script di Integrazione Chat Module
# Questo script automatizza il processo di integrazione del modulo chat in un'altra app iOS

set -e  # Esci se c'è un errore

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funzioni di utilità
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Controlla se siamo nella directory corretta
check_directory() {
    if [ ! -f "Marilena.xcodeproj/project.pbxproj" ]; then
        print_error "Questo script deve essere eseguito dalla directory root del progetto Marilena"
        exit 1
    fi
}

# Crea la directory di destinazione
create_destination() {
    local dest_dir="$1"
    
    if [ -d "$dest_dir" ]; then
        print_warning "La directory $dest_dir esiste già"
        read -p "Vuoi sovrascrivere? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Operazione annullata"
            exit 0
        fi
        rm -rf "$dest_dir"
    fi
    
    mkdir -p "$dest_dir"
    print_success "Creata directory di destinazione: $dest_dir"
}

# Copia i file del modulo chat
copy_chat_module() {
    local dest_dir="$1"
    
    print_info "Copiando modulo chat..."
    
    # Crea la struttura delle directory
    mkdir -p "$dest_dir/Core/AI/ChatModule"
    mkdir -p "$dest_dir/Core/AI/TranscriptionModule"
    
    # Copia i file del modulo chat
    cp -r "Marilena/Core/AI/ChatModule/"* "$dest_dir/Core/AI/ChatModule/"
    cp -r "Marilena/Core/AI/TranscriptionModule/"* "$dest_dir/Core/AI/TranscriptionModule/"
    cp "Marilena/Core/AI/ModuleAdapter.swift" "$dest_dir/Core/AI/"
    
    # Copia i servizi AI
    cp "Marilena/AIProviderManager.swift" "$dest_dir/"
    cp "Marilena/OpenAIService.swift" "$dest_dir/"
    cp "Marilena/AnthropicService.swift" "$dest_dir/"
    cp "Marilena/PerplexityService.swift" "$dest_dir/"
    
    # Copia i file di gestione dati
    cp "Marilena/PromptManager.swift" "$dest_dir/"
    cp "Marilena/KeychainManager.swift" "$dest_dir/"
    cp "Marilena/Persistence.swift" "$dest_dir/"
    cp "Marilena/SharedTypes.swift" "$dest_dir/"
    
    # Copia il modello Core Data
    cp -r "Marilena/Marilena.xcdatamodeld" "$dest_dir/"
    
    print_success "Modulo chat copiato con successo"
}

# Crea il file di configurazione
create_config_file() {
    local dest_dir="$1"
    local app_name="$2"
    
    print_info "Creando file di configurazione..."
    
    cat > "$dest_dir/Config.swift" << EOF
import Foundation

// MARK: - Configurazione App
// Configura le tue API keys qui

struct Config {
    // API Keys - Sostituisci con le tue chiavi
    static let openAIApiKey = "your-openai-key"
    static let anthropicApiKey = "your-anthropic-key"
    static let groqApiKey = "your-groq-key"
    static let perplexityApiKey = "your-perplexity-key"
    
    // Configurazione App
    static let appName = "$app_name"
    static let bundleIdentifier = "com.yourcompany.$app_name"
    
    // Configurazione Chat
    static let defaultModel = "gpt-4o-mini"
    static let maxTokens = 4000
    static let temperature = 0.7
    
    // Configurazione UI
    static let primaryColor = "blue"
    static let enableDarkMode = true
    static let enableAnimations = true
}

// MARK: - Configurazione Core Data
extension Config {
    static let coreDataModelName = "$app_name"
    static let coreDataStoreType = "sqlite"
}
EOF

    print_success "File di configurazione creato: $dest_dir/Config.swift"
}

# Crea il file App.swift
create_app_file() {
    local dest_dir="$1"
    local app_name="$2"
    
    print_info "Creando file App.swift..."
    
    cat > "$dest_dir/${app_name}App.swift" << EOF
import SwiftUI

@main
struct ${app_name}App: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
EOF

    print_success "File App.swift creato: $dest_dir/${app_name}App.swift"
}

# Crea il file ContentView.swift
create_content_view() {
    local dest_dir="$1"
    
    print_info "Creando ContentView.swift..."
    
    cat > "$dest_dir/ContentView.swift" << EOF
import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationView {
            ChatListView()
        }
        .environment(\.managedObjectContext, viewContext)
    }
}

struct ChatListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: ChatMarilena.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \\ChatMarilena.dataCreazione, ascending: false)]
    ) private var chats: FetchedResults<ChatMarilena>
    
    var body: some View {
        List {
            ForEach(chats, id: \\.objectID) { chat in
                NavigationLink(destination: ModularChatView(chat: chat)) {
                    ChatRowView(chat: chat)
                }
            }
        }
        .navigationTitle("Le Mie Chat")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Nuova Chat") {
                    createNewChat()
                }
            }
        }
    }
    
    private func createNewChat() {
        let newChat = ChatMarilena(context: viewContext)
        newChat.id = UUID()
        newChat.titolo = "Nuova Chat"
        newChat.dataCreazione = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("Errore salvataggio chat: \\(error)")
        }
    }
}

struct ChatRowView: View {
    let chat: ChatMarilena
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(chat.titolo ?? "Chat senza titolo")
                .font(.headline)
                .lineLimit(1)
            
            if let lastMessage = chat.messaggi?.lastObject as? MessaggioMarilena {
                Text(lastMessage.contenuto ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Text(chat.dataCreazione?.formatted() ?? "")
                .font(.caption2)
                .foregroundColor(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
EOF

    print_success "File ContentView.swift creato: $dest_dir/ContentView.swift"
}

# Crea il file Persistence.swift modificato
create_persistence_file() {
    local dest_dir="$1"
    local app_name="$2"
    
    print_info "Creando Persistence.swift..."
    
    cat > "$dest_dir/Persistence.swift" << EOF
import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "$app_name")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Errore caricamento Core Data: \\(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
EOF

    print_success "File Persistence.swift creato: $dest_dir/Persistence.swift"
}

# Crea il file Info.plist
create_info_plist() {
    local dest_dir="$1"
    local app_name="$2"
    
    print_info "Creando Info.plist..."
    
    cat > "$dest_dir/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <true/>
    </dict>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>armv7</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>L'app utilizza il riconoscimento vocale per trascrivere l'audio</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>L'app utilizza il microfono per registrare l'audio</string>
</dict>
</plist>
EOF

    print_success "File Info.plist creato: $dest_dir/Info.plist"
}

# Crea il README
create_readme() {
    local dest_dir="$1"
    local app_name="$2"
    
    print_info "Creando README.md..."
    
    cat > "$dest_dir/README.md" << EOF
# $app_name

App iOS con integrazione del modulo chat AI di Marilena.

## 🚀 Funzionalità

- ✅ Chat AI con modelli multipli (OpenAI, Anthropic, Groq)
- ✅ Ricerca web con Perplexity
- ✅ Trascrizione audio
- ✅ Gestione sessioni chat
- ✅ Statistiche avanzate
- ✅ Esportazione conversazioni

## 📱 Requisiti

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+

## 🛠️ Installazione

1. Apri il progetto in Xcode
2. Configura le API keys in \`Config.swift\`
3. Build e run

## 🔧 Configurazione

### API Keys

Modifica il file \`Config.swift\` con le tue API keys:

\`\`\`swift
struct Config {
    static let openAIApiKey = "your-openai-key"
    static let anthropicApiKey = "your-anthropic-key"
    static let groqApiKey = "your-groq-key"
    static let perplexityApiKey = "your-perplexity-key"
}
\`\`\`

### Core Data

Il modello Core Data è già configurato. Assicurati che sia incluso nel target dell'app.

## 📁 Struttura Progetto

\`\`\`
$app_name/
├── Core/AI/
│   ├── ChatModule/
│   └── TranscriptionModule/
├── Config.swift
├── ContentView.swift
├── ${app_name}App.swift
└── README.md
\`\`\`

## 🎯 Utilizzo

1. Avvia l'app
2. Tocca "Nuova Chat"
3. Inizia a chattare con l'AI
4. Usa le impostazioni per personalizzare l'esperienza

## 📄 Licenza

Questo progetto utilizza il modulo chat di Marilena.
EOF

    print_success "File README.md creato: $dest_dir/README.md"
}

# Crea lo script di build
create_build_script() {
    local dest_dir="$1"
    local app_name="$2"
    
    print_info "Creando script di build..."
    
    cat > "$dest_dir/build.sh" << EOF
#!/bin/bash

# Script di build per $app_name

set -e

echo "Building $app_name..."

# Controlla se Xcode è installato
if ! command -v xcodebuild &> /dev/null; then
    echo "Errore: Xcode non trovato"
    exit 1
fi

# Build del progetto
xcodebuild -project $app_name.xcodeproj -scheme $app_name -destination 'platform=iOS Simulator,name=iPhone 16' build

echo "Build completata con successo!"
EOF

    chmod +x "$dest_dir/build.sh"
    print_success "Script di build creato: $dest_dir/build.sh"
}

# Funzione principale
main() {
    print_info "🚀 Script di Integrazione Chat Module"
    print_info "====================================="
    
    # Controlla la directory
    check_directory
    
    # Richiedi il nome dell'app
    read -p "Inserisci il nome della tua app: " app_name
    if [ -z "$app_name" ]; then
        print_error "Nome app richiesto"
        exit 1
    fi
    
    # Richiedi la directory di destinazione
    read -p "Inserisci la directory di destinazione (default: ./$app_name): " dest_dir
    if [ -z "$dest_dir" ]; then
        dest_dir="./$app_name"
    fi
    
    print_info "Configurazione:"
    print_info "- Nome app: $app_name"
    print_info "- Directory: $dest_dir"
    
    # Crea la directory di destinazione
    create_destination "$dest_dir"
    
    # Copia i file del modulo chat
    copy_chat_module "$dest_dir"
    
    # Crea i file di configurazione
    create_config_file "$dest_dir" "$app_name"
    create_app_file "$dest_dir" "$app_name"
    create_content_view "$dest_dir"
    create_persistence_file "$dest_dir" "$app_name"
    create_info_plist "$dest_dir" "$app_name"
    create_readme "$dest_dir" "$app_name"
    create_build_script "$dest_dir" "$app_name"
    
    print_success "✅ Integrazione completata con successo!"
    print_info ""
    print_info "Prossimi passi:"
    print_info "1. Apri la directory $dest_dir"
    print_info "2. Configura le API keys in Config.swift"
    print_info "3. Crea un nuovo progetto Xcode"
    print_info "4. Aggiungi tutti i file al progetto"
    print_info "5. Configura Core Data"
    print_info "6. Build e testa l'app"
    print_info ""
    print_info "Per assistenza, consulta la documentazione in docs/INTEGRAZIONE_CHAT_MODULE.md"
}

# Esegui lo script
main "$@" 