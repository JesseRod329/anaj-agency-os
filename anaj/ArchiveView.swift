//
//  ArchiveView.swift
//  ANAJ
//
//  View for browsing and restoring archived items
//

import SwiftUI
import SwiftData

struct ArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(filter: #Predicate<Project> { $0.isArchived == true }, sort: \Project.title)
    private var archivedProjects: [Project]
    
    @Query(filter: #Predicate<Client> { $0.isArchived == true }, sort: \Client.name)
    private var archivedClients: [Client]
    
    @Query(filter: #Predicate<Note> { $0.isArchived == true }, sort: \Note.lastModified, order: .reverse)
    private var archivedNotes: [Note]
    
    @Query(filter: #Predicate<AgencyTask> { $0.isArchived == true }, sort: \AgencyTask.content)
    private var archivedTasks: [AgencyTask]
    
    @State private var selectedCategory: ArchiveCategory = .all
    
    enum ArchiveCategory: String, CaseIterable {
        case all = "All"
        case projects = "Projects"
        case clients = "Clients"
        case notes = "Notes"
        case tasks = "Tasks"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "archivebox.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.orange)
                Text("Archive")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(totalArchivedCount) items")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            // Category Filter
            HStack(spacing: 8) {
                ForEach(ArchiveCategory.allCases, id: \.self) { category in
                    Button(action: { selectedCategory = category }) {
                        Text(category.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(selectedCategory == category ? .black : .white.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedCategory == category ? Color.white : Color.white.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Archive List
            ScrollView {
                LazyVStack(spacing: 12) {
                    if shouldShowCategory(.projects) {
                        ForEach(archivedProjects) { project in
                            ArchiveRow(
                                icon: "folder.fill",
                                title: project.title,
                                subtitle: project.client?.name ?? "No client",
                                color: Color(hex: project.accentHex) ?? .blue
                            ) {
                                restoreProject(project)
                            } onDelete: {
                                deleteProject(project)
                            }
                        }
                    }
                    
                    if shouldShowCategory(.clients) {
                        ForEach(archivedClients) { client in
                            ArchiveRow(
                                icon: "person.fill",
                                title: client.name,
                                subtitle: client.industry,
                                color: Color(hex: client.brandHex) ?? .purple
                            ) {
                                restoreClient(client)
                            } onDelete: {
                                deleteClient(client)
                            }
                        }
                    }
                    
                    if shouldShowCategory(.notes) {
                        ForEach(archivedNotes) { note in
                            ArchiveRow(
                                icon: "doc.text.fill",
                                title: note.title,
                                subtitle: note.lastModified.formatted(date: .abbreviated, time: .omitted),
                                color: .orange
                            ) {
                                restoreNote(note)
                            } onDelete: {
                                deleteNote(note)
                            }
                        }
                    }
                    
                    if shouldShowCategory(.tasks) {
                        ForEach(archivedTasks) { task in
                            ArchiveRow(
                                icon: "checkmark.circle.fill",
                                title: task.content,
                                subtitle: task.project?.title ?? "No project",
                                color: .green
                            ) {
                                restoreTask(task)
                            } onDelete: {
                                deleteTask(task)
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            
            if totalArchivedCount == 0 {
                VStack(spacing: 12) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.1))
                    Text("Archive is empty")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(20)
    }
    
    private var totalArchivedCount: Int {
        archivedProjects.count + archivedClients.count + archivedNotes.count + archivedTasks.count
    }
    
    private func shouldShowCategory(_ category: ArchiveCategory) -> Bool {
        selectedCategory == .all || selectedCategory == category
    }
    
    // MARK: - Restore Actions
    
    private func restoreProject(_ project: Project) {
        withAnimation { project.isArchived = false }
        try? modelContext.save()
    }
    
    private func restoreClient(_ client: Client) {
        withAnimation { client.isArchived = false }
        try? modelContext.save()
    }
    
    private func restoreNote(_ note: Note) {
        withAnimation { note.isArchived = false }
        try? modelContext.save()
    }
    
    private func restoreTask(_ task: AgencyTask) {
        withAnimation { task.isArchived = false }
        try? modelContext.save()
    }
    
    // MARK: - Delete Actions
    
    private func deleteProject(_ project: Project) {
        modelContext.delete(project)
        try? modelContext.save()
    }
    
    private func deleteClient(_ client: Client) {
        modelContext.delete(client)
        try? modelContext.save()
    }
    
    private func deleteNote(_ note: Note) {
        modelContext.delete(note)
        try? modelContext.save()
    }
    
    private func deleteTask(_ task: AgencyTask) {
        modelContext.delete(task)
        try? modelContext.save()
    }
}

// MARK: - Archive Row

struct ArchiveRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let onRestore: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
            
            Spacer()
            
            if isHovered {
                HStack(spacing: 8) {
                    Button(action: onRestore) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Restore")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .padding(6)
                            .background(Color.red.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }
}
