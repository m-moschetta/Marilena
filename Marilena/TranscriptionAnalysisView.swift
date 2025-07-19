import SwiftUI
internal import CoreData
import NaturalLanguage
import Charts

struct TranscriptionAnalysisView: View {
    let recording: RegistrazioneAudio
    
    @State private var analysisData: TranscriptionAnalysis?
    @State private var isLoading = true
    @State private var selectedMetric: AnalysisMetric = .wordCount
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if isLoading {
                    loadingView
                } else if let analysis = analysisData {
                    // Overview Cards
                    overviewCardsView(analysis)
                    
                    // Sentiment Analysis
                    sentimentAnalysisView(analysis)
                    
                    // Word Frequency
                    wordFrequencyView(analysis)
                    
                    // Language Statistics
                    languageStatsView(analysis)
                    
                    // Topic Distribution
                    topicAnalysisView(analysis)
                    
                    // Time Analysis
                    timeAnalysisView(analysis)
                } else {
                    emptyStateView
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            performAnalysis()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Analizzando trascrizione...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("Nessuna Analisi Disponibile")
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)
            
            Text("La registrazione deve avere almeno una trascrizione completata per poter essere analizzata.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Overview Cards
    
    private func overviewCardsView(_ analysis: TranscriptionAnalysis) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            AnalysisCard(
                title: "Parole Totali",
                value: "\(analysis.totalWords)",
                icon: "textformat.abc",
                color: .blue
            )
            
            AnalysisCard(
                title: "Frasi",
                value: "\(analysis.sentenceCount)",
                icon: "text.quote",
                color: .green
            )
            
            AnalysisCard(
                title: "Velocità Parlato",
                value: "\(analysis.wordsPerMinute) wpm",
                icon: "speedometer",
                color: .orange
            )
            
            AnalysisCard(
                title: "Complessità",
                value: analysis.complexityLevel,
                icon: "brain.head.profile",
                color: .purple
            )
        }
    }
    
    // MARK: - Sentiment Analysis
    
    private func sentimentAnalysisView(_ analysis: TranscriptionAnalysis) -> some View {
        AnalysisSection(title: "Analisi del Sentiment", icon: "heart.circle") {
            VStack(spacing: 16) {
                // Sentiment Score Gauge
                VStack {
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 8)
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .trim(from: 0, to: sentimentProgress(analysis.sentimentScore))
                            .stroke(sentimentColor(analysis.sentimentScore), lineWidth: 8)
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                        
                        VStack {
                            Text(String(format: "%.2f", analysis.sentimentScore))
                                .font(.title.weight(.bold))
                                .foregroundColor(.primary)
                            
                            Text(sentimentLabel(analysis.sentimentScore))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Negativo")
                            .font(.caption)
                            .foregroundColor(.red)
                        
                        Spacer()
                        
                        Text("Neutro")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text("Positivo")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.top, 8)
                }
                
                // Sentiment Distribution
                if !analysis.sentimentBySegment.isEmpty {
                    Chart {
                        ForEach(Array(analysis.sentimentBySegment.enumerated()), id: \.offset) { index, sentiment in
                            LineMark(
                                x: .value("Segmento", index),
                                y: .value("Sentiment", sentiment)
                            )
                            .foregroundStyle(Color.blue)
                        }
                    }
                    .frame(height: 100)
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                Text("\(value.as(Double.self) ?? 0, specifier: "%.1f")")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Word Frequency
    
    private func wordFrequencyView(_ analysis: TranscriptionAnalysis) -> some View {
        AnalysisSection(title: "Parole Più Frequenti", icon: "textformat.size") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(Array(analysis.topWords.prefix(10).enumerated()), id: \.offset) { index, wordData in
                    WordFrequencyCard(
                        word: wordData.word,
                        count: wordData.count,
                        rank: index + 1
                    )
                }
            }
        }
    }
    
    // MARK: - Language Stats
    
    private func languageStatsView(_ analysis: TranscriptionAnalysis) -> some View {
        AnalysisSection(title: "Statistiche Linguistiche", icon: "globe.europe.africa") {
            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    StatItem(
                        title: "Parole Uniche",
                        value: "\(analysis.uniqueWords)",
                        subtitle: "Varietà lessicale"
                    )
                    
                    StatItem(
                        title: "Lunghezza Media",
                        value: String(format: "%.1f", analysis.averageWordLength),
                        subtitle: "Caratteri per parola"
                    )
                }
                
                HStack(spacing: 20) {
                    StatItem(
                        title: "Frasi Lunghe",
                        value: "\(analysis.longSentences)",
                        subtitle: ">20 parole"
                    )
                    
                    StatItem(
                        title: "Densità Lessicale",
                        value: "\(Int(analysis.lexicalDensity * 100))%",
                        subtitle: "Contenuto vs funzione"
                    )
                }
            }
        }
    }
    
    // MARK: - Topic Analysis
    
    private func topicAnalysisView(_ analysis: TranscriptionAnalysis) -> some View {
        AnalysisSection(title: "Argomenti Principali", icon: "tag.circle") {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(analysis.topics, id: \.name) { topic in
                    TopicRow(topic: topic)
                }
            }
        }
    }
    
    // MARK: - Time Analysis
    
    private func timeAnalysisView(_ analysis: TranscriptionAnalysis) -> some View {
        AnalysisSection(title: "Analisi Temporale", icon: "clock.circle") {
            VStack(spacing: 16) {
                if !analysis.activityByTime.isEmpty {
                    Chart {
                        ForEach(Array(analysis.activityByTime.enumerated()), id: \.offset) { index, activity in
                            BarMark(
                                x: .value("Tempo", index),
                                y: .value("Attività", activity)
                            )
                            .foregroundStyle(Color.blue.gradient)
                        }
                    }
                    .frame(height: 120)
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                Text("\(value.as(Int.self) ?? 0)min")
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                HStack(spacing: 20) {
                    StatItem(
                        title: "Pause Lunghe",
                        value: "\(analysis.longPauses)",
                        subtitle: ">3 secondi"
                    )
                    
                    StatItem(
                        title: "Ritmo Costante",
                        value: "\(Int(analysis.speechConsistency * 100))%",
                        subtitle: "Uniformità velocità"
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func performAnalysis() {
        Task {
            let analysis = await analyzeTranscription()
            
            await MainActor.run {
                self.analysisData = analysis
                self.isLoading = false
            }
        }
    }
    
    private func analyzeTranscription() async -> TranscriptionAnalysis? {
        guard let transcriptions = recording.trascrizioni?.allObjects as? [Trascrizione],
              let transcription = transcriptions.first,
              let text = transcription.testoCompleto,
              !text.isEmpty else {
            return nil
        }
        
        // Inizializza analyzer NaturalLanguage
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .sentimentScore, .nameType])
        tagger.string = text
        
        let sentimentTagger = NLTagger(tagSchemes: [.sentimentScore])
        sentimentTagger.string = text
        
        var analysis = TranscriptionAnalysis()
        
        // Analisi base
        analysis.totalWords = countWords(in: text)
        analysis.sentenceCount = countSentences(in: text)
        analysis.uniqueWords = countUniqueWords(in: text)
        analysis.averageWordLength = calculateAverageWordLength(in: text)
        
        // Calcolo velocità
        if recording.durata > 0 {
            analysis.wordsPerMinute = Int(Double(analysis.totalWords) / (recording.durata / 60))
        }
        
        // Sentiment analysis
        let (sentimentTag, _) = sentimentTagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        analysis.sentimentScore = Double(sentimentTag?.rawValue ?? "0") ?? 0.0
        
        // Sentiment per segmenti
        analysis.sentimentBySegment = analyzeSentimentBySegments(text)
        
        // Analisi parole frequenti
        analysis.topWords = extractTopWords(from: text)
        
        // Analisi complessità
        analysis.complexityLevel = calculateComplexity(text)
        analysis.lexicalDensity = calculateLexicalDensity(text)
        analysis.longSentences = countLongSentences(in: text)
        
        // Analisi topics
        analysis.topics = extractTopics(from: text)
        
        // Analisi temporale
        analysis.activityByTime = analyzeActivityByTime(transcription)
        analysis.longPauses = countLongPauses(transcription)
        analysis.speechConsistency = calculateSpeechConsistency(transcription)
        
        return analysis
    }
    
    // MARK: - Analysis Helper Functions
    
    private func countWords(in text: String) -> Int {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        
        var wordCount = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { _, _ in
            wordCount += 1
            return true
        }
        return wordCount
    }
    
    private func countSentences(in text: String) -> Int {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        
        var sentenceCount = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { _, _ in
            sentenceCount += 1
            return true
        }
        return sentenceCount
    }
    
    private func countUniqueWords(in text: String) -> Int {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 2 }
        return Set(words).count
    }
    
    private func calculateAverageWordLength(in text: String) -> Double {
        let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return 0 }
        
        let totalLength = words.reduce(0) { $0 + $1.count }
        return Double(totalLength) / Double(words.count)
    }
    
    private func analyzeSentimentBySegments(_ text: String) -> [Double] {
        let sentences = text.components(separatedBy: ".")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        let sentimentTagger = NLTagger(tagSchemes: [.sentimentScore])
        var sentiments: [Double] = []
        
        for sentence in sentences.prefix(20) { // Limite per performance
            sentimentTagger.string = sentence
            let (tag, _) = sentimentTagger.tag(at: sentence.startIndex, unit: .paragraph, scheme: .sentimentScore)
            let sentiment = Double(tag?.rawValue ?? "0") ?? 0.0
            sentiments.append(sentiment)
        }
        
        return sentiments
    }
    
    private func extractTopWords(from text: String) -> [WordFrequency] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        var wordCounts: [String: Int] = [:]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            let word = String(text[tokenRange]).lowercased()
            
            if let tag = tag, (tag == .noun || tag == .verb || tag == .adjective),
               word.count > 3 {
                wordCounts[word, default: 0] += 1
            }
            
            return true
        }
        
        return wordCounts
            .sorted { $0.value > $1.value }
            .prefix(20)
            .map { WordFrequency(word: $0.key, count: $0.value) }
    }
    
    private func calculateComplexity(_ text: String) -> String {
        let averageWordsPerSentence = Double(countWords(in: text)) / Double(countSentences(in: text))
        
        if averageWordsPerSentence < 10 {
            return "Semplice"
        } else if averageWordsPerSentence < 20 {
            return "Medio"
        } else {
            return "Complesso"
        }
    }
    
    private func calculateLexicalDensity(_ text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        var contentWords = 0
        var totalWords = 0
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, _ in
            totalWords += 1
            
            if let tag = tag, [.noun, .verb, .adjective, .adverb].contains(tag) {
                contentWords += 1
            }
            
            return true
        }
        
        guard totalWords > 0 else { return 0 }
        return Double(contentWords) / Double(totalWords)
    }
    
    private func countLongSentences(in text: String) -> Int {
        let sentences = text.components(separatedBy: ".")
        return sentences.filter { $0.split(separator: " ").count > 20 }.count
    }
    
    private func extractTopics(from text: String) -> [Topic] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        var topicWords: [String: Int] = [:]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            let word = String(text[tokenRange]).lowercased()
            
            if let tag = tag, tag == .noun && word.count > 4 {
                topicWords[word, default: 0] += 1
            }
            
            return true
        }
        
        return topicWords
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { Topic(name: $0.key.capitalized, relevance: min(Double($0.value) / 10.0, 1.0)) }
    }
    
    private func analyzeActivityByTime(_ transcription: Trascrizione) -> [Double] {
        // Simulazione analisi temporale basata sulla durata
        let duration = recording.durata
        let segments = Int(duration / 60) + 1 // Un segmento per minuto
        
        return (0..<segments).map { _ in Double.random(in: 0.3...1.0) }
    }
    
    private func countLongPauses(_ transcription: Trascrizione) -> Int {
        // Simulazione conteggio pause lunghe
        return Int.random(in: 2...8)
    }
    
    private func calculateSpeechConsistency(_ transcription: Trascrizione) -> Double {
        // Simulazione calcolo consistenza
        return Double.random(in: 0.6...0.9)
    }
    
    // MARK: - Sentiment Helper Methods
    
    private func sentimentProgress(_ score: Double) -> CGFloat {
        return CGFloat((score + 1) / 2) // Converte da [-1,1] a [0,1]
    }
    
    private func sentimentColor(_ score: Double) -> Color {
        if score > 0.3 {
            return .green
        } else if score < -0.3 {
            return .red
        } else {
            return .orange
        }
    }
    
    private func sentimentLabel(_ score: Double) -> String {
        if score > 0.3 {
            return "Positivo"
        } else if score < -0.3 {
            return "Negativo"
        } else {
            return "Neutro"
        }
    }
}

