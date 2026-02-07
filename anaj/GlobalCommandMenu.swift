#if os(macOS)
import SwiftUI
import SwiftData

struct GlobalCommandMenu: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @Environment(\.modelContext) private var modelContext
    
    // Data Queries
    @Query private var clients: [Client]
    @Query private var projects: [Project]
    @Query private var tasks: [AgencyTask]
    @Query private var notes: [Note]
    
    // Filtered Results
    var results: [CommandResult] {
        if searchText.isEmpty { return [] }
        
        var combined: [CommandResult] = []
        
        combined += clients.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            .map { CommandResult(id: $0.id.uuidString, title: $0.name, type: .client, icon: "person.2.fill") }
        
        combined += projects.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
            .map { CommandResult(id: $0.id.uuidString, title: $0.title, type: .project, icon: "folder.fill") }
        
        combined += tasks.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
            .map { CommandResult(id: $0.id.uuidString, title: $0.content, type: .task, icon: "checkmark.circle.fill") }
            
        combined += notes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
            .map { CommandResult(id: $0.id.uuidString, title: $0.title, type: .note, icon: "doc.text.fill") }
            
        return combined.prefix(10).map { $0 }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Input
            HStack(spacing: 15) {
                Image(systemName: "command")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                
                TextField("Search anything...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                
                if !searchText.isEmpty {
                    Button("ESC") { isPresented = false }
                        .font(.system(size: 10, weight: .bold))
                        .padding(4)
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(20)
            
            Divider().background(.white.opacity(0.1))
            
            // Results
            ScrollView {
                VStack(spacing: 4) {
                    if results.isEmpty && !searchText.isEmpty {
                        Text("No matches found")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(.vertical, 40)
                    } else if results.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            CommandTip(icon: "doc.text", text: "Search for notes or documents")
                            CommandTip(icon: "folder", text: "Jump to a specific project")
                            CommandTip(icon: "person.2", text: "Find client brand details")
                        }
                        .padding(20)
                    }
                    
                    ForEach(results) { result in
                        CommandRow(result: result) {
                            execute(result)
                        }
                    }
                }
                .padding(10)
            }
        }
        .frame(width: 500, height: 400)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 30)
    }
    
    private func execute(_ result: CommandResult) {
        // Here we would trigger navigation
        // For now, let's just close the menu
        isPresented = false
    }
}

struct CommandResult: Identifiable {
    let id: String
    let title: String
    let type: ResultType
    let icon: String
    
    enum ResultType { case client, project, task, note }
}

struct CommandRow: View {
    let result: CommandResult
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: result.icon)
                    .frame(width: 24)
                    .foregroundStyle(.white.opacity(0.6))
                
                Text(result.title)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text(String(describing: result.type).uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(isHovered ? .white.opacity(0.1) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct CommandTip: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.white.opacity(0.2))
            Text(text).font(.system(size: 13)).foregroundStyle(.white.opacity(0.4))
        }
    }
}
#endif
