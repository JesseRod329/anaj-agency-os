import SwiftUI
import SwiftData
import EventKit

// MARK: - Main Container
struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allTasks: [AgencyTask]
    @State private var calendarManager = CalendarManager()
    
    // State
    @State private var selectedDate = Date()
    @State private var viewMode: CalendarMode = .month
    #if os(macOS)
    @State private var showingSidebar = true
    #else
    @State private var showingSidebar = false
    #endif
    
    enum CalendarMode: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case year = "Year" // Future scope
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // --- Sidebar ---
            if showingSidebar {
                VStack(spacing: 20) {
                    // Mini Calendar for Navigation
                    MiniCalendar(selectedDate: $selectedDate)
                        .padding(.top, 20)
                    
                    Divider().background(.white.opacity(0.1))
                    
                    // Upcoming List
                    VStack(alignment: .leading, spacing: 10) {
                        Text("UPCOMING")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                        
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                let upcoming = combinedItems(for: selectedDate)
                                if upcoming.isEmpty {
                                    Text("No items for this day")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.3))
                                        .padding(.top, 10)
                                } else {
                                    ForEach(upcoming) { item in
                                        SidebarItemRow(item: item)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .padding(.horizontal, 16)
                .frame(width: 250)
                .background(.black.opacity(0.2))
                .overlay(Rectangle().frame(width: 1).padding(.leading, 249).foregroundStyle(.white.opacity(0.1)), alignment: .trailing)
                .transition(.move(edge: .leading))
            }
            
            // --- Main Content ---
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Button(action: { withAnimation { showingSidebar.toggle() }}) {
                        Image(systemName: "sidebar.left")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // Date Navigation
                    HStack(spacing: 20) {
                        Button(action: previousPage) {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.plain)
                        
                        Text(headerTitle)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 140)
                            .onTapGesture { selectedDate = Date() } // Jump to today
                        
                        Button(action: nextPage) {
                            Image(systemName: "chevron.right")
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                    
                    // Mode Switcher
                    Picker("", selection: $viewMode) {
                        ForEach(CalendarMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                .padding(16)
                .background(.ultraThinMaterial.opacity(0.5))
                
                // Calendar Content
                Group {
                    switch viewMode {
                    case .month:
                        MonthView(selectedDate: $selectedDate, tasks: allTasks, events: calendarManager.events)
                    case .week:
                        WeekView(selectedDate: $selectedDate, tasks: allTasks, events: calendarManager.events)
                    case .day:
                        DayView(selectedDate: $selectedDate, tasks: allTasks, events: calendarManager.events)
                    case .year:
                        Text("Year View Coming Soon")
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
            }
        }
        .background(Color.clear)
        .onAppear {
            calendarManager.checkAuthorization()
        }
    }
    
    // --- Logic ---
    
    private var headerTitle: String {
        let formatter = DateFormatter()
        switch viewMode {
        case .month: formatter.dateFormat = "MMMM yyyy"
        case .week:
            let weekStart = selectedDate.startOfWeek
            let weekEnd = Calendar.current.date(byAdding: .day, value: 6, to: weekStart)!
            if Calendar.current.isDate(weekStart, equalTo: weekEnd, toGranularity: .month) {
                return "\(weekStart.formatted(.dateTime.month())) \(weekStart.formatted(.dateTime.year()))"
            } else {
                return "\(weekStart.formatted(.dateTime.month().year())) - \(weekEnd.formatted(.dateTime.month()))"
            }
        case .day: formatter.dateFormat = "MMMM d, yyyy"
        case .year: formatter.dateFormat = "yyyy"
        }
        return formatter.string(from: selectedDate)
    }
    
    private func previousPage() {
        let cal = Calendar.current
        switch viewMode {
        case .month: selectedDate = cal.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
        case .week: selectedDate = cal.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
        case .day: selectedDate = cal.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        case .year: selectedDate = cal.date(byAdding: .year, value: -1, to: selectedDate) ?? selectedDate
        }
    }
    
    private func nextPage() {
        let cal = Calendar.current
        switch viewMode {
        case .month: selectedDate = cal.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
        case .week: selectedDate = cal.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
        case .day: selectedDate = cal.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        case .year: selectedDate = cal.date(byAdding: .year, value: 1, to: selectedDate) ?? selectedDate
        }
    }
    
    private func combinedItems(for date: Date) -> [UnifiedCalendarItem] {
        let cal = Calendar.current
        var items: [UnifiedCalendarItem] = []
        
        // Add Events
        let dayEvents = calendarManager.events.filter { cal.isDate($0.startDate, inSameDayAs: date) }
        items.append(contentsOf: dayEvents.map { UnifiedCalendarItem(event: $0) })
        
        // Add Tasks
        let dayTasks = allTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return cal.isDate(dueDate, inSameDayAs: date)
        }
        items.append(contentsOf: dayTasks.map { UnifiedCalendarItem(task: $0) })
        
        return items.sorted { $0.date < $1.date }
    }
}

// MARK: - Unified Data Model
struct UnifiedCalendarItem: Identifiable {
    let id = UUID()
    let title: String
    let date: Date
    let color: Color
    let isTask: Bool
    let duration: TimeInterval
    
    init(event: EKEvent) {
        self.title = event.title
        self.date = event.startDate
        self.color = Color(cgColor: event.calendar.cgColor)
        self.isTask = false
        self.duration = event.endDate.timeIntervalSince(event.startDate)
    }
    
    init(task: AgencyTask) {
        self.title = task.content
        self.date = task.dueDate ?? Date()
        self.color = Color(hex: task.project?.accentHex ?? "#5AE6FF") ?? .blue
        self.isTask = true
        self.duration = 3600 // Default 1 hour for tasks
    }
}

// MARK: - Views

struct MonthView: View {
    @Binding var selectedDate: Date
    let tasks: [AgencyTask]
    let events: [EKEvent]
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Weekday Headers
                HStack(spacing: 0) {
                    ForEach(days, id: \.self) { day in
                        Text(day.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
                .background(Color.white.opacity(0.05))
                
                let daysInMonth = datesInMonth()
                let cellHeight = (geometry.size.height - 40) / CGFloat(daysInMonth.count / 7 + 1)
                
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(daysInMonth, id: \.self) { date in
                        MonthCell(
                            date: date,
                            height: cellHeight,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isCurrentMonth: calendar.isDate(date, equalTo: selectedDate, toGranularity: .month),
                            items: itemsFor(date: date)
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    }
                }
            }
        }
    }
    
    func datesInMonth() -> [Date] {
        guard let _ = calendar.range(of: .day, in: .month, for: selectedDate),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)) else { return [] }
        
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let offset = firstWeekday - 1
        
        // Start from previous month's overlapping days
        let start = calendar.date(byAdding: .day, value: -offset, to: firstOfMonth)!
        
        // 42 days (6 weeks) standard grid
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
    
    func itemsFor(date: Date) -> [UnifiedCalendarItem] {
        var items: [UnifiedCalendarItem] = []
        items.append(contentsOf: events.filter { calendar.isDate($0.startDate, inSameDayAs: date) }.map { UnifiedCalendarItem(event: $0) })
        items.append(contentsOf: tasks.filter { calendar.isDate($0.dueDate ?? Date.distantPast, inSameDayAs: date) }.map { UnifiedCalendarItem(task: $0) })
        return items
    }
}

struct MonthCell: View {
    let date: Date
    let height: CGFloat
    let isSelected: Bool
    let isCurrentMonth: Bool
    let items: [UnifiedCalendarItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .black : (isCurrentMonth ? .white : .white.opacity(0.3)))
                    .frame(width: 24, height: 24)
                    .background(isSelected ? Color.white : Color.clear)
                    .clipShape(Circle())
                Spacer()
            }
            .padding(6)
            
            // Dots/Bars for events
            ForEach(items.prefix(4)) { item in
                HStack(spacing: 4) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 4, height: 4)
                    Text(item.title)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                .padding(.horizontal, 4)
            }
            
            if items.count > 4 {
                Text("+ \(items.count - 4) more")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.leading, 8)
            }
            
            Spacer()
        }
        .frame(height: height)
        .background(Color.white.opacity(0.02))
        .border(Color.white.opacity(0.05), width: 0.5)
    }
}

