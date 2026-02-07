#if os(macOS)
import SwiftUI
import SwiftData

struct InsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatInsight.timestamp, order: .reverse) private var insights: [ChatInsight]
    @Query(sort: \Project.title) private var projects: [Project]
    
    @State private var selectedInsight: ChatInsight?
    @State private var searchText = ""
    @State private var indexFilter: IndexFilter = .all
    @State private var selectedProjectID: UUID?
    @State private var selectedType: InsightType?
    
    enum IndexFilter {
        case all, starred, project, type
    }
    
    var filteredInsights: [ChatInsight] {
        var results = insights
        
        if !searchText.isEmpty {
            results = results.filter { 
                $0.title.localizedCaseInsensitiveContains(searchText) || 
                $0.content.localizedCaseInsensitiveContains(searchText) 
            }
        }
        
        switch indexFilter {
        case .all: break
        case .starred:
            results = results.filter { $0.isStarred }
        case .project:
            if let projectID = selectedProjectID {
                results = results.filter { $0.project?.id == projectID }
            }
        case .type:
            if let type = selectedType {
                results = results.filter { $0.type == type }
            }
        }
        
        return results
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // --- Panel 1: Intelligence Index ---
            IntelligenceIndex(
                indexFilter: $indexFilter,
                selectedProjectID: $selectedProjectID,
                selectedType: $selectedType,
                projects: projects,
                insights: insights
            )
            .frame(width: 240)
            .background(AppColors.bgSecondary)
            
            // --- Panel 2: Insight Feed ---
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(indexTitle)
                            .font(AppFonts.display(24))
                            .foregroundStyle(AppColors.textPrimary)
                        Text("\(filteredInsights.count) Insights")
                            .font(AppFonts.caption())
                            .foregroundStyle(AppColors.textQuaternary)
                    }
                    Spacer()
                    
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textTertiary)
                        TextField("Search...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(AppFonts.code(13))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    .padding(8)
                    .background(AppColors.bgPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .frame(width: 200)
                }
                .padding(AppSpacing.xxl)
                
                ScrollView {
                    LazyVStack(spacing: AppSpacing.lg) {
                        if filteredInsights.isEmpty {
                            EmptyStateView(
                                icon: "lightbulb.slash",
                                title: "No Insights Found",
                                message: "Try adjusting your filters or search query."
                            )
                            .padding(.top, 40)
                        }
                        ForEach(filteredInsights) { insight in
                            InsightCard(
                                insight: insight,
                                isSelected: selectedInsight?.id == insight.id
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedInsight = insight
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.xxl)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .frame(maxWidth: .infinity)
            .background(AppColors.surface)
            
            // --- Panel 3: Insight Inspector ---
            if let insight = selectedInsight {
                InsightInspector(insight: insight) {
                    selectedInsight = nil
                }
                .frame(width: 380)
                .background(AppColors.bgPrimary)
                .transition(.move(edge: .trailing))
            }
        }
    }
    
    private var indexTitle: String {
        switch indexFilter {
        case .all: return "All Insights"
        case .starred: return "Starred"
        case .project:
            return projects.first(where: { $0.id == selectedProjectID })?.title ?? "Project"
        case .type:
            return selectedType?.rawValue ?? "Type"
        }
    }
}

// MARK: - Intelligence Index
struct IntelligenceIndex: View {
    @Binding var indexFilter: InsightsView.IndexFilter
    @Binding var selectedProjectID: UUID?
    @Binding var selectedType: InsightType?
    
    let projects: [Project]
    let insights: [ChatInsight]
    
    @State private var projectExpanded = true
    @State private var typeExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            Text("Intelligence")
                .font(AppFonts.title(18).weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.xxl)
            
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    // Standard Sections
                    IndexRow(title: "All Insights", icon: "tray.full.fill", isSelected: indexFilter == .all) {
                        indexFilter = .all
                    }
                    
                    IndexRow(title: "Starred", icon: "star.fill", isSelected: indexFilter == .starred, color: AppColors.accentYellow) {
                        indexFilter = .starred
                    }
                    
                    Divider().overlay(AppColors.borderSubtle).padding(.vertical, 8)
                    
                    // Projects Section
                    DisclosureGroup(isExpanded: $projectExpanded) {
                        VStack(spacing: 4) {
                            ForEach(projects) { project in
                                let count = insights.filter { $0.project?.id == project.id }.count
                                ProjectIndexRow(
                                    project: project,
                                    count: count,
                                    isSelected: indexFilter == .project && selectedProjectID == project.id
                                ) {
                                    selectedProjectID = project.id
                                    indexFilter = .project
                                }
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Text("BY PROJECT")
                            .font(AppFonts.caption(10).weight(.black))
                            .kerning(1)
                            .foregroundStyle(AppColors.textQuaternary)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    
                    // Type Section
                    DisclosureGroup(isExpanded: $typeExpanded) {
                        VStack(spacing: 4) {
                            ForEach(InsightType.allCases, id: \.self) { type in
                                let count = insights.filter { $0.type == type }.count
                                TypeIndexRow(
                                    type: type,
                                    count: count,
                                    isSelected: indexFilter == .type && selectedType == type
                                ) {
                                    selectedType = type
                                    indexFilter = .type
                                }
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Text("BY TYPE")
                            .font(AppFonts.caption(10).weight(.black))
                            .kerning(1)
                            .foregroundStyle(AppColors.textQuaternary)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                }
            }
        }
    }
}

// MARK: - Components

struct IndexRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var color: Color = AppColors.textPrimary
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? Color.black : color.opacity(0.7))
                    .frame(width: 18)
                
                Text(title)
                    .font(AppFonts.body(13).weight(isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.black : AppColors.textPrimary.opacity(0.8))
                
                Spacer()
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, 10)
            .background(isSelected ? Color.white : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
    }
}

struct ProjectIndexRow: View {
    let project: Project
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(hex: project.accentHex) ?? AppColors.accentBlue)
                    .frame(width: 8, height: 8)
                
                Text(project.title)
                    .font(AppFonts.body(13).weight(isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.black : AppColors.textSecondary)
                    .lineLimit(1)
                
                Spacer()
                
                if count > 0 {
                    Text("\(count)")
                        .font(AppFonts.caption(10).weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.black.opacity(0.1) : AppColors.surface)
                        .clipShape(Capsule())
                        .foregroundStyle(isSelected ? Color.black.opacity(0.6) : AppColors.textQuaternary)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 8)
            .background(isSelected ? Color.white : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        }
        .buttonStyle(.plain)
    }
}

