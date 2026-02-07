//
//  NoteIntelligence.swift
//  ANAJ
//
//  Smart Notes Intelligence - Data Models & Extraction Logic
//

import Foundation
import SwiftUI

// MARK: - Entity Types

enum ExtractedEntityType: String, Codable, CaseIterable {
    case budget = "Budget"
    case cost = "Cost"
    case task = "Task"
    case decision = "Decision"
    case personMention = "Person"
    case deadline = "Deadline"
    
    var icon: String {
        switch self {
        case .budget: return "dollarsign.circle.fill"
        case .cost: return "creditcard.fill"
        case .task: return "checkmark.circle.fill"
        case .decision: return "brain.head.profile"
        case .personMention: return "person.fill"
        case .deadline: return "calendar.badge.clock"
        }
    }
    
    var color: Color {
        switch self {
        case .budget: return .green
        case .cost: return .orange
        case .task: return .blue
        case .decision: return .purple
        case .personMention: return .cyan
        case .deadline: return .red
        }
    }
}

// MARK: - Extracted Entity

struct ExtractedEntity: Identifiable, Codable, Equatable {
    let id: UUID
    let type: ExtractedEntityType
    let value: String           // The extracted text/value
    let context: String         // Surrounding context from note
    let confidence: Double      // 0.0 - 1.0
    var isAccepted: Bool        // User accepted this suggestion
    var isDismissed: Bool       // User dismissed this suggestion
    
    // For financial entities
    var amount: Double?
    
    // For deadline entities
    var date: Date?
    
    init(id: UUID = UUID(), 
         type: ExtractedEntityType, 
         value: String, 
         context: String = "", 
         confidence: Double = 0.8,
         amount: Double? = nil,
         date: Date? = nil) {
        self.id = id
        self.type = type
        self.value = value
        self.context = context
        self.confidence = confidence
        self.amount = amount
        self.date = date
        self.isAccepted = false
        self.isDismissed = false
    }
}

// MARK: - Note Extraction Result

struct NoteExtraction: Codable {
    let noteId: UUID
    let extractedAt: Date
    var entities: [ExtractedEntity]
    
    // Suggested links based on extraction
    var suggestedClientId: UUID?
    var suggestedProjectId: UUID?
    var clientMatchConfidence: Double?
    var projectMatchConfidence: Double?
    
    init(noteId: UUID, entities: [ExtractedEntity] = []) {
        self.noteId = noteId
        self.extractedAt = Date()
        self.entities = entities
    }
    
    var pendingSuggestions: [ExtractedEntity] {
        entities.filter { !$0.isAccepted && !$0.isDismissed }
    }
    
    var acceptedEntities: [ExtractedEntity] {
        entities.filter { $0.isAccepted }
    }
    
    var hasPendingSuggestions: Bool {
        !pendingSuggestions.isEmpty || suggestedClientId != nil || suggestedProjectId != nil
    }
}

// MARK: - Ollama Response Parsing

struct OllamaExtractionResponse: Codable {
    let budgets: [OllamaEntity]?
    let costs: [OllamaEntity]?
    let tasks: [OllamaEntity]?
    let decisions: [OllamaEntity]?
    let people: [OllamaEntity]?
    let deadlines: [OllamaEntity]?
    
    struct OllamaEntity: Codable {
        let value: String
        let context: String?
        let amount: Double?
        let date: String?
    }
    
    func toExtractedEntities() -> [ExtractedEntity] {
        var result: [ExtractedEntity] = []
        
        if let budgets = budgets {
            for b in budgets {
                result.append(ExtractedEntity(
                    type: .budget, 
                    value: b.value, 
                    context: b.context ?? "",
                    amount: b.amount
                ))
            }
        }
        
        if let costs = costs {
            for c in costs {
                result.append(ExtractedEntity(
                    type: .cost, 
                    value: c.value, 
                    context: c.context ?? "",
                    amount: c.amount
                ))
            }
        }
        
        if let tasks = tasks {
            for t in tasks {
                result.append(ExtractedEntity(
                    type: .task, 
                    value: t.value, 
                    context: t.context ?? ""
                ))
            }
        }
        
        if let decisions = decisions {
            for d in decisions {
                result.append(ExtractedEntity(
                    type: .decision, 
                    value: d.value, 
                    context: d.context ?? ""
                ))
            }
        }
        
        if let people = people {
            for p in people {
                result.append(ExtractedEntity(
                    type: .personMention, 
                    value: p.value, 
                    context: p.context ?? ""
                ))
            }
        }
        
        if let deadlines = deadlines {
            for dl in deadlines {
                var entity = ExtractedEntity(
                    type: .deadline, 
                    value: dl.value, 
                    context: dl.context ?? ""
                )
                // Parse date if provided
                if let dateStr = dl.date {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withFullDate]
                    entity.date = formatter.date(from: dateStr)
                }
                result.append(entity)
            }
        }
        
        return result
    }
}

// MARK: - Client/Project Match

struct EntityMatch: Identifiable {
    let id = UUID()
    let entity: ExtractedEntity
    let matchedClientId: UUID?
    let matchedClientName: String?
    let matchedProjectId: UUID?
    let matchedProjectName: String?
    let confidence: Double
    
    var hasMatch: Bool {
        matchedClientId != nil || matchedProjectId != nil
    }
}