struct WeekView: View {
    @Binding var selectedDate: Date
    let tasks: [AgencyTask]
    let events: [EKEvent]
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                // Fixed Time Column
                TimeLabels()
                    .padding(.top, 40) // Align with grid start
                    .frame(width: 50)
                    .background(Color.white.opacity(0.05))
                
                // Responsive Day Columns
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        // Header Row (Days)
                        HStack(spacing: 0) {
                            let weekDates = getWeekDates()
                            let dayWidth = (geometry.size.width - 50) / 7
                            
                            ForEach(weekDates, id: \.self) { date in
                                VStack {
                                    Text(date.formatted(.dateTime.weekday(.abbreviated)))
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Calendar.current.isDateInToday(date) ? .blue : .white.opacity(0.6))
                                    Text(date.formatted(.dateTime.day()))
                                        .font(.system(size: 20))
                                        .foregroundStyle(Calendar.current.isDateInToday(date) ? .blue : .white)
                                }
                                .frame(width: dayWidth, height: 50)
                                .background(Calendar.current.isDate(date, inSameDayAs: selectedDate) ? Color.white.opacity(0.1) : Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedDate = date }
                            }
                        }
                        .background(Color.white.opacity(0.05)) // Header background
                        
                        Divider().background(.white.opacity(0.1))
                        
                        // Timeline Grid
                        ZStack(alignment: .topLeading) {
                            let weekDates = getWeekDates()
                            let dayWidth = (geometry.size.width - 50) / 7
                            
                            // 1. Grid Lines (Horizontal)
                            VStack(spacing: 0) {
                                ForEach(0..<24) { _ in
                                    Divider()
                                        .background(.white.opacity(0.05))
                                    Spacer().frame(height: 60) // 60px per hour
                                }
                            }
                            
                            // 2. Vertical Day Dividers
                            HStack(spacing: 0) {
                                ForEach(0..<7) { _ in
                                    Divider()
                                        .background(.white.opacity(0.05))
                                        .frame(width: 1, height: 24 * 60 + 20)
                                    Spacer().frame(width: dayWidth - 1)
                                }
                            }
                            
                            // 3. Events Placed Absolutely
                            ForEach(weekDates.indices, id: \.self) { index in
                                let date = weekDates[index]
                                let items = itemsFor(date: date)
                                let xOffset = CGFloat(index) * dayWidth
                                
                                ZStack(alignment: .topLeading) {
                                    ForEach(items) { item in
                                        EventBlock(item: item)
                                            .frame(width: dayWidth - 4) // Padding for aesthetics
                                            .offset(y: offsetForTime(item.date))
                                    }
                                }
                                .frame(width: dayWidth, alignment: .topLeading)
                                .offset(x: xOffset)
                            }
                            
                            // 4. Current Time Indicator
                            if let todayIndex = weekDates.firstIndex(where: { Calendar.current.isDateInToday($0) }) {
                                CurrentTimeLine()
                                    .frame(width: dayWidth)
                                    .offset(x: CGFloat(todayIndex) * dayWidth)
                            }
                        }
                        .frame(height: 24 * 60 + 20)
                    }
                }
            }
        }
        .background(Color.clear)
    }
    
    func getWeekDates() -> [Date] {
        let start = selectedDate.startOfWeek
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }
    
    func itemsFor(date: Date) -> [UnifiedCalendarItem] {
        var items: [UnifiedCalendarItem] = []
        items.append(contentsOf: events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }.map { UnifiedCalendarItem(event: $0) })
        items.append(contentsOf: tasks.filter { Calendar.current.isDate($0.dueDate ?? Date.distantPast, inSameDayAs: date) }.map { UnifiedCalendarItem(task: $0) })
        return items
    }
    
    func offsetForTime(_ date: Date) -> CGFloat {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        return CGFloat(hour * 60 + minute)
    }
}