struct TypeIndexRow: View {
    let type: InsightType
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var icon: String {
        switch type {
        case .summary: return "text.alignleft"
        case .decision: return "checkmark.seal.fill"
        case .strategy: return "map.fill"
        case .research: return "magnifyingglass.circle.fill"
        case .note: return "doc.text.fill"
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? Color.black : AppColors.textTertiary)
                
                Text(type.rawValue)
                    .font(AppFonts.body(13).weight(isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.black : AppColors.textSecondary)
                
                Spacer()
                
                if count > 0 {
                    Text("\(count)")
                        .font(AppFonts.caption(10).weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.black.opacity(0.1) : AppColors.surface)
                        .clipShape(Capsule())
                        .foregroundStyle(isSelected ? Color.black.opacity(0.6) : AppColors.textQuaternary)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 8)
            .background(isSelected ? Color.white : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        }
        .buttonStyle(.plain)
    }
}

struct InsightCard: View {
    let insight: ChatInsight
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Top Row
                HStack {
                    Text(insight.title.isEmpty ? "Untitled Insight" : insight.title)
                        .font(AppFonts.titleRounded(16))
                        .foregroundStyle(AppColors.textPrimary)
                    
                    Spacer()
                    
                    if let project = insight.project {
                        Text(project.title)
                            .font(AppFonts.caption(10).weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: project.accentHex)?.opacity(0.2) ?? AppColors.accentBlue.opacity(0.2))
                            .foregroundStyle(Color(hex: project.accentHex) ?? AppColors.accentBlue)
                            .clipShape(Capsule())
                    }
                    
                    Text(insight.type.rawValue)
                        .font(AppFonts.caption(10).weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.surfaceHighlight)
                        .foregroundStyle(AppColors.textSecondary)
                        .clipShape(Capsule())
                    
                    Button(action: {
                        insight.isStarred.toggle()
                        try? modelContext.save()
                    }) {
                        Image(systemName: insight.isStarred ? "star.fill" : "star")
                            .font(.system(size: 14))
                            .foregroundStyle(insight.isStarred ? AppColors.accentYellow : AppColors.textQuaternary)
                    }
                    .buttonStyle(.plain)
                }
                
                // Content Preview
                Text(insight.content)
                    .font(AppFonts.code(13))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(4)
                    .lineSpacing(4)
                
                // Meta Row
                HStack {
                    if let prompt = insight.prompt {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 10))
                        Text(prompt.title)
                            .font(AppFonts.caption(11))
                        
