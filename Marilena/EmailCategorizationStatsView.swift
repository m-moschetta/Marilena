import SwiftUI
import Charts

// MARK: - Email Categorization Statistics View

public struct EmailCategorizationStatsView: View {
    
    @StateObject private var monitor: EmailCategorizationMonitor
    @ObservedObject private var configManager = EmailCategorizationConfigManager.shared
    
    @State private var showingConfigSheet = false
    @State private var showingExportSheet = false
    @State private var exportedStats = ""
    
    // MARK: - Initialization
    
    public init(categorizationService: EmailCategorizationService) {
        self._monitor = StateObject(wrappedValue: EmailCategorizationMonitor(categorizationService: categorizationService))
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Header con stato
                    headerSection
                    
                    // Statistiche principali
                    mainStatsSection
                    
                    // Grafico distribuzione AI vs Traditional
                    usageChartSection
                    
                    // Performance e costi
                    performanceSection
                    
                    // Distribuzione categorie
                    categoryDistributionSection
                    
                    // Sessione corrente
                    sessionSection
                    
                    // Configurazione
                    configSection
                    
                }
                .padding()
            }
            .navigationTitle("📊 Statistiche Categorizzazione")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu("Azioni") {
                        Button("📊 Esporta Statistiche") {
                            exportedStats = monitor.exportStats()
                            showingExportSheet = true
                        }
                        
                        Button("🔄 Reset Sessione") {
                            monitor.resetSessionStats()
                        }
                        
                        Button("⚙️ Configurazione") {
                            showingConfigSheet = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingConfigSheet) {
            EmailCategorizationConfigView()
        }
        .sheet(isPresented: $showingExportSheet) {
            ShareSheet(activityItems: [exportedStats])
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(monitor.isMonitoring ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(monitor.isMonitoring ? "Monitoraggio Attivo" : "Monitoraggio Inattivo")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(monitor.currentStats.totalEmailsCategorized)")
                    .font(.title2)
                    .fontWeight(.bold)
                + Text(" email categorizzate")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var mainStatsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            
            StatCard(
                title: "AI Utilizzata",
                value: "\(monitor.currentStats.aiCategorized)",
                subtitle: "\(String(format: "%.1f", monitor.currentStats.aiUsagePercentage))%",
                color: .blue,
                systemImage: "brain.head.profile"
            )
            
            StatCard(
                title: "Tradizionale",
                value: "\(monitor.currentStats.traditionalCategorized)",
                subtitle: "\(String(format: "%.1f", monitor.currentStats.traditionalUsagePercentage))%",
                color: .green,
                systemImage: "gearshape"
            )
            
        }
    }
    
    @ViewBuilder
    private var usageChartSection: some View {
        if monitor.currentStats.totalEmailsCategorized > 0 {
            VStack(alignment: .leading, spacing: 12) {
                Text("Distribuzione Metodi")
                    .font(.headline)
                
                Chart {
                    SectorMark(
                        angle: .value("AI", monitor.currentStats.aiCategorized),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(.blue.gradient)
                    .opacity(0.8)
                    
                    SectorMark(
                        angle: .value("Traditional", monitor.currentStats.traditionalCategorized),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(.green.gradient)
                    .opacity(0.8)
                }
                .frame(height: 200)
                .chartLegend(position: .bottom)
                
                HStack {
                    Label("AI", systemImage: "circle.fill")
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Label("Tradizionale", systemImage: "circle.fill")
                        .foregroundColor(.green)
                }
                .font(.caption)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance & Costi")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                
                PerformanceCard(
                    title: "Velocità AI",
                    value: String(format: "%.2f", monitor.currentStats.averageAITime),
                    unit: "secondi",
                    color: .blue
                )
                
                PerformanceCard(
                    title: "Velocità Tradizionale",
                    value: String(format: "%.3f", monitor.currentStats.averageTraditionalTime),
                    unit: "secondi",
                    color: .green
                )
                
                PerformanceCard(
                    title: "Costo Stimato",
                    value: String(format: "%.4f", monitor.currentStats.estimatedCost),
                    unit: "USD",
                    color: .orange
                )
                
                PerformanceCard(
                    title: "Risparmio",
                    value: String(format: "%.4f", monitor.currentStats.estimatedSavings),
                    unit: "USD",
                    color: .mint
                )
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var categoryDistributionSection: some View {
        if !monitor.currentStats.categoryDistribution.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Distribuzione Categorie")
                    .font(.headline)
                
                ForEach(monitor.currentStats.categoryDistribution.sorted(by: { $0.value > $1.value }), id: \.key) { category, count in
                    HStack {
                        Label(category.displayName, systemImage: category.icon)
                            .foregroundColor(category.color)
                        
                        Spacer()
                        
                        Text("\(count)")
                            .fontWeight(.medium)
                        
                        Text("(\(String(format: "%.1f", Double(count) / Double(monitor.currentStats.totalEmailsCategorized) * 100))%)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sessione Corrente")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Categorizzate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(monitor.currentStats.sessionCategorized)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .center) {
                    Text("AI Utilizzate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(monitor.currentStats.sessionAIUsed)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("AI Rimanenti")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(monitor.currentStats.sessionAIRemaining)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(monitor.currentStats.sessionAIRemaining > 10 ? .green : .orange)
                }
            }
            
            // Progress bar per AI rimanenti
            ProgressView(value: Double(monitor.currentStats.sessionAIUsed), total: Double(monitor.currentStats.sessionAIUsed + monitor.currentStats.sessionAIRemaining))
                .progressViewStyle(LinearProgressViewStyle())
                .scaleEffect(y: 2)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var configSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configurazione Attuale")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Max AI Sessione: \(configManager.currentConfig.maxAICategorizationPerSession)")
                    Text("Max AI Account: \(configManager.currentConfig.maxAICategorizationPerAccount)")
                    Text("Email Recenti: \(configManager.currentConfig.recentEmailDaysThreshold) giorni")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Modifica") {
                    showingConfigSheet = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let systemImage: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct PerformanceCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Email Category Extensions
// Le proprietà icon, displayName, color sono già definite in SharedTypes.swift

// MARK: - Configuration View

struct EmailCategorizationConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var configManager = EmailCategorizationConfigManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section("Limiti AI") {
                    HStack {
                        Text("Max AI per sessione")
                        Spacer()
                        Text("\(configManager.currentConfig.maxAICategorizationPerSession)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Max AI per account")
                        Spacer()
                        Text("\(configManager.currentConfig.maxAICategorizationPerAccount)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Performance") {
                    HStack {
                        Text("Email recenti (giorni)")
                        Spacer()
                        Text("\(configManager.currentConfig.recentEmailDaysThreshold)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Soglia confidence")
                        Spacer()
                        Text(String(format: "%.1f", configManager.currentConfig.traditionalConfidenceThreshold))
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Preset") {
                    Button("🚀 Aggressive (poche email)") {
                        configManager.updateConfig(.aggressive)
                    }
                    
                    Button("⚖️ Default (normale)") {
                        configManager.updateConfig(.default)
                    }
                    
                    Button("💰 Conservative (molte email)") {
                        configManager.updateConfig(.conservative)
                    }
                }
            }
            .navigationTitle("Configurazione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fine") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}