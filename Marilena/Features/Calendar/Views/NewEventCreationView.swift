//
//  NewEventCreationView.swift
//  Marilena
//
//  Created by AI Assistant
//  Copyright © 2024. All rights reserved.
//

import SwiftUI

/// Vista di creazione eventi con linguaggio naturale ispirata a Fantastical
public struct NewEventCreationView: View {
    @ObservedObject var calendarService: NewCalendarService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var title = ""
    @State private var naturalLanguageText = ""
    @State private var selectedDate = Date()
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    @State private var location = ""
    @State private var notes = ""
    @State private var selectedCalendarIndex = 0
    @State private var isAllDay = false
    @State private var showAdvancedOptions = false
    @State private var isCreating = false
    @State private var parsingTask: Task<Void, Never>? = nil

    private let calendar = Calendar.current

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Sezione linguaggio naturale (Fantastical-style)
                    naturalLanguageSection

                    // Anteprima evento intelligente
                    if !naturalLanguageText.isEmpty {
                        eventPreviewSection
                    }

                    // Opzioni avanzate
                    if showAdvancedOptions {
                        advancedOptionsSection
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createEvent) {
                        if isCreating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Create")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(title.isEmpty || isCreating)
                    .foregroundColor(title.isEmpty ? .secondary : .blue)
                }
            }
            .background(
                (colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
                    .edgesIgnoringSafeArea(.all)
            )
            .onDisappear {
                parsingTask?.cancel()
            }
        }
    }

    // MARK: - Natural Language Section
    private var naturalLanguageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What would you like to schedule?")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            // Campo di testo principale
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color.white)
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(naturalLanguageText.isEmpty ? 0.3 : 0.6), lineWidth: 2)
                    )

                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $naturalLanguageText)
                        .font(.system(size: 16))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(height: 100)
                        .onChange(of: naturalLanguageText) { newValue in
                            scheduleParsing(for: newValue)
                        }

                    if naturalLanguageText.isEmpty {
                        Text("Try: 'Meeting with John tomorrow at 3pm for 1 hour'")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }
                }
            }

            // Suggerimenti rapidi
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    QuickSuggestionButton(text: "Meeting tomorrow 10am", action: { naturalLanguageText = "Meeting tomorrow 10am" })
                    QuickSuggestionButton(text: "Lunch with Sarah today 12pm", action: { naturalLanguageText = "Lunch with Sarah today 12pm" })
                    QuickSuggestionButton(text: "Call mom this evening", action: { naturalLanguageText = "Call mom this evening" })
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Event Preview Section
    private var eventPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Event Preview")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(calendarService.calendars[selectedCalendarIndex].uiColor)
                        .frame(width: 12, height: 12)

                    Text(title.isEmpty ? "Untitled Event" : title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                }

                HStack(spacing: 16) {
                    Label {
                        Text(formattedDateTime)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                    }

                    if !location.isEmpty {
                        Label {
                            Text(location)
                                .foregroundColor(.secondary)
                        } icon: {
                            Image(systemName: "location")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .font(.system(size: 14))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color.white)
            )

            Button(action: { showAdvancedOptions.toggle() }) {
                HStack {
                    Text(showAdvancedOptions ? "Hide Details" : "Edit Details")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)

                    Spacer()

                    Image(systemName: showAdvancedOptions ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }
        }
    }

    // MARK: - Advanced Options Section
    private var advancedOptionsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Titolo
            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.system(size: 16, weight: .semibold))

                TextField("Event title", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 16))
            }

            // Data e ora
            VStack(alignment: .leading, spacing: 8) {
                Text("Date & Time")
                    .font(.system(size: 16, weight: .semibold))

                Toggle("All day", isOn: $isAllDay)
                    .font(.system(size: 16))

                if !isAllDay {
                    DatePicker("Start", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                        .font(.system(size: 16))

                    DatePicker("End", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                        .font(.system(size: 16))
                } else {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: [.date])
                        .font(.system(size: 16))
                }
            }

            // Location
            VStack(alignment: .leading, spacing: 8) {
                Text("Location")
                    .font(.system(size: 16, weight: .semibold))

                TextField("Add location", text: $location)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 16))
            }

            // Calendario
            VStack(alignment: .leading, spacing: 8) {
                Text("Calendar")
                    .font(.system(size: 16, weight: .semibold))

                Picker("Calendar", selection: $selectedCalendarIndex) {
                    ForEach(calendarService.calendars.indices, id: \.self) { index in
                        HStack {
                            Circle()
                                .fill(calendarService.calendars[index].uiColor)
                                .frame(width: 12, height: 12)

                            Text(calendarService.calendars[index].title)
                        }
                        .tag(index)
                    }
                }
                .pickerStyle(.menu)
            }

            // Note
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.system(size: 16, weight: .semibold))

                TextEditor(text: $notes)
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                    .font(.system(size: 16))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.systemGray5) : Color.white)
        )
    }

    // MARK: - Helper Methods

    private func scheduleParsing(for text: String) {
        parsingTask?.cancel()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            parsingTask = nil
            Task { @MainActor in resetForm() }
            return
        }

        parsingTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            let suggestion = await calendarService.suggestedEvent(from: text)
            guard !Task.isCancelled else { return }
            if let suggestion {
                await MainActor.run { applySuggestion(suggestion) }
            }
        }
    }

    @MainActor
    private func applySuggestion(_ event: NewCalendarEvent) {
        title = event.title
        notes = event.notes ?? ""
        location = event.location ?? ""
        isAllDay = event.isAllDay
        startTime = event.startDate
        endTime = event.endDate
        selectedDate = event.startDate

        if let calendarId = event.calendarId,
           let index = calendarService.calendars.firstIndex(where: { $0.id == calendarId }) {
            selectedCalendarIndex = index
        }
    }

    @MainActor
    private func resetForm() {
        title = ""
        notes = ""
        location = ""
        isAllDay = false
        let now = Date()
        selectedDate = now
        startTime = now
        endTime = now.addingTimeInterval(3600)
    }

    private var formattedDateTime: String {
        let formatter = DateFormatter()
        if isAllDay {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: selectedDate)
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let start = formatter.string(from: startTime)
            let end = formatter.string(from: endTime)
            return "\(start) - \(end)"
        }
    }

    private func createEvent() {
        guard !title.isEmpty else { return }

        isCreating = true

        Task {
            do {
                let event = NewCalendarEvent(
                    title: title,
                    notes: notes.isEmpty ? nil : notes,
                    startDate: isAllDay ? calendar.startOfDay(for: selectedDate) : startTime,
                    endDate: isAllDay ? calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: selectedDate))! : endTime,
                    isAllDay: isAllDay,
                    location: location.isEmpty ? nil : location,
                    calendarId: calendarService.calendars[selectedCalendarIndex].id,
                    color: calendarService.calendars[selectedCalendarIndex].uiColor
                )

                try await calendarService.createEvent(event)
                dismiss()
            } catch {
                print("Error creating event: \(error)")
                isCreating = false
            }
        }
    }
}

// MARK: - Quick Suggestion Button
private struct QuickSuggestionButton: View {
    let text: String
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.blue.opacity(0.1))
                )
        }
    }
}

// MARK: - Preview
struct NewEventCreationView_Previews: PreviewProvider {
    static var previews: some View {
        let service = NewCalendarService(calendarManager: CalendarManager())
        NewEventCreationView(calendarService: service)
    }
}