struct DayView: View {
    @Binding var selectedDate: Date
    let tasks: [AgencyTask]
    let events: [EKEvent]
    
    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 0) {
                TimeLabels()
                
                ZStack(alignment: .top) {
                    // Grid Lines
                    VStack(spacing: 0) {
                        ForEach(0..<24) { _ in
                            Divider().background(.white.opacity(0.1))
                            Spacer().frame(height: 60)
                        }
                    }
                    
                    let items = itemsFor(date: selectedDate)
                    ForEach(items) { item in
                        EventBlock(item: item)
                    }
                    
                    if Calendar.current.isDateInToday(selectedDate) {
                        CurrentTimeLine()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.leading, 10)
            }
            .padding(.vertical, 20)
        }
        .background(Color.clear)
    }
    
    func itemsFor(date: Date) -> [UnifiedCalendarItem] {
        var items: [UnifiedCalendarItem] = []
        items.append(contentsOf: events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }.map { UnifiedCalendarItem(event: $0) })
        items.append(contentsOf: tasks.filter { Calendar.current.isDate($0.dueDate ?? Date.distantPast, inSameDayAs: date) }.map { UnifiedCalendarItem(task: $0) })
        return items
    }
}

struct TimeLabels: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<24) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(height: 60, alignment: .top)
                    .offset(y: -5) // Align with grid line
            }
        }
        .frame(width: 40)
    }
}

