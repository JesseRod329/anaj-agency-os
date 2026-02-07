//
//  ExtractedEntitiesPanel.swift
//  ANAJ
//
//  Collapsible sidebar panel showing AI-extracted suggestions
//

import SwiftUI
import SwiftData

struct ExtractedEntitiesPanel: View {
    let extraction: NoteExtraction?
    let clients: [Client]
    let projects: [Project]
    
    var onAcceptClient: (UUID) -> Void
    var onAcceptProject: (UUID) -> Void
    var onAcceptEntity: (ExtractedEntity) -> Void
    var onDismissEntity: (ExtractedEntity) -> Void
    var onCreateTask: (ExtractedEntity) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.yellow)
                Text("Intelligence")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(Color.white.opacity(0.05))
            
            Divider().background(.white.opacity(0.1))
            
            if let extraction = extraction {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Suggested Links Section
                        if extraction.suggestedClientId != nil || extraction.suggestedProjectId != nil {
                            suggestedLinksSection(extraction)
                        }
                        
                        // Grouped Entities
                        let grouped = Dictionary(grouping: extraction.pendingSuggestions) { $0.type }
                        
                        ForEach(ExtractedEntityType.allCases, id: \.self) { type in
                            if let entities = grouped[type], !entities.isEmpty {
                                entitySection(type: type, entities: entities)
                            }
                        }
                        
                        if extraction.pendingSuggestions.isEmpty && extraction.suggestedClientId == nil {
                            emptyState
                        }
                    }
                    .padding(16)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("Click ✨ Analyze to extract\ninformation from this note")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(20)
            }
        }
        .frame(width: 280)
        .background(Color.black.opacity(0.15))
    }
    
    // MARK: - Suggested Links
    
    @ViewBuilder
    private func suggestedLinksSection(_ extraction: NoteExtraction) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Suggested Links", systemImage: "link")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
            
            if let clientId = extraction.suggestedClientId,
               let client = clients.first(where: { $0.id == clientId }) {
                SuggestionCard(
                    icon: "person.fill",
                    iconColor: .cyan,
                    title: client.name,
                    subtitle: "Client Match",
                    confidence: extraction.clientMatchConfidence ?? 0.8,
                    onAccept: { onAcceptClient(clientId) },
                    onDismiss: { }
                )
            }
            
            if let projectId = extraction.suggestedProjectId,
               let project = projects.first(where: { $0.id == projectId }) {
                SuggestionCard(
                    icon: "folder.fill",
                    iconColor: Color(hex: project.accentHex) ?? .blue,
                    title: project.title,
                    subtitle: "Project Match",
                    confidence: extraction.projectMatchConfidence ?? 0.7,
                    onAccept: { onAcceptProject(projectId) },
                    onDismiss: { }
                )
            }
        }
    }
    
    // MARK: - Entity Section
    
    @ViewBuilder
    private func entitySection(type: ExtractedEntityType, entities: [ExtractedEntity]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(type.rawValue + "s", systemImage: type.icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(type.color.opacity(0.8))
            
            ForEach(entities) { entity in
                EntityCard(
                    entity: entity,
                    onAccept: { onAcceptEntity(entity) },
                    onDismiss: { onDismissEntity(entity) },
                    onCreateTask: type == .task ? { onCreateTask(entity) } : nil
                )
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.green.opacity(0.6))
            Text("All caught up!")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Suggestion Card

struct SuggestionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let confidence: Double
    let onAccept: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(iconColor.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(iconColor)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    ConfidenceBadge(confidence: confidence)
                }
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Button(action: onAccept) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.green.opacity(0.8))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(iconColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Entity Card

struct EntityCard: View {
    let entity: ExtractedEntity
    let onAccept: () -> Void
    let onDismiss: () -> Void
    var onCreateTask: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entity.value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
            
            if let amount = entity.amount {
                Text("$\(amount, specifier: "%.2f")")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
            }
            
            if !entity.context.isEmpty {
                Text(entity.context)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }
            
            HStack(spacing: 6) {
                ConfidenceBadge(confidence: entity.confidence)
                
                Spacer()
                
                if let createTask = onCreateTask {
                    Button(action: createTask) {
                        Label("Add Task", systemImage: "plus.circle")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                
                Button(action: onAccept) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Confidence Badge

struct ConfidenceBadge: View {
    let confidence: Double
    
    var color: Color {
        if confidence >= 0.8 { return .green }
        if confidence >= 0.6 { return .yellow }
        return .orange
    }
    
    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .clipShape(Capsule())
    }
}
