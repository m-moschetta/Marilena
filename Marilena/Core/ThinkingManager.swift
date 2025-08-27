import Foundation
import SwiftUI
import Combine

// MARK: - Thinking Response Models

public struct ThinkingResponse {
    public let thinking: String?
    public let finalAnswer: String
    public let model: String
    public let isReasoningModel: Bool
    
    public init(thinking: String? = nil, finalAnswer: String, model: String, isReasoningModel: Bool = false) {
        self.thinking = thinking
        self.finalAnswer = finalAnswer
        self.model = model
        self.isReasoningModel = isReasoningModel
    }
}

// MARK: - Thinking Manager

@MainActor
public class ThinkingManager: ObservableObject {
    public static let shared = ThinkingManager()
    
    @Published public var showThinkingByDefault: Bool = false
    @Published public var showThinkingSteps: [String: Bool] = [:]
    
    private init() {
        // Load settings
        showThinkingByDefault = UserDefaults.standard.bool(forKey: "showThinkingByDefault")
    }
    
    // MARK: - Settings
    
    public func toggleDefaultThinkingVisibility() {
        showThinkingByDefault.toggle()
        UserDefaults.standard.set(showThinkingByDefault, forKey: "showThinkingByDefault")
    }
    
    public func setThinkingVisibility(for messageId: String, visible: Bool) {
        showThinkingSteps[messageId] = visible
    }
    
    public func isThinkingVisible(for messageId: String) -> Bool {
        return showThinkingSteps[messageId] ?? showThinkingByDefault
    }
    
    // MARK: - Model Detection
    
    public func isReasoningModel(_ model: String) -> Bool {
        let reasoningModels = [
            // Anthropic reasoning models
            "claude-opus-4-20250514",
            "claude-sonnet-4-20250514", 
            "claude-3-7-sonnet-20250219",
            
            // OpenAI reasoning models
            "o1", "o1-preview", "o1-mini", "o3", "o3-mini", "o3-pro",
            
            // Groq reasoning models (DeepSeek R1 Distill)
            "deepseek-r1-distill-llama-70b",
            "deepseek-r1-distill-qwen-32b",
            "deepseek-r1-distill-qwen-14b",
            "deepseek-r1-distill-qwen-1.5b"
        ]
        
        return reasoningModels.contains(model)
    }
    
    // MARK: - Response Parsing
    
    public func parseResponse(_ content: String, model: String) -> ThinkingResponse {
        let isReasoning = isReasoningModel(model)
        
        if isReasoning {
            // Parse thinking from reasoning models
            return parseReasoningResponse(content, model: model)
        } else {
            // Non-reasoning models return only final answer
            return ThinkingResponse(finalAnswer: content, model: model, isReasoningModel: false)
        }
    }
    
    private func parseReasoningResponse(_ content: String, model: String) -> ThinkingResponse {
        // DeepSeek R1 models use <think> tags
        if model.contains("deepseek-r1") {
            return parseDeepSeekThinking(content, model: model)
        }
        
        // Claude 4 and 3.7 with extended thinking
        if model.contains("claude-4") || model.contains("claude-3-7") {
            return parseClaudeThinking(content, model: model)
        }
        
        // OpenAI o1/o3 models have internal reasoning
        if model.contains("o1") || model.contains("o3") {
            return parseOpenAIThinking(content, model: model)
        }
        
        // Fallback - treat as regular response
        return ThinkingResponse(finalAnswer: content, model: model, isReasoningModel: true)
    }
    
    private func parseDeepSeekThinking(_ content: String, model: String) -> ThinkingResponse {
        // DeepSeek R1 format: <think>...</think> followed by final answer
        let thinkPattern = #"<think>(.*?)</think>"#
        
        if let regex = try? NSRegularExpression(pattern: thinkPattern, options: [.dotMatchesLineSeparators]),
           let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)) {
            
            let thinkingRange = Range(match.range(at: 1), in: content)!
            let thinking = String(content[thinkingRange])
            
            // Remove thinking tags from final answer
            let finalAnswer = content.replacingOccurrences(of: regex.pattern, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            return ThinkingResponse(
                thinking: thinking.trimmingCharacters(in: .whitespacesAndNewlines),
                finalAnswer: finalAnswer,
                model: model,
                isReasoningModel: true
            )
        }
        
        // No thinking tags found, treat as regular response
        return ThinkingResponse(finalAnswer: content, model: model, isReasoningModel: true)
    }
    
    private func parseClaudeThinking(_ content: String, model: String) -> ThinkingResponse {
        // Claude format may have explicit thinking sections
        // For now, treat as regular response unless specific format is detected
        return ThinkingResponse(finalAnswer: content, model: model, isReasoningModel: true)
    }
    
    private func parseOpenAIThinking(_ content: String, model: String) -> ThinkingResponse {
        // OpenAI o1/o3 models don't expose thinking tokens currently
        return ThinkingResponse(finalAnswer: content, model: model, isReasoningModel: true)
    }
}

// MARK: - Thinking Display Component

public struct ThinkingView: View {
    let thinking: String
    let model: String
    @State private var isExpanded: Bool = false
    
    public init(thinking: String, model: String, isExpanded: Bool = false) {
        self.thinking = thinking
        self.model = model
        self._isExpanded = State(initialValue: isExpanded)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with toggle
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.orange)
                    
                    Text("Processo di ragionamento")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            // Thinking content (collapsible)
            if isExpanded {
                ScrollView {
                    Text(thinking)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 200)
                
                // Model info
                HStack {
                    Image(systemName: "cpu")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text(model)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Reasoning Model")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .onAppear {
            // Respect user's default setting
            isExpanded = ThinkingManager.shared.showThinkingByDefault
        }
    }
}

// MARK: - Settings Extension

extension ThinkingManager {
    public func getSettingsView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reasoning & Thinking")
                .font(.headline)
            
            Toggle("Mostra ragionamento di default", isOn: Binding(
                get: { ThinkingManager.shared.showThinkingByDefault },
                set: { ThinkingManager.shared.showThinkingByDefault = $0 }
            ))
            .onChange(of: ThinkingManager.shared.showThinkingByDefault) { oldValue, newValue in
                UserDefaults.standard.set(newValue, forKey: "showThinkingByDefault")
            }
            
            Text("I modelli di reasoning (Claude 4, DeepSeek R1, o1/o3) mostrano il loro processo di pensiero. Puoi scegliere se visualizzarlo automaticamente o mostrarlo solo su richiesta.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}