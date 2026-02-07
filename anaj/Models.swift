//
//  Models.swift
//  ANAJ
//
//  Created by Assistant on 12/21/25.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Prompt {
    @Attribute(.unique) var id: UUID
    var title: String
    var content: String // Acts as System Prompt / Context
    var role: String
    var version: Int
    var timestamp: Date
    
    @Relationship(inverse: \Project.prompts) var project: Project?
    @Relationship(deleteRule: .cascade) var messages: [ChatMessage] = []
    @Relationship(deleteRule: .cascade) var insights: [ChatInsight] = []
    
    init(id: UUID = UUID(), title: String, content: String = "", role: String = "Assistant", version: Int = 1, timestamp: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.role = role
        self.version = version
        self.timestamp = timestamp
        self.messages = []
        self.insights = []
    }
}

@Model
final class ChatInsight {
    @Attribute(.unique) var id: UUID
    var title: String
    var content: String
    var source: InsightSource
    var timestamp: Date
    
    // New fields
    var type: InsightType
    var isStarred: Bool
    var lastEditedAt: Date
    var sourceMessageIDs: [UUID]
    var providerLabel: String?
    var externalRunID: String?
    var externalEventID: String?
    
    @Relationship(inverse: \Prompt.insights) var prompt: Prompt?
    @Relationship(inverse: \Project.insights) var project: Project?
    
    init(id: UUID = UUID(), 
         title: String, 
         content: String, 
         source: InsightSource, 
         type: InsightType = .note,
         isStarred: Bool = false,
         sourceMessageIDs: [UUID] = [],
         providerLabel: String? = nil,
         externalRunID: String? = nil,
         externalEventID: String? = nil,
         timestamp: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.source = source
        self.type = type
        self.isStarred = isStarred
        self.lastEditedAt = timestamp
        self.sourceMessageIDs = sourceMessageIDs
        self.providerLabel = providerLabel
        self.externalRunID = externalRunID
        self.externalEventID = externalEventID
        self.timestamp = timestamp
    }
}

enum InsightType: String, Codable, CaseIterable {
    case summary = "Summary"
    case decision = "Decision"
    case strategy = "Strategy"
    case research = "Research"
    case note = "Note"
}

enum InsightSource: String, Codable {
    case aiSummary
    case manualSelection
}

@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var role: String // "user" or "assistant"
    var content: String
    var timestamp: Date
    var attachmentsJSON: String? // Serialized [ProcessedAttachment]
    
    @Relationship(inverse: \Prompt.messages) var prompt: Prompt?
    
    init(id: UUID = UUID(), role: String, content: String, timestamp: Date = Date(), attachmentsJSON: String? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.attachmentsJSON = attachmentsJSON
    }
}

@Model
final class Decision {
    @Attribute(.unique) var id: UUID
    var title: String
    var context: String
    var outcome: String
    var timestamp: Date
    
    @Relationship(inverse: \Project.decisions) var project: Project?
    
    init(id: UUID = UUID(), title: String, context: String = "", outcome: String = "", timestamp: Date = Date()) {
        self.id = id
        self.title = title
        self.context = context
        self.outcome = outcome
        self.timestamp = timestamp
    }
}

@Model
final class Activity {
    @Attribute(.unique) var id: UUID
    var title: String
    var subtitle: String
    var type: ActivityType
    var timestamp: Date
    
    init(id: UUID = UUID(), title: String, subtitle: String = "", type: ActivityType = .task, timestamp: Date = Date()) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.timestamp = timestamp
    }
}

enum ActivityType: String, Codable, CaseIterable {
    case task = "checkmark.circle.fill"
    case project = "folder.fill"
    case client = "person.2.fill"
    case note = "doc.text.fill"
    case system = "bolt.fill"
}

