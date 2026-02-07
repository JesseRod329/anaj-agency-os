//
//  MenuBarWidget.swift
//  ANAJ
//
//  Menu bar quick add widget
//

#if os(macOS)
import SwiftUI
import SwiftData

struct QuickAddMenuBar: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.title) private var projects: [Project]
    
    @State private var quickTaskText = ""
    @State private var selectedProject: Project?
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.blue)
                Text("ANAJ Quick Add")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }
            .padding(12)
            .background(Color.black.opacity(0.3))
            
            Divider()
            
            // Quick Task Input
            VStack(alignment: .leading, spacing: 12) {
                Text("NEW TASK")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                
                TextField("What needs to be done?", text: $quickTaskText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(10)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onSubmit(createTask)
                
                // Project Picker
                HStack {
                    Text("Project:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    
                    Picker("", selection: $selectedProject) {
                        Text("Inbox").tag(nil as Project?)
                        ForEach(projects.filter { !$0.isArchived }) { project in
                            Text(project.title).tag(project as Project?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 150)
                }
                
                // Create Button
                Button(action: createTask) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Task")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(quickTaskText.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(quickTaskText.isEmpty)
            }
            .padding(12)
            
            Divider()
            
            // Quick Actions
            VStack(spacing: 4) {
                QuickActionButton(icon: "doc.badge.plus", title: "New Note") {
                    createNote()
                }
                
                QuickActionButton(icon: "folder.badge.plus", title: "New Project") {
                    createProject()
                }
                
                Divider().padding(.vertical, 4)
                
                QuickActionButton(icon: "magnifyingglass", title: "Search (⌘K)") {
                    NotificationCenter.default.post(name: .openGlobalSearch, object: nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            .padding(8)
            
            Divider()
            
            // Footer
            Button(action: {
                NSApp.activate(ignoringOtherApps: true)
            }) {
                HStack {
                    Text("Open ANAJ")
                    Spacer()
                    Text("⌘O")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 280)
    }
    
    private func createTask() {
        guard !quickTaskText.isEmpty else { return }
        let task = AgencyTask(content: quickTaskText)
        task.project = selectedProject
        modelContext.insert(task)
        
        // Log activity
        let activity = Activity(title: "Quick Task Created", subtitle: quickTaskText, type: .task)
        modelContext.insert(activity)
        
        try? modelContext.save()
        quickTaskText = ""
    }
    
    private func createNote() {
        let note = Note(title: "Quick Note", content: "", createdAt: Date())
        modelContext.insert(note)
        
        let activity = Activity(title: "Quick Note Created", subtitle: "", type: .note)
        modelContext.insert(activity)
        
        try? modelContext.save()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func createProject() {
        let project = Project(title: "New Project")
        modelContext.insert(project)
        
        let activity = Activity(title: "Quick Project Created", subtitle: "New Project", type: .project)
        modelContext.insert(activity)
        
        try? modelContext.save()
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isHovered ? Color.white.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
#endif
