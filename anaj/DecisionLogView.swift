import SwiftUI
import SwiftData

struct DecisionLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Decision.timestamp, order: .reverse) private var decisions: [Decision]
    @Query(sort: \Project.title) private var projects: [Project]
    
    @State private var showingAddDecision = false
    @State private var showSavedToast = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Agency Intelligence")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .kerning(1)
                    
                    Text("Decision Log")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                
                if showSavedToast {
                    Text("Recorded!")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.green)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Button(action: { showingAddDecision.toggle() }) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                        Text("Record Decision")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            if decisions.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.05))
                    Text("No architectural or design decisions recorded yet.")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("Start logging 'Why' things are built a certain way.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.1))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(decisions) { decision in
                            DecisionCard(decision: decision)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .padding(30)
        .sheet(isPresented: $showingAddDecision) {
            AddDecisionSheet(isPresented: $showingAddDecision, projects: projects) {
                withAnimation { showSavedToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { showSavedToast = false }
                }
            }
        }
    }
}

struct DecisionCard: View {
    let decision: Decision
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(decision.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    if let project = decision.project {
                        HStack {
                            Circle()
                                .fill(Color(hex: project.accentHex) ?? .white)
                                .frame(width: 8, height: 8)
                            Text(project.title)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                Spacer()
                
                Text(decision.timestamp, style: .date)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
            }
            
            Divider().background(.white.opacity(0.1))
            
            VStack(alignment: .leading, spacing: 10) {
                LabelGroup(label: "CONTEXT", text: decision.context)
                LabelGroup(label: "OUTCOME", text: decision.outcome, color: .green)
            }
            
            HStack {
                Spacer()
                Button(role: .destructive) {
                    withAnimation { modelContext.delete(decision) }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.2))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(25)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct LabelGroup: View {
    let label: String
    let text: String
    var color: Color = .white
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .kerning(1)
                .foregroundStyle(.white.opacity(0.3))
            
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(color.opacity(0.8))
                .lineSpacing(4)
        }
    }
}

struct AddDecisionSheet: View {
    @Binding var isPresented: Bool
    let projects: [Project]
    var onComplete: () -> Void
    @Environment(\.modelContext) private var modelContext
    
    @State private var title = ""
    @State private var context = ""
    @State private var outcome = ""
    @State private var selectedProject: Project?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("What was decided?") {
                    TextField("Title", text: $title)
                    Picker("Project Link", selection: $selectedProject) {
                        Text("Agency Wide").tag(nil as Project?)
                        ForEach(projects) { project in
                            Text(project.title).tag(project as Project?)
                        }
                    }
                }
                
                Section("The Background (Context)") {
                    TextEditor(text: $context)
                        .frame(height: 80)
                }
                
                Section("The Final Choice (Outcome)") {
                    TextEditor(text: $outcome)
                        .frame(height: 80)
                }
            }
            .navigationTitle("New Intelligence Record")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Record") {
                        let newDecision = Decision(title: title, context: context, outcome: outcome)
                        newDecision.project = selectedProject
                        modelContext.insert(newDecision)
                        
                        // Pulse log
                        let activity = Activity(title: "Decision Recorded", subtitle: title, type: .system)
                        modelContext.insert(activity)
                        
                        try? modelContext.save() // Force save
                        onComplete()
                        isPresented = false
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 500)
    }
}
