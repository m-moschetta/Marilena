//
//  NavigationCoordinator.swift
//  Marilena
//
//  Coordinatore di navigazione centralizzato
//

import SwiftUI
import Combine

/// Tab principali dell'app
enum AppTab: Int, CaseIterable {
    case chat = 0
    case email = 1
    case recorder = 2
    case calendar = 3
    case profile = 4
    
    var icon: String {
        switch self {
        case .chat: return "message.fill"
        case .email: return "envelope.fill"
        case .recorder: return "mic.fill"
        case .calendar: return "calendar"
        case .profile: return "person.fill"
        }
    }
    
    var title: String {
        switch self {
        case .chat: return "Chat AI"
        case .email: return "Email"
        case .recorder: return "Registratore"
        case .calendar: return "Calendario"
        case .profile: return "Profilo"
        }
    }
}

/// Coordinatore di navigazione globale
@MainActor
class NavigationCoordinator: ObservableObject {
    @Published var selectedTab: AppTab = .email
    
    func navigate(to tab: AppTab) {
        selectedTab = tab
    }
    
    func selectCalendar() {
        selectedTab = .calendar
    }
    
    func selectEmail() {
        selectedTab = .email
    }
    
    func selectChat() {
        selectedTab = .chat
    }
}