struct EventBlock: View {
    let item: UnifiedCalendarItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.title)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
            Text(item.date.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 9))
                .opacity(0.8)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: CGFloat(item.duration / 60)) // 1 min = 1 pixel roughly (scale 60px/hr = 1px/min)
        .background(item.color.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(item.color, lineWidth: 1))
        .foregroundStyle(.white)
        .offset(y: offsetForTime(item.date))
        .padding(.horizontal, 2)
    }
    
    func offsetForTime(_ date: Date) -> CGFloat {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        return CGFloat(hour * 60 + minute)
    }
}

struct CurrentTimeLine: View {
    @State private var nowOffset: CGFloat = 0
    
    var body: some View {
        Rectangle()
            .fill(Color.red)
            .frame(height: 1)
            .overlay(
                Circle().fill(.red).frame(width: 6, height: 6),
                alignment: .leading
            )
            .offset(y: nowOffset)
            .onAppear { updateTime() }
    }
    
    func updateTime() {
        let now = Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        nowOffset = CGFloat(hour * 60 + minute)
    }
}

// MARK: - Mini Components

struct MiniCalendar: View {
    @Binding var selectedDate: Date
    private let calendar = Calendar.current
    
    var body: some View {
        VStack {
            HStack {
                Text(selectedDate.formatted(.dateTime.month().year()))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 15) {
                    Button(action: { selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate)! }) {
                        Image(systemName: "chevron.left").font(.caption)
                    }
                    Button(action: { selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate)! }) {
                        Image(systemName: "chevron.right").font(.caption)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 10)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { d in
                    Text(d).font(.caption2).foregroundStyle(.gray)
                }
                
                ForEach(daysForMiniCalendar(), id: \.self) { date in
                    Text("\(calendar.component(.day, from: date))")
                        .font(.caption)
                        .foregroundStyle(
                            calendar.isDate(date, inSameDayAs: selectedDate) ? .black :
                            calendar.isDate(date, equalTo: selectedDate, toGranularity: .month) ? .white : .gray
                        )
                        .frame(width: 24, height: 24)
                        .background(calendar.isDate(date, inSameDayAs: selectedDate) ? Color.white : Color.clear)
                        .clipShape(Circle())
                        .onTapGesture { selectedDate = date }
                }
            }
        }
    }
    
    func daysForMiniCalendar() -> [Date] {
        guard let _ = calendar.range(of: .day, in: .month, for: selectedDate),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)) else { return [] }
        let offset = calendar.component(.weekday, from: first) - 1
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0 - offset, to: first) }
    }
}

struct SidebarItemRow: View {
    let item: UnifiedCalendarItem
    
    var body: some View {
        HStack {
            Rectangle()
                .fill(item.color)
                .frame(width: 3)
                .clipShape(Capsule())
            
            VStack(alignment: .leading) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(item.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

extension Date {
    var startOfWeek: Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)) ?? self
    }
}