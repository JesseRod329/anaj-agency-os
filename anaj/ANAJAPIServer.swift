#if os(macOS)
import Foundation
import Network
import SwiftData

final class ANAJAPIServer {
    static let shared = ANAJAPIServer()

    private var listener: NWListener?
    private var modelContainer: ModelContainer?
    private let queue = DispatchQueue(label: "anaj.api.server", qos: .utility)

    private init() {}

    func start(modelContainer: ModelContainer, port: UInt16 = 18790) {
        guard listener == nil else { return }

        do {
            let nwPort = NWEndpoint.Port(rawValue: port) ?? 18790
            let listener = try NWListener(using: .tcp, on: nwPort)
            self.modelContainer = modelContainer

            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }

            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("ANAJ API listening on http://127.0.0.1:\(port)")
                case .failed(let error):
                    print("ANAJ API failed: \(error)")
                default:
                    break
                }
            }

            listener.start(queue: queue)
            self.listener = listener
        } catch {
            print("Failed to start ANAJ API: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_000_000) { [weak self] data, _, _, _ in
            guard let self, let data, !data.isEmpty else {
                connection.cancel()
                return
            }

            Task { @MainActor [weak self] in
                guard let self else {
                    connection.cancel()
                    return
                }

                let response = self.processRequest(rawData: data)
                connection.send(content: response.serialized(), completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }

    private func processRequest(rawData: Data) -> HTTPResponse {
        guard let request = HTTPRequest.parse(rawData) else {
            return .json(status: 400, body: ["error": "Malformed HTTP request"])
        }

        guard authorize(request: request) else {
            return .json(status: 401, body: ["error": "Unauthorized"])
        }

        guard let modelContainer else {
            return .json(status: 503, body: ["error": "Model container unavailable"])
        }

        do {
            let context = ModelContext(modelContainer)
            let path = request.path

            if request.method == "GET" && path == "/api/health" {
                return .json(status: 200, body: [
                    "status": "ok",
                    "service": "anaj-api",
                    "port": 18790,
                    "time": Date().iso8601
                ])
            }

            if request.method == "GET" && path == "/api/clients" {
                let clients = try context.fetch(FetchDescriptor<Client>())
                    .filter { !$0.isArchived }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

                let payload = clients.map { client in
                    ClientResponse(
                        id: client.id.uuidString,
                        name: client.name,
                        industry: client.industry,
                        activeProjectCount: client.projects.filter { !$0.isArchived && $0.status != .completed }.count,
                        projectIDs: client.projects.filter { !$0.isArchived }.map { $0.id.uuidString }
                    )
                }

                return .encodable(200, payload)
            }

            if request.method == "GET" && path == "/api/projects" {
                let clientFilter = request.queryItems["clientId"]
                let projects = try context.fetch(FetchDescriptor<Project>())
                    .filter { !$0.isArchived }
                    .filter { project in
                        guard let clientFilter else { return true }
                        return project.client?.id.uuidString == clientFilter
                    }
                    .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

                let payload = projects.map { project in
                    ProjectResponse(
                        id: project.id.uuidString,
                        title: project.title,
                        status: project.status.rawValue,
                        clientID: project.client?.id.uuidString,
                        clientName: project.client?.name,
                        budget: project.budget,
                        deadline: project.deadline?.iso8601,
                        activeTaskCount: project.tasks.filter { !$0.isArchived && !$0.isDone }.count
                    )
                }

                return .encodable(200, payload)
            }

            if request.method == "GET" && path == "/api/tasks" {
                let includeDone = request.queryItems["includeDone"] == "true"
                let projectFilter = request.queryItems["projectId"]

                let tasks = try context.fetch(FetchDescriptor<AgencyTask>())
                    .filter { !$0.isArchived }
                    .filter { includeDone || !$0.isDone }
                    .filter { task in
                        guard let projectFilter else { return true }
                        return task.project?.id.uuidString == projectFilter
                    }
                    .sorted { lhs, rhs in
                        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                        return lhs.content.localizedCaseInsensitiveCompare(rhs.content) == .orderedAscending
                    }

                let payload = tasks.map { task in
                    TaskResponse(
                        id: task.id.uuidString,
                        content: task.content,
                        isDone: task.isDone,
                        priority: task.priority,
                        dueDate: task.dueDate?.iso8601,
                        estimatedHours: task.estimatedHours,
                        actualHours: task.actualHours,
                        projectID: task.project?.id.uuidString,
                        projectTitle: task.project?.title
                    )
                }

                return .encodable(200, payload)
            }

            if request.method == "POST" && path == "/api/tasks" {
                let input: CreateTaskRequest = try request.decodeJSON()
                guard !input.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return .json(status: 422, body: ["error": "Task content is required"])
                }

                let task = AgencyTask(
                    content: input.content,
                    isDone: false,
                    priority: input.priority ?? 1,
                    dueDate: input.dueDate?.asISODate,
                    estimatedHours: input.estimatedHours ?? 1,
                    actualHours: input.actualHours ?? 0
                )

                if let projectID = input.projectId,
                   let projectUUID = UUID(uuidString: projectID),
                   let project = try context.fetch(FetchDescriptor<Project>()).first(where: { $0.id == projectUUID }) {
                    task.project = project
                }

                context.insert(task)
                logActivity("Task Created", subtitle: task.content, context: context)
                try context.save()

                return .encodable(201, TaskResponse(from: task))
            }

            if request.method == "PATCH", let taskID = request.taskIDFromPath {
                guard let taskUUID = UUID(uuidString: taskID) else {
                    return .json(status: 400, body: ["error": "Invalid task id"])
                }

                guard let task = try context.fetch(FetchDescriptor<AgencyTask>()).first(where: { $0.id == taskUUID && !$0.isArchived }) else {
                    return .json(status: 404, body: ["error": "Task not found"])
                }

                let patch: UpdateTaskRequest = try request.decodeJSON()

                if let content = patch.content { task.content = content }
                if let isDone = patch.isDone { task.isDone = isDone }
                if let priority = patch.priority { task.priority = priority }
                if let estimatedHours = patch.estimatedHours { task.estimatedHours = estimatedHours }
                if let actualHours = patch.actualHours { task.actualHours = actualHours }
                if patch.clearDueDate == true {
                    task.dueDate = nil
                } else if let dueDate = patch.dueDate?.asISODate {
                    task.dueDate = dueDate
                }

                if let projectID = patch.projectId {
                    if projectID.isEmpty {
                        task.project = nil
                    } else if let projectUUID = UUID(uuidString: projectID),
                              let project = try context.fetch(FetchDescriptor<Project>()).first(where: { $0.id == projectUUID && !$0.isArchived }) {
                        task.project = project
                    }
                }

                logActivity("Task Updated", subtitle: task.content, context: context)
                try context.save()
                return .encodable(200, TaskResponse(from: task))
            }

            if request.method == "POST" && path == "/api/clients" {
                let input: CreateClientRequest = try request.decodeJSON()
                guard !input.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return .json(status: 422, body: ["error": "Client name is required"])
                }

                let client = Client(name: input.name, industry: input.industry ?? "")
                context.insert(client)
                logActivity("Client Created", subtitle: client.name, context: context)
                try context.save()

                let payload = ClientResponse(
                    id: client.id.uuidString,
                    name: client.name,
                    industry: client.industry,
                    activeProjectCount: 0,
                    projectIDs: []
                )
                return .encodable(201, payload)
            }

            if request.method == "POST" && path == "/api/projects" {
                let input: CreateProjectRequest = try request.decodeJSON()
                guard !input.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return .json(status: 422, body: ["error": "Project title is required"])
                }

                let project = Project(
                    title: input.title,
                    projectDescription: input.projectDescription ?? "",
                    status: .flow,
                    accentHex: input.accentHex ?? "#5AE6FF",
                    budget: input.budget ?? 0,
                    deadline: input.deadline?.asISODate
                )

                if let clientID = input.clientId,
                   let clientUUID = UUID(uuidString: clientID),
                   let client = try context.fetch(FetchDescriptor<Client>()).first(where: { $0.id == clientUUID && !$0.isArchived }) {
                    project.client = client
                }

                context.insert(project)
                logActivity("Project Created", subtitle: project.title, context: context)
                try context.save()

                return .encodable(201, ProjectResponse(
                    id: project.id.uuidString,
                    title: project.title,
                    status: project.status.rawValue,
                    clientID: project.client?.id.uuidString,
                    clientName: project.client?.name,
                    budget: project.budget,
                    deadline: project.deadline?.iso8601,
                    activeTaskCount: 0
                ))
            }

            if request.method == "POST" && path == "/api/notes" {
                let input: CreateNoteRequest = try request.decodeJSON()
                let title = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else {
                    return .json(status: 422, body: ["error": "Note title is required"])
                }

                let note = Note(title: title, content: input.content ?? "")

                if let projectID = input.projectId,
                   let projectUUID = UUID(uuidString: projectID),
                   let project = try context.fetch(FetchDescriptor<Project>()).first(where: { $0.id == projectUUID && !$0.isArchived }) {
                    note.project = project
                }

                if let clientID = input.clientId,
                   let clientUUID = UUID(uuidString: clientID),
                   let client = try context.fetch(FetchDescriptor<Client>()).first(where: { $0.id == clientUUID && !$0.isArchived }) {
                    note.client = client
                }

                context.insert(note)
                logActivity("Note Created", subtitle: note.title, context: context)
                try context.save()

                return .json(status: 201, body: [
                    "id": note.id.uuidString,
                    "title": note.title,
                    "createdAt": note.createdAt.iso8601
                ])
            }

            if request.method == "GET" && path == "/api/ledger" {
                let projects = try context.fetch(FetchDescriptor<Project>()).filter { !$0.isArchived }
                let tasks = try context.fetch(FetchDescriptor<AgencyTask>()).filter { !$0.isArchived }
                let invoices = try context.fetch(FetchDescriptor<Invoice>())

                let totalRevenue = projects.reduce(0.0) { $0 + $1.budget }
                let laborCost = tasks.reduce(0.0) { partial, task in
                    let rate = task.project?.internalRate ?? 0
                    return partial + (task.actualHours * rate)
                }
                let additionalCosts = projects.reduce(0.0) { $0 + $1.additionalCosts }
                let netProfit = totalRevenue - laborCost - additionalCosts

                let totalInvoiced = invoices.reduce(0.0) { $0 + $1.total }
                let paidInvoices = invoices.filter { $0.status == .paid }.reduce(0.0) { $0 + $1.total }
                let outstanding = invoices.filter { $0.status != .paid && $0.status != .cancelled }.reduce(0.0) { $0 + $1.total }

                return .json(status: 200, body: [
                    "totalRevenue": totalRevenue,
                    "laborCost": laborCost,
                    "additionalCosts": additionalCosts,
                    "netProfit": netProfit,
                    "averageMargin": totalRevenue == 0 ? 0 : (netProfit / totalRevenue),
                    "totalInvoiced": totalInvoiced,
                    "totalPaid": paidInvoices,
                    "outstanding": outstanding
                ])
            }

            if request.method == "POST" && path == "/api/notify" {
                let input: NotifyRequest = try request.decodeJSON()
                let payload = [
                    "channel": input.channel ?? "default",
                    "to": input.to ?? "unknown",
                    "message": input.message,
                    "priority": input.priority ?? "normal"
                ]
                let payloadJSON = serializeJSONObject(payload)
                let event = IntegrationEvent(
                    eventType: "notify.dispatch",
                    source: "anaj",
                    direction: .outbound,
                    status: .emitted,
                    idempotencyKey: request.idempotencyKey,
                    payloadJSON: payloadJSON,
                    processedAt: Date()
                )
                context.insert(event)
                try context.save()

                return .json(status: 202, body: [
                    "status": "accepted",
                    "message": "Notification accepted for bridge dispatch",
                    "eventId": event.id.uuidString
                ])
            }

            if request.method == "POST" && path == "/api/openclaw/webhook" {
                let payload = try request.decodeJSONDictionary()
                let eventType = payload["eventType"] as? String ?? "openclaw.event"
                let idempotencyKey = (payload["idempotencyKey"] as? String) ?? request.idempotencyKey

                if let idempotencyKey,
                   let existing = try findIntegrationEvent(idempotencyKey: idempotencyKey, context: context) {
                    return .json(status: 200, body: [
                        "status": "duplicate",
                        "eventId": existing.id.uuidString,
                        "idempotencyKey": idempotencyKey
                    ])
                }

                let source = payload["source"] as? String ?? "openclaw"
                let event = IntegrationEvent(
                    eventType: eventType,
                    source: source,
                    direction: .inbound,
                    status: .processed,
                    idempotencyKey: idempotencyKey,
                    payloadJSON: serializeJSONObject(payload),
                    processedAt: Date()
                )
                context.insert(event)
                logActivity("OpenClaw Event", subtitle: eventType, context: context)
                try context.save()

                return .json(status: 202, body: [
                    "status": "accepted",
                    "eventId": event.id.uuidString
                ])
            }

            if request.method == "POST" && path == "/api/commands/execute" {
                let payload = try request.decodeJSONDictionary()
                let command = (payload["command"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !command.isEmpty else {
                    return .json(status: 422, body: [
                        "error": "command is required",
                        "code": "MISSING_COMMAND"
                    ])
                }

                let idempotencyKey = ((payload["idempotencyKey"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines))
                    ?? request.idempotencyKey
                    ?? "cmd-\(UUID().uuidString)"

                if let existing = try findCommandExecution(idempotencyKey: idempotencyKey, context: context) {
                    return .json(status: 200, body: [
                        "status": "duplicate",
                        "idempotencyKey": idempotencyKey,
                        "command": existing.command,
                        "executionId": existing.id.uuidString,
                        "result": existing.responseJSON ?? "{}"
                    ])
                }

                let execution = CommandExecution(
                    idempotencyKey: idempotencyKey,
                    command: command,
                    status: .running,
                    requestJSON: serializeJSONObject(payload)
                )
                context.insert(execution)
                try context.save()

                do {
                    let result = try executeCommand(command: command, payload: payload, context: context)
                    execution.status = .completed
                    execution.responseJSON = serializeJSONObject(result)
                    execution.completedAt = Date()

                    let event = IntegrationEvent(
                        eventType: "command.executed",
                        source: "anaj",
                        direction: .outbound,
                        status: .emitted,
                        idempotencyKey: idempotencyKey,
                        payloadJSON: serializeJSONObject([
                            "command": command,
                            "result": result
                        ]),
                        processedAt: Date()
                    )
                    context.insert(event)
                    try context.save()

                    return .json(status: 200, body: [
                        "status": "completed",
                        "idempotencyKey": idempotencyKey,
                        "executionId": execution.id.uuidString,
                        "result": result
                    ])
                } catch let apiError as APICommandError {
                    execution.status = .failed
                    execution.errorMessage = apiError.message
                    execution.completedAt = Date()
                    try context.save()

                    return .json(status: apiError.status, body: [
                        "error": apiError.message,
                        "code": "COMMAND_EXECUTION_FAILED",
                        "command": command,
                        "idempotencyKey": idempotencyKey,
                        "executionId": execution.id.uuidString
                    ])
                }
            }

            if request.method == "GET" && path == "/api/events/stream" {
                let limit = min(max(Int(request.queryItems["limit"] ?? "50") ?? 50, 1), 200)
                let events = try context.fetch(FetchDescriptor<IntegrationEvent>())
                    .sorted { $0.createdAt > $1.createdAt }
                    .prefix(limit)

                var lines: [String] = []
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]

                for event in events {
                    let payload = IntegrationEventResponse(from: event)
                    let data = (try? encoder.encode(payload)) ?? Data("{}".utf8)
                    let json = String(data: data, encoding: .utf8) ?? "{}"
                    lines.append("event: anaj.integration")
                    lines.append("id: \(event.id.uuidString)")
                    lines.append("data: \(json)")
                    lines.append("")
                }

                if lines.isEmpty {
                    lines = ["event: anaj.integration", "data: {}", ""]
                }

                return .raw(status: 200, contentType: "text/event-stream", body: Data(lines.joined(separator: "\n").utf8))
            }

            if request.method == "POST" && path == "/api/memory/sync" {
                let input: MemorySyncRequest = try request.decodeJSON()
                let source = input.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "openclaw" : input.source

                var createdCount = 0
                var updatedCount = 0

                let projects = try context.fetch(FetchDescriptor<Project>())

                for item in input.items {
                    let existing = try context.fetch(FetchDescriptor<Note>()).first(where: {
                        $0.externalMemoryID == item.externalId
                    })

                    let targetProject = projects.first(where: { $0.id.uuidString == item.projectId })
                    let content = item.content.trimmingCharacters(in: .whitespacesAndNewlines)

                    if let existing {
                        existing.title = (item.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                            ? (item.title ?? existing.title)
                            : existing.title
                        if !content.isEmpty {
                            existing.content = content
                        }
                        existing.project = targetProject ?? existing.project
                        existing.lastModified = item.timestamp?.asISODate ?? Date()
                        updatedCount += 1
                    } else {
                        let note = Note(
                            title: item.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                                ? (item.title ?? "Synced Memory")
                                : "Synced Memory",
                            content: content
                        )
                        note.externalMemoryID = item.externalId
                        note.lastModified = item.timestamp?.asISODate ?? Date()
                        note.project = targetProject
                        note.linkedFromExtraction = true
                        context.insert(note)
                        createdCount += 1
                    }
                }

                let cursorValue = input.cursor ?? Date().iso8601
                if let existingCursor = try context.fetch(FetchDescriptor<MemorySyncCursor>()).first(where: { $0.source == source }) {
                    existingCursor.cursor = cursorValue
                    existingCursor.updatedAt = Date()
                } else {
                    context.insert(MemorySyncCursor(source: source, cursor: cursorValue))
                }

                let event = IntegrationEvent(
                    eventType: "memory.synced",
                    source: source,
                    direction: .inbound,
                    status: .processed,
                    idempotencyKey: request.idempotencyKey,
                    payloadJSON: serializeJSONObject([
                        "source": source,
                        "created": createdCount,
                        "updated": updatedCount
                    ]),
                    processedAt: Date()
                )
                context.insert(event)
                try context.save()

                return .json(status: 200, body: [
                    "status": "synced",
                    "source": source,
                    "created": createdCount,
                    "updated": updatedCount,
                    "cursor": cursorValue
                ])
            }

            if request.method == "GET" && path == "/api/memory/changes" {
                let source = request.queryItems["source"] ?? "openclaw"
                let limit = min(max(Int(request.queryItems["limit"] ?? "50") ?? 50, 1), 200)
                let sinceDateFromQuery = request.queryItems["since"]?.asISODate
                let cursorDate = try context.fetch(FetchDescriptor<MemorySyncCursor>())
                    .first(where: { $0.source == source })?
                    .cursor
                    .asISODate
                let sinceDate = sinceDateFromQuery ?? cursorDate

                var notes = try context.fetch(FetchDescriptor<Note>())
                    .filter { !$0.isArchived }
                    .sorted { $0.lastModified > $1.lastModified }

                if let sinceDate {
                    notes = notes.filter { $0.lastModified >= sinceDate }
                }

                let payload = Array(notes.prefix(limit)).map { note in
                    MemoryChangeResponse(
                        id: note.id.uuidString,
                        externalId: note.externalMemoryID,
                        title: note.title,
                        content: note.content,
                        projectId: note.project?.id.uuidString,
                        lastModified: note.lastModified.iso8601
                    )
                }

                let nextCursor = payload.first?.lastModified ?? Date().iso8601
                return .encodable(200, MemoryChangesEnvelope(
                    source: source,
                    since: sinceDate?.iso8601,
                    nextCursor: nextCursor,
                    count: payload.count,
                    items: payload
                ))
            }

            if request.method == "POST" && path == "/api/agents/run" {
                let input: AgentRunRequest = try request.decodeJSON()
                let idempotencyKey = input.idempotencyKey?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let idempotencyKey,
                   let existing = try findAgentRun(idempotencyKey: idempotencyKey, context: context) {
                    return .encodable(200, AgentRunResponse(from: existing, duplicate: true))
                }

                let run = AgentRun(
                    name: input.name,
                    goal: input.goal,
                    status: .running,
                    inputJSON: input.inputJSON,
                    retryCount: 0,
                    deadLettered: false,
                    rollbackReference: input.rollbackReference,
                    idempotencyKey: idempotencyKey,
                    startedAt: Date()
                )
                context.insert(run)
                logActivity("Agent Run Started", subtitle: run.name, context: context)

                // Fully-auto default: execute immediately and complete with a deterministic summary.
                run.output = "Agent \(run.name) executed locally with goal: \(run.goal)"
                run.status = .completed
                run.completedAt = Date()

                let event = IntegrationEvent(
                    eventType: "agent.run.completed",
                    source: "anaj",
                    direction: .outbound,
                    status: .emitted,
                    idempotencyKey: idempotencyKey,
                    payloadJSON: serializeJSONObject([
                        "runId": run.id.uuidString,
                        "name": run.name,
                        "status": run.status.rawValue
                    ]),
                    relatedRunID: run.id.uuidString,
                    processedAt: Date()
                )
                context.insert(event)
                try context.save()

                return .encodable(201, AgentRunResponse(from: run, duplicate: false))
            }

            if request.method == "GET", let runID = request.agentRunIDFromPath {
                guard let runUUID = UUID(uuidString: runID) else {
                    return .json(status: 400, body: ["error": "Invalid run id", "code": "INVALID_RUN_ID"])
                }

                guard let run = try context.fetch(FetchDescriptor<AgentRun>()).first(where: { $0.id == runUUID }) else {
                    return .json(status: 404, body: ["error": "Run not found", "code": "RUN_NOT_FOUND"])
                }

                return .encodable(200, AgentRunResponse(from: run, duplicate: false))
            }

            return .json(status: 404, body: ["error": "Endpoint not found"])
        } catch {
            return .json(status: 500, body: [
                "error": error.localizedDescription,
                "code": "INTERNAL_SERVER_ERROR"
            ])
        }
    }

    private func executeCommand(command: String, payload: [String: Any], context: ModelContext) throws -> [String: Any] {
        switch command {
        case "create_task":
            guard let content = payload["content"] as? String,
                  !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APICommandError(status: 422, message: "create_task requires non-empty content")
            }

            let task = AgencyTask(
                content: content,
                isDone: false,
                priority: payload["priority"] as? Int ?? 1,
                dueDate: (payload["dueDate"] as? String)?.asISODate,
                estimatedHours: payload["estimatedHours"] as? Double ?? 1,
                actualHours: payload["actualHours"] as? Double ?? 0
            )

            if let projectID = payload["projectId"] as? String,
               let projectUUID = UUID(uuidString: projectID),
               let project = try context.fetch(FetchDescriptor<Project>()).first(where: { $0.id == projectUUID && !$0.isArchived }) {
                task.project = project
            }

            context.insert(task)
            logActivity("Task Created", subtitle: task.content, context: context)
            try context.save()

            return [
                "id": task.id.uuidString,
                "type": "task",
                "content": task.content,
                "isDone": task.isDone,
                "priority": task.priority
            ]

        case "update_task":
            guard let taskID = payload["taskId"] as? String,
                  let taskUUID = UUID(uuidString: taskID),
                  let task = try context.fetch(FetchDescriptor<AgencyTask>()).first(where: { $0.id == taskUUID && !$0.isArchived }) else {
                throw APICommandError(status: 404, message: "update_task could not find task")
            }

            if let content = payload["content"] as? String {
                task.content = content
            }
            if let isDone = payload["isDone"] as? Bool {
                task.isDone = isDone
            }
            if let priority = payload["priority"] as? Int {
                task.priority = priority
            }
            if let estimatedHours = payload["estimatedHours"] as? Double {
                task.estimatedHours = estimatedHours
            }
            if let actualHours = payload["actualHours"] as? Double {
                task.actualHours = actualHours
            }
            if let dueDate = payload["dueDate"] as? String {
                task.dueDate = dueDate.asISODate
            }

            if let projectID = payload["projectId"] as? String {
                if projectID.isEmpty {
                    task.project = nil
                } else if let projectUUID = UUID(uuidString: projectID),
                          let project = try context.fetch(FetchDescriptor<Project>()).first(where: { $0.id == projectUUID && !$0.isArchived }) {
                    task.project = project
                }
            }

            logActivity("Task Updated", subtitle: task.content, context: context)
            try context.save()

            return [
                "id": task.id.uuidString,
                "type": "task",
                "content": task.content,
                "isDone": task.isDone,
                "priority": task.priority
            ]

        case "create_note":
            let title = (payload["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty else {
                throw APICommandError(status: 422, message: "create_note requires non-empty title")
            }

            let note = Note(
                title: title,
                content: (payload["content"] as? String) ?? ""
            )

            if let projectID = payload["projectId"] as? String,
               let projectUUID = UUID(uuidString: projectID),
               let project = try context.fetch(FetchDescriptor<Project>()).first(where: { $0.id == projectUUID && !$0.isArchived }) {
                note.project = project
            }

            if let clientID = payload["clientId"] as? String,
               let clientUUID = UUID(uuidString: clientID),
               let client = try context.fetch(FetchDescriptor<Client>()).first(where: { $0.id == clientUUID && !$0.isArchived }) {
                note.client = client
            }

            context.insert(note)
            logActivity("Note Created", subtitle: note.title, context: context)
            try context.save()

            return [
                "id": note.id.uuidString,
                "type": "note",
                "title": note.title
            ]

        case "create_client":
            let name = (payload["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else {
                throw APICommandError(status: 422, message: "create_client requires non-empty name")
            }

            let client = Client(name: name, industry: (payload["industry"] as? String) ?? "")
            context.insert(client)
            logActivity("Client Created", subtitle: client.name, context: context)
            try context.save()

            return [
                "id": client.id.uuidString,
                "type": "client",
                "name": client.name
            ]

        case "create_project":
            let title = (payload["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty else {
                throw APICommandError(status: 422, message: "create_project requires non-empty title")
            }

            let project = Project(
                title: title,
                projectDescription: (payload["projectDescription"] as? String) ?? "",
                status: .flow,
                accentHex: (payload["accentHex"] as? String) ?? "#5AE6FF",
                budget: payload["budget"] as? Double ?? 0,
                deadline: (payload["deadline"] as? String)?.asISODate
            )

            if let clientID = payload["clientId"] as? String,
               let clientUUID = UUID(uuidString: clientID),
               let client = try context.fetch(FetchDescriptor<Client>()).first(where: { $0.id == clientUUID && !$0.isArchived }) {
                project.client = client
            }

            context.insert(project)
            logActivity("Project Created", subtitle: project.title, context: context)
            try context.save()

            return [
                "id": project.id.uuidString,
                "type": "project",
                "title": project.title,
                "status": project.status.rawValue
            ]

        default:
            throw APICommandError(status: 422, message: "Unsupported command: \(command)")
        }
    }

    private func findIntegrationEvent(idempotencyKey: String, context: ModelContext) throws -> IntegrationEvent? {
        try context.fetch(FetchDescriptor<IntegrationEvent>()).first(where: { $0.idempotencyKey == idempotencyKey })
    }

    private func findCommandExecution(idempotencyKey: String, context: ModelContext) throws -> CommandExecution? {
        try context.fetch(FetchDescriptor<CommandExecution>()).first(where: { $0.idempotencyKey == idempotencyKey })
    }

    private func findAgentRun(idempotencyKey: String, context: ModelContext) throws -> AgentRun? {
        try context.fetch(FetchDescriptor<AgentRun>()).first(where: { $0.idempotencyKey == idempotencyKey })
    }

    private func logActivity(_ title: String, subtitle: String, context: ModelContext) {
        context.insert(Activity(title: title, subtitle: subtitle, type: .system))
    }

    private func serializeJSONObject(_ object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private func authorize(request: HTTPRequest) -> Bool {
#if DEBUG
        return true
#else
        let required = ProcessInfo.processInfo.environment["ANAJ_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !required.isEmpty else { return false }

        if request.headers["x-anaj-key"] == required {
            return true
        }

        if let authorization = request.headers["authorization"],
           authorization.lowercased().hasPrefix("bearer ") {
            let token = String(authorization.dropFirst("bearer ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if token == required {
                return true
            }
        }

        return false
#endif
    }
}

private struct APICommandError: Error {
    let status: Int
    let message: String
}

// MARK: - Request/Response Models

private struct CreateTaskRequest: Decodable {
    let content: String
    let priority: Int?
    let dueDate: String?
    let estimatedHours: Double?
    let actualHours: Double?
    let projectId: String?
}

private struct UpdateTaskRequest: Decodable {
    let content: String?
    let isDone: Bool?
    let priority: Int?
    let dueDate: String?
    let clearDueDate: Bool?
    let estimatedHours: Double?
    let actualHours: Double?
    let projectId: String?
}

private struct CreateClientRequest: Decodable {
    let name: String
    let industry: String?
}

private struct CreateProjectRequest: Decodable {
    let title: String
    let projectDescription: String?
    let clientId: String?
    let budget: Double?
    let deadline: String?
    let accentHex: String?
}

private struct CreateNoteRequest: Decodable {
    let title: String
    let content: String?
    let projectId: String?
    let clientId: String?
}

private struct NotifyRequest: Decodable {
    let channel: String?
    let to: String?
    let message: String
    let priority: String?
}

private struct MemorySyncRequest: Decodable {
    let source: String
    let cursor: String?
    let items: [MemorySyncItem]
}

private struct MemorySyncItem: Decodable {
    let externalId: String
    let title: String?
    let content: String
    let projectId: String?
    let timestamp: String?
}

private struct MemoryChangeResponse: Encodable {
    let id: String
    let externalId: String?
    let title: String
    let content: String
    let projectId: String?
    let lastModified: String
}

private struct MemoryChangesEnvelope: Encodable {
    let source: String
    let since: String?
    let nextCursor: String
    let count: Int
    let items: [MemoryChangeResponse]
}

private struct AgentRunRequest: Decodable {
    let name: String
    let goal: String
    let inputJSON: String?
    let rollbackReference: String?
    let idempotencyKey: String?
}

private struct AgentRunResponse: Encodable {
    let id: String
    let name: String
    let goal: String
    let status: String
    let output: String?
    let retryCount: Int
    let deadLettered: Bool
    let rollbackReference: String?
    let idempotencyKey: String?
    let startedAt: String
    let completedAt: String?
    let duplicate: Bool

    init(from run: AgentRun, duplicate: Bool) {
        self.id = run.id.uuidString
        self.name = run.name
        self.goal = run.goal
        self.status = run.status.rawValue
        self.output = run.output
        self.retryCount = run.retryCount
        self.deadLettered = run.deadLettered
        self.rollbackReference = run.rollbackReference
        self.idempotencyKey = run.idempotencyKey
        self.startedAt = run.startedAt.iso8601
        self.completedAt = run.completedAt?.iso8601
        self.duplicate = duplicate
    }
}

private struct IntegrationEventResponse: Encodable {
    let id: String
    let eventType: String
    let source: String
    let direction: String
    let status: String
    let idempotencyKey: String?
    let relatedRunID: String?
    let payloadJSON: String
    let createdAt: String
    let processedAt: String?

    init(from event: IntegrationEvent) {
        self.id = event.id.uuidString
        self.eventType = event.eventType
        self.source = event.source
        self.direction = event.direction.rawValue
        self.status = event.status.rawValue
        self.idempotencyKey = event.idempotencyKey
        self.relatedRunID = event.relatedRunID
        self.payloadJSON = event.payloadJSON
        self.createdAt = event.createdAt.iso8601
        self.processedAt = event.processedAt?.iso8601
    }
}

private struct ClientResponse: Encodable {
    let id: String
    let name: String
    let industry: String
    let activeProjectCount: Int
    let projectIDs: [String]
}

private struct ProjectResponse: Encodable {
    let id: String
    let title: String
    let status: String
    let clientID: String?
    let clientName: String?
    let budget: Double
    let deadline: String?
    let activeTaskCount: Int
}

private struct TaskResponse: Encodable {
    let id: String
    let content: String
    let isDone: Bool
    let priority: Int
    let dueDate: String?
    let estimatedHours: Double
    let actualHours: Double
    let projectID: String?
    let projectTitle: String?

    init(
        id: String,
        content: String,
        isDone: Bool,
        priority: Int,
        dueDate: String?,
        estimatedHours: Double,
        actualHours: Double,
        projectID: String?,
        projectTitle: String?
    ) {
        self.id = id
        self.content = content
        self.isDone = isDone
        self.priority = priority
        self.dueDate = dueDate
        self.estimatedHours = estimatedHours
        self.actualHours = actualHours
        self.projectID = projectID
        self.projectTitle = projectTitle
    }

    init(from task: AgencyTask) {
        self.id = task.id.uuidString
        self.content = task.content
        self.isDone = task.isDone
        self.priority = task.priority
        self.dueDate = task.dueDate?.iso8601
        self.estimatedHours = task.estimatedHours
        self.actualHours = task.actualHours
        self.projectID = task.project?.id.uuidString
        self.projectTitle = task.project?.title
    }
}

// MARK: - HTTP Helpers

private struct HTTPRequest {
    let method: String
    let path: String
    let queryItems: [String: String]
    let headers: [String: String]
    let body: Data

    var idempotencyKey: String? {
        headers["idempotency-key"]?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var taskIDFromPath: String? {
        guard method == "PATCH" else { return nil }
        let components = path.split(separator: "/").map(String.init)
        guard components.count == 3, components[0] == "api", components[1] == "tasks" else {
            return nil
        }
        return components[2]
    }

    var agentRunIDFromPath: String? {
        guard method == "GET" else { return nil }
        let components = path.split(separator: "/").map(String.init)
        guard components.count == 4, components[0] == "api", components[1] == "agents", components[2] == "runs" else {
            return nil
        }
        return components[3]
    }

    static func parse(_ raw: Data) -> HTTPRequest? {
        guard let rawString = String(data: raw, encoding: .utf8) else { return nil }

        let separator = "\r\n\r\n"
        let parts = rawString.components(separatedBy: separator)
        guard let headerPart = parts.first else { return nil }

        let bodyString = parts.dropFirst().joined(separator: separator)
        let bodyData = Data(bodyString.utf8)

        let lines = headerPart.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }

        let requestBits = requestLine.split(separator: " ").map(String.init)
        guard requestBits.count >= 2 else { return nil }

        let method = requestBits[0].uppercased()
        let target = requestBits[1]

        let url = URL(string: "http://localhost\(target)")
        let path = url?.path ?? "/"

        var queryItems: [String: String] = [:]
        if let items = URLComponents(string: "http://localhost\(target)")?.queryItems {
            for item in items {
                queryItems[item.name] = item.value ?? ""
            }
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let split = line.split(separator: ":", maxSplits: 1).map(String.init)
            if split.count == 2 {
                headers[split[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] =
                    split[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return HTTPRequest(method: method, path: path, queryItems: queryItems, headers: headers, body: bodyData)
    }

    func decodeJSON<T: Decodable>() throws -> T {
        try JSONDecoder().decode(T.self, from: body)
    }

    func decodeJSONDictionary() throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: body, options: [])
        guard let dictionary = object as? [String: Any] else {
            throw APICommandError(status: 400, message: "JSON body must be an object")
        }
        return dictionary
    }
}

private struct HTTPResponse {
    let status: Int
    let reason: String
    let contentType: String
    let body: Data

    static func json(status: Int, body: [String: Any]) -> HTTPResponse {
        let data = (try? JSONSerialization.data(withJSONObject: body, options: [])) ?? Data("{}".utf8)
        return HTTPResponse(status: status, reason: Self.reason(for: status), contentType: "application/json", body: data)
    }

    static func encodable<T: Encodable>(_ status: Int, _ payload: T) -> HTTPResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(payload)) ?? Data("{}".utf8)
        return HTTPResponse(status: status, reason: reason(for: status), contentType: "application/json", body: data)
    }

    static func raw(status: Int, contentType: String, body: Data) -> HTTPResponse {
        HTTPResponse(status: status, reason: reason(for: status), contentType: contentType, body: body)
    }

    func serialized() -> Data {
        var header = "HTTP/1.1 \(status) \(reason)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Connection: close\r\n"
        header += "\r\n"

        return Data(header.utf8) + body
    }

    private static func reason(for code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 201: return "Created"
        case 202: return "Accepted"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 404: return "Not Found"
        case 409: return "Conflict"
        case 422: return "Unprocessable Entity"
        case 500: return "Internal Server Error"
        case 503: return "Service Unavailable"
        default: return "OK"
        }
    }
}

private extension Date {
    var iso8601: String {
        ISO8601DateFormatter.cached.string(from: self)
    }
}

private extension String {
    var asISODate: Date? {
        if let exact = ISO8601DateFormatter.cached.date(from: self) {
            return exact
        }
        return ISO8601DateFormatter.fallback.date(from: self)
    }
}

private extension ISO8601DateFormatter {
    static let cached: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let fallback: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

#endif
