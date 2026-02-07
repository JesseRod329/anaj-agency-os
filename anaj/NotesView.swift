import SwiftUI
import SwiftData

struct NotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.lastModified, order: .reverse) private var notes: [Note]
    @Query(sort: \Project.title) private var projects: [Project]
    @Query(sort: \Client.name) private var clients: [Client]
    
    @AppStorage("ollamaBaseURL") private var ollamaBaseURL = "http://localhost:11434/api"
    @AppStorage("selectedLocalModel") private var selectedLocalModel = "llama3.2"
    
    @State private var selectedNote: Note?
    @State private var searchText = ""
    
    var filteredNotes: [Note] {
        if searchText.isEmpty { return notes }
        return notes.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.content.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar for Notes
            VStack(alignment: .leading, spacing: 20) {
                Text("Knowledge Base")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white.opacity(0.4))
                    TextField("Search notes...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                }
                .padding(10)
                .background(.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 20)
                
                Button(action: createNote) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New Note")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(filteredNotes) { note in
                            NoteListRow(note: note, isSelected: selectedNote?.id == note.id) {
                                selectedNote = note
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .frame(width: 300)
            .background(.black.opacity(0.1))
            
            // Editor Area
            Group {
                if let note = selectedNote {
                    NoteEditor(
                        note: note, 
                        projects: projects, 
                        clients: clients,
                        ollamaBaseURL: ollamaBaseURL,
                        modelName: selectedLocalModel
                    )
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "note.text")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.05))
                        Text("Select or create a note")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.2))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(.black.opacity(0.05))
        }
    }
    
    private func createNote() {
        let newNote = Note(title: "New Note", content: "")
        modelContext.insert(newNote)
        try? modelContext.save()
        selectedNote = newNote
    }
}

struct NoteListRow: View {
    let note: Note
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if note.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(isSelected ? .black.opacity(0.6) : .yellow)
                        }
                        
                        Text(note.title.isEmpty ? "Untitled" : note.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isSelected ? .black : .white)
                        
                        // Show indicator if note has been analyzed
                        if note.lastAnalyzedAt != nil {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                                .foregroundStyle(isSelected ? .black.opacity(0.5) : .yellow.opacity(0.7))
                        }
                    }
                    
                    Text(note.content.prefix(60).replacingOccurrences(of: "\n", with: " "))
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? .black.opacity(0.6) : .white.opacity(0.4))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Show linked indicator
                if note.project != nil || note.client != nil {
                    Image(systemName: "link")
                        .font(.system(size: 10))
                        .foregroundStyle(isSelected ? .black.opacity(0.4) : .white.opacity(0.3))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(isSelected ? Color.white : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: duplicateNote) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            
            Button(action: { note.isPinned.toggle(); try? modelContext.save() }) {
                Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
            }
            
            Divider()
            
            Button(action: archiveNote) {
                Label("Archive", systemImage: "archivebox")
            }
            
            Button(role: .destructive, action: deleteNote) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func duplicateNote() {
        let duplicate = Note(
            title: "\(note.title) (Copy)",
            content: note.content,
            createdAt: Date()
        )
        duplicate.project = note.project
        duplicate.client = note.client
        duplicate.tags = note.tags
        modelContext.insert(duplicate)
        try? modelContext.save()
    }
    
    private func archiveNote() {
        withAnimation { note.isArchived = true }
        try? modelContext.save()
    }
    
    private func deleteNote() {
        modelContext.delete(note)
        try? modelContext.save()
    }
}

struct NoteEditor: View {
    @Bindable var note: Note
    let projects: [Project]
    let clients: [Client]
    let ollamaBaseURL: String
    let modelName: String
    
    @Environment(\.modelContext) private var modelContext
    @State private var isPreview = false
    @State private var showIntelligencePanel = true
    
    // Intelligence
    @StateObject private var extractionService: NoteExtractionService
    @State private var currentExtraction: NoteExtraction?
    
