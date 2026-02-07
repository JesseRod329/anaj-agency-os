#if os(iOS)
import SwiftUI
import SwiftData

// MARK: - iOS Root View
struct iOSRootView: View {
    @State private var selectedTab: SidebarRoute = .dashboard
    @State private var showingCreateSheet = false
    
    var body: some View {
        ZStack {
            // Full Screen Background
            LiquidBackground()
                .ignoresSafeArea()
            
            // Content
            VStack(spacing: 0) {
                Group {
                    switch selectedTab {
                    case .dashboard:
                        iOSDashboardView()
                    case .projects:
                        iOSProjectsView()
                    case .calendar:
                        CalendarView()
                    case .settings:
                        iOSSettingsView()
                    default:
                        iOSDashboardView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Custom Tab Bar
                CustomTabBar(selectedTab: $selectedTab, onCreate: { showingCreateSheet = true })
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingCreateSheet) {
            CreateActionSheet()
        }
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: SidebarRoute
    var onCreate: () -> Void
    
    var body: some View {
        HStack {
            TabBarButton(icon: "tray.fill", label: "Inbox", tab: .dashboard, selectedTab: $selectedTab)
            TabBarButton(icon: "folder.fill", label: "Projects", tab: .projects, selectedTab: $selectedTab)
            
            // Create Button
            Button(action: onCreate) {
                VStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(AppColors.accentBlue)
                        .background(Circle().fill(Color.white).padding(4))
                        .shadow(color: AppColors.accentBlue.opacity(0.5), radius: 8)
                    Text("Create").font(AppFonts.caption(10))
                }
                .frame(maxWidth: .infinity)
                .offset(y: -15)
            }
            .buttonStyle(.plain)
            
            TabBarButton(icon: "calendar", label: "Calendar", tab: .calendar, selectedTab: $selectedTab)
            TabBarButton(icon: "gearshape.fill", label: "Settings", tab: .settings, selectedTab: $selectedTab)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, AppSpacing.lg)
        .padding(.top, AppSpacing.md)
        .background(.ultraThinMaterial)
        .background(AppColors.bgPrimary.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)) // Floating look? Or full width? 
        // Let's make it full width docked at bottom for standard iOS feel but glass
        .edgesIgnoringSafeArea(.bottom)
    }
}

struct TabBarButton: View {
    let icon: String
    let label: String
    let tab: SidebarRoute
    @Binding var selectedTab: SidebarRoute
    
    var isSelected: Bool { selectedTab == tab }
    
    var body: some View {
        Button(action: { selectedTab = tab }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .symbolVariant(isSelected ? .fill : .none)
                Text(label)
                    .font(AppFonts.caption(10).weight(isSelected ? .bold : .medium))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Create Action Sheet
struct CreateActionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedAction: CreateAction?
    @State private var newTaskText = ""
    @State private var newProjectTitle = ""
    @State private var newNoteTitle = ""
    @State private var newClientName = ""
    @State private var newClientIndustry = ""
    
    enum CreateAction: String, CaseIterable, Identifiable {
        case task = "Task"
        case project = "Project"
        case note = "Note"
        case client = "Client"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .task: return "checkmark.circle"
            case .project: return "folder.fill"
            case .note: return "doc.text.fill"
            case .client: return "person.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .task: return .green
            case .project: return .blue
            case .note: return .orange
            case .client: return .purple
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.95).ignoresSafeArea()
                
                VStack(spacing: AppSpacing.xxl) {
                    if selectedAction == nil {
                        // Action Selection Grid
                        Text("What would you like to create?")
                            .font(AppFonts.title(18))
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.top, 20)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.lg) {
                            ForEach(CreateAction.allCases) { action in
                                Button(action: { withAnimation { selectedAction = action } }) {
                                    VStack(spacing: AppSpacing.md) {
                                        Image(systemName: action.icon)
                                            .font(.system(size: 32))
                                            .foregroundStyle(action.color)
                                        
                                        Text(action.rawValue)
                                            .font(AppFonts.title(16))
                                            .foregroundStyle(AppColors.textPrimary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 30)
                                    .glassCardStyle(cornerRadius: AppRadius.lg)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, AppSpacing.xl)
                        
                    } else {
                        // Creation Form
                        creationForm
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle(selectedAction?.rawValue ?? "Create")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        if selectedAction != nil {
                            withAnimation { selectedAction = nil }
                        } else {
                            dismiss()
                        }
                    }) {
                        Text(selectedAction != nil ? "Back" : "Cancel")
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                
                if selectedAction != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveItem()
                            dismiss()
                        }
                        .bold()
                        .foregroundStyle(AppColors.textPrimary)
                        .disabled(!canSave)
                    }
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
    }
    
    @ViewBuilder
    private var creationForm: some View {
        VStack(spacing: AppSpacing.xl) {
            switch selectedAction {
            case .task:
                InputField(placeholder: "What needs to be done?", text: $newTaskText)
                
            case .project:
                InputField(placeholder: "Project name", text: $newProjectTitle)
                
            case .note:
                InputField(placeholder: "Note title", text: $newNoteTitle)
                
            case .client:
                VStack(spacing: AppSpacing.md) {
                    InputField(placeholder: "Client name", text: $newClientName)
                    InputField(placeholder: "Industry", text: $newClientIndustry)
                }
                
            case .none:
                EmptyView()
            }
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.top, AppSpacing.xl)
    }
    
    private var canSave: Bool {
        switch selectedAction {
        case .task: return !newTaskText.isEmpty
        case .project: return !newProjectTitle.isEmpty
        case .note: return !newNoteTitle.isEmpty
        case .client: return !newClientName.isEmpty
        case .none: return false
        }
    }
    
    private func saveItem() {
        switch selectedAction {
        case .task:
            let task = AgencyTask(content: newTaskText)
            modelContext.insert(task)
            Task {
                await TaskNotificationManager.shared.syncReminder(for: task)
            }
        case .project:
            let project = Project(title: newProjectTitle)
            modelContext.insert(project)
        case .note:
            let note = Note(title: newNoteTitle, content: "")
            modelContext.insert(note)
        case .client:
            let client = Client(name: newClientName, industry: newClientIndustry)
            modelContext.insert(client)
        case .none:
            break
        }
    }
}

// MARK: - iOS Dashboard
struct iOSDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AgencyTask.priority, order: .reverse) private var tasks: [AgencyTask]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xxl) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Date(), style: .date)
                            .font(AppFonts.code(13).weight(.bold))
                            .foregroundStyle(AppColors.textTertiary)
                            .kerning(1)
                        
                        Text("My Inbox")
                            .font(AppFonts.display(34))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    
                    // Task Groups
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("ACTIVE")
                            .font(AppFonts.caption(11).weight(.bold))
                            .foregroundStyle(AppColors.textTertiary)
                        
                        if tasks.filter({ !$0.isDone }).isEmpty {
                            EmptyStateView(
                                icon: "checkmark.circle",
                                title: "No active tasks",
                                message: "Tap + to create one"
                            )
                            .glassCardStyle()
                        } else {
                            LazyVStack(spacing: AppSpacing.md) {
                                ForEach(tasks.filter { !$0.isDone }) { task in
                                    iOSTaskRow(task: task)
                                }
                            }
                        }
                    }
                    
                    if !tasks.filter({ $0.isDone }).isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("COMPLETED")
                                .font(AppFonts.caption(11).weight(.bold))
                                .foregroundStyle(AppColors.textQuaternary)
                            
                            LazyVStack(spacing: AppSpacing.md) {
                                ForEach(tasks.filter { $0.isDone }) { task in
                                    iOSTaskRow(task: task)
                                        .opacity(0.6)
                                }
                            }
                        }
                    }
                }
                .padding(AppSpacing.xl)
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
    }
}

