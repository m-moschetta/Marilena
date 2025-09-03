//
//  NewCalendarDemoView.swift
//  Demo view for the new Fantastical-style calendar
//

import SwiftUI

struct NewCalendarDemoView: View {
    var body: some View {
        VStack {
            Text("🎉 Nuovo Calendario Fantastical-Style 🎉")
                .font(.title)
                .fontWeight(.bold)
                .padding()

            Text("Caratteristiche implementate:")
                .font(.headline)
                .padding(.top)

            VStack(alignment: .leading, spacing: 10) {
                FeatureRow(icon: "📅", text: "Vista mensile con punti colorati")
                FeatureRow(icon: "📊", text: "Vista settimanale elegante")
                FeatureRow(icon: "📋", text: "Vista giornaliera dettagliata")
                FeatureRow(icon: "📝", text: "Vista agenda intelligente")
                FeatureRow(icon: "🎤", text: "Creazione eventi con linguaggio naturale")
                FeatureRow(icon: "🎨", text: "Design moderno e animazioni fluide")
                FeatureRow(icon: "🌙", text: "Supporto temi scuri/chiari")
                FeatureRow(icon: "🔄", text: "Integrazione con servizi calendario")
            }
            .padding()

            Spacer()

            Text("Il nuovo calendario è pronto per sostituire quello attuale!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack {
            Text(icon)
                .font(.title2)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}

#Preview {
    NewCalendarDemoView()
}