                        Text("•")
                        Text("\(prompt.messages.count) messages")
                            .font(AppFonts.caption(11))
                    } else if insight.source == .manualSelection {
                        Text("Manually Extracted")
                            .font(AppFonts.caption(11))
                    } else {
                        Text("AI Summarized")
                            .font(AppFonts.caption(11))
                    }
                    
                    Spacer()
                    
                    Text(insight.timestamp, style: .date)
                        .font(AppFonts.caption(10))
                        .foregroundStyle(AppColors.textQuaternary)
                }
                .foregroundStyle(AppColors.textQuaternary)
            }
            .padding(AppSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .fill(isSelected ? AppColors.surfaceStrong : AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .stroke(isSelected ? AppColors.borderStrong : AppColors.borderSubtle, lineWidth: 1)
            )
            .shadow(color: .black.opacity(isSelected ? 0.2 : 0.1), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct InsightInspector: View {
    @Bindable var insight: ChatInsight
    let onClose: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var isEditing = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Inspector")
                    .font(AppFonts.body().weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(AppSpacing.xl)
            
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    // Content
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        TextField("Insight Title", text: $insight.title)
                            .font(AppFonts.display(20))
                            .textFieldStyle(.plain)
                            .foregroundStyle(AppColors.textPrimary)
                        
                        TextEditor(text: $insight.content)
                            .font(AppFonts.body())
                            .foregroundStyle(AppColors.textPrimary.opacity(0.9))
                            .lineSpacing(6)
                            .frame(minHeight: 200)
                            .scrollContentBackground(.hidden)
                            .padding(AppSpacing.lg)
                            .background(AppColors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                            .onChange(of: insight.content) {
                                insight.lastEditedAt = Date()
                            }
                    }
                    
                    // Provenance
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        Text("PROVENANCE")
                            .font(AppFonts.caption(10).weight(.black))
                            .kerning(1)
                            .foregroundStyle(AppColors.textQuaternary)
                        
                        ProvenanceRow(label: "Source Chat", value: insight.prompt?.title ?? "None")
                        ProvenanceRow(label: "Project", value: insight.project?.title ?? "Unassigned")
                        
                        if let provider = insight.providerLabel {
                            ProvenanceRow(label: "AI Source", value: "\(provider) [Unverified]")
                        }
                        
                        ProvenanceRow(label: "Created", value: insight.timestamp.formatted())
                        ProvenanceRow(label: "Last Edited", value: insight.lastEditedAt.formatted())
                    }
                    .padding(AppSpacing.xl)
                    .background(AppColors.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
                    
                    // Actions
                    VStack(spacing: 10) {
                        InspectorAction(title: "Open Source Chat", icon: "bubble.left.and.bubble.right.fill") {
                            // This would ideally navigate back to Prompt Studio
                        }
                        
                        InspectorAction(title: "Convert to Note", icon: "doc.text.fill") {
                            let note = Note(title: insight.title, content: insight.content)
                            note.project = insight.project
                            modelContext.insert(note)
                        }
                        
                        InspectorAction(title: "Convert to Decision", icon: "checkmark.seal.fill") {
                            let decision = Decision(title: insight.title, context: "Converted from Insight", outcome: insight.content)
                            decision.project = insight.project
                            modelContext.insert(decision)
                        }
                        
                        HStack(spacing: 10) {
                            InspectorAction(title: "Export Markdown", icon: "square.and.arrow.up") {
                                // Export logic
                            }
                            
                            InspectorAction(title: "Delete", icon: "trash", color: AppColors.accentRed) {
                                modelContext.delete(insight)
                                try? modelContext.save()
                                onClose()
                            }
                        }
                    }
                }
                .padding(AppSpacing.section)
            }
        }
    }
}

struct ProvenanceRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppFonts.caption(9).weight(.bold))
                .foregroundStyle(AppColors.textQuaternary)
            Text(value)
                .font(AppFonts.caption(12))
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}

struct InspectorAction: View {
    let title: String
    let icon: String
    var color: Color = .white
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(AppFonts.body(13).weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .background(color == AppColors.accentRed ? AppColors.accentRed.opacity(0.1) : AppColors.surfaceHighlight)
            .foregroundStyle(color == AppColors.accentRed ? AppColors.accentRed : AppColors.textPrimary.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(color == AppColors.accentRed ? AppColors.accentRed.opacity(0.2) : AppColors.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    InsightsView()
        .frame(width: 1000, height: 700)
}
#endif