struct iOSTaskRow: View {
    @Bindable var task: AgencyTask
    
    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            Button(action: {
                withAnimation { task.isDone.toggle() }
                Task {
                    await TaskNotificationManager.shared.syncReminder(for: task)
                }
            }) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isDone ? AppColors.accentGreen : AppColors.textTertiary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.content)
                    .font(AppFonts.title(16).design(.rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .strikethrough(task.isDone)
                
                if let project = task.project {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: project.accentHex) ?? AppColors.accentBlue)
                            .frame(width: 6, height: 6)
                        Text(project.title)
                            .font(AppFonts.caption(11))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
            Spacer()
        }
        .glassCardStyle()
    }
}

// MARK: - iOS Projects
struct iOSProjectsView: View {
    @Query(sort: \Project.title) private var projects: [Project]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xxl) {
                    Text("Projects")
                        .font(AppFonts.display(34))
                        .foregroundStyle(AppColors.textPrimary)
                    
                    if projects.isEmpty {
                        EmptyStateView(
                            icon: "folder",
                            title: "No projects yet",
                            message: "Tap + to create one"
                        )
                        .glassCardStyle()
                    } else {
                        LazyVStack(spacing: AppSpacing.lg) {
                            ForEach(projects) { project in
                                NavigationLink(destination: ProjectDetailView(project: project)) {
                                    HStack(spacing: AppSpacing.lg) {
                                        Circle()
                                            .fill(Color(hex: project.accentHex) ?? AppColors.textSecondary)
                                            .frame(width: 12, height: 12)
                                            .shadow(color: (Color(hex: project.accentHex) ?? AppColors.textSecondary).opacity(0.5), radius: 4)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(project.title)
                                                .font(AppFonts.title())
                                                .foregroundStyle(AppColors.textPrimary)
                                            if let client = project.client {
                                                Text(client.name)
                                                    .font(AppFonts.caption())
                                                    .foregroundStyle(AppColors.textTertiary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(AppColors.textQuaternary)
                                    }
                                    .glassCardStyle()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(AppSpacing.xl)
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
    }
}

struct ProjectDetailView: View {
    let project: Project
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Text("Details")
                        .font(AppFonts.title())
                        .foregroundStyle(AppColors.textPrimary)
                    
                    detailRow(label: "Status", value: project.status.rawValue.capitalized)
                    if let client = project.client {
                        detailRow(label: "Client", value: client.name)
                    }
                    if let deadline = project.deadline {
                        detailRow(label: "Deadline", value: deadline.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .glassCardStyle()
                
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Text("Financials")
                        .font(AppFonts.title())
                        .foregroundStyle(AppColors.textPrimary)
                    
                    detailRow(label: "Budget", value: project.budget.formatted(.currency(code: "USD")))
                    detailRow(label: "Hourly Rate", value: project.hourlyRate.formatted(.currency(code: "USD")))
                }
                .glassCardStyle()
                
                if !project.figmaURL.isEmpty || !project.githubURL.isEmpty || !project.liveURL.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        Text("Links")
                            .font(AppFonts.title())
                            .foregroundStyle(AppColors.textPrimary)
                        
                        if !project.figmaURL.isEmpty { Link("Figma", destination: URL(string: project.figmaURL)!) }
                        if !project.githubURL.isEmpty { Link("GitHub", destination: URL(string: project.githubURL)!) }
                        if !project.liveURL.isEmpty { Link("Live Site", destination: URL(string: project.liveURL)!) }
                    }
                    .glassCardStyle()
                }
            }
            .padding(AppSpacing.xl)
        }
        .background(Color.clear)
        .navigationTitle(project.title)
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(AppColors.textTertiary)
            Spacer()
            Text(value).foregroundStyle(AppColors.textPrimary)
        }
        .font(AppFonts.body().design(.rounded))
    }
}

