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
                    "port": 18790
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
                print("ANAJ notify request: channel=\(input.channel ?? "default") to=\(input.to ?? "unknown") message=\(input.message)")
                return .json(status: 202, body: [
                    "status": "accepted",
                    "message": "Notification accepted for bridge dispatch"
                ])
            }

            return .json(status: 404, body: ["error": "Endpoint not found"])

        } catch {
            return .json(status: 500, body: ["error": error.localizedDescription])
        }
    }

    private func authorize(request: HTTPRequest) -> Bool {
#if DEBUG
        return true
#else
        let required = ProcessInfo.processInfo.environment["ANAJ_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !required.isEmpty else { return false }
        return request.headers["x-anaj-key"] == required
#endif
    }
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

    var taskIDFromPath: String? {
        guard method == "PATCH" else { return nil }
        let components = path.split(separator: "/").map(String.init)
        guard components.count == 3, components[0] == "api", components[1] == "tasks" else {
            return nil
        }
        return components[2]
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
}

private struct HTTPResponse {
    let status: Int
    let reason: String
    let body: Data

    static func json(status: Int, body: [String: Any]) -> HTTPResponse {
        let data = (try? JSONSerialization.data(withJSONObject: body, options: [])) ?? Data("{}".utf8)
        return HTTPResponse(status: status, reason: Self.reason(for: status), body: data)
    }

    static func encodable<T: Encodable>(_ status: Int, _ payload: T) -> HTTPResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(payload)) ?? Data("{}".utf8)
        return HTTPResponse(status: status, reason: reason(for: status), body: data)
    }

    func serialized() -> Data {
        var header = "HTTP/1.1 \(status) \(reason)\r\n"
        header += "Content-Type: application/json\r\n"
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
        case 422: return "Unprocessable Entity"
        case 500: return "Internal Server Error"
        case 503: return "Service Unavailable"
        default: return "OK"
        }
    }
}

private extension Date {
    var iso8601: String {
        ISO8601DateFormatter().string(from: self)
    }
}

private extension String {
    var asISODate: Date? {
        ISO8601DateFormatter().date(from: self)
    }
}

#endif
