import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.title, order: .forward) private var projects: [Project]
    @Query(sort: \Client.name, order: .forward) private var clients: [Client]

    @State private var newTitle: String = ""
    @State private var selectedClient: Client? = nil
    @State private var accentHex: String = "#5AE6FF"
    @State private var showSuccess = false
    @State private var filterStatus: ProjectStatus? = nil

    // Filter archived projects
    private var visibleProjects: [Project] {
        let filtered = projects.filter { !$0.isArchived }
        if let status = filterStatus {
            return filtered.filter { $0.status == status }
        }
        // Sort pinned first
        return filtered.sorted { $0.isPinned && !$1.isPinned }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Projects")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(visibleProjects.count) active projects")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Status Filter Pills
                HStack(spacing: 6) {
                    FilterPillButton(title: "All", isSelected: filterStatus == nil) {
                        filterStatus = nil
                    }
                    ForEach(ProjectStatus.allCases, id: \.self) { status in
                        FilterPillButton(title: status.rawValue.capitalized, isSelected: filterStatus == status) {
                            filterStatus = filterStatus == status ? nil : status
                        }
                    }
                }
                
                if showSuccess {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Created!")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
                }
            }

            // Quick Create Bar
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.blue)
                    
                    TextField("", text: $newTitle, prompt: Text("New project name...").foregroundColor(.white.opacity(0.4)))
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .onSubmit { createProject() }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                
                Picker("", selection: $selectedClient) {
                    Text("No Client").tag(nil as Client?)
                    ForEach(clients.filter { !$0.isArchived }) { client in
                        Text(client.name).tag(client as Client?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button(action: createProject) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Create")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(newTitle.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(newTitle.isEmpty)
            }

            // Project Grid
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    ForEach(visibleProjects) { project in
                        ProjectRow(project: project, clients: clients, onDelete: { delete(project) })
                    }
                    
                    if visibleProjects.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 48))
                                .foregroundStyle(.white.opacity(0.1))
                            Text("No projects yet")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.3))
                            Text("Create your first project above")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.2))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .padding(24)
    }

    private func createProject() {
        guard !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        withAnimation(.snappy) {
            let proj = Project(title: newTitle, status: .flow, accentHex: accentHex)
            proj.client = selectedClient
            modelContext.insert(proj)
            
            let activity = Activity(title: "New Project", subtitle: newTitle, type: .project)
            modelContext.insert(activity)
            
            do {
                try modelContext.save()
                newTitle = ""
                selectedClient = nil
                withAnimation { showSuccess = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { showSuccess = false }
                }
            } catch {
                print("Failed to save project: \(error)")
            }
        }
    }

    private func delete(_ project: Project) {
        withAnimation(.snappy) {
            modelContext.delete(project)
        }
    }
}

private struct ProjectRow: View {
    @Bindable var project: Project
    let clients: [Client]
    var onDelete: () -> Void
    @State private var isEditing: Bool = false
    @State private var showFinancials: Bool = false
    @State private var draftTitle: String = ""
    @State private var showColorPicker: Bool = false
    @State private var showIconPicker: Bool = false
    @State private var draftColor: Color = .white
    @State private var isHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row
            HStack(spacing: 12) {
                // Icon Button (clickable to change)
                Button(action: { showIconPicker = true }) {
                    ProjectIcon(icon: project.icon, size: 28, background: Color(hex: project.accentHex)?.opacity(0.3) ?? .blue.opacity(0.3))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showIconPicker) {
                    IconPicker(selectedIcon: $project.icon)
                }
                
                // Pin indicator
                if project.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                        .rotationEffect(.degrees(45))
                }

