//
//  NewCalendarView.swift
//  Marilena
//
//  Created by AI Assistant
//  Copyright © 2024. All rights reserved.
//

import SwiftUI

/// Vista principale del nuovo calendario ispirato a Fantastical
public struct NewCalendarView: View {
    @StateObject private var calendarService: NewCalendarService
    @State private var showingEventCreation = false
    @State private var searchText = ""

    @Environment(\.colorScheme) private var colorScheme

    // Inizializzazione con dependency injection
    public init(calendarManager: CalendarManager) {
        _calendarService = StateObject(wrappedValue: NewCalendarService(calendarManager: calendarManager))
    }

    public var body: some View {
        ZStack {
            // Background color based on theme
            (colorScheme == .dark ? Color.black : Color(.systemGray6))
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Header elegante come Fantastical
                headerView

                // View Mode Selector
                viewModeSelector

                // Main Content Area
                mainContentView
            }
        }
        .sheet(isPresented: $showingEventCreation) {
            NavigationView {
                CreateEventView(calendarManager: calendarService.calendarManager)
            }
        }
        .onAppear {
            Task {
                await calendarService.loadEvents()
            }
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                // Titolo del periodo corrente
                Text(calendarService.monthTitle(for: calendarService.selectedDate))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                // Pulsanti di navigazione compatti
                HStack(spacing: 8) {
                    Button(action: {
                        calendarService.navigateToPreviousPeriod()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                    }

                    Button(action: {
                        calendarService.navigateToToday()
                    }) {
                        Text("Today")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }

                    Button(action: {
                        calendarService.navigateToNextPeriod()
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                    }

                    // Pulsante AI per creazione evento AI
                    Button(action: {
                        // TODO: Implement AI event creation
                        showingEventCreation = true
                    }) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.purple)
                            .clipShape(Circle())
                    }
                    
                    // Pulsante + per creazione evento classica
                    Button(action: {
                        showingEventCreation = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 2)
            .padding(.bottom, 2)

            // Search bar rimossa per ottimizzare spazio
        }
        .background(
            (colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }



    // MARK: - View Mode Selector
    private var viewModeSelector: some View {
        HStack(spacing: 0) {
            ForEach([NewCalendarViewMode.month, .week, .day, .agenda], id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        calendarService.viewMode = mode
                    }
                }) {
                    Text(mode.title)
                        .font(.system(size: 14, weight: calendarService.viewMode == mode ? .semibold : .regular))
                        .foregroundColor(calendarService.viewMode == mode ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
        }
        .background(Color(.systemGray5).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - Main Content View
    private var mainContentView: some View {
        ZStack {
            switch calendarService.viewMode {
            case .month:
                NewMonthView(calendarService: calendarService)
                    .transition(.opacity)
            case .week:
                NewWeekView(calendarService: calendarService)
                    .transition(.opacity)
            case .day:
                NewDayView(calendarService: calendarService)
                    .transition(.opacity)
            case .agenda:
                NewAgendaView(calendarService: calendarService)
                    .transition(.opacity)
            case .year:
                // Implementazione futura
                Text("Year view - Coming Soon")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: calendarService.viewMode)
    }




}

// MARK: - Preview
struct NewCalendarView_Previews: PreviewProvider {
    static var previews: some View {
        NewCalendarView(calendarManager: CalendarManager())
    }
}
