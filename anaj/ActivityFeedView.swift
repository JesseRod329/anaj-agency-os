//
//  ActivityFeedView.swift
//  ANAJ
//
//  Full-page activity feed with filtering and timeline
//

import SwiftUI
import SwiftData

struct ActivityFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Activity.timestamp, order: .reverse) private var activities: [Activity]
    
    @State private var selectedFilter: ActivityType? = nil
    @State private var searchText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Activity")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(filteredActivities.count) events")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Clear All Button
                if !activities.isEmpty {
                    Button(action: clearAllActivities) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Clear All")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterPill(title: "All", isSelected: selectedFilter == nil) {
                        selectedFilter = nil
                    }
                    
                    ForEach(ActivityType.allCases, id: \.self) { type in
                        FilterPill(
                            title: type.displayName,
                            icon: type.rawValue,
                            isSelected: selectedFilter == type
                        ) {
                            selectedFilter = selectedFilter == type ? nil : type
                        }
                    }
                }
            }
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.4))
                TextField("Search activity...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Timeline
            if filteredActivities.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.1))
                    Text("No activity yet")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groupedActivities.keys.sorted().reversed(), id: \.self) { date in
                            Section {
                                ForEach(groupedActivities[date] ?? []) { activity in
                                    ActivityTimelineRow(activity: activity)
                                }
                            } header: {
                                HStack {
                                    Text(formatDateHeader(date))
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.4))
                                        .textCase(.uppercase)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 4)
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .padding(20)
    }
    
    private var filteredActivities: [Activity] {
        var result = activities
        
        if let filter = selectedFilter {
            result = result.filter { $0.type == filter }
        }
        
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.subtitle.lowercased().contains(query)
            }
        }
        
        return result
    }
    
    private var groupedActivities: [Date: [Activity]] {
        let calendar = Calendar.current
        return Dictionary(grouping: filteredActivities) { activity in
            calendar.startOfDay(for: activity.timestamp)
        }
    }
    
    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }
    
    private func clearAllActivities() {
        for activity in activities {
            modelContext.delete(activity)
        }
        try? modelContext.save()
    }
}

// MARK: - Activity Timeline Row

struct ActivityTimelineRow: View {
    let activity: Activity
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline connector
            VStack(spacing: 0) {
                Circle()
                    .fill(activity.type.color)
                    .frame(width: 10, height: 10)
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1)
            }
            .frame(width: 10)
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: activity.type.rawValue)
                        .font(.system(size: 12))
                        .foregroundStyle(activity.type.color)
                    
                    Text(activity.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Text(activity.timestamp, style: .time)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                }
                
                if !activity.subtitle.isEmpty {
                    Text(activity.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                }
            }
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Filter Pill

struct FilterPill: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isSelected ? .black : .white.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.white : Color.white.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Activity Type Extensions

extension ActivityType {
    var displayName: String {
        switch self {
        case .task: return "Tasks"
        case .project: return "Projects"
        case .client: return "Clients"
        case .note: return "Notes"
        case .system: return "System"
        }
    }
    
    var color: Color {
        switch self {
        case .task: return .green
        case .project: return .blue
        case .client: return .purple
        case .note: return .orange
        case .system: return .yellow
        }
    }
}
