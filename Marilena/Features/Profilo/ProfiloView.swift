import SwiftUI
import CoreData
import PhotosUI

struct ProfiloView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var profilo: ProfiloUtente
    
    private let profiloService = ProfiloUtenteService.shared
    
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingSettings = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoadingContesto = false
    @State private var isEditingContesto = false
    @State private var editedContesto: String
    @State private var showingCronologia = false
    
    // Stati per la modifica del profilo
    @State private var isEditingProfile = false
    @State private var editedNome: String
    @State private var editedUsername: String
    @State private var editedBio: String
    @State private var editedSitoWeb: String
    @State private var editedLinkedIn: String
    @State private var editedTwitter: String
    @State private var editedInstagram: String

    init(profilo: ProfiloUtente) {
        self.profilo = profilo
        _editedContesto = State(initialValue: profilo.contestoAI ?? "")
        _editedNome = State(initialValue: profilo.nome ?? "")
        _editedUsername = State(initialValue: profilo.username ?? "")
        _editedBio = State(initialValue: profilo.bio ?? "")
        
        // Inizializza i campi social dal dizionario profiliSocial
        let profiliSocial = profilo.profiliSocial ?? [:]
        _editedSitoWeb = State(initialValue: profiliSocial["sitoWeb"] ?? "")
        _editedLinkedIn = State(initialValue: profiliSocial["linkedin"] ?? "")
        _editedTwitter = State(initialValue: profiliSocial["twitter"] ?? "")
        _editedInstagram = State(initialValue: profiliSocial["instagram"] ?? "")
    }
    
    var body: some View {
            ScrollView {
            LazyVStack(spacing: 8) { // Ridotto da 16 a 8
                // Header del profilo
                VStack(spacing: 16) {
                    ZStack {
                        // Foto profilo
                        if let fotoData = profilo.fotoProfilo, let uiImage = UIImage(data: fotoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 4
                                        )
                                )
                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        } else {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        
                        // Pulsante camera
                        Button(action: { showingImagePicker = true }) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .offset(x: 42, y: 42)
                    }
                    
                    VStack(spacing: 6) {
                        Text(profilo.nome ?? "Nome Utente")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 10, height: 10)
                            
                            Text("in linea")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.bottom, 20)
                
                // Sezione Informazioni Personali
                ModernInfoCard(
                    title: "Informazioni Personali",
                    icon: "person.circle.fill",
                    iconColor: .blue
                ) {
                    VStack(spacing: 0) {
                        if isEditingProfile {
                            // Campi di modifica
                            VStack(spacing: 6) {
                                ModernEditableInfoRow(
                                    icon: "person.fill",
                                    label: "Nome",
                                    value: $editedNome,
                                    iconColor: .blue
                                )
                                
                                ModernEditableInfoRow(
                                    icon: "at",
                                    label: "Username", 
                                    value: $editedUsername,
                                    iconColor: .green
                                )
                                
                                ModernEditableInfoRow(
                                    icon: "text.quote",
                                    label: "Bio",
                                    value: $editedBio,
                                    iconColor: .orange
                                )
                                
                                ModernEditableInfoRow(
                                    icon: "globe",
                                    label: "Sito Web",
                                    value: $editedSitoWeb,
                                    iconColor: .purple
                                )
                                
                                ModernEditableInfoRow(
                                    icon: "link.circle.fill",
                                    label: "LinkedIn",
                                    value: $editedLinkedIn,
                                    iconColor: .blue
                                )
                                
                                ModernEditableInfoRow(
                                    icon: "bird.fill",
                                    label: "Twitter/X",
                                    value: $editedTwitter,
                                    iconColor: .cyan
                                )
                                
                                ModernEditableInfoRow(
                                    icon: "camera.circle.fill",
                                    label: "Instagram",
                                    value: $editedInstagram,
                                    iconColor: .pink
                                )
                            }
                            
                            // Pulsanti salva/annulla
                            HStack(spacing: 12) {
                                Button("Annulla") {
                                    resetEditedValues()
                                    isEditingProfile = false
                                }
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                
                                Spacer()
                                
                                Button("Salva") {
                                    salvaModificheProfilo()
                                }
                                .font(.body)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            .padding(.top, 12)
                        } else {
                            // Visualizzazione normale
                            VStack(spacing: 6) {
                                ModernInfoRow(
                                    icon: "person.fill",
                                    label: "Nome",
                                    value: profilo.nome ?? "Non specificato",
                                    iconColor: .blue
                                )
                                
                                ModernInfoRow(
                                    icon: "at",
                                    label: "Username", 
                                    value: profilo.username ?? "Non specificato",
                                    iconColor: .green
                                )
                                
                                ModernInfoRow(
                                    icon: "text.quote",
                                    label: "Bio",
                                    value: profilo.bio ?? "Nessuna bio disponibile",
                                    iconColor: .orange
                                )
                                
                                if let profiliSocial = profilo.profiliSocial {
                                    if let sitoWeb = profiliSocial["sitoWeb"], !sitoWeb.isEmpty {
                                        ModernInfoRow(
                                            icon: "globe",
                                            label: "Sito Web",
                                            value: sitoWeb,
                                            iconColor: .purple
                                        )
                                    }
                                    
                                    if let linkedin = profiliSocial["linkedin"], !linkedin.isEmpty {
                                        ModernInfoRow(
                                            icon: "link.circle.fill",
                                            label: "LinkedIn",
                                            value: linkedin,
                                            iconColor: .blue
                                        )
                                    }
                                    
                                    if let twitter = profiliSocial["twitter"], !twitter.isEmpty {
                                        ModernInfoRow(
                                            icon: "bird.fill",
                                            label: "Twitter/X",
                                            value: twitter,
                                            iconColor: .cyan
                                        )
                                    }
                                    
                                    if let instagram = profiliSocial["instagram"], !instagram.isEmpty {
                                        ModernInfoRow(
                                            icon: "camera.circle.fill",
                                            label: "Instagram",
                                            value: instagram,
                                            iconColor: .pink
                                        )
                                    }
                                }
                            }
                            
                            // Pulsante modifica
                            HStack {
                                Spacer()
                                Button(action: { isEditingProfile = true }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.title3)
                                        Text("Modifica")
                                            .font(.body)
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(10)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                
                // Sezione Contesto AI
                ModernInfoCard(
                    title: "Contesto AI",
                    icon: "brain.head.profile",
                    iconColor: .purple
                ) {
                    VStack(spacing: 12) {
                        if isEditingContesto {
                            VStack(spacing: 12) {
                                TextEditor(text: $editedContesto)
                                    .frame(minHeight: 100)
                                    .padding(12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    .font(.body)
                                
                                HStack {
                                    Button("Annulla") {
                                        editedContesto = profilo.contestoAI ?? ""
                                        isEditingContesto = false
                                    }
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button("Salva") {
                                        salvaContestoAI()
                                    }
                                    .font(.body)
                                    .foregroundColor(.white)
                .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(profilo.contestoAI ?? "Nessun contesto AI configurato")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                
                                HStack {
                                    Image(systemName: "clock.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                    
                                    Text("Ultimo aggiornamento: \(formatLastUpdate())")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button(action: { isEditingContesto = true }) {
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.blue)
                                            .padding(6)
                                            .background(Color.blue.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                    
                                    Button(action: aggiornaContesto) {
                                        if isLoadingContesto {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .frame(width: 32, height: 32)
                                                .background(Color(.systemGray6))
                                                .clipShape(Circle())
                                        } else {
                                            Image(systemName: "arrow.clockwise.circle.fill")
                                                .font(.title3)
                                                .foregroundColor(.green)
                                                .padding(6)
                                                .background(Color.green.opacity(0.1))
                                                .clipShape(Circle())
                                        }
                                    }
                                    .disabled(isLoadingContesto)
                                }
                            }
                        }
                    }
                }
                
                // Sezione Suggerimenti
                ModernInfoCard(
                    title: "Suggerimenti",
                    icon: "lightbulb.fill",
                    iconColor: .yellow
                ) {
                    CompactSuggerimentiView(profilo: profilo)
                }
                

            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profilo")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    if isEditingContesto || isEditingProfile {
                        Button("Annulla") {
                            if isEditingContesto {
                                isEditingContesto = false
                                editedContesto = profilo.contestoAI ?? ""
                            }
                            if isEditingProfile {
                                isEditingProfile = false
                                resetEditedValues()
                            }
                        }
                        .foregroundColor(.red)
                    }
                    
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage) { image in
                if let img = image {
                    profilo.fotoProfilo = img.jpegData(compressionQuality: 0.8)
                    try? viewContext.save()
            }
            }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        .sheet(isPresented: $showingCronologia) {
            CronologiaContestoView(profilo: profilo)
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Profilo"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func resetEditedValues() {
        editedNome = profilo.nome ?? ""
        editedUsername = profilo.username ?? ""
        editedBio = profilo.bio ?? ""
        
        let profiliSocial = profilo.profiliSocial ?? [:]
        editedSitoWeb = profiliSocial["sitoWeb"] ?? ""
        editedLinkedIn = profiliSocial["linkedin"] ?? ""
        editedTwitter = profiliSocial["twitter"] ?? ""
        editedInstagram = profiliSocial["instagram"] ?? ""
    }
    
    private func salvaModificheProfilo() {
        profilo.nome = editedNome
        profilo.username = editedUsername
        profilo.bio = editedBio
        
        // Aggiorna il dizionario profiliSocial
        var profiliSocial = profilo.profiliSocial ?? [:]
        
        if !editedSitoWeb.isEmpty {
            profiliSocial["sitoWeb"] = editedSitoWeb
        } else {
            profiliSocial.removeValue(forKey: "sitoWeb")
        }
        
        if !editedLinkedIn.isEmpty {
            profiliSocial["linkedin"] = editedLinkedIn
        } else {
            profiliSocial.removeValue(forKey: "linkedin")
        }
        
        if !editedTwitter.isEmpty {
            profiliSocial["twitter"] = editedTwitter
        } else {
            profiliSocial.removeValue(forKey: "twitter")
        }
        
        if !editedInstagram.isEmpty {
            profiliSocial["instagram"] = editedInstagram
        } else {
            profiliSocial.removeValue(forKey: "instagram")
        }
        
        profilo.profiliSocial = profiliSocial.isEmpty ? nil : profiliSocial
        
        do {
            try viewContext.save()
            isEditingProfile = false
            alertMessage = "Profilo aggiornato con successo!"
            showingAlert = true
        } catch {
            alertMessage = "Errore nel salvataggio del profilo."
            showingAlert = true
        }
    }
    
    private func salvaContestoAI() {
        profilo.contestoAI = editedContesto
        profilo.dataUltimoAggiornamentoContesto = Date()
        
        do {
            try viewContext.save()
            isEditingContesto = false
            alertMessage = "Contesto AI aggiornato con successo!"
            showingAlert = true
        } catch {
            alertMessage = "Errore nel salvataggio del contesto AI."
            showingAlert = true
        }
    }
    
    private func formatLastUpdate() -> String {
        guard let data = profilo.dataUltimoAggiornamentoContesto else {
            return "Mai"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "it_IT")
        
        return formatter.localizedString(for: data, relativeTo: Date())
    }
    
    private func aggiornaContesto() {
        isLoadingContesto = true
        
        let chats = profilo.chats?.allObjects as? [ChatMarilena] ?? []
        let messaggi = chats.compactMap { $0.messaggi?.allObjects as? [MessaggioMarilena] }.flatMap { $0 }
        let messaggiUtente = messaggi.filter { $0.isUser }

        guard !messaggiUtente.isEmpty else {
            DispatchQueue.main.async {
                isLoadingContesto = false
                alertMessage = "Nessun nuovo messaggio da analizzare."
                showingAlert = true
            }
            return
        }

        let prompt = profiloService.creaPromptPerAggiornamentoContesto(profiloAttuale: profilo, messaggi: messaggiUtente)

        profiloService.aggiornaContestoAI(profilo: profilo, prompt: prompt) { success in
            DispatchQueue.main.async {
                isLoadingContesto = false
                if success {
                    alertMessage = "Contesto AI aggiornato con successo!"
                    editedContesto = profilo.contestoAI ?? ""
                } else {
                    alertMessage = "Errore durante l'aggiornamento del contesto AI."
                }
                showingAlert = true
            }
        }
    }

    private func salvaContesto() {
        profilo.contestoAI = editedContesto
        salvaContestoInCronologia(contesto: editedContesto, tipo: "Manuale")

        do {
            try viewContext.save()
            isEditingContesto = false
        } catch {
            print("Errore nel salvataggio del contesto: \(error)")
            alertMessage = "Errore nel salvataggio del contesto."
            showingAlert = true
        }
    }

    private func salvaContestoInCronologia(contesto: String, tipo: String) {
        let historyEntry = CronologiaContesto(context: viewContext)
        historyEntry.id = UUID()
        historyEntry.dataSalvataggio = Date()
        historyEntry.contenuto = contesto
        historyEntry.tipoAggiornamento = tipo
        historyEntry.profilo = profilo
    }
}

// MARK: - Header Moderno
struct ModernProfiloHeaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    let profilo: ProfiloUtente
    let onSelectImage: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Foto profilo moderna
            Button(action: onSelectImage) {
                ZStack {
                Group {
                        if let fotoData = profilo.fotoProfilo,
                       let uiImage = UIImage(data: fotoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "person.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.gray.opacity(0.3))
                    }
                }
                    .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(
                    Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    // Icona camera moderna
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                    Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "camera.fill")
                                        .font(.caption)
                                .foregroundColor(.white)
                        )
                                .shadow(radius: 4)
                        }
                    }
                    .frame(width: 100, height: 100)
                }
            }
            
            // Informazioni utente
            VStack(spacing: 8) {
                Text(profilo.nome ?? "Caricamento...")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text("Online")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Card Moderna
struct ModernInfoCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let icon: String
    let iconColor: Color
    let content: Content
    
    init(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header card
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Contenuto
            content
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Riga Informazione Moderna
struct ModernInfoRow: View {
    let icon: String
    let label: String
    let value: String
    let iconColor: Color
    
    var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(value)
                        .font(.body)
                        .foregroundColor(.primary)
                    .lineLimit(2)
                }
                
                Spacer()
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Riga Informazione Modificabile
struct ModernEditableInfoRow: View {
    let icon: String
    let label: String
    @Binding var value: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                        .foregroundColor(.secondary)
                
                TextField(label, text: $value)
                    .font(.body)
                    .foregroundColor(.primary)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Suggerimenti Compatti
struct CompactSuggerimentiView: View {
    @Environment(\.colorScheme) private var colorScheme
    let profilo: ProfiloUtente
    @State private var suggerimenti: [SuggerimentoContesto] = []
    @State private var tendenzaMessaggi: TendenzaMessaggi?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tendenza messaggi compatta
            if let tendenza = tendenzaMessaggi {
                CompactTendenzaCard(tendenza: tendenza)
            }
            
            // Lista suggerimenti compatta
            if suggerimenti.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Profilo Completo!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                        Text("Il tuo profilo è completo e aggiornato")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(8)
                    } else {
                ForEach(suggerimenti.indices, id: \.self) { index in
                    CompactSuggerimentoCard(
                        suggerimento: suggerimenti[index],
                        profilo: profilo
                    ) {
                        suggerimenti.remove(at: index)
                    }
                }
            }
        }
        .onAppear {
            caricaSuggerimenti()
        }
    }
    
    private func caricaSuggerimenti() {
        var suggerimentiBase = ContestoAIService.shared.generaSuggerimentiContesto(profilo: profilo)
        
        // Aggiungi suggerimenti per profili social se mancanti
        let profiliSocial = profilo.profiliSocial ?? [:]
        
        if profiliSocial["linkedin"]?.isEmpty ?? true {
            suggerimentiBase.append(SuggerimentoContesto(
                id: UUID(),
                tipo: .social,
                titolo: "Aggiungi LinkedIn",
                descrizione: "Il tuo profilo LinkedIn aiuta l'AI a capire meglio la tua esperienza professionale",
                priorita: .alta,
                azione: "Aggiungi LinkedIn"
            ))
        }
        
        if profiliSocial["twitter"]?.isEmpty ?? true {
            suggerimentiBase.append(SuggerimentoContesto(
                id: UUID(),
                tipo: .social,
                titolo: "Aggiungi Twitter/X",
                descrizione: "Il tuo profilo Twitter/X mostra i tuoi interessi e la tua personalità",
                priorita: .media,
                azione: "Aggiungi Twitter/X"
            ))
        }
        
        if profiliSocial["instagram"]?.isEmpty ?? true {
            suggerimentiBase.append(SuggerimentoContesto(
                id: UUID(),
                tipo: .social,
                titolo: "Aggiungi Instagram",
                descrizione: "Il tuo profilo Instagram aiuta l'AI a capire i tuoi interessi visivi",
                priorita: .media,
                azione: "Aggiungi Instagram"
            ))
        }
        
        if profiliSocial["sitoWeb"]?.isEmpty ?? true {
            suggerimentiBase.append(SuggerimentoContesto(
                id: UUID(),
                tipo: .social,
                titolo: "Aggiungi Sito Web",
                descrizione: "Il tuo sito web personale fornisce informazioni dettagliate su di te",
                priorita: .alta,
                azione: "Aggiungi Sito Web"
            ))
        }
        
        suggerimenti = suggerimentiBase
        tendenzaMessaggi = ContestoAIService.shared.analizzaTendenzaMessaggi(profilo: profilo)
    }
}

// MARK: - Card Tendenza Compatta
struct CompactTendenzaCard: View {
    let tendenza: TendenzaMessaggi
    
    var body: some View {
        HStack(spacing: 10) {
            // Indicatore colorato
            Circle()
                .fill(Color(tendenza.tipo.colore))
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tendenza.tipo.descrizione)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(String(format: "%.1f", tendenza.mediaGiornaliera)) messaggi/giorno")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(tendenza.messaggiRecenti)")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("ultimi 7gg")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - Card Suggerimento Compatta
struct CompactSuggerimentoCard: View {
    let suggerimento: SuggerimentoContesto
    let profilo: ProfiloUtente
    let onCompleted: () -> Void
    
    @State private var showingAction = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Icona priorità
            Image(systemName: suggerimento.priorita.icona)
                    .font(.title3)
                .foregroundColor(Color(suggerimento.priorita.colore))
                .frame(width: 20)
                
            // Contenuto
                VStack(alignment: .leading, spacing: 2) {
                Text(suggerimento.titolo)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(suggerimento.descrizione)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    .lineLimit(1)
                }
                
                Spacer()
                
            // Pulsante azione
            Button(action: {
                eseguiAzione()
            }) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
        .sheet(isPresented: $showingAction) {
            NavigationView {
                vistaPerAzione()
                    .navigationTitle(suggerimento.titolo)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Chiudi") {
                                showingAction = false
                                onCompleted()
                            }
                        }
                    }
            }
        }
    }
    
    private func eseguiAzione() {
        switch suggerimento.tipo {
        case .aggiornamentoContesto:
            profilo.dataUltimoAggiornamentoContesto = Date()
            profilo.contestoAI = "Contesto aggiornato automaticamente"
            
            do {
                try profilo.managedObjectContext?.save()
                onCompleted()
            } catch {
                print("Errore aggiornamento contesto: \(error)")
            }
            
        case .completaProfilo, .aggiungiFoto, .social:
            showingAction = true
        }
    }
    
    @ViewBuilder
    private func vistaPerAzione() -> some View {
        switch suggerimento.tipo {
        case .completaProfilo, .aggiungiFoto, .social:
            ModificaProfiloView(profilo: profilo)
            
        case .aggiornamentoContesto:
            VStack(spacing: 20) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("Contesto Aggiornato!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Il tuo profilo è stato aggiornato con le conversazioni recenti")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Continua") {
                    showingAction = false
                    onCompleted()
            }
                .buttonStyle(.borderedProminent)
        }
            .padding()
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let onImageSelected: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let result = results.first else {
                parent.onImageSelected(nil)
                return
            }
            
            result.itemProvider.loadObject(ofClass: UIImage.self) { [self] image, error in
                if let image = image as? UIImage {
                    parent.onImageSelected(image)
                } else {
                    parent.onImageSelected(nil)
                }
            }
        }
    }
}