// MARK: - Supporting Views

struct AnalysisSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct AnalysisCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title.weight(.bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

struct WordFrequencyCard: View {
    let word: String
    let count: Int
    let rank: Int
    
    var body: some View {
        HStack {
            Text("\(rank)")
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(word.capitalized)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Text("\(count) volte")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TopicRow: View {
    let topic: Topic
    
    var body: some View {
        HStack {
            Text(topic.name)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            ProgressView(value: topic.relevance)
                .frame(width: 60)
            
            Text("\(Int(topic.relevance * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 30)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Data Models

struct TranscriptionAnalysis {
    var totalWords: Int = 0
    var sentenceCount: Int = 0
    var uniqueWords: Int = 0
    var averageWordLength: Double = 0
    var wordsPerMinute: Int = 0
    var sentimentScore: Double = 0
    var sentimentBySegment: [Double] = []
    var topWords: [WordFrequency] = []
    var complexityLevel: String = ""
    var lexicalDensity: Double = 0
    var longSentences: Int = 0
    var topics: [Topic] = []
    var activityByTime: [Double] = []
    var longPauses: Int = 0
    var speechConsistency: Double = 0
}

struct WordFrequency {
    let word: String
    let count: Int
}

struct Topic {
    let name: String
    let relevance: Double
}

enum AnalysisMetric: CaseIterable {
    case wordCount
    case sentiment
    case complexity
    case topics
    
    var title: String {
        switch self {
        case .wordCount: return "Conteggio Parole"
        case .sentiment: return "Sentiment"
        case .complexity: return "Complessità"
        case .topics: return "Argomenti"
        }
    }
} 