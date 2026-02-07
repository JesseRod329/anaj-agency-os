//
//  Tag.swift
//  ANAJ
//
//  Tag model for categorizing projects, notes, tasks, and clients
//

import SwiftUI
import SwiftData

@Model
final class Tag {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var icon: String  // SF Symbol name
    var createdAt: Date
    
    // Relationships
    @Relationship(deleteRule: .nullify) var projects: [Project]
    @Relationship(deleteRule: .nullify) var notes: [Note]
    @Relationship(deleteRule: .nullify) var tasks: [AgencyTask]
    @Relationship(deleteRule: .nullify) var clients: [Client]
    
    init(id: UUID = UUID(), name: String, colorHex: String = "#5AE6FF", icon: String = "tag.fill") {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.createdAt = Date()
        self.projects = []
        self.notes = []
        self.tasks = []
        self.clients = []
    }
    
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}

// MARK: - Preset Colors for Tags

extension Tag {
    static let presetColors: [(name: String, hex: String)] = [
        ("Blue", "#5AE6FF"),
        ("Purple", "#A78BFA"),
        ("Pink", "#F472B6"),
        ("Red", "#F87171"),
        ("Orange", "#FB923C"),
        ("Yellow", "#FBBF24"),
        ("Green", "#4ADE80"),
        ("Teal", "#2DD4BF"),
        ("Gray", "#9CA3AF")
    ]
}
