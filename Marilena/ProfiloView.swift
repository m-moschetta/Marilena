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
            LazyVStack(spacing: 20) {
                // Sezione Header
                ProfiloHeaderView(
                    profilo: profilo,
                    onSelectImage: { showingImagePicker = true }
                )
                .padding(.vertical)
                
                // Sezione Informazioni
                VStack(alignment: .leading, spacing: 16) {
                    Text("Informazioni Personali")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        InfoRow(label: "Nome", value: profilo.nome ?? "N/A")
                        InfoRow(label: "Username", value: profilo.username ?? "N/A")
                        InfoRow(label: "Bio", value: profilo.bio ?? "N/A")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Sezione Contesto AI
                VStack(alignment: .leading, spacing: 16) {
                    Text("Contesto AI")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.title3)
                            .foregroundColor(.purple)
                        
                        Text("Contesto AI")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()

                        if isEditingContesto {
                            Button(action: salvaContesto) {
                                Text("Salva")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                        } else {
                            HStack(spacing: 12) {
                                Button(action: { showingCronologia = true }) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.title3)
                                        .foregroundColor(.gray)
                                }
                                
                                Button(action: aggiornaContesto) {
                                    if isLoadingContesto {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.title3)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .disabled(isLoadingContesto)
                            }
                        }
                    }
                    
                    if isEditingContesto {
                        TextEditor(text: $editedContesto)
                            .font(.body)
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    } else {
                        Text(profilo.contestoAI ?? "Il contesto AI verrà generato automaticamente basandosi sulle tue conversazioni.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                            .background(Color(.tertiarySystemGroupedBackground))
                            .cornerRadius(8)
                            .onTapGesture {
                                editedContesto = profilo.contestoAI ?? ""
                                isEditingContesto = true
                            }
                    }
                    
                    if let ultimoAggiornamento = profilo.dataUltimoAggiornamentoContesto {
                        HStack {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Ultimo aggiornamento: \(ultimoAggiornamento, style: .relative)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Sezione Suggerimenti
            VStack(alignment: .leading, spacing: 16) {
                Text("Suggerimenti")
                    .font(.headline)
                    .padding(.horizontal)
                
                SuggerimentiProfiloView(profilo: profilo)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
            
            // Sezione Social
            VStack(alignment: .leading, spacing: 16) {
                Text("Profili Social")
                    .font(.headline)
                    .padding(.horizontal)
                
                Button("Gestisci Profili Social") {
                    showingSocialSheet = true
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }
        .navigationTitle("Profilo")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if isEditingContesto {
                        Button("Annulla") {
                            isEditingContesto = false
                            editedContesto = profilo.contestoAI ?? ""
                        }
                    }
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
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
        // Salva anche una copia nella cronologia (Fase 3)
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
        historyEntry.tipoAggiornamento = tipo // "Automatico" o "Manuale"
        historyEntry.profilo = profilo
    }
}

// MARK: - Header con foto profilo
struct ProfiloHeaderView: View {
    let profilo: ProfiloUtente
    let onSelectImage: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Foto profilo
            Button(action: onSelectImage) {
                Group {
                    if let fotoData = profilo.fotoProfilo,
                       let uiImage = UIImage(data: fotoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color(.systemBackground), lineWidth: 4)
                        .shadow(radius: 10)
                )
                .overlay(
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                        )
                        .offset(x: 40, y: 40)
                )
            }
            
            // Nome e stato
            VStack(spacing: 4) {
                Text(profilo.nome ?? "Caricamento...")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    
                    Text("in linea")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Riga informazione profilo
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
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