@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var lastModified: Date
    
    // Intelligence features
    var extractedEntitiesJSON: String?
    var lastAnalyzedAt: Date?
    var linkedFromExtraction: Bool
    var externalMemoryID: String?
    
    // QoL features
    var isArchived: Bool = false
    var isPinned: Bool = false
    
    @Relationship(inverse: \Project.notes) var project: Project?
    @Relationship(inverse: \Client.notes) var client: Client?
    @Relationship(inverse: \Tag.notes) var tags: [Tag] = []

    init(id: UUID = UUID(), title: String = "Untitled Note", content: String = "", createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.lastModified = createdAt
        self.linkedFromExtraction = false
        self.externalMemoryID = nil
        self.isArchived = false
        self.isPinned = false
        self.tags = []
    }
}

// MARK: - OpenClaw Integration Models

enum IntegrationDirection: String, Codable, CaseIterable {
    case inbound
    case outbound
}

enum IntegrationEventStatus: String, Codable, CaseIterable {
    case received
    case processed
    case emitted
    case failed
}

@Model
final class IntegrationEvent {
    @Attribute(.unique) var id: UUID
    var eventType: String
    var source: String
    var direction: IntegrationDirection
    var status: IntegrationEventStatus
    var idempotencyKey: String?
    var payloadJSON: String
    var relatedRunID: String?
    var createdAt: Date
    var processedAt: Date?

    init(
        id: UUID = UUID(),
        eventType: String,
        source: String = "openclaw",
        direction: IntegrationDirection,
        status: IntegrationEventStatus = .received,
        idempotencyKey: String? = nil,
        payloadJSON: String = "{}",
        relatedRunID: String? = nil,
        createdAt: Date = Date(),
        processedAt: Date? = nil
    ) {
        self.id = id
        self.eventType = eventType
        self.source = source
        self.direction = direction
        self.status = status
        self.idempotencyKey = idempotencyKey
        self.payloadJSON = payloadJSON
        self.relatedRunID = relatedRunID
        self.createdAt = createdAt
        self.processedAt = processedAt
    }
}

enum CommandExecutionStatus: String, Codable, CaseIterable {
    case received
    case running
    case completed
    case failed
    case rolledBack
}

@Model
final class CommandExecution {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var idempotencyKey: String
    var command: String
    var status: CommandExecutionStatus
    var requestJSON: String
    var responseJSON: String?
    var errorMessage: String?
    var rollbackReference: String?
    var createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        idempotencyKey: String,
        command: String,
        status: CommandExecutionStatus = .received,
        requestJSON: String = "{}",
        responseJSON: String? = nil,
        errorMessage: String? = nil,
        rollbackReference: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.idempotencyKey = idempotencyKey
        self.command = command
        self.status = status
        self.requestJSON = requestJSON
        self.responseJSON = responseJSON
        self.errorMessage = errorMessage
        self.rollbackReference = rollbackReference
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

enum AgentRunStatus: String, Codable, CaseIterable {
    case queued
    case running
    case completed
    case failed
    case deadLettered
}

@Model
final class AgentRun {
    @Attribute(.unique) var id: UUID
    var name: String
    var goal: String
    var status: AgentRunStatus
    var inputJSON: String?
    var output: String?
    var retryCount: Int
    var lastError: String?
    var deadLettered: Bool
    var rollbackReference: String?
    var idempotencyKey: String?
    var startedAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        goal: String,
        status: AgentRunStatus = .queued,
        inputJSON: String? = nil,
        output: String? = nil,
        retryCount: Int = 0,
        lastError: String? = nil,
        deadLettered: Bool = false,
        rollbackReference: String? = nil,
        idempotencyKey: String? = nil,
        startedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.goal = goal
        self.status = status
        self.inputJSON = inputJSON
        self.output = output
        self.retryCount = retryCount
        self.lastError = lastError
        self.deadLettered = deadLettered
        self.rollbackReference = rollbackReference
        self.idempotencyKey = idempotencyKey
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}

@Model
final class MemorySyncCursor {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var source: String
    var cursor: String
    var updatedAt: Date

