import SwiftUI
import CoreData

struct ChatsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    private let profiloService = ProfiloUtenteService.shared
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ChatMarilena.dataCreazione, ascending: false)],
        animation: .default
    ) private var chats: FetchedResults<ChatMarilena>
    
    @State private var showingNewChatSheet = false
    @State private var selectedChat: ChatMarilena?
    @State private var showingSettings = false
    
    var body: some View {
            VStack {
                if chats.isEmpty {
                    emptyStateView
                } else {
                    chatsList
                }
            }
            .navigationTitle("Chat AI")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createNewChat) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingNewChatSheet) {
                NewChatView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenChatInMainList"))) { notification in
            if let chat = notification.object as? ChatMarilena {
                selectedChat = chat
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Benvenuto in Marilena AI")
                    .font(.title.weight(.bold))
                    .foregroundColor(.primary)
                
                Text("La tua assistente AI personale pronta ad aiutarti")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: createNewChat) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Inizia Nuova Conversazione")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
    
    private var chatsList: some View {
        List {
            ForEach(chats) { chat in
                ChatRowView(chat: chat)
                    .onTapGesture {
                        selectedChat = chat
                    }
            }
            .onDelete(perform: deleteChats)
        }
        .refreshable {
            // Refresh logic if needed
        }
        .sheet(item: $selectedChat) { chat in
            ChatView(chat: chat)
                .environment(\.managedObjectContext, viewContext)
        }
    }
    
    private func createNewChat() {
        withAnimation {
            let newChat = ChatMarilena(context: viewContext)
            newChat.id = UUID()
            newChat.dataCreazione = Date()
            newChat.titolo = "Nuova Chat"
            
            // Associa al profilo utente
            if let profilo = profiloService.ottieniProfiloUtente(in: viewContext) {
                newChat.profilo = profilo
            }
            
            do {
                try viewContext.save()
                selectedChat = newChat
            } catch {
                print("Errore creazione chat: \(error)")
            }
        }
    }
    
    private func deleteChats(offsets: IndexSet) {
        withAnimation {
            offsets.map { chats[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                print("Errore eliminazione chat: \(error)")
            }
        }
    }
}

struct ChatRowView: View {
    let chat: ChatMarilena
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(chat.titolo ?? "Chat senza titolo")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let data = getChatDisplayDate() {
                    Text(data, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let ultimoMessaggio = getUltimoMessaggio() {
                Text(ultimoMessaggio)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            } else {
                Text("Nessun messaggio")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            HStack {
                if chat.tipo == "transcription" {
                    Image(systemName: "waveform.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "message.circle.fill")
                        .foregroundColor(.blue)
                }
                
                Text("\(getNumeroMessaggi()) messaggi")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
    
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