#if os(macOS)
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Export Helper (Moved to top level for concurrency safety)
struct WorkspaceExport: Sendable {
    let clients: Int
    let projects: Int
    let tasks: Int
    let timestamp: Date
}

extension WorkspaceExport: Codable {
    enum CodingKeys: String, CodingKey {
        case clients, projects, tasks, timestamp
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clients = try container.decode(Int.self, forKey: .clients)
        projects = try container.decode(Int.self, forKey: .projects)
        tasks = try container.decode(Int.self, forKey: .tasks)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(clients, forKey: .clients)
        try container.encode(projects, forKey: .projects)
        try container.encode(tasks, forKey: .tasks)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: WorkspaceExport
    
    init(data: WorkspaceExport) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        let decoder = JSONDecoder()
        let fileData = configuration.file.regularFileContents ?? Data()
        self.data = try decoder.decode(WorkspaceExport.self, from: fileData)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let encodedData = try encoder.encode(self.data)
        return FileWrapper(regularFileWithContents: encodedData)
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case integrations = "Integrations"
    case data = "Data & Sync"
    case about = "About"
    
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .general: return "person.crop.circle"
        case .appearance: return "paintbrush.fill"
        case .integrations: return "network"
        case .data: return "server.rack"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    // --- General Prefs ---
    @AppStorage("userName") private var userName = "Jesse"
    @AppStorage("userRole") private var userRole = "Creative Director"
    
    // --- Appearance Prefs ---
    @AppStorage("accentColor") private var accentColor = "#5AE6FF"
    @AppStorage("glassOpacity") private var glassOpacity = 0.3
    @AppStorage("backgroundStyle") private var bgStyle: BackgroundStyle = .classic
    @AppStorage("appTheme") private var appTheme = "Dark"
    
    // --- Integration Prefs (Synced with Prompt Studio) ---
    @AppStorage("openAIKey") private var openAIKey = ""
    @AppStorage("googleAPIKey") private var googleAPIKey = ""
    @AppStorage("ollamaBaseURL") private var ollamaBaseURL = "http://localhost:11434/api"
    @AppStorage("selectedAIProvider") private var selectedProvider = PromptStudioView.AIProvider.local
    
    @State private var selectedTab: SettingsTab = .general
    @State private var cloudManager = CloudKitManager()
    @State private var hasInitializedCloud = false
    
    @Environment(\.modelContext) private var modelContext
    @Query private var clients: [Client]
    @Query private var projects: [Project]
    @Query private var tasks: [AgencyTask]
    
