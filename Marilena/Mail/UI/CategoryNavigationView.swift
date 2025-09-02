//
//  CategoryNavigationView.swift
//  Marilena
//
//  Created by Marilena on 2024
//
//  View per la navigazione tra categorie email con conteggi non letti
//

import SwiftUI

/// View per la navigazione tra categorie
public struct CategoryNavigationView: View {
    public let categories: [MailCategory]
    @Binding public var selectedCategory: MailCategory?
    public let unreadCounts: [MailCategory: Int]

    public var body: some View {
        List(categories, id: \.self, selection: $selectedCategory) { category in
            CategoryRow(
                category: category,
                unreadCount: unreadCounts[category] ?? 0,
                isSelected: selectedCategory == category
            )
        }
        .listStyle(.sidebar)
        .navigationTitle("Posta")
    }
}

/// Riga singola per categoria
private struct CategoryRow: View {
    let category: MailCategory
    let unreadCount: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icona categoria
            Image(systemName: category.iconName)
                .font(.system(size: 16))
                .foregroundColor(category.color)
                .frame(width: 24, height: 24)

            // Nome categoria
            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)

                // Conteggio non letti (solo se > 0)
                if unreadCount > 0 {
                    Text("\(unreadCount) non letti")
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }

            Spacer()

            // Indicatore non letti
            if unreadCount > 0 {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? category.color : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

/// Preview per la navigazione categorie
struct CategoryNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CategoryNavigationView(
                categories: MailCategory.allCases,
                selectedCategory: .constant(.inbox),
                unreadCounts: [
                    .inbox: 5,
                    .important: 2,
                    .work: 8,
                    .marketing: 0
                ]
            )
        }
        .previewLayout(.fixed(width: 280, height: 600))
    }
}