    init(id: UUID = UUID(), source: String, cursor: String, updatedAt: Date = Date()) {
        self.id = id
        self.source = source
        self.cursor = cursor
        self.updatedAt = updatedAt
    }
}

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var title: String
    var projectDescription: String
    var status: ProjectStatus
    var accentHex: String
    
    // Brand Management Specifics
    var figmaURL: String
    var githubURL: String
    var liveURL: String
    var localPath: String
    var deadline: Date?
    
    // Financial & Scope
    var budget: Double
    var hourlyRate: Double
    var internalRate: Double
    var additionalCosts: Double
    
    // QoL features
    var isArchived: Bool = false
    var isPinned: Bool = false
    var icon: String = "folder.fill"  // SF Symbol or emoji
    
    @Relationship(deleteRule: .cascade) var tasks: [AgencyTask]
    @Relationship(deleteRule: .cascade) var notes: [Note]
    @Relationship(deleteRule: .cascade) var decisions: [Decision]
    @Relationship(deleteRule: .cascade) var prompts: [Prompt]
    @Relationship(deleteRule: .nullify) var insights: [ChatInsight]
    @Relationship(deleteRule: .cascade) var invoices: [Invoice]
    @Relationship(inverse: \Client.projects) var client: Client?
    @Relationship(inverse: \Tag.projects) var tags: [Tag] = []

    init(id: UUID = UUID(), 
         title: String,
         projectDescription: String = "",
         status: ProjectStatus = .flow, 
         accentHex: String = "#5AE6FF", 
         figmaURL: String = "", 
         githubURL: String = "", 
         liveURL: String = "",
         localPath: String = "",
         budget: Double = 0.0,
         hourlyRate: Double = 150.0,
         internalRate: Double = 50.0,
         additionalCosts: Double = 0.0,
         deadline: Date? = nil) {
        self.id = id
        self.title = title
        self.projectDescription = projectDescription
        self.status = status
        self.accentHex = accentHex
        self.figmaURL = figmaURL
        self.githubURL = githubURL
        self.liveURL = liveURL
        self.localPath = localPath
        self.budget = budget
        self.hourlyRate = hourlyRate
        self.internalRate = internalRate
        self.additionalCosts = additionalCosts
        self.deadline = deadline
        self.isArchived = false
        self.isPinned = false
        self.icon = "folder.fill"
        self.tasks = []
        self.notes = []
        self.decisions = []
        self.prompts = []
        self.insights = []
        self.invoices = []
        self.tags = []
    }
}

@Model
final class Client {
    @Attribute(.unique) var id: UUID
    var name: String
    var industry: String
    var brandHex: String
    
    // QoL features
    var isArchived: Bool = false
    var isPinned: Bool = false
    
    @Relationship(deleteRule: .cascade) var projects: [Project]
    @Relationship(deleteRule: .cascade) var notes: [Note]
    @Relationship(deleteRule: .cascade) var invoices: [Invoice]
    @Relationship(inverse: \Tag.clients) var tags: [Tag] = []
    
    init(id: UUID = UUID(), name: String, industry: String = "", brandHex: String = "#FFFFFF") {
        self.id = id
        self.name = name
        self.industry = industry
        self.brandHex = brandHex
        self.isArchived = false
        self.isPinned = false
        self.projects = []
        self.notes = []
        self.invoices = []
        self.tags = []
    }
}

@Model
final class Member {
    @Attribute(.unique) var id: UUID
    var name: String
    var role: String
    var email: String
    
    init(id: UUID = UUID(), name: String, role: String, email: String) {
        self.id = id
        self.name = name
        self.role = role
        self.email = email
    }
}

@Model
final class AgencyTask {
    @Attribute(.unique) var id: UUID
    var content: String
    var isDone: Bool
    var priority: Int
    var dueDate: Date?
    var estimatedHours: Double
    var actualHours: Double
    var sortOrder: Int = 0  // For drag & drop reordering
    
    // QoL features
    var isArchived: Bool = false
    var isPinned: Bool = false
    
