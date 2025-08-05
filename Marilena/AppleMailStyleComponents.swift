import SwiftUI
import Foundation

// MARK: - iOS 26 Liquid Glass Components
// Componenti modernizzati per iOS 26 con Liquid Glass design system

// MARK: - Apple Mail Style Header with Liquid Glass
struct AppleMailStyleHeader: View {
    let email: EmailMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Avatar e info mittente - Liquid Glass style
            HStack(alignment: .top, spacing: 12) {
                // Avatar con gradient iOS 26
                Circle()
                    .fill(.blue)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(email.from.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundStyle(.white)
                    )
                    .liquidGlass(.prominent)
                
                VStack(alignment: .leading, spacing: 2) {
                    // From
                    Text(email.from)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    // To
                    HStack(spacing: 4) {
                        Text("A:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(email.to.first ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Data
                Text(formatDate(email.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Subject
            Text(email.subject)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .padding(.top, 8)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
        } else {
            formatter.dateStyle = .medium
        }
        
        return formatter.string(from: date)
    }
}

// MARK: - Apple Mail Style Toolbar with SF Symbols 7
struct AppleMailStyleToolbar: View {
    let email: EmailMessage
    let onReply: () -> Void
    let onForward: () -> Void
    let onDelete: () -> Void
    let onMore: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Reply - SF Symbols 7 with gradient
            ToolbarButton(
                icon: "arrowshape.turn.up.left",
                action: onReply,
                gradient: .blue
            )
            
            Spacer()
            
            // Forward - SF Symbols 7 with gradient
            ToolbarButton(
                icon: "arrowshape.turn.up.right",
                action: onForward,
                gradient: .indigo
            )
            
            Spacer()
            
            // Trash - SF Symbols 7 with gradient
            ToolbarButton(
                icon: "trash",
                action: onDelete,
                gradient: .red
            )
            
            Spacer()
            
            // More - SF Symbols 7 with gradient
            ToolbarButton(
                icon: "ellipsis.circle",
                action: onMore,
                gradient: .gray
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .liquidGlass(.prominent)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.separator, lineWidth: 0.5)
        )
    }
}

// MARK: - Enhanced Toolbar Button with SF Symbols 7
private struct ToolbarButton: View {
    let icon: String
    let action: () -> Void
    let gradient: Color
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Haptic feedback iOS 26
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(gradient)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.bounce, value: isPressed)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            isPressed.toggle()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }
    }
}

// MARK: - AI Response Section (iOS 26 Style)
struct AppleMailAISection: View {
    let analysis: EmailAnalysis?
    let summary: String?
    @Binding var showingAI: Bool
    let onGenerateResponse: (ResponseType) -> Void
    @State private var showingFullSummary = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // AI Toggle Button - Liquid Glass
            Button(action: { 
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showingAI.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .symbolRenderingMode(.multicolor)
                        .symbolEffect(.variableColor, value: showingAI)
                    
                    Text("Assistente AI")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: showingAI ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .symbolEffect(.bounce, value: showingAI)
                            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            
            if showingAI {
                VStack(alignment: .leading, spacing: 16) {
                    // Quick Actions - iOS 26 style
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Risposte Rapide")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        
                        HStack(spacing: 8) {
                            QuickResponseButton(
                                title: "Accetta",
                                icon: "checkmark.circle.fill",
                                gradient: .green,
                                action: { onGenerateResponse(.yes) }
                            )
                            
                            QuickResponseButton(
                                title: "Rifiuta",
                                icon: "xmark.circle.fill",
                                gradient: .red,
                                action: { onGenerateResponse(.no) }
                            )
                            
                            QuickResponseButton(
                                title: "Personalizza",
                                icon: "square.and.pencil",
                                gradient: .blue,
                                action: { onGenerateResponse(.custom) }
                            )
                        }
                    }
                    
                    // Summary if available - Liquid Glass with expandable
                    if let summary = summary, !summary.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Riassunto")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showingFullSummary.toggle()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Text(showingFullSummary ? "Comprimi" : "Leggi tutto")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                        
                                        Image(systemName: showingFullSummary ? "chevron.up" : "chevron.down")
                                            .font(.caption2)
                                            .foregroundStyle(.blue)
                                            .symbolEffect(.bounce, value: showingFullSummary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Text(summary)
                                .font(.callout)
                                .foregroundStyle(.primary)
                                .lineLimit(showingFullSummary ? nil : 3)
                                .padding()
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                                .animation(.easeInOut(duration: 0.3), value: showingFullSummary)
                        }
                    }
                    
                    // Analysis if available - iOS 26 style
                    if let analysis = analysis {
                        HStack(spacing: 16) {
                            // Category
                            Label(analysis.category.displayName, systemImage: analysis.category.icon)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: Capsule())
                            
                            // Urgency
                            Label(analysis.urgency.displayName, systemImage: analysis.urgency.icon)
                                .font(.caption)
                                .foregroundStyle(colorFromString(analysis.urgency.color))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(colorFromString(analysis.urgency.color).opacity(0.1), in: Capsule())
                        }
                    }
                }
                .padding()
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Enhanced Quick Response Button iOS 26
private struct QuickResponseButton: View {
    let title: String
    let icon: String
    let gradient: Color
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(gradient)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.bounce, value: isPressed)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(gradient.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            isPressed.toggle()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }
    }
}

// MARK: - Response Type
enum ResponseType {
    case yes
    case no
    case custom
}

// MARK: - iOS 26 Liquid Glass Extension
extension View {
    func liquidGlass(_ style: LiquidGlassStyle) -> some View {
        self.modifier(LiquidGlassModifier(style: style))
    }
}

// MARK: - Helper Functions
private func colorFromString(_ colorString: String) -> Color {
    switch colorString.lowercased() {
    case "red":
        return .red
    case "blue":
        return .blue
    case "green":
        return .green
    case "orange":
        return .orange
    case "yellow":
        return .yellow
    case "purple":
        return .purple
    case "pink":
        return .pink
    default:
        return .gray
    }
}

enum LiquidGlassStyle {
    case subtle
    case prominent
}

struct LiquidGlassModifier: ViewModifier {
    let style: LiquidGlassStyle
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            )
    }
} 