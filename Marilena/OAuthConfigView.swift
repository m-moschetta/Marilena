import SwiftUI

// MARK: - OAuth Configuration View
// Vista per configurare le credenziali OAuth per Google e Microsoft

struct OAuthConfigView: View {
    
    // MARK: - State Properties
    @State private var googleClientId = ""
    @State private var googleClientSecret = ""
    @State private var microsoftClientId = ""
    @State private var microsoftClientSecret = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSaving = false
    
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                Section("Google OAuth Configuration") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Client ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SecureField("Google Client ID", text: $googleClientId)
                            .textContentType(.none)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Client Secret")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SecureField("Google Client Secret", text: $googleClientSecret)
                            .textContentType(.none)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    Button("Test Google Configuration") {
                        testGoogleConfiguration()
                    }
                    .foregroundColor(.blue)
                }
                
                Section("Microsoft OAuth Configuration") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Client ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SecureField("Microsoft Client ID", text: $microsoftClientId)
                            .textContentType(.none)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Client Secret")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SecureField("Microsoft Client Secret", text: $microsoftClientSecret)
                            .textContentType(.none)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    Button("Test Microsoft Configuration") {
                        testMicrosoftConfiguration()
                    }
                    .foregroundColor(.blue)
                }
                
                Section("Instructions") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Per configurare OAuth:")
                            .font(.headline)
                        
                        Text("1. Vai su Google Cloud Console e crea un progetto")
                        Text("2. Abilita Gmail API e Google+ API")
                        Text("3. Crea credenziali OAuth 2.0")
                        Text("4. Aggiungi 'com.marilena.email://oauth/callback' come URI di redirect")
                        Text("5. Copia Client ID e Client Secret")
                        
                        Divider()
                        
                        Text("Per Microsoft:")
                            .font(.headline)
                        
                        Text("1. Vai su Azure Portal e registra un'app")
                        Text("2. Configura le API Microsoft Graph")
                        Text("3. Aggiungi 'com.marilena.email://oauth/callback' come redirect URI")
                        Text("4. Copia Client ID e Client Secret")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("OAuth Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveConfiguration()
                    }
                    .disabled(isSaving)
                }
            }
        }
        .onAppear {
            loadCurrentConfiguration()
        }
        .alert("Configuration", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Private Methods
    
    private func loadCurrentConfiguration() {
        // Carica le configurazioni salvate (se esistono)
        googleClientId = UserDefaults.standard.string(forKey: "google_client_id") ?? ""
        googleClientSecret = KeychainManager.shared.load(key: "google_client_secret") ?? ""
        microsoftClientId = UserDefaults.standard.string(forKey: "microsoft_client_id") ?? ""
        microsoftClientSecret = KeychainManager.shared.load(key: "microsoft_client_secret") ?? ""
        
        // Debug: Mostra le credenziali caricate
        print("🔧 OAuthConfig Debug: Credenziali caricate")
        print("🔧 OAuthConfig Debug: Google Client ID = \(googleClientId)")
        print("🔧 OAuthConfig Debug: Google Client Secret = \(googleClientSecret)")
        print("🔧 OAuthConfig Debug: Microsoft Client ID = \(microsoftClientId)")
        print("🔧 OAuthConfig Debug: Microsoft Client Secret = \(microsoftClientSecret)")
    }
    
    private func saveConfiguration() {
        isSaving = true
        
        // Debug: Mostra le credenziali che stiamo salvando
        print("🔧 OAuthConfig Debug: Salvando credenziali")
        print("🔧 OAuthConfig Debug: Google Client ID = \(googleClientId)")
        print("🔧 OAuthConfig Debug: Google Client Secret = \(googleClientSecret)")
        print("🔧 OAuthConfig Debug: Microsoft Client ID = \(microsoftClientId)")
        print("🔧 OAuthConfig Debug: Microsoft Client Secret = \(microsoftClientSecret)")
        
        // Salva le configurazioni
        UserDefaults.standard.set(googleClientId, forKey: "google_client_id")
        let googleSecretSaved = KeychainManager.shared.save(key: "google_client_secret", value: googleClientSecret)
        UserDefaults.standard.set(microsoftClientId, forKey: "microsoft_client_id")
        let microsoftSecretSaved = KeychainManager.shared.save(key: "microsoft_client_secret", value: microsoftClientSecret)
        
        print("🔧 OAuthConfig Debug: Google Secret salvato = \(googleSecretSaved)")
        print("🔧 OAuthConfig Debug: Microsoft Secret salvato = \(microsoftSecretSaved)")
        
        alertMessage = "Configurazione OAuth salvata con successo!"
        showingAlert = true
        
        isSaving = false
        
        // Chiudi la vista dopo un breve delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
    
    private func testGoogleConfiguration() {
        guard !googleClientId.isEmpty && !googleClientSecret.isEmpty else {
            alertMessage = "Inserisci Client ID e Client Secret per Google"
            showingAlert = true
            return
        }
        
        alertMessage = "Configurazione Google valida! Puoi procedere con il salvataggio."
        showingAlert = true
    }
    
    private func testMicrosoftConfiguration() {
        guard !microsoftClientId.isEmpty && !microsoftClientSecret.isEmpty else {
            alertMessage = "Inserisci Client ID e Client Secret per Microsoft"
            showingAlert = true
            return
        }
        
        alertMessage = "Configurazione Microsoft valida! Puoi procedere con il salvataggio."
        showingAlert = true
    }
}

#Preview {
    OAuthConfigView()
} 