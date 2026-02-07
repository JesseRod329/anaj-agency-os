//
//  NoteExtractionService.swift
//  ANAJ
//
//  Apple NaturalLanguage + Ollama hybrid extraction service
//

import Foundation
import Combine
import SwiftData
import NaturalLanguage

@MainActor
class NoteExtractionService: ObservableObject {
    
    @Published var isAnalyzing = false
    @Published var lastError: String?
    @Published var currentExtraction: NoteExtraction?
    
    private let ollamaBaseURL: String
    private let modelName: String
    
    init(ollamaBaseURL: String = "http://localhost:11434/api", modelName: String = "llama3.2") {
        self.ollamaBaseURL = ollamaBaseURL
        self.modelName = modelName
    }
    
    // MARK: - Main Extraction (Ollama - Accurate)
    
    func analyzeNote(_ note: Note, clients: [Client], projects: [Project]) async -> NoteExtraction? {
        guard !note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            lastError = "Note is empty"
            return nil
        }
        
        isAnalyzing = true
        lastError = nil
        
        defer { isAnalyzing = false }
        
        do {
            // Use Ollama for accurate extraction (120s timeout)
            let entities = try await extractWithOllama(from: note.content)
            
            // Create extraction result
            var extraction = NoteExtraction(noteId: note.id, entities: entities)
            
            // Match people mentions to clients
            for entity in entities where entity.type == .personMention {
                if let match = findClientMatch(name: entity.value, in: clients) {
                    extraction.suggestedClientId = match.id
                    extraction.clientMatchConfidence = calculateConfidence(entity.value, match.name)
                    break
                }
            }
            
            // Try to match project context
            if let projectMatch = findProjectMatch(content: note.content, in: projects) {
                extraction.suggestedProjectId = projectMatch.id
                extraction.projectMatchConfidence = 0.7
            }
            
            currentExtraction = extraction
            return extraction
            
        } catch {
            lastError = "Extraction failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    // MARK: - Apple NaturalLanguage Extraction (FAST - On Device)
    
    private func extractWithAppleNL(from content: String) -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []
        
        // 1. Extract People, Organizations, Places using NLTagger
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = content
        
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        
        tagger.enumerateTags(in: content.startIndex..<content.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            guard let tag = tag else { return true }
            
            let value = String(content[tokenRange])
            let context = extractContext(around: tokenRange, in: content)
            
            switch tag {
            case .personalName:
                entities.append(ExtractedEntity(
                    type: .personMention,
                    value: value,
                    context: context,
                    confidence: 0.95
                ))
            case .organizationName:
                // Treat organizations as potential clients too
                entities.append(ExtractedEntity(
                    type: .personMention,
                    value: value,
                    context: context,
                    confidence: 0.85
                ))
            default:
                break
            }
            return true
        }
        
        // 2. Extract Dates and Money using NSDataDetector
        let detectorTypes: NSTextCheckingResult.CheckingType = [.date, .phoneNumber]
        if let detector = try? NSDataDetector(types: detectorTypes.rawValue) {
            let nsContent = content as NSString
            let matches = detector.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
            
            for match in matches {
                let value = nsContent.substring(with: match.range)
                let context = extractContextNS(around: match.range, in: nsContent)
                
                if match.resultType == .date, let date = match.date {
                    entities.append(ExtractedEntity(
                        type: .deadline,
                        value: value,
                        context: context,
                        confidence: 0.9,
                        date: date
                    ))
                }
            }
        }
        
        // 3. Extract Money amounts with regex (NSDataDetector doesn't have money type)
        let moneyPattern = #"\$[\d,]+(?:\.\d{2})?|\d+(?:,\d{3})*(?:\.\d{2})?\s*(?:dollars?|USD|k\b|K\b)"#
        if let regex = try? NSRegularExpression(pattern: moneyPattern, options: .caseInsensitive) {
            let nsContent = content as NSString
            let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
            
            for match in matches {
                let value = nsContent.substring(with: match.range)
                let context = extractContextNS(around: match.range, in: nsContent)
                let amount = parseMoneyAmount(from: value)
                
                // Determine if budget or cost based on context
                let contextLower = context.lowercased()
                let isBudget = contextLower.contains("budget") || contextLower.contains("agreed") || contextLower.contains("quote") || contextLower.contains("project")
                
                entities.append(ExtractedEntity(
                    type: isBudget ? .budget : .cost,
                    value: value,
                    context: context,
                    confidence: 0.9,
                    amount: amount
                ))
            }
        }
        
        // 4. Extract Tasks using keyword patterns
        let taskPatterns = [
            #"(?:need to|have to|must|should|will|going to)\s+(.{10,60}?)(?:\.|$)"#,
            #"(?:TODO|TO-DO|Action item|Task):\s*(.{10,80}?)(?:\.|$)"#,
            #"(?:remember to|don't forget to)\s+(.{10,60}?)(?:\.|$)"#
        ]
        
        for pattern in taskPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsContent = content as NSString
                let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
                
                for match in matches {
                    let fullMatch = nsContent.substring(with: match.range)
                    entities.append(ExtractedEntity(
                        type: .task,
                        value: fullMatch.trimmingCharacters(in: .whitespacesAndNewlines),
                        context: "",
                        confidence: 0.8
                    ))
                }
            }
        }
        
        // 5. Extract Decisions using keyword patterns
        let decisionPatterns = [
            #"(?:decided|decision|agreed|concluded|going with|chose|choosing)\s*(?:to|that|on)?\s*(.{10,80}?)(?:\.|$)"#
        ]
        
        for pattern in decisionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsContent = content as NSString
                let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
                
                for match in matches {
                    let fullMatch = nsContent.substring(with: match.range)
                    entities.append(ExtractedEntity(
                        type: .decision,
                        value: fullMatch.trimmingCharacters(in: .whitespacesAndNewlines),
                        context: "",
                        confidence: 0.75
                    ))
                }
            }
        }
        
        return entities
    }
    
    private func extractContext(around range: Range<String.Index>, in content: String) -> String {
        let start = content.index(range.lowerBound, offsetBy: -30, limitedBy: content.startIndex) ?? content.startIndex
        let end = content.index(range.upperBound, offsetBy: 30, limitedBy: content.endIndex) ?? content.endIndex
        return String(content[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractContextNS(around range: NSRange, in content: NSString) -> String {
        let start = max(0, range.location - 30)
        let end = min(content.length, range.location + range.length + 30)
        return content.substring(with: NSRange(location: start, length: end - start)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parseMoneyAmount(from value: String) -> Double? {
        var cleaned = value.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        
        var multiplier: Double = 1.0
        if cleaned.hasSuffix("k") {
            multiplier = 1000
            cleaned = String(cleaned.dropLast())
        }
        
        cleaned = cleaned.replacingOccurrences(of: "dollars", with: "")
            .replacingOccurrences(of: "dollar", with: "")
            .replacingOccurrences(of: "usd", with: "")
        
        if let amount = Double(cleaned) {
            return amount * multiplier
        }
        return nil
    }
    
    // MARK: - Ollama Extraction (Backup - 120s timeout)
    
    private func extractWithOllama(from content: String) async throws -> [ExtractedEntity] {
        guard let url = URL(string: "\(ollamaBaseURL)/generate") else {
            throw URLError(.badURL)
        }
        
        let prompt = buildExtractionPrompt(content: content)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120  // Increased to 120 seconds
        
        let body: [String: Any] = [
            "model": modelName,
            "prompt": prompt,
            "stream": false,
            "format": "json"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let responseText = json["response"] as? String,
           let responseData = responseText.data(using: .utf8) {
            
            if let extraction = try? JSONDecoder().decode(OllamaExtractionResponse.self, from: responseData) {
                // Only return tasks and decisions (Apple NL handles the rest)
                return extraction.toExtractedEntities().filter { 
                    $0.type == .task || $0.type == .decision 
                }
            }
        }
        
        return []
    }
    
    private func buildExtractionPrompt(content: String) -> String {
        """
        Analyze this note and extract ONLY tasks and decisions. Return ONLY valid JSON.
        
        - tasks: Action items, to-dos, things that need to be done
        - decisions: Key decisions or conclusions made
        
        NOTE CONTENT:
        \(content)
        
        Return JSON:
        {
          "tasks": [{"value": "...", "context": "..."}],
          "decisions": [{"value": "...", "context": "..."}]
        }
        """
    }
    
    // MARK: - Matching Logic
    
    private func findClientMatch(name: String, in clients: [Client]) -> Client? {
        let nameLower = name.lowercased()
        
        if let exact = clients.first(where: { $0.name.lowercased() == nameLower }) {
            return exact
        }
        
        for client in clients {
            let clientLower = client.name.lowercased()
            if clientLower.contains(nameLower) || nameLower.contains(clientLower) {
                return client
            }
            
            let clientParts = clientLower.split(separator: " ")
            let nameParts = nameLower.split(separator: " ")
            
            for clientPart in clientParts {
                for namePart in nameParts {
                    if clientPart == namePart && namePart.count > 2 {
                        return client
                    }
                }
            }
        }
        
        return nil
    }
    
    private func findProjectMatch(content: String, in projects: [Project]) -> Project? {
        let contentLower = content.lowercased()
        
        for project in projects {
            let titleLower = project.title.lowercased()
            if contentLower.contains(titleLower) {
                return project
            }
        }
        
        return nil
    }
    
    private func calculateConfidence(_ extracted: String, _ matched: String) -> Double {
        let extractedLower = extracted.lowercased()
        let matchedLower = matched.lowercased()
        
        if extractedLower == matchedLower { return 1.0 }
        if matchedLower.contains(extractedLower) || extractedLower.contains(matchedLower) { return 0.85 }
        return 0.6
    }
}