// MARK: - Cronologia Contesto View
struct CronologiaContestoView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var profilo: ProfiloUtente
    
    var cronologiaOrdinata: [CronologiaContesto] {
        let cronologia = profilo.cronologia?.allObjects as? [CronologiaContesto] ?? []
        return cronologia.sorted { 
            ($0.dataSalvataggio ?? Date.distantPast) > ($1.dataSalvataggio ?? Date.distantPast) 
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if cronologiaOrdinata.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("Nessuna cronologia disponibile")
                            .font(.headline)
                                    .foregroundColor(.secondary)
                        
                        Text("Le modifiche al contesto AI verranno salvate qui")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                    } else {
                    ForEach(cronologiaOrdinata, id: \.id) { voce in
                        CronologiaContestoRow(voce: voce)
                    }
                }
                    }
            .navigationTitle("Cronologia Contesto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Cronologia Contesto Row
struct CronologiaContestoRow: View {
    let voce: CronologiaContesto
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: voce.tipoAggiornamento == "Manuale" ? "person.fill" : "cpu")
                            .font(.caption)
                            .foregroundColor(voce.tipoAggiornamento == "Manuale" ? .blue : .purple)
                        
                        Text(voce.tipoAggiornamento ?? "Sconosciuto")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(voce.tipoAggiornamento == "Manuale" ? .blue : .purple)
                    }
                    
                    if let data = voce.dataSalvataggio {
                        Text(data, style: .date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                Text(voce.contenuto ?? "Nessun contenuto")
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding()
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ProfiloView(profilo: ProfiloUtenteService.shared.creaProfiloDefault(in: PersistenceController.preview.container.viewContext))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 
