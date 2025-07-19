import SwiftUI
import CoreData
import PhotosUI

struct ProfiloView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var profilo: ProfiloUtente
    
    private let profiloService = ProfiloUtenteService.shared
    
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingSocialSheet = false
    @State private var showingSettings = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoadingContesto = false
    @State private var isEditingContesto = false
    @State private var editedContesto: String
    @State private var showingCronologia = false

    init(profilo: ProfiloUtente) {
        self.profilo = profilo
        _editedContesto = State(initialValue: profilo.contestoAI ?? "")
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Header Moderno
                ModernProfiloHeaderView(
                    profilo: profilo,
                    onSelectImage: { showingImagePicker = true }
                )
                .padding(.top, 20)
                
                // Sezione Informazioni Personali
                ModernInfoCard(
                    title: "Informazioni Personali",
                    icon: "person.circle.fill",
                    iconColor: .blue
                ) {
                    VStack(spacing: 16) {
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
                    }
                }
                
                // Sezione Contesto AI
                ModernInfoCard(
                    title: "Contesto AI",
                    icon: "brain.head.profile",
                    iconColor: .purple
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header con controlli
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "brain.head.profile")
                                    .font(.title3)
                                    .foregroundColor(.purple)
                                
                                Text("Contesto AI")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()

                            if isEditingContesto {
                                Button(action: salvaContesto) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Salva")
                                    }
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.green)
                                    .cornerRadius(16)
                                }
                            } else {
                                HStack(spacing: 12) {
                                    Button(action: { showingCronologia = true }) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.title3)
                                            .foregroundColor(.gray)
                                            .frame(width: 32, height: 32)
                                            .background(Color(.systemGray6))
                                            .clipShape(Circle())
                                    }
                                    
                                    Button(action: aggiornaContesto) {
                                        if isLoadingContesto {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                                .frame(width: 32, height: 32)
                                                .background(Color(.systemGray6))
                                                .clipShape(Circle())
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.title3)
                                                .foregroundColor(.blue)
                                                .frame(width: 32, height: 32)
                                                .background(Color(.systemGray6))
                                                .clipShape(Circle())
                                        }
                                    }
                                    .disabled(isLoadingContesto)
                                }
                            }
                        }
                        
                        // Contenuto contesto
                        if isEditingContesto {
                            TextEditor(text: $editedContesto)
                                .font(.body)
                                .frame(minHeight: 120)
                                .padding(12)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(profilo.contestoAI ?? "Il contesto AI verrà generato automaticamente basandosi sulle tue conversazioni.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .lineLimit(4)
                                
                                Button("Modifica contesto") {
                                    editedContesto = profilo.contestoAI ?? ""
                                    isEditingContesto = true
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            .padding(16)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .cornerRadius(12)
                            .onTapGesture {
                                editedContesto = profilo.contestoAI ?? ""
                                isEditingContesto = true
                            }
                        }
                        
                        // Timestamp
                        if let ultimoAggiornamento = profilo.dataUltimoAggiornamentoContesto {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text("Aggiornato \(ultimoAggiornamento, style: .relative)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
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
                    SuggerimentiProfiloView(profilo: profilo)
                }
                
                // Sezione Social
                ModernInfoCard(
                    title: "Profili Social",
                    icon: "network",
                    iconColor: .pink
                ) {
                    Button(action: { showingSocialSheet = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                            
                            Text("Gestisci Profili Social")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Profilo")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if isEditingContesto {
                        Button("Annulla") {
                            isEditingContesto = false
                            editedContesto = profilo.contestoAI ?? ""
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
        .sheet(isPresented: $showingSocialSheet) {
            ProfiliSocialSheet(profilo: profilo)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingCronologia) {
            CronologiaContestoView(profilo: profilo)
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Contesto AI"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
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
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
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
        .padding(.horizontal, 20)
    }
}

// MARK: - Card Moderna
struct ModernInfoCard<Content: View>: View {
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
        VStack(alignment: .leading, spacing: 16) {
            // Header card
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.headline)
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
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
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
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Text(value)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
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

// MARK: - Sheet Profili Social
struct ProfiliSocialSheet: View {
    let profilo: ProfiloUtente?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section("Profili Social") {
                if let profili = profilo?.profiliSocial, !profili.isEmpty {
                    ForEach(Array(profili.keys), id: \.self) { piattaforma in
                        HStack {
                            Text(piattaforma.capitalized)
                            Spacer()
                            Text(profili[piattaforma] ?? "")
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("Nessun profilo social")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Aggiungi Profilo") {
                Button("Aggiungi profilo social") {
                    // Implementazione per aggiungere nuovo profilo
                }
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
    }
}

#Preview {
    ProfiloView(profilo: ProfiloUtenteService.shared.creaProfiloDefault(in: PersistenceController.preview.container.viewContext))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
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