    init(note: Note, projects: [Project], clients: [Client], ollamaBaseURL: String, modelName: String) {
        self._note = Bindable(wrappedValue: note)
        self.projects = projects
        self.clients = clients
        self.ollamaBaseURL = ollamaBaseURL
        self.modelName = modelName
        self._extractionService = StateObject(wrappedValue: NoteExtractionService(ollamaBaseURL: ollamaBaseURL, modelName: modelName))
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Main Editor
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 16) {
                    TextField("Note Title", text: $note.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    // Analyze Button
                    Button(action: analyzeNote) {
                        HStack(spacing: 6) {
                            if extractionService.isAnalyzing {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.yellow)
                            } else {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.yellow)
                            }
                            Text(extractionService.isAnalyzing ? "Analyzing..." : "Analyze")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            extractionService.isAnalyzing 
                                ? Color.yellow.opacity(0.2) 
                                : Color.yellow.opacity(0.15)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(extractionService.isAnalyzing || note.content.isEmpty)
                    
                    // View Mode Toggle
                    Picker("", selection: $isPreview) {
                        Image(systemName: "pencil").tag(false)
                        Image(systemName: "eye").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                    
                    // Status Indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.green.opacity(0.8))
                            .frame(width: 6, height: 6)
                        Text("Autosaved")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.05))
                    .clipShape(Capsule())
                    
                    // Link to Project/Client
                    Menu {
                        Menu("Link Project") {
                            Button("None") { 
                                note.project = nil 
                                note.linkedFromExtraction = false
                            }
                            ForEach(projects) { project in
                                Button(project.title) { note.project = project }
                            }
                        }
                        Menu("Link Client") {
                            Button("None") { 
                                note.client = nil
                                note.linkedFromExtraction = false
                            }
                            ForEach(clients) { client in
                                Button(client.name) { note.client = client }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                            Text(linkStatus)
                            if note.linkedFromExtraction {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.yellow)
                            }
                        }
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    
                    // Toggle Intelligence Panel
                    Button(action: { withAnimation { showIntelligencePanel.toggle() } }) {
                        Image(systemName: showIntelligencePanel ? "sidebar.right" : "sidebar.left")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 20)
                
                Divider().background(.white.opacity(0.1))
                
                // Editor Content
                if isPreview {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 15) {
                            Text(LocalizedStringKey(note.content))
                                .font(.system(size: 16, design: .serif))
                                .foregroundStyle(.white.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(30)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TextEditor(text: $note.content)
                        .font(.system(size: 16, design: .serif))
                        .scrollContentBackground(.hidden)
                        .padding(30)
                        .foregroundStyle(.white.opacity(0.9))
                        .onChange(of: note.content) {
                            note.lastModified = Date()
                        }
                }
                
                // Error Banner
                if let error = extractionService.lastError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Button("Dismiss") {
                            extractionService.lastError = nil
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.orange)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.15))
                }
            }
            
            // Intelligence Panel
            if showIntelligencePanel {
                ExtractedEntitiesPanel(
                    extraction: currentExtraction,
                    clients: clients,
                    projects: projects,
                    onAcceptClient: acceptClientSuggestion,
                    onAcceptProject: acceptProjectSuggestion,
                    onAcceptEntity: acceptEntity,
                    onDismissEntity: dismissEntity,
                    onCreateTask: createTaskFromEntity
                )
            }
        }
        .onAppear {
            loadExistingExtraction()
        }
        .onChange(of: note.id) {
            loadExistingExtraction()
        }
    }
    
    private var linkStatus: String {
        if let p = note.project { return p.title }
        if let c = note.client { return c.name }
        return "Link Context"
    }
    
    // MARK: - Intelligence Actions
    
    private func analyzeNote() {
        Task {
            if let extraction = await extractionService.analyzeNote(note, clients: Array(clients), projects: Array(projects)) {
                currentExtraction = extraction
                saveExtraction(extraction)
                note.lastAnalyzedAt = Date()
                try? modelContext.save()
            }
        }
    }
    
    private func loadExistingExtraction() {
        guard let json = note.extractedEntitiesJSON,
              let data = json.data(using: .utf8),
              let extraction = try? JSONDecoder().decode(NoteExtraction.self, from: data) else {
            currentExtraction = nil
            return
        }
        currentExtraction = extraction
    }
    
    private func saveExtraction(_ extraction: NoteExtraction) {
        if let data = try? JSONEncoder().encode(extraction),
           let json = String(data: data, encoding: .utf8) {
            note.extractedEntitiesJSON = json
            try? modelContext.save()
        }
    }
    
    private func acceptClientSuggestion(_ clientId: UUID) {
        guard let client = clients.first(where: { $0.id == clientId }) else { return }
        note.client = client
        note.linkedFromExtraction = true
        
        // Update extraction to remove suggestion
        if var extraction = currentExtraction {
            extraction.suggestedClientId = nil
            currentExtraction = extraction
            saveExtraction(extraction)
        }
        try? modelContext.save()
    }
    
    private func acceptProjectSuggestion(_ projectId: UUID) {
        guard let project = projects.first(where: { $0.id == projectId }) else { return }
        note.project = project
        note.linkedFromExtraction = true
        
        // Update extraction to remove suggestion
        if var extraction = currentExtraction {
            extraction.suggestedProjectId = nil
            currentExtraction = extraction
            saveExtraction(extraction)
        }
        try? modelContext.save()
    }
    
    private func acceptEntity(_ entity: ExtractedEntity) {
        guard var extraction = currentExtraction,
              let index = extraction.entities.firstIndex(where: { $0.id == entity.id }) else { return }
        
        // Actually create the record based on entity type
        switch entity.type {
        case .personMention:
            createClientFromEntity(entity)
            
        case .task:
            createTaskFromEntity(entity)
            
        case .decision:
            createDecisionFromEntity(entity)
            
        case .budget:
            applyBudgetFromEntity(entity)
            
        case .cost:
            // Costs are informational, just mark accepted
            break
            
        case .deadline:
            // Deadlines could update project deadline
            applyDeadlineFromEntity(entity)
        }
        
        // Mark as accepted
        extraction.entities[index].isAccepted = true
        currentExtraction = extraction
        saveExtraction(extraction)
    }
    
    private func dismissEntity(_ entity: ExtractedEntity) {
        guard var extraction = currentExtraction,
              let index = extraction.entities.firstIndex(where: { $0.id == entity.id }) else { return }
        
        extraction.entities[index].isDismissed = true
        currentExtraction = extraction
        saveExtraction(extraction)
    }
    
    private func createTaskFromEntity(_ entity: ExtractedEntity) {
        // Create a new task linked to the note's project
        let task = AgencyTask(
            content: entity.value,
            isDone: false,
            priority: 2,
            dueDate: entity.date,
            project: note.project
        )
        modelContext.insert(task)
        try? modelContext.save()
    }
    
    private func createClientFromEntity(_ entity: ExtractedEntity) {
        // Check if client already exists
        let existingClient = clients.first { 
            $0.name.lowercased() == entity.value.lowercased() 
        }
        
        if let client = existingClient {
            // Link note to existing client
            note.client = client
            note.linkedFromExtraction = true
        } else {
            // Create new client
            let newClient = Client(name: entity.value, industry: "")
            modelContext.insert(newClient)
            
            // Link note to new client
            note.client = newClient
            note.linkedFromExtraction = true
        }
        try? modelContext.save()
    }
    
    private func createDecisionFromEntity(_ entity: ExtractedEntity) {
        // Create a new decision record
        let decision = Decision(
            title: entity.value,
            context: entity.context,
            outcome: ""
        )
        decision.project = note.project
        modelContext.insert(decision)
        try? modelContext.save()
    }
    
    private func applyBudgetFromEntity(_ entity: ExtractedEntity) {
        // If note is linked to a project, update its budget
        if let project = note.project, let amount = entity.amount {
            project.budget = amount
            try? modelContext.save()
        }
    }
    
    private func applyDeadlineFromEntity(_ entity: ExtractedEntity) {
        // If note is linked to a project and entity has a date, update deadline
        if let project = note.project, let date = entity.date {
            project.deadline = date
            try? modelContext.save()
        }
    }
}
