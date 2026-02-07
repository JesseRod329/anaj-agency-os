//
//  GlobalSearchView.swift
//  ANAJ
//
//  Spotlight-style global search (Cmd+K)
//

#if os(macOS)
import SwiftUI
import SwiftData

struct GlobalSearchView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Project.title) private var projects: [Project]
    @Query(sort: \Client.name) private var clients: [Client]
    @Query(sort: \Note.lastModified, order: .reverse) private var notes: [Note]
    @Query(sort: \AgencyTask.content) private var tasks: [AgencyTask]
    @Query(sort: \Decision.timestamp, order: .reverse) private var decisions: [Decision]
    
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.5))
                
                TextField("Search anything...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .focused($isSearchFocused)
                    .onSubmit { performAction() }
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
                
                Text("esc")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(16)
            .background(.ultraThinMaterial)
            
            Divider().background(.white.opacity(0.1))
            
            // Results
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if filteredResults.isEmpty && !searchText.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.white.opacity(0.2))
                                    Text("No results found")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                .padding(40)
                                Spacer()
                            }
                        } else {
                            ForEach(Array(filteredResults.enumerated()), id: \.element.id) { index, result in
                                SearchResultRow(
                                    result: result,
                                    isSelected: index == selectedIndex
                                )
                                .id(index)
                                .onTapGesture {
                                    selectedIndex = index
                                    performAction()
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 400)
                .onChange(of: selectedIndex) { _, newValue in
                    withAnimation { proxy.scrollTo(newValue, anchor: .center) }
                }
            }
            
            // Footer hints
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                    Image(systemName: "arrow.down")
                    Text("Navigate")
                }
                HStack(spacing: 4) {
                    Image(systemName: "return")
                    Text("Open")
                }
                Spacer()
            }
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.3))
            .padding(12)
            .background(Color.black.opacity(0.3))
        }
        .frame(width: 600)
        .background(.ultraThinMaterial.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 40)
        .onAppear { isSearchFocused = true }
        .onKeyPress(.upArrow) { navigateUp(); return .handled }
        .onKeyPress(.downArrow) { navigateDown(); return .handled }
        .onKeyPress(.escape) { isPresented = false; return .handled }
    }
    
    // MARK: - Search Results
    
    private var filteredResults: [SearchResult] {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        var results: [SearchResult] = []
        
        // Quick actions (always show when empty)
        if query.isEmpty {
            results.append(SearchResult(type: .action, title: "New Project", subtitle: "Create a new project", icon: "folder.badge.plus", color: .blue))
            results.append(SearchResult(type: .action, title: "New Note", subtitle: "Create a new note", icon: "doc.badge.plus", color: .orange))
            results.append(SearchResult(type: .action, title: "New Task", subtitle: "Add a task to inbox", icon: "plus.circle", color: .green))
            results.append(SearchResult(type: .action, title: "New Client", subtitle: "Add a new client", icon: "person.badge.plus", color: .purple))
            return results
        }
        
        // Search Projects
        for project in projects.filter({ !$0.isArchived }) {
            if project.title.lowercased().contains(query) {
                results.append(SearchResult(
                    type: .project,
                    title: project.title,
                    subtitle: project.client?.name ?? "No client",
                    icon: "folder.fill",
                    color: Color(hex: project.accentHex) ?? .blue,
                    id: project.id
                ))
            }
        }
        
        // Search Clients
        for client in clients.filter({ !$0.isArchived }) {
            if client.name.lowercased().contains(query) || client.industry.lowercased().contains(query) {
                results.append(SearchResult(
                    type: .client,
                    title: client.name,
                    subtitle: client.industry,
                    icon: "person.fill",
                    color: Color(hex: client.brandHex) ?? .purple,
                    id: client.id
                ))
            }
        }
        
        // Search Notes
        for note in notes.filter({ !$0.isArchived }) {
            if note.title.lowercased().contains(query) || note.content.lowercased().contains(query) {
                results.append(SearchResult(
                    type: .note,
                    title: note.title,
                    subtitle: String(note.content.prefix(50)),
                    icon: "doc.text.fill",
                    color: .orange,
                    id: note.id
                ))
            }
        }
        
        // Search Tasks  
        for task in tasks.filter({ !$0.isArchived }) {
            if task.content.lowercased().contains(query) {
                results.append(SearchResult(
                    type: .task,
                    title: task.content,
                    subtitle: task.project?.title ?? "Inbox",
                    icon: task.isDone ? "checkmark.circle.fill" : "circle",
                    color: .green,
                    id: task.id
                ))
            }
        }
        
        return Array(results.prefix(15))
    }
    
    private func navigateUp() {
        if selectedIndex > 0 { selectedIndex -= 1 }
    }
    
    private func navigateDown() {
        if selectedIndex < filteredResults.count - 1 { selectedIndex += 1 }
    }
    
    private func performAction() {
        guard selectedIndex < filteredResults.count else { return }
        let result = filteredResults[selectedIndex]
        
        switch result.type {
        case .action:
            handleAction(result.title)
        default:
            // Close search and navigate (would need navigation callback)
            break
        }
        
        isPresented = false
    }
    
    private func handleAction(_ action: String) {
        switch action {
        case "New Project":
            let project = Project(title: "Untitled Project")
            modelContext.insert(project)
        case "New Note":
            let note = Note(title: "New Note")
            modelContext.insert(note)
        case "New Task":
            let task = AgencyTask(content: "New Task")
            modelContext.insert(task)
        case "New Client":
            let client = Client(name: "New Client")
            modelContext.insert(client)
        default:
            break
        }
        try? modelContext.save()
    }
}

// MARK: - Search Result Model

struct SearchResult: Identifiable {
    let id: UUID
    let type: SearchResultType
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    init(type: SearchResultType, title: String, subtitle: String, icon: String, color: Color, id: UUID = UUID()) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
    }
}

enum SearchResultType {
    case project, client, note, task, decision, action
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: SearchResult
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.icon)
                .font(.system(size: 16))
                .foregroundStyle(result.color)
                .frame(width: 32, height: 32)
                .background(result.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(result.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(result.type.label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
    }
}

extension SearchResultType {
    var label: String {
        switch self {
        case .project: return "Project"
        case .client: return "Client"
        case .note: return "Note"
        case .task: return "Task"
        case .decision: return "Decision"
        case .action: return "Action"
        }
    }
}
#endif