// MARK: - iOS Insights View
// Note: InsightsView is currently shared or macOS only in file structure, assuming this was a copy-paste or similar. 
// I will just refactor this existing block as requested.
struct iOSInsightsView: View {
    @Query(sort: \ChatInsight.timestamp, order: .reverse) private var insights: [ChatInsight]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xxl) {
                    Text("Insights")
                        .font(AppFonts.display(34))
                        .foregroundStyle(AppColors.textPrimary)
                    
                    if insights.isEmpty {
                        EmptyStateView(
                            icon: "lightbulb",
                            title: "No insights yet",
                            message: "Create insights from Prompt Studio on Mac"
                        )
                        .glassCardStyle()
                    } else {
                        LazyVStack(spacing: AppSpacing.lg) {
                            ForEach(insights) { insight in
                                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                    HStack {
                                        Text(insight.title)
                                            .font(AppFonts.title())
                                            .foregroundStyle(AppColors.textPrimary)
                                        Spacer()
                                        if insight.isStarred {
                                            Image(systemName: "star.fill")
                                                .foregroundStyle(AppColors.accentYellow)
                                                .font(.caption)
                                        }
                                    }
                                    
                                    Text(insight.content)
                                        .font(AppFonts.body().design(.rounded))
                                        .foregroundStyle(AppColors.textSecondary)
                                        .lineLimit(3)
                                    
                                    HStack {
                                        Text(insight.type.rawValue)
                                            .font(AppFonts.caption(10).weight(.bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(AppColors.surfaceHighlight)
                                            .clipShape(Capsule())
                                        
                                        if let project = insight.project {
                                            Text(project.title)
                                                .font(AppFonts.caption(10))
                                                .foregroundStyle(Color(hex: project.accentHex) ?? AppColors.accentBlue)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(insight.timestamp, style: .date)
                                            .font(AppFonts.caption(10))
                                            .foregroundStyle(AppColors.textQuaternary)
                                    }
                                }
                                .glassCardStyle()
                            }
                        }
                    }
                }
                .padding(AppSpacing.xl)
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
    }
}

// MARK: - iOS Settings View
struct iOSSettingsView: View {
    @AppStorage("userName") private var userName = "User"
    @AppStorage("userRole") private var userRole = "Team Member"
    @AppStorage("accentColor") private var accentColor = "#5AE6FF"
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xxl) {
                    Text("Settings")
                        .font(AppFonts.display(34))
                        .foregroundStyle(AppColors.textPrimary)
                    
                    HStack(spacing: AppSpacing.lg) {
                        Circle()
                            .fill(Color(hex: accentColor) ?? AppColors.accentBlue)
                            .frame(width: 60, height: 60)
                            .overlay(Text(String(userName.prefix(1))).font(.title).bold())
                        
                        VStack(alignment: .leading) {
                            TextField("Name", text: $userName)
                                .font(AppFonts.title())
                            TextField("Role", text: $userRole)
                                .font(AppFonts.body())
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }
                    .glassCardStyle()
                    
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        Text("Appearance").font(AppFonts.title())
                        
                        ColorPicker("Accent Color", selection: Binding(
                            get: { Color(hex: accentColor) ?? AppColors.accentBlue },
                            set: { accentColor = $0.toHex() ?? "#5AE6FF" }
                        ))
                    }
                    .glassCardStyle()
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("About").font(AppFonts.title())
                        Text("ANAJ v1.0").font(AppFonts.body()).foregroundStyle(AppColors.textTertiary)
                        Text("Build 2025.12.28").font(AppFonts.caption(10)).foregroundStyle(AppColors.textQuaternary)
                    }
                    .glassCardStyle()
                }
                .padding(AppSpacing.xl)
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
    }
}
#endif