    @Relationship(inverse: \Project.tasks) var project: Project?
    @Relationship(inverse: \Tag.tasks) var tags: [Tag] = []
    var assignedMember: Member?

    init(id: UUID = UUID(), 
         content: String, 
         isDone: Bool = false, 
         priority: Int = 1, 
         dueDate: Date? = nil,
         estimatedHours: Double = 1.0,
         actualHours: Double = 0.0,
         project: Project? = nil) {
        self.id = id
        self.content = content
        self.isDone = isDone
        self.priority = priority
        self.dueDate = dueDate
        self.estimatedHours = estimatedHours
        self.actualHours = actualHours
        self.sortOrder = 0
        self.isArchived = false
        self.isPinned = false
        self.project = project
        self.tags = []
    }
}

// MARK: - Invoice Models

@Model
final class Invoice {
    @Attribute(.unique) var id: UUID
    var invoiceNumber: String
    var issueDate: Date
    var dueDate: Date
    var status: InvoiceStatus
    var notes: String
    var taxRate: Double
    var discount: Double
    
    // Business Info
    var businessName: String
    var businessAddress: String
    var businessEmail: String
    var businessPhone: String
    
    @Relationship(deleteRule: .cascade) var lineItems: [InvoiceItem]
    @Relationship(inverse: \Project.invoices) var project: Project?
    @Relationship(inverse: \Client.invoices) var client: Client?
    
    var subtotal: Double {
        lineItems.reduce(0) { $0 + $1.amount }
    }
    
    var taxAmount: Double {
        subtotal * (taxRate / 100)
    }
    
    var total: Double {
        subtotal + taxAmount - discount
    }
    
    init(id: UUID = UUID(),
         invoiceNumber: String = "",
         issueDate: Date = Date(),
         dueDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date(),
         status: InvoiceStatus = .draft,
         notes: String = "",
         taxRate: Double = 0,
         discount: Double = 0,
         businessName: String = "",
         businessAddress: String = "",
         businessEmail: String = "",
         businessPhone: String = "") {
        self.id = id
        self.invoiceNumber = invoiceNumber
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.status = status
        self.notes = notes
        self.taxRate = taxRate
        self.discount = discount
        self.businessName = businessName
        self.businessAddress = businessAddress
        self.businessEmail = businessEmail
        self.businessPhone = businessPhone
        self.lineItems = []
    }
}

@Model
final class InvoiceItem {
    @Attribute(.unique) var id: UUID
    var itemDescription: String
    var quantity: Double
    var rate: Double
    
    var amount: Double {
        quantity * rate
    }
    
    @Relationship(inverse: \Invoice.lineItems) var invoice: Invoice?
    
    init(id: UUID = UUID(), itemDescription: String = "", quantity: Double = 1, rate: Double = 0) {
        self.id = id
        self.itemDescription = itemDescription
        self.quantity = quantity
        self.rate = rate
    }
}

enum InvoiceStatus: String, Codable, CaseIterable {
    case draft = "Draft"
    case sent = "Sent"
    case paid = "Paid"
    case overdue = "Overdue"
    case cancelled = "Cancelled"
    
    var color: Color {
        switch self {
        case .draft: return .gray
        case .sent: return .blue
        case .paid: return .green
        case .overdue: return .red
        case .cancelled: return .orange
        }
    }
}

enum ProjectStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case flow
    case stagnant
    case completed

    var id: String { rawValue }
}

extension Color {
    func toHex() -> String? {
        #if os(macOS)
        let nsColor = NSColor(self)
        guard let rgb = nsColor.usingColorSpace(.deviceRGB) else { return nil }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
        #elseif os(iOS)
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let ri = Int(r * 255)
        let gi = Int(g * 255)
        let bi = Int(b * 255)
        return String(format: "#%02X%02X%02X", ri, gi, bi)
        #else
        return nil
        #endif
    }

    init?(hex: String) {
        let hexSanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&int) else { return nil }
        let a, r, g, b: UInt64
        switch hexSanitized.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