                // Title and details
                VStack(alignment: .leading, spacing: 3) {
                    if isEditing {
                        TextField("Project Name", text: $draftTitle)
                            .textFieldStyle(.plain)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .onSubmit(commitRename)
                            .onAppear { draftTitle = project.title }
                    } else {
                        Text(project.title)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    
                    HStack(spacing: 8) {
                        if let client = project.client {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: client.brandHex) ?? .purple)
                                    .frame(width: 6, height: 6)
                                Text(client.name)
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        // Status Badge
                        Text(project.status.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(statusColor.opacity(0.9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()

                HStack(spacing: 15) {
                    Button(action: { showFinancials.toggle() }) {
                        Image(systemName: "dollarsign.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showFinancials) {
                        ProjectFinancialsView(project: project)
                    }

                    URLButton(icon: "figma", url: project.figmaURL, color: .purple)
                    URLButton(icon: "terminal", url: project.githubURL, color: .gray)
                    URLButton(icon: "safari", url: project.liveURL, color: .blue)
                }
                .padding(.trailing, 10)

                Menu {
                    if isEditing {
                        Button("Save") { commitRename() }
                        Button("Cancel", role: .cancel) { isEditing = false }
                    } else {
                        Button("Edit Project Details") { isEditing = true }
                    }

                    Divider()
                    
                    Button(action: { duplicateProject() }) {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    
                    Button(action: { project.isPinned.toggle() }) {
                        Label(project.isPinned ? "Unpin" : "Pin", systemImage: project.isPinned ? "pin.slash" : "pin")
                    }

                    Button("Edit Accent Color") { showColorPicker.toggle() }

                    Divider()
                    
                    Button(action: { archiveProject() }) {
                        Label("Archive", systemImage: "archivebox")
                    }
                    
                    Button("Delete", role: .destructive) { onDelete() }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.white.opacity(0.8))
                }
                .menuStyle(.borderlessButton)
            }
            
            if isEditing {
                VStack(spacing: 8) {
                    // Client Picker
                    HStack {
                        Text("Client").font(.system(size: 12, weight: .bold)).frame(width: 70, alignment: .leading)
                        Picker("", selection: $project.client) {
                            Text("No Client").tag(nil as Client?)
                            ForEach(clients) { client in
                                Text(client.name).tag(client as Client?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(8)
                    .background(.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Accent Color Picker
                    HStack {
                        Text("Color").font(.system(size: 12, weight: .bold)).frame(width: 70, alignment: .leading)
                        HStack(spacing: 6) {
                            ForEach(["#5AE6FF", "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD", "#98D8C8"], id: \.self) { hex in
                                Circle()
                                    .fill(Color(hex: hex) ?? .blue)
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Circle()
                                            .stroke(.white, lineWidth: project.accentHex == hex ? 2 : 0)
                                    )
                                    .onTapGesture {
                                        project.accentHex = hex
                                    }
                            }
                        }
                    }
                    .padding(8)
                    .background(.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Simple Description Editor
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                        TextEditor(text: $project.projectDescription)
                            .scrollContentBackground(.hidden)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(minHeight: 60, maxHeight: 120)
                            .padding(8)
                            .background(.black.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    AssetInput(label: "Figma", text: $project.figmaURL, icon: "figma")
                    AssetInput(label: "GitHub", text: $project.githubURL, icon: "terminal")
                    AssetInput(label: "Live URL", text: $project.liveURL, icon: "safari")
                    AssetInput(label: "Local Path", text: $project.localPath, icon: "folder.badge.gearshape")
                }
                .padding(.top, 10)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    // Show description if not empty
                    if !project.projectDescription.isEmpty {
                        Text(project.projectDescription)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(3)
                    }
                    
                    // Quick Actions for Local Automation
                    HStack(spacing: 12) {
                        ActionButton("VS Code", icon: "chevron.left.forwardslash.chevron.right") {
                            openInVSCode(project.localPath)
                        }
                        ActionButton("Finder", icon: "folder") {
                            openInFinder(project.localPath)
                        }
                        Spacer()
                    }
                }
                .padding(.top, 5)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .popover(isPresented: $showColorPicker, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Accent Color")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                ColorPicker("", selection: $draftColor, supportsOpacity: false)
                    .labelsHidden()
                HStack {
                    Spacer()
                    Button("Apply") { commitColor() }
                }
            }
            .padding(12)
            .frame(width: 220)
        }
    }

    private func commitRename() {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            project.title = trimmed
        }
        isEditing = false
    }

    private func commitColor() {
        if let hex = draftColor.toHex() {
            project.accentHex = hex
        }
        showColorPicker = false
    }
    
    @Environment(\.modelContext) private var modelContext
    
    private func duplicateProject() {
        let duplicate = Project(
            title: "\(project.title) (Copy)",
            projectDescription: project.projectDescription,
            status: project.status,
            accentHex: project.accentHex,
            figmaURL: project.figmaURL,
            githubURL: project.githubURL,
            liveURL: project.liveURL,
            localPath: project.localPath,
            budget: project.budget,
            hourlyRate: project.hourlyRate,
            internalRate: project.internalRate,
            additionalCosts: project.additionalCosts,
            deadline: project.deadline
        )
        duplicate.client = project.client
        duplicate.tags = project.tags
        modelContext.insert(duplicate)
        try? modelContext.save()
    }
    
    private func archiveProject() {
        withAnimation {
            project.isArchived = true
        }
        try? modelContext.save()
    }
    
    // Status color helper
    private var statusColor: Color {
        switch project.status {
        case .flow: return .green
        case .stagnant: return .yellow
        case .completed: return .blue
        }
    }
}

struct URLButton: View {
    let icon: String
    let url: String
    let color: Color
    
    var body: some View {
        Button(action: {
            if let urlObj = URL(string: url) {
                #if os(macOS)
                NSWorkspace.shared.open(urlObj)
                #elseif os(iOS)
                UIApplication.shared.open(urlObj)
                #endif
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(url.isEmpty ? .white.opacity(0.2) : color)
        }
        .buttonStyle(.plain)
        .disabled(url.isEmpty)
    }
}

struct AssetInput: View {
    let label: String
    @Binding var text: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon).frame(width: 20)
            Text(label).font(.system(size: 12, weight: .bold)).frame(width: 60, alignment: .leading)
            TextField("URL", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
        }
        .padding(8)
        .background(.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        
        // MARK: - Local Automation Helpers
        private func openInVSCode(_ path: String) {
        
    #if os(macOS)
    guard !path.isEmpty else { return }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["code", path]
    try? process.run()
    #endif
}

private func openInFinder(_ path: String) {
    #if os(macOS)
    guard !path.isEmpty else { return }
    let url = URL(fileURLWithPath: path)
    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    #endif
}

// MARK: - Filter Pill Button

struct FilterPillButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.white : Color.white.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}