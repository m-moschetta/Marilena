//
//  CreateEventView.swift
//  Marilena
//
//  Vista per creare un nuovo evento
//

import SwiftUI

struct CreateEventView: View {
    let calendarManager: CalendarManager
    var suggestedStart: Date?
    var suggestedEnd: Date?
    
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    
    init(calendarManager: CalendarManager, suggestedStart: Date? = nil, suggestedEnd: Date? = nil) {
        self.calendarManager = calendarManager
        self.suggestedStart = suggestedStart
        self.suggestedEnd = suggestedEnd
        
        if let start = suggestedStart {
            _startDate = State(initialValue: start)
        }
        if let end = suggestedEnd {
            _endDate = State(initialValue: end)
        }
    }
    
    var body: some View {
        Form {
            Section("Dettagli Evento") {
                TextField("Titolo", text: $title)
                DatePicker("Inizio", selection: $startDate)
                DatePicker("Fine", selection: $endDate)
            }
        }
        .navigationTitle("Nuovo Evento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annulla") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Salva") { saveEvent() }
                    .disabled(title.isEmpty)
            }
        }
    }
    
    private func saveEvent() {
        // Implementazione base
        dismiss()
    }
}
