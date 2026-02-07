import SwiftUI
import SwiftData
import Charts

struct AgencyLedgerView: View {
    @Query private var projects: [Project]
    @Query private var tasks: [AgencyTask]
    @Query private var invoices: [Invoice]
    
    @State private var selectedTab: LedgerTab = .profitability
    @State private var showInvoiceSheet = false
    
    enum LedgerTab: String, CaseIterable {
        case profitability = "Profitability"
        case invoices = "Invoices"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Agency Operations")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .kerning(1)
                    
                    Text("Profit Ledger")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                // Create Invoice Button
                Button {
                    showInvoiceSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("New Invoice")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            
            // Tab Picker
            HStack(spacing: 0) {
                ForEach(LedgerTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(selectedTab == tab ? .white.opacity(0.15) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            
            // Content Based on Tab
            if selectedTab == .profitability {
                profitabilityContent
            } else {
                invoicesContent
            }
        }
        .padding(30)
        .sheet(isPresented: $showInvoiceSheet) {
            InvoiceFormSheet()
        }
    }
    
    // MARK: - Profitability Tab Content
    
    @ViewBuilder
    private var profitabilityContent: some View {
        // Stats Overview
        HStack(spacing: 20) {
            LedgerStatCard(title: "Total Revenue", value: totalRevenue, icon: "banknote", color: .green)
            LedgerStatCard(title: "Net Profit", value: netProfit, icon: "chart.line.uptrend.xyaxis", color: .blue)
            LedgerStatCard(title: "Avg Margin", value: averageMargin, icon: "percent", color: .orange)
        }
        
        // Charts Section
        if !projects.isEmpty {
            ProfitabilityChart(projects: projects, tasks: tasks)
                .frame(height: 250)
        }
        
        // Project Financial List
        ScrollView {
            VStack(spacing: 15) {
                ForEach(projects) { project in
                    ProjectProfitRow(project: project, allTasks: tasks)
                }
            }
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - Invoices Tab Content
    
    @ViewBuilder
    private var invoicesContent: some View {
        // Invoice Stats
        HStack(spacing: 20) {
            LedgerStatCard(title: "Total Invoiced", value: totalInvoiced, icon: "doc.text", color: .blue)
            LedgerStatCard(title: "Paid", value: totalPaid, icon: "checkmark.circle", color: .green)
            LedgerStatCard(title: "Outstanding", value: totalOutstanding, icon: "clock", color: .orange)
        }
        
        // Invoice List
        ScrollView {
            if invoices.isEmpty {
                VStack(spacing: 15) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("No invoices yet")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Create your first invoice to get started")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                VStack(spacing: 15) {
                    ForEach(invoices.sorted { $0.issueDate > $1.issueDate }) { invoice in
                        InvoiceRow(invoice: invoice)
                    }
                }
                .padding(.bottom, 30)
            }
        }
    }
    
    // MARK: - Invoice Computed Stats
    
    private var totalInvoiced: String {
        let total = invoices.reduce(0) { $0 + $1.total }
        return formatCurrency(total)
    }
    
    private var totalPaid: String {
        let total = invoices.filter { $0.status == .paid }.reduce(0) { $0 + $1.total }
        return formatCurrency(total)
    }
    
    private var totalOutstanding: String {
        let total = invoices.filter { $0.status == .sent || $0.status == .overdue }.reduce(0) { $0 + $1.total }
        return formatCurrency(total)
    }
    
    // MARK: - Computed Stats
    private var totalRevenue: String {
        let total = projects.reduce(0) { $0 + $1.budget }
        return formatCurrency(total)
    }
    
    private var netProfit: String {
        let total = projects.reduce(0) { sum, project in
            let projectTasks = tasks.filter { $0.project?.id == project.id }
            let laborCost = projectTasks.reduce(0) { $0 + ($1.actualHours * project.internalRate) }
            let totalCost = laborCost + project.additionalCosts
            return sum + (project.budget - totalCost)
        }
        return formatCurrency(total)
    }
    
    private var averageMargin: String {
        let totalRev = projects.reduce(0) { $0 + $1.budget }
        guard totalRev > 0 else { return "0%" }
        
        let totalProfit = projects.reduce(0) { sum, project in
            let projectTasks = tasks.filter { $0.project?.id == project.id }
            let laborCost = projectTasks.reduce(0) { $0 + ($1.actualHours * project.internalRate) }
            return sum + (project.budget - (laborCost + project.additionalCosts))
        }
        
        let margin = (totalProfit / totalRev) * 100
        return "\(Int(margin))%"
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Components

struct ProfitabilityChart: View {
    let projects: [Project]
    let tasks: [AgencyTask]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PROFITABILITY ANALYSIS")
                .font(.system(size: 11, weight: .black))
                .kerning(1.5)
                .foregroundStyle(.white.opacity(0.4))
            
            Chart {
                ForEach(projects) { project in
                    let costs = calculateCosts(for: project)
                    let profit = project.budget - costs
                    
                    // Cost Bar
                    BarMark(
                        x: .value("Project", project.title),
                        y: .value("Amount", costs)
                    )
                    .foregroundStyle(.red.opacity(0.5))
                    
                    // Profit Bar (Stacked)
                    BarMark(
                        x: .value("Project", project.title),
                        y: .value("Amount", max(0, profit))
                    )
                    .foregroundStyle(.green.opacity(0.8))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 4])).foregroundStyle(.white.opacity(0.1))
                    AxisValueLabel().foregroundStyle(.white.opacity(0.4))
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel().foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
        }
    }
    
    private func calculateCosts(for project: Project) -> Double {
        let projectTasks = tasks.filter { $0.project?.id == project.id }
        let labor = projectTasks.reduce(0) { $0 + ($1.actualHours * project.internalRate) }
        return labor + project.additionalCosts
    }
}


struct LedgerStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1), lineWidth: 1))
    }
}

struct ProjectProfitRow: View {
    let project: Project
    let allTasks: [AgencyTask]
    
    var projectTasks: [AgencyTask] {
        allTasks.filter { $0.project?.id == project.id }
    }
    
    var totalCost: Double {
        let labor = projectTasks.reduce(0) { $0 + ($1.actualHours * project.internalRate) }
        return labor + project.additionalCosts
    }
    
    var profit: Double {
        project.budget - totalCost
    }
    
    var margin: Double {
        guard project.budget > 0 else { return 0 }
        return profit / project.budget
    }
    
    var statusColor: Color {
        if profit < 0 { return .red }
        if margin < 0.2 { return .orange }
        return .green
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: profit >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(statusColor)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                
                Text("Fixed Price: \(formatCurrency(project.budget))")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }
            
            Spacer()
            
            // Financials
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(profit))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(statusColor)
                
                Text("Profit")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(statusColor.opacity(0.7))
            }
            
            // Margin Badge
            Text("\(Int(margin * 100))%")
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.2))
                .foregroundStyle(statusColor)
                .clipShape(Capsule())
                .frame(width: 50)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}
