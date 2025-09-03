//
//  AIEventCreationView.swift
//  Marilena
//
//  Created by AI Assistant
//  Copyright © 2024. All rights reserved.
//

import SwiftUI

struct AIEventCreationView: View {
    @ObservedObject var calendarManager: CalendarManager
    let suggestedStart: Date
    let suggestedEnd: Date
    
    @Environment(\.dismiss) private var dismiss
    @State private var prompt: String = ""
    @State private var isCreating: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("AI Event Creation")
                .font(.title2.bold())
                .foregroundColor(.purple)
            
            Text("Describe your event in natural language")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Examples:")
                    .font(.caption.bold())
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• \"Meeting with John tomorrow at 2pm\"")
                    Text("• \"Dentist appointment next Tuesday at 10am\"")
                    Text("• \"Weekly team standup every Monday at 9am\"")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
            
            TextField("e.g., Meeting with team tomorrow at 3pm", text: $prompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3, reservesSpace: true)
            
            Button(action: {
                createAIEvent()
            }) {
                HStack {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "brain.head.profile")
                    }
                    Text(isCreating ? "Creating..." : "Create Event with AI")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.purple)
                .cornerRadius(12)
            }
            .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
            
            Spacer()
        }
        .padding()
        .navigationTitle("AI Event")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
    
    private func createAIEvent() {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isCreating = true
        
        // TODO: Implement AI event parsing
        // For now, create a simple event based on the prompt
        Task {
            do {
                let request = CalendarEventRequest(
                    title: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: "Created with AI",
                    startDate: suggestedStart,
                    endDate: suggestedEnd,
                    location: nil,
                    isAllDay: false,
                    attendeeEmails: [],
                    calendarId: nil
                )
                
                _ = try await calendarManager.createEvent(request)
                
                await MainActor.run {
                    isCreating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    calendarManager.error = "Error creating AI event: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct AIEventCreationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AIEventCreationView(
                calendarManager: CalendarManager(),
                suggestedStart: Date(),
                suggestedEnd: Date().addingTimeInterval(3600)
            )
        }
    }
}