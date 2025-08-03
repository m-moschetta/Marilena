import SwiftUI
import CoreData

struct ModificaProfiloView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let profilo: ProfiloUtente
    
    @State private var nome: String = ""
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var cellulare: String = ""
    @State private var bio: String = ""
    @State private var dataNascita: Date = Date()
    @State private var showingDatePicker = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Informazioni Personali") {
                    TextField("Nome", text: $nome)
                        .textContentType(.name)
                    
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    TextField("Cellulare", text: $cellulare)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }
                
                Section("Bio") {
                    TextField("Racconta qualcosa di te...", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Data di Nascita") {
                    HStack {
                        Text(dataNascita, style: .date)
                        Spacer()
                        Button("Modifica") {
                            showingDatePicker = true
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Section("Profili Social") {
                    NavigationLink("Gestisci profili social") {
                        GestioneProfiliSocialView(profilo: profilo)
                    }
                }
            }
            .navigationTitle("Modifica Profilo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        salvaModifiche()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                caricaDatiProfilo()
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(dataSelezionata: $dataNascita)
            }
            .alert("Profilo", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func caricaDatiProfilo() {
        nome = profilo.nome ?? ""
        username = profilo.username ?? ""
        email = profilo.email ?? ""
        cellulare = profilo.cellulare ?? ""
        bio = profilo.bio ?? ""
        dataNascita = profilo.dataNascita ?? Date()
    }
    
    private func salvaModifiche() {
        profilo.nome = nome.isEmpty ? nil : nome
        profilo.username = username.isEmpty ? nil : username
        profilo.email = email.isEmpty ? nil : email
        profilo.cellulare = cellulare.isEmpty ? nil : cellulare
        profilo.bio = bio.isEmpty ? nil : bio
        profilo.dataNascita = dataNascita
        
        if ProfiloUtenteService.shared.salvaProfilo(profilo, in: viewContext) {
            alertMessage = "Profilo aggiornato con successo!"
            showingAlert = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                dismiss()
            }
        } else {
            alertMessage = "Errore nel salvare le modifiche"
            showingAlert = true
        }
    }
}

// MARK: - Date Picker Sheet
struct DatePickerSheet: View {
    @Binding var dataSelezionata: Date
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Data di Nascita",
                    selection: $dataSelezionata,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                
                Spacer()
            }
            .navigationTitle("Seleziona Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fatto") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Gestione Profili Social
struct GestioneProfiliSocialView: View {
    let profilo: ProfiloUtente
    @Environment(\.dismiss) private var dismiss
    @State private var piattaformaSelezionata = "Instagram"
    @State private var usernameSocial = ""
    @State private var showingAddSheet = false
    
    let piattaformeDisponibili = [
        "Instagram", "Twitter", "LinkedIn", "Facebook", 
        "TikTok", "YouTube", "GitHub", "Telegram"
    ]
    
    var body: some View {
        List {
            Section("Profili Esistenti") {
                if let profili = profilo.profiliSocial, !profili.isEmpty {
                    ForEach(Array(profili.keys), id: \.self) { piattaforma in
                        HStack {
                            Image(systemName: iconaPerPiattaforma(piattaforma))
                                .foregroundColor(colorePerPiattaforma(piattaforma))
                                .frame(width: 24)
                            
                            VStack(alignment: .leading) {
                                Text(piattaforma)
                                    .font(.headline)
                                Text(profili[piattaforma] ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Apri") {
                                apriProfiloSocial(piattaforma: piattaforma, username: profili[piattaforma] ?? "")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .onDelete(perform: rimuoviProfilo)
                } else {
                    Text("Nessun profilo social aggiunto")
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            Section {
                Button("Aggiungi Profilo Social") {
                    showingAddSheet = true
                }
                .foregroundColor(.blue)
            }
        }
        .navigationTitle("Profili Social")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Chiudi") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AggiungiProfiloSocialSheet(
                profilo: profilo,
                piattaforme: piattaformeDisponibili
            )
        }
    }
    
    private func iconaPerPiattaforma(_ piattaforma: String) -> String {
        switch piattaforma.lowercased() {
        case "instagram":
            return "camera.fill"
        case "twitter":
            return "bird.fill"
        case "linkedin":
            return "briefcase.fill"
        case "facebook":
            return "person.2.fill"
        case "tiktok":
            return "music.note"
        case "youtube":
            return "play.rectangle.fill"
        case "github":
            return "chevron.left.forwardslash.chevron.right"
        case "telegram":
            return "paperplane.fill"
        default:
            return "globe"
        }
    }
    
    private func colorePerPiattaforma(_ piattaforma: String) -> Color {
        switch piattaforma.lowercased() {
        case "instagram":
            return .purple
        case "twitter":
            return .blue
        case "linkedin":
            return .blue
        case "facebook":
            return .blue
        case "tiktok":
            return .black
        case "youtube":
            return .red
        case "github":
            return .black
        case "telegram":
            return .blue
        default:
            return .gray
        }
    }
    
    private func apriProfiloSocial(piattaforma: String, username: String) {
        var urlString = ""
        
        switch piattaforma.lowercased() {
        case "instagram":
            urlString = "https://instagram.com/\(username)"
        case "twitter":
            urlString = "https://twitter.com/\(username)"
        case "linkedin":
            urlString = "https://linkedin.com/in/\(username)"
        case "facebook":
            urlString = "https://facebook.com/\(username)"
        case "tiktok":
            urlString = "https://tiktok.com/@\(username)"
        case "youtube":
            urlString = "https://youtube.com/@\(username)"
        case "github":
            urlString = "https://github.com/\(username)"
        case "telegram":
            urlString = "https://t.me/\(username)"
        default:
            return
        }
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func rimuoviProfilo(offsets: IndexSet) {
        guard let profili = profilo.profiliSocial else { return }
        let piattaforme = Array(profili.keys)
        
        for index in offsets {
            let piattaforma = piattaforme[index]
            var profili = profilo.profiliSocial ?? [:]
            profili.removeValue(forKey: piattaforma)
            profilo.profiliSocial = profili
        }
        
        // Salva le modifiche
        if let context = profilo.managedObjectContext {
            try? context.save()
        }
    }
}

// MARK: - Sheet Aggiungi Profilo Social
struct AggiungiProfiloSocialSheet: View {
    let profilo: ProfiloUtente
    let piattaforme: [String]
    
    @Environment(\.dismiss) private var dismiss
    @State private var piattaformaSelezionata = "Instagram"
    @State private var usernameSocial = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Piattaforma") {
                    Picker("Piattaforma", selection: $piattaformaSelezionata) {
                        ForEach(piattaforme, id: \.self) { piattaforma in
                            Text(piattaforma).tag(piattaforma)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Username") {
                    TextField("Username", text: $usernameSocial)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section {
                    Button("Aggiungi Profilo") {
                        aggiungiProfilo()
                    }
                    .disabled(usernameSocial.isEmpty)
                }
            }
            .navigationTitle("Aggiungi Profilo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func aggiungiProfilo() {
        var profili = profilo.profiliSocial ?? [:]
        profili[piattaformaSelezionata] = usernameSocial
        profilo.profiliSocial = profili
        
        // Salva le modifiche
        if let context = profilo.managedObjectContext {
            try? context.save()
        }
        
        dismiss()
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let profilo = ProfiloUtenteService.shared.creaProfiloDefault(in: context)
    return ModificaProfiloView(profilo: profilo)
        .environment(\.managedObjectContext, context)
} 