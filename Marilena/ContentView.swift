//
//  ContentView.swift
//  Marilena
//
//  Vista principale con layout adattivo iPad/iPhone
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var coordinator = NavigationCoordinator()
    @EnvironmentObject private var calendarManager: CalendarManager
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                iPhoneLayout()
            } else {
                iPadLayout()
            }
        }
        .environmentObject(coordinator)
        .accentColor(.blue)
        .onAppear {
            PerformanceSignpost.event("HomeAppear")
        }
    }
}

// MARK: - iPhone Layout
struct iPhoneLayout: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @EnvironmentObject private var calendarManager: CalendarManager
    @Environment(\ .managedObjectContext) private var viewContext
    
    var body: some View {
        TabView(selection: Binding(
            get: { coordinator.selectedTab },
            set: { coordinator.selectedTab = $0 }
        )) {
            // Tab 1: Chat AI
            NavigationStack {
                ChatsListView()
            }
            .tabItem { Label(AppTab.chat.title, systemImage: AppTab.chat.icon) }
            .tag(AppTab.chat)
            
            // Tab 2: Email
            NavigationStack {
                EmailListView()
            }
            .tabItem { Label(AppTab.email.title, systemImage: AppTab.email.icon) }
            .tag(AppTab.email)
            
            // Tab 3: Registratore
            NavigationStack {
                RecorderMainView()
            }
            .tabItem { Label(AppTab.recorder.title, systemImage: AppTab.recorder.icon) }
            .tag(AppTab.recorder)
            
            // Tab 4: Calendario
            NavigationStack {
                NewCalendarView(calendarManager: calendarManager)
            }
            .tabItem { Label(AppTab.calendar.title, systemImage: AppTab.calendar.icon) }
            .tag(AppTab.calendar)
            
            // Tab 5: Profilo
            NavigationStack {
                ProfiloWrapperView()
            }
            .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.icon) }
            .tag(AppTab.profile)
        }
    }
}

// MARK: - iPad Layout
struct iPadLayout: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @EnvironmentObject private var calendarManager: CalendarManager
    @EnvironmentObject private var recordingService: RecordingService
    @Environment(\ .managedObjectContext) private var viewContext
    
    var body: some View {
        HStack(spacing: 0) {
            mainContent
            sidebar
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var header: some View {
        HStack {
            HStack(spacing: 0) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    TabButton(
                        title: tab.title,
                        icon: tab.icon,
                        isSelected: coordinator.selectedTab == tab
                    ) {
                        coordinator.selectedTab = tab
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    private var content: some View {
        Group {
            switch coordinator.selectedTab {
            case .chat:
                ChatsListView()
            case .email:
                EmailListView()
            case .recorder:
                RecordingsListView(
                    context: viewContext,
                    recordingService: recordingService,
                    hideRecordButton: true
                )
            case .calendar:
                NewCalendarView(calendarManager: calendarManager)
            case .profile:
                ProfiloWrapperView()
                    .padding(.top, 16)
            }
        }
    }
    
    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Registrazione")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                StatusIndicator(service: recordingService)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.separator)),
                alignment: .bottom
            )
            
            AudioRecorderView(recordingService: recordingService)
                .padding()
        }
        .frame(width: 320)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color(.separator)),
            alignment: .leading
        )
    }
}

// MARK: - Supporting Views
struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .blue : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StatusIndicator: View {
    @ObservedObject var service: RecordingService
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(service.recordingState == .recording ? Color.red : Color.green)
                .frame(width: 8, height: 8)
            Text(service.recordingState == .recording ? "Registrando" : "Pronto")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Profilo Wrapper
struct ProfiloWrapperView: View {
    @Environment(\ .managedObjectContext) private var viewContext
    @State private var profilo: ProfiloUtente?
    
    var body: some View {
        Group {
            if let profilo = profilo {
                ProfiloView(profilo: profilo)
                    .transition(.opacity)
            } else {
                DSLoadingView(message: "Caricamento profilo...")
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: profilo != nil)
        .onAppear {
            loadProfile()
        }
    }
    
    private func loadProfile() {
        DispatchQueue.main.async {
            profilo = ProfiloUtenteService.shared.ottieniProfiloUtente(in: viewContext)
            if profilo == nil {
                profilo = ProfiloUtenteService.shared.creaProfiloDefault(in: viewContext)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\ .managedObjectContext, PersistenceController.preview.container.viewContext)
}
