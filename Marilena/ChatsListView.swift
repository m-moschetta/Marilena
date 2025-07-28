import SwiftUI
import CoreData
import Combine

// MARK: - Chats List View
// Vista principale per la gestione delle chat con sezioni separate per email e AI

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
    
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header con titolo e pulsante nuovo
                headerView
                
                // Lista delle chat
                if chats.isEmpty {
                    emptyStateView
                } else {
                    chatsList
                }
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createNewChat) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .symbolRenderingMode(.hierarchical)
                            .symbolEffect(.bounce, value: false)
                    }
                }
            }
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
    }
    
    // MARK: - Helper Functions
    
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
            let chat = chats[index]
            viewContext.delete(chat)
        }
        
        do {
            try viewContext.save()
        } catch {
            print("❌ ChatsListView: Errore eliminazione chat: \(error)")
        }
    }
    
    // MARK: - UI Components
    
    private var headerView: some View {
        HStack {
            Text("Chat")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var chatsList: some View {
        List {
            // Sezione Chat Mail
            Section(header: 
                HStack {
                    Image(systemName: "envelope.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Chat Mail")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            ) {
                let emailChats = chats.filter { $0.tipo == "email" }
                if emailChats.isEmpty {
                    HStack {
                        Image(systemName: "envelope.badge")
                            .foregroundStyle(.secondary)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nessuna Chat Mail")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Le chat mail verranno create automaticamente quando arriveranno nuove email")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(emailChats) { chat in
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
                    }
                }
            }
            
            // Sezione Chat AI classiche
            Section(header: 
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.purple)
                    Text("Chat AI")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            ) {
                let aiChats = chats.filter { $0.tipo != "email" }
                if aiChats.isEmpty {
                    HStack {
                        Image(systemName: "message.circle")
                            .foregroundStyle(.secondary)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nessuna Chat AI")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Crea la tua prima chat per iniziare a conversare con l'AI")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(aiChats) { chat in
                        ChatRowView(chat: chat)
                            .onTapGesture {
                                selectedChat = chat
                            }
                    }
                    .onDelete(perform: deleteChats)
                }
            }
        }
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

#Preview {
    ChatsListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 