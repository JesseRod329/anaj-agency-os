//
//  BackupManager.swift
//  ANAJ
//
//  Auto-backup system for data export
//

import Foundation
import SwiftData
import Combine

#if os(macOS)
import AppKit
#endif

@MainActor
class BackupManager: ObservableObject {
    static let shared = BackupManager()
    
    @Published var lastBackupDate: Date?
    @Published var isBackingUp = false
    
    private let backupDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let backupDir = appSupport.appendingPathComponent("anaj/backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        return backupDir
    }()
    
    // MARK: - Export All Data as JSON
    
    func exportBackup(modelContext: ModelContext) async throws -> URL {
        isBackingUp = true
        defer { isBackingUp = false }
        
        // Fetch all data
        let projects = try modelContext.fetch(FetchDescriptor<Project>())
        let clients = try modelContext.fetch(FetchDescriptor<Client>())
        let tasks = try modelContext.fetch(FetchDescriptor<AgencyTask>())
        let notes = try modelContext.fetch(FetchDescriptor<Note>())
        let tags = try modelContext.fetch(FetchDescriptor<Tag>())
        
        // Create backup structure
        let backup = BackupData(
            exportDate: Date(),
            version: "1.0",
            projects: projects.map { ProjectExport(from: $0) },
            clients: clients.map { ClientExport(from: $0) },
            tasks: tasks.map { TaskExport(from: $0) },
            notes: notes.map { NoteExport(from: $0) },
            tags: tags.map { TagExport(from: $0) }
        )
        
        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(backup)
        
        // Write to file
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let filename = "anaj_backup_\(dateFormatter.string(from: Date())).json"
        let fileURL = backupDirectory.appendingPathComponent(filename)
        
        try data.write(to: fileURL)
        
        lastBackupDate = Date()
        
        // Cleanup old backups (keep last 10)
        cleanupOldBackups()
        
        return fileURL
    }
    
    // MARK: - Auto Backup on Quit
    
    func performAutoBackup(modelContext: ModelContext) {
        Task {
            do {
                let _ = try await exportBackup(modelContext: modelContext)
                print("✅ Auto-backup completed")
            } catch {
                print("❌ Auto-backup failed: \(error)")
            }
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanupOldBackups() {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.pathExtension == "json" }
                .sorted { (url1, url2) -> Bool in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    return date1 > date2
                }
            
            // Keep only last 10
            if files.count > 10 {
                for file in files.dropFirst(10) {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            print("Backup cleanup error: \(error)")
        }
    }
    
    // MARK: - Open Backup Folder
    
    #if os(macOS)
    func openBackupFolder() {
        NSWorkspace.shared.open(backupDirectory)
    }
    #endif
}

// MARK: - Export Structures

struct BackupData: Codable {
    let exportDate: Date
    let version: String
    let projects: [ProjectExport]
    let clients: [ClientExport]
    let tasks: [TaskExport]
    let notes: [NoteExport]
    let tags: [TagExport]
}

struct ProjectExport: Codable {
    let id: UUID
    let title: String
    let description: String
    let status: String
    let accentHex: String
    let figmaURL: String
    let githubURL: String
    let liveURL: String
    let localPath: String
    let budget: Double
    let deadline: Date?
    let isArchived: Bool
    let isPinned: Bool
    let clientId: UUID?
    let tagIds: [UUID]
    
    init(from project: Project) {
        self.id = project.id
        self.title = project.title
        self.description = project.projectDescription
        self.status = project.status.rawValue
        self.accentHex = project.accentHex
        self.figmaURL = project.figmaURL
        self.githubURL = project.githubURL
        self.liveURL = project.liveURL
        self.localPath = project.localPath
        self.budget = project.budget
        self.deadline = project.deadline
        self.isArchived = project.isArchived
        self.isPinned = project.isPinned
        self.clientId = project.client?.id
        self.tagIds = project.tags.map { $0.id }
    }
}

struct ClientExport: Codable {
    let id: UUID
    let name: String
    let industry: String
    let brandHex: String
    let isArchived: Bool
    let isPinned: Bool
    let tagIds: [UUID]
    
    init(from client: Client) {
        self.id = client.id
        self.name = client.name
        self.industry = client.industry
        self.brandHex = client.brandHex
        self.isArchived = client.isArchived
        self.isPinned = client.isPinned
        self.tagIds = client.tags.map { $0.id }
    }
}

struct TaskExport: Codable {
    let id: UUID
    let content: String
    let isDone: Bool
    let priority: Int
    let dueDate: Date?
    let estimatedHours: Double
    let actualHours: Double
    let sortOrder: Int
    let isArchived: Bool
    let isPinned: Bool
    let projectId: UUID?
    let tagIds: [UUID]
    
    init(from task: AgencyTask) {
        self.id = task.id
        self.content = task.content
        self.isDone = task.isDone
        self.priority = task.priority
        self.dueDate = task.dueDate
        self.estimatedHours = task.estimatedHours
        self.actualHours = task.actualHours
        self.sortOrder = task.sortOrder
        self.isArchived = task.isArchived
        self.isPinned = task.isPinned
        self.projectId = task.project?.id
        self.tagIds = task.tags.map { $0.id }
    }
}

struct NoteExport: Codable {
    let id: UUID
    let title: String
    let content: String
    let createdAt: Date
    let lastModified: Date
    let isArchived: Bool
    let isPinned: Bool
    let projectId: UUID?
    let clientId: UUID?
    let tagIds: [UUID]
    
    init(from note: Note) {
        self.id = note.id
        self.title = note.title
        self.content = note.content
        self.createdAt = note.createdAt
        self.lastModified = note.lastModified
        self.isArchived = note.isArchived
        self.isPinned = note.isPinned
        self.projectId = note.project?.id
        self.clientId = note.client?.id
        self.tagIds = note.tags.map { $0.id }
    }
}

struct TagExport: Codable {
    let id: UUID
    let name: String
    let colorHex: String
    let icon: String
    
    init(from tag: Tag) {
        self.id = tag.id
        self.name = tag.name
        self.colorHex = tag.colorHex
        self.icon = tag.icon
    }
}