    // Alert States
    @State private var showingDeleteAlert = false
    @State private var isResetting = false
    @State private var showingExport = false
    @State private var exportDocument: JSONDocument?
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14))
                                .frame(width: 20)
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            if selectedTab == tab {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .opacity(0.5)
                            }
                        }
                        .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.6))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(selectedTab == tab ? 0.1 : 0))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                }
                
                Spacer()
                
                // Mini Profile
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: accentColor) ?? .blue)
                        .frame(width: 32, height: 32)
                        .overlay(Text(String(userName.prefix(1))).font(.caption).bold().foregroundStyle(.black))
                    
                    VStack(alignment: .leading) {
                        Text(userName)
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.white)
                        Text(userRole)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.05))
            }
            .frame(width: 220)
            .background(Color.black.opacity(0.2))
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Main Content Area
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    
                    // Tab Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedTab.rawValue)
                            .font(.largeTitle)
                            .bold()
                            .foregroundStyle(.white)
                        
                        Text(tabDescription)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.bottom, 20)
                    
                    // Dynamic Content
                    Group {
                        switch selectedTab {
                        case .general: generalSettings
                        case .appearance: appearanceSettings
                        case .integrations: integrationsSettings
                        case .data: dataSettings
                        case .about: aboutSettings
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                .padding(40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if !hasInitializedCloud {
                cloudManager.checkAccountStatus()
                hasInitializedCloud = true
            }
        }
        .fileExporter(
            isPresented: $showingExport,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "ANAJ_Backup_\(Date().formatted(date: .numeric, time: .omitted)).json"
        ) { result in
            // Handle result
        }
    }
    
    var tabDescription: String {
        switch selectedTab {
        case .general: "Manage your personal profile and preferences."
        case .appearance: "Customize the look and feel of your workspace."
        case .integrations: "Connect external AI services and tools."
        case .data: "Manage database, sync status, and backups."
        case .about: "Version information and support."
        }
    }
    
    // MARK: - Sections
    
    var generalSettings: some View {
        VStack(spacing: 25) {
            SettingsCard(title: "Profile") {
                VStack(spacing: 20) {
                    SettingsInput(label: "Display Name", text: $userName, icon: "person")
                    SettingsInput(label: "Job Title", text: $userRole, icon: "briefcase")
                }
            }
        }
    }
    
    var appearanceSettings: some View {
        VStack(spacing: 25) {
            SettingsCard(title: "Visual Theme") {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("Base Theme")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Picker("", selection: $appTheme) {
                            Text("Dark").tag("Dark")
                            Text("Light").tag("Light")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                    
                    Divider().background(.white.opacity(0.1))
                    
                    Text("Liquid Style")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 15) {
                        ForEach(BackgroundStyle.allCases) { style in
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    bgStyle = style
                                    // Auto-theme: Set accent color to match background
                                    if let primaryColor = style.colors(for: appTheme).first, let hex = primaryColor.toHex() {
                                        accentColor = hex
                                    }
                                }
                            }) {
                                VStack {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(LinearGradient(colors: style.colors(for: appTheme).prefix(3).map { $0 }, startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(height: 70)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white, lineWidth: bgStyle == style ? 3 : 0)
                                            )
                                        
                                        if bgStyle == style {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(.white)
                                                .shadow(radius: 2)
                                        }
                                    }
                                    .shadow(color: style.colors(for: appTheme).first?.opacity(0.5) ?? .clear, radius: bgStyle == style ? 10 : 0)
                                    .scaleEffect(bgStyle == style ? 1.05 : 1.0)
                                    
                                    Text(style.rawValue)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(bgStyle == style ? .white : .white.opacity(0.6))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            SettingsCard(title: "Interface") {
                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(Color(hex: accentColor) ?? .blue)
                        Text("Accent Color")
                            .foregroundStyle(.white)
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: accentColor) ?? .blue },
                            set: { accentColor = $0.toHex() ?? "#5AE6FF" }
                        ))
                        .labelsHidden()
                    }
                    
                    Divider().background(.white.opacity(0.1))
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "square.stack.3d.down.right.fill")
                                .foregroundStyle(.white.opacity(0.7))
                            Text("Glass Transparency")
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(Int(glassOpacity * 100))%")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Slider(value: $glassOpacity, in: 0.1...0.9)
                            .tint(Color(hex: accentColor) ?? .blue)
                    }
                }
            }
        }
    }
    
    var integrationsSettings: some View {
        VStack(spacing: 25) {
            SettingsCard(title: "Local Intelligence (Ollama)") {
                VStack(alignment: .leading, spacing: 15) {
                    SettingsInput(label: "Ollama Base URL", text: $ollamaBaseURL, icon: "network")
                    Text("Default: http://localhost:11434/api")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            
            SettingsCard(title: "Cloud Models") {
                VStack(spacing: 20) {
                    SecureSettingsInput(label: "OpenAI API Key", text: $openAIKey, icon: "key.fill")
                    SecureSettingsInput(label: "Google Gemini API Key", text: $googleAPIKey, icon: "key.fill")
                }
            }
        }
    }
    
    var dataSettings: some View {
        VStack(spacing: 25) {
            SettingsCard(title: "Sync Status") {
                HStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(cloudManager.statusColor.opacity(0.2))
                            .frame(width: 50, height: 50)
                        Image(systemName: cloudManager.statusIcon)
                            .font(.title2)
                            .foregroundStyle(cloudManager.statusColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cloudManager.statusText)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(cloudManager.userName ?? "Not signed in")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Button { cloudManager.checkAccountStatus() } label: {
                        Image(systemName: "arrow.clockwise")
                            .padding(8)
                            .background(.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            SettingsCard(title: "Maintenance") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Backup Workspace")
                            .foregroundStyle(.white)
                        Text("Export all data to JSON")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Button("Export") {
                        prepareExport()
                    }
                    .buttonStyle(.bordered)
                }
                
                Divider().background(.white.opacity(0.1))
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Reset Workspace")
                            .foregroundStyle(.red)
                        Text("Delete all data permanently")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Button("Reset") {
                        showingDeleteAlert = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
        }
    }
    
    var aboutSettings: some View {
        VStack(spacing: 25) {
            SettingsCard(title: "Application") {
                HStack {
                    Image(systemName: "app.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                        .foregroundStyle(Color(hex: accentColor) ?? .blue)
                    
                    VStack(alignment: .leading) {
                        Text("ANAJ OS")
                            .font(.title3)
                            .bold()
                            .foregroundStyle(.white)
                        Text("v1.0.0 (Build 2025.1)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Logic
    
    private func prepareExport() {
        let exportData = WorkspaceExport(
            clients: clients.count,
            projects: projects.count,
            tasks: tasks.count,
            timestamp: Date()
        )
        // In a real app, we'd serialize the actual arrays. 
        // For now, exporting a summary to prove the concept.
        exportDocument = JSONDocument(data: exportData)
        showingExport = true
    }
    
    private func resetData() {
        isResetting = true
        // Safe reset logic from previous iteration
        Task {
            do {
                let taskDescriptor = FetchDescriptor<AgencyTask>()
                let allTasks = try modelContext.fetch(taskDescriptor)
                for task in allTasks { modelContext.delete(task) }
                
                let projDescriptor = FetchDescriptor<Project>()
                let allProjs = try modelContext.fetch(projDescriptor)
                for proj in allProjs { modelContext.delete(proj) }
                
                try modelContext.save()
                isResetting = false
            } catch {
                isResetting = false
            }
        }
    }
}

// MARK: - Components

struct SettingsCard<Content: View>: View {
    let title: String
    let content: () -> Content
    
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .kerning(1)
            
            VStack {
                content()
            }
            .padding(20)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

struct SettingsInput: View {
    let label: String
    @Binding var text: String
    var icon: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
            
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundStyle(.white.opacity(0.3))
                }
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
            }
            .padding(12)
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct SecureSettingsInput: View {
    let label: String
    @Binding var text: String
    var icon: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
            
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundStyle(.white.opacity(0.3))
                }
                SecureField("", text: $text)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
            }
            .padding(12)
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct StatBox: View {
    let label: String
    let value: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
}
#endif