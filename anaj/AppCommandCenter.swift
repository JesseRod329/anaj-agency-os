#if os(macOS)
import Foundation
import SwiftUI
import Combine

@MainActor
final class AppCommandCenter: ObservableObject {
    static let shared = AppCommandCenter()

    @Published var route: SidebarRoute = .dashboard
    @Published var refreshToken = UUID()
    @Published var projectNavigationTarget: UUID?
    @Published var pendingProjectDraft: ProjectDraft?

    private init() {}

    struct ProjectDraft: Sendable {
        let title: String
        let projectDescription: String
        let budget: Double?
        let clientId: UUID?
    }

    func setRoute(_ route: SidebarRoute) {
        self.route = route
    }

    func triggerRefresh() {
        refreshToken = UUID()
        NotificationCenter.default.post(name: .anajDataDidChange, object: nil)
    }

    func handleExternalCommand(command: String, params: [String: Any]) throws -> [String: Any] {
        let normalized = command.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch normalized {
        case "navigate":
            let rawTarget = (params["target"] as? String) ?? (params["view"] as? String) ?? ""
            guard let resolvedRoute = resolveRoute(rawTarget) else {
                throw AppCommandError("Unsupported navigation target: \(rawTarget)")
            }
            route = resolvedRoute

            if let projectIdString = (params["projectId"] as? String) ?? (params["projectID"] as? String),
               let projectID = UUID(uuidString: projectIdString) {
                projectNavigationTarget = projectID
            }

            return [
                "route": resolvedRoute.rawValue,
                "projectId": projectNavigationTarget?.uuidString ?? ""
            ]

        case "refresh":
            triggerRefresh()
            return ["refreshed": true]

        case "fillform":
            let formName = ((params["form"] as? String) ?? "").lowercased()
            guard formName == "createprojectform" else {
                throw AppCommandError("Unsupported form target: \(formName)")
            }

            guard let data = params["data"] as? [String: Any] else {
                throw AppCommandError("fillForm requires a data object")
            }

            let title = (data["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if title.isEmpty {
                throw AppCommandError("Project draft title is required")
            }

            let projectDescription = (data["description"] as? String) ?? (data["projectDescription"] as? String) ?? ""
            let budget = data["budget"] as? Double

            var clientID: UUID?
            if let clientIdString = data["clientId"] as? String {
                clientID = UUID(uuidString: clientIdString)
            }

            pendingProjectDraft = ProjectDraft(
                title: title,
                projectDescription: projectDescription,
                budget: budget,
                clientId: clientID
            )
            route = .projects

            return [
                "queued": true,
                "form": "CreateProjectForm",
                "title": title
            ]

        default:
            throw AppCommandError("Unsupported app command: \(command)")
        }
    }

    private func resolveRoute(_ rawTarget: String) -> SidebarRoute? {
        let cleaned = rawTarget
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "view", with: "")
            .replacingOccurrences(of: " ", with: "")

        if cleaned.isEmpty { return nil }

        switch cleaned {
        case "dashboard", "dashboardview":
            return .dashboard
        case "projects", "projectdetail", "projectdetailview", "project", "projectsview":
            return .projects
        case "promptstudio", "studio", "promptstudioview":
            return .studio
        case "insights":
            return .insights
        case "clients", "client":
            return .clients
        case "knowledge", "notes", "note":
            return .knowledge
        case "memory", "decisionlog":
            return .memory
        case "ledger":
            return .ledger
        case "team":
            return .team
        case "calendar":
            return .calendar
        case "archive":
            return .archive
        case "settings":
            return .settings
        default:
            return nil
        }
    }
}

private struct AppCommandError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}
#endif
