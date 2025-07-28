import SwiftUI
import CoreData
import Combine

// MARK: - Chats List View
// Vista principale per la gestione delle chat con filtri per tipo

struct ChatsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    private let profiloService = ProfiloUtenteService.shared
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ChatMarilena.dataCreazione, ascending: false)],
        animation: .default
    ) private var chats: FetchedResults<ChatMarilena>
    
    @State private var selectedChat: ChatMarilena?
    @State private var showingSettings = false
    @State private var showingNewChatAlert = false
    @State private var newChatAlertMessage = ""
    @State private var searchText = ""
    @State private var selectedFilter: ChatFilter = .all
    
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header con filtri - senza padding superiore
                headerView
                
                // Lista chat
                chatsListView
            }
            
            // Pulsante flottante in basso
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: createNewChat) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.white)
                            .background(.blue, in: Circle())
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 100) // Sopra la tab bar
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.large)
        .alert("Nuova Chat Mail", isPresented: $showingNewChatAlert) {
            Button("OK") { }
        } message: {
            Text(newChatAlertMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: .emailChatCreated)) { notification in
            if let chat = notification.object as? ChatMarilena,
               let email = notification.userInfo?["email"] as? EmailMessage {
                DispatchQueue.main.async {
                    handleNewEmailChat(chat: chat, email: email)
                }
            }
        }
        .onAppear {
            setupEmailChatObserver()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 8) {
            // Filtri per tipo di chat - senza padding superiore
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ChatFilter.allCases, id: \.self) { filter in
                        ChatFilterChip(
                            title: filter.title,
                            isSelected: selectedFilter == filter,
                            count: getFilterCount(filter)
                        ) {
                            selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Barra di ricerca - solo se necessaria
            if !searchText.isEmpty || selectedFilter != .all {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Cerca chat...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .padding(.top, 4) // Padding minimo
    }
    
    // MARK: - Chats List
    
    private var chatsListView: some View {
        List {
            if filteredChats.isEmpty {
                emptyStateView
            } else {
                ForEach(filteredChats, id: \.objectID) { chat in
                    ChatRowView(chat: chat)
                        .onTapGesture {
                            selectedChat = chat
                        }
                        .background(
                            NavigationLink(value: chat) {
                                EmptyView()
                            }
                            .opacity(0)
                        )
                        // Swipe Actions per Chat
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            // Archive
                            Button {
                                archiveChat(chat)
                            } label: {
                                Label("Archivia", systemImage: "archivebox.fill")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            // Delete
                            Button(role: .destructive) {
                                deleteChat(chat)
                            } label: {
                                Label("Elimina", systemImage: "trash.fill")
                            }
                        }
                }
                .onDelete(perform: deleteChats)
            }
            
            // Spazio extra per permettere scroll sotto il pulsante flottante
            if !filteredChats.isEmpty {
                Spacer()
                    .frame(height: 120)
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: ChatMarilena.self) { chat in
            if chat.tipo == "email" {
                EmailChatView(chat: chat)
            } else {
                let adapter = ModuleAdapter(context: viewContext)
                adapter.createModularChatView(for: chat)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .refreshable {
            // Refresh automatico tramite FetchRequest
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredChats: [ChatMarilena] {
        var filtered = Array(chats)
        
        // Escludi chat archiviate e eliminate
        filtered = filtered.filter { chat in
            !(chat.isArchived || chat.isMarkedAsDeleted)
        }
        
        // Applica filtro di categoria
        switch selectedFilter {
        case .all:
            break
        case .email:
            filtered = filtered.filter { $0.tipo == "email" }
        case .transcription:
            filtered = filtered.filter { $0.tipo == "transcription" }
        case .ai:
            filtered = filtered.filter { $0.tipo != "email" && $0.tipo != "transcription" }
        }
        
        // Applica ricerca testuale
        if !searchText.isEmpty {
            filtered = filtered.filter { chat in
                let titleMatch = chat.titolo?.localizedCaseInsensitiveContains(searchText) ?? false
                let messageMatch = getLastMessage(chat)?.localizedCaseInsensitiveContains(searchText) ?? false
                return titleMatch || messageMatch
            }
        }
        
        return filtered
    }
    
    // MARK: - Helper Methods
    
    private func getFilterCount(_ filter: ChatFilter) -> Int {
        let activeChats = chats.filter { !($0.isArchived || $0.isMarkedAsDeleted) }
        
        switch filter {
        case .all:
            return activeChats.count
        case .email:
            return activeChats.filter { $0.tipo == "email" }.count
        case .transcription:
            return activeChats.filter { $0.tipo == "transcription" }.count
        case .ai:
            return activeChats.filter { $0.tipo != "email" && $0.tipo != "transcription" }.count
        }
    }
    
    private func getLastMessage(_ chat: ChatMarilena) -> String? {
        guard let messaggi = chat.messaggi?.allObjects as? [MessaggioMarilena],
              !messaggi.isEmpty else { return nil }
        
        let messaggiOrdinati = messaggi.sorted { 
            ($0.dataCreazione ?? Date()) > ($1.dataCreazione ?? Date()) 
        }
        
        return messaggiOrdinati.first?.contenuto
    }
    
    private func setupEmailChatObserver() {
        let publisher = NotificationCenter.default.publisher(for: .emailChatCreated)
        let cancellable = publisher.sink { notification in
            if let chat = notification.object as? ChatMarilena,
               let email = notification.userInfo?["email"] as? EmailMessage {
                DispatchQueue.main.async {
                    self.handleNewEmailChat(chat: chat, email: email)
                }
            }
        }
        cancellables.insert(cancellable)
    }
    
    private func handleNewEmailChat(chat: ChatMarilena, email: EmailMessage) {
        // Mostra notifica
        newChatAlertMessage = "Nuova chat mail creata automaticamente per \(email.from)"
        showingNewChatAlert = true
        
        print("✅ ChatsListView: Chat mail creata per \(email.from)")
    }
    
    private func createNewChat() {
        let newChat = ChatMarilena(context: viewContext)
        newChat.id = UUID()
        newChat.dataCreazione = Date()
        newChat.titolo = "Nuova Chat"
        newChat.tipo = "general"
        
        // Associa al profilo utente
        if let profilo = profiloService.ottieniProfiloUtente(in: viewContext) {
            newChat.profilo = profilo
        }
        
        do {
            try viewContext.save()
        } catch {
            print("❌ ChatsListView: Errore creazione chat: \(error)")
        }
    }
    
    private func deleteChats(offsets: IndexSet) {
        for index in offsets {
            let chat = filteredChats[index]
            viewContext.delete(chat)
        }
        
        do {
            try viewContext.save()
        } catch {
            print("❌ ChatsListView: Errore eliminazione chat: \(error)")
        }
    }
    
    // MARK: - Swipe Actions Functions
    
    private func archiveChat(_ chat: ChatMarilena) {
        print("📦 ChatsListView: Archiviazione chat: \(chat.titolo ?? "Senza titolo")")
        
        // Archivia la chat
        chat.isArchived = true
        
        // Se è una chat email, archivia anche l'email corrispondente
        if chat.tipo == "email", let emailSender = chat.emailSender {
            archiveCorrespondingEmail(sender: emailSender)
        }
        
        do {
            try viewContext.save()
            print("✅ ChatsListView: Chat archiviata con successo")
        } catch {
            print("❌ ChatsListView: Errore archiviazione chat: \(error)")
        }
    }
    
    private func deleteChat(_ chat: ChatMarilena) {
        print("🗑️ ChatsListView: Eliminazione chat: \(chat.titolo ?? "Senza titolo")")
        
        // Se è una chat email, elimina anche l'email corrispondente
        if chat.tipo == "email", let emailSender = chat.emailSender {
            deleteCorrespondingEmail(sender: emailSender)
        }
        
        // Elimina la chat
        viewContext.delete(chat)
        
        do {
            try viewContext.save()
            print("✅ ChatsListView: Chat eliminata con successo")
        } catch {
            print("❌ ChatsListView: Errore eliminazione chat: \(error)")
        }
    }
    
    private func archiveCorrespondingEmail(sender: String) {
        print("📦 ChatsListView: Archiviazione email per sender: \(sender)")
        
        // Cerca l'email corrispondente nella cache
        let fetchRequest: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "from == %@ AND isArchived == NO", sender)
        
        do {
            let emails = try viewContext.fetch(fetchRequest)
            for email in emails {
                email.isArchived = true
                print("📦 ChatsListView: Email archiviata: \(email.subject ?? "Senza oggetto")")
            }
        } catch {
            print("❌ ChatsListView: Errore ricerca email per archiviazione: \(error)")
        }
    }
    
    private func deleteCorrespondingEmail(sender: String) {
        print("🗑️ ChatsListView: Eliminazione email per sender: \(sender)")
        
        // Cerca l'email corrispondente nella cache
        let fetchRequest: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "from == %@ AND isMarkedAsDeleted == NO", sender)
        
        do {
            let emails = try viewContext.fetch(fetchRequest)
            for email in emails {
                email.isMarkedAsDeleted = true
                print("🗑️ ChatsListView: Email eliminata: \(email.subject ?? "Senza oggetto")")
            }
        } catch {
            print("❌ ChatsListView: Errore ricerca email per eliminazione: \(error)")
        }
    }
    
    // MARK: - UI Components
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("Nessuna Chat")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Crea la tua prima chat per iniziare a conversare con l'AI")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: createNewChat) {
                Label("Nuova Chat", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
        }
        .padding()
    }
}

// MARK: - Chat Filter

enum ChatFilter: CaseIterable {
    case all
    case email
    case transcription
    case ai
    
    var title: String {
        switch self {
        case .all: return "Tutte"
        case .email: return "Email"
        case .transcription: return "Trascrizioni"
        case .ai: return "AI"
        }
    }
}

struct ChatRowView: View {
    let chat: ChatMarilena
    
    var body: some View {
        HStack(spacing: 12) {
            // Icona e colore basati sul tipo di chat
            ZStack {
                Circle()
                    .fill(chatTypeColor)
                    .frame(width: 44, height: 44)
                
                Image(systemName: chatTypeIcon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.titolo ?? "Chat senza titolo")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    if let data = getChatDisplayDate() {
                        Text(data, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let ultimoMessaggio = getUltimoMessaggio() {
                    Text(ultimoMessaggio)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text(chat.tipo == "email" ? "Nessuna email" : "Nessun messaggio")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .italic()
                }
                
                HStack(spacing: 8) {
                    // Badge per il numero di messaggi
                    HStack(spacing: 4) {
                        Image(systemName: "message.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(getNumeroMessaggi())")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
                    
                    // Badge per il tipo di chat
                    if chat.tipo == "email" {
                        HStack(spacing: 4) {
                            Image(systemName: "envelope.fill")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                            Text("Email")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.blue)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1), in: Capsule())
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    // MARK: - Computed Properties
    
    private var chatTypeIcon: String {
        switch chat.tipo {
        case "email":
            return "envelope.circle.fill"
        case "transcription":
            return "waveform.circle.fill"
        default:
            return "message.circle.fill"
        }
    }
    
    private var chatTypeColor: Color {
        switch chat.tipo {
        case "email":
            return .blue
        case "transcription":
            return .green
        default:
            return .purple
        }
    }
    
    // MARK: - Helper Methods
    
    private func getUltimoMessaggio() -> String? {
        guard let messaggi = chat.messaggi?.allObjects as? [MessaggioMarilena],
              !messaggi.isEmpty else { return nil }
        
        let messaggiOrdinati = messaggi.sorted { 
            ($0.dataCreazione ?? Date()) > ($1.dataCreazione ?? Date()) 
        }
        
        let ultimoMessaggio = messaggiOrdinati.first?.contenuto ?? ""
        
        // Se è una trascrizione, mostra un preview più breve
        if messaggiOrdinati.first?.tipo == "transcription" {
            let preview = String(ultimoMessaggio.prefix(100))
            return preview + (ultimoMessaggio.count > 100 ? "..." : "")
        }
        
        // Se è una email, mostra un preview più breve
        if chat.tipo == "email" {
            let preview = String(ultimoMessaggio.prefix(80))
            return preview + (ultimoMessaggio.count > 80 ? "..." : "")
        }
        
        return ultimoMessaggio
    }
    
    private func getNumeroMessaggi() -> Int {
        return chat.messaggi?.count ?? 0
    }
    
    private func getChatDisplayDate() -> Date? {
        // Se è una chat di trascrizione, cerca la registrazione associata
        if chat.tipo == "transcription", let recordingId = chat.recordingId {
            let fetchRequest: NSFetchRequest<RegistrazioneAudio> = RegistrazioneAudio.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", recordingId)
            
            do {
                let recordings = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
                if let recording = recordings.first, let dataCreazione = recording.dataCreazione {
                    return dataCreazione
                }
            } catch {
                print("Errore ricerca registrazione: \(error)")
            }
        }
        
        // Fallback alla data di creazione della chat
        return chat.dataCreazione
    }
}

struct NewChatView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    private let profiloService = ProfiloUtenteService.shared
    
    @State private var titolo = ""
    @State private var messaggioIniziale = ""
    
    var body: some View {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Titolo Chat")
                        .font(.headline)
                    
                    TextField("Es. Pianificazione progetti", text: $titolo)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Messaggio Iniziale (Opzionale)")
                        .font(.headline)
                    
                    TextField("Inizia la conversazione...", text: $messaggioIniziale, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                Spacer()
                
                Button("Crea Chat") {
                    createChat()
                }
                .disabled(titolo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Nuova Chat AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                }
            }
        }
    }
    
    private func createChat() {
        let chat = ChatMarilena(context: viewContext)
        chat.id = UUID()
        chat.dataCreazione = Date()
        chat.titolo = titolo.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Associa al profilo utente
        if let profilo = profiloService.ottieniProfiloUtente(in: viewContext) {
            chat.profilo = profilo
        }
        
        // Aggiungi messaggio iniziale se presente
        if !messaggioIniziale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let messaggio = MessaggioMarilena(context: viewContext)
            messaggio.id = UUID()
            messaggio.contenuto = messaggioIniziale.trimmingCharacters(in: .whitespacesAndNewlines)
            messaggio.isUser = true
            messaggio.dataCreazione = Date()
            messaggio.chat = chat
        }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Errore creazione chat: \(error)")
        }
    }
}

// MARK: - Filter Chip

struct ChatFilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color.primary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ChatsListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 