import SwiftUI
import SwiftData

struct ProjectFinancialsView: View {
    @Bindable var project: Project
    @Environment(\.dismiss) private var dismiss

    // Financial Computations
    private var clientPrice: Double { project.budget }
    
    private var laborCost: Double {
        let hours = project.tasks.reduce(0) { $0 + $1.actualHours }
        return hours * project.internalRate
    }
    
    private var totalInternalCost: Double {
        laborCost + project.additionalCosts
    }
    
    private var profit: Double {
        clientPrice - totalInternalCost
    }
    
    private var profitMargin: Double {
        guard clientPrice > 0 else { return 0 }
        return profit / clientPrice
    }
    
    private var profitColor: Color {
        if profit < 0 { return .red }
        if profitMargin < 0.2 { return .orange }
        return .green
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Project Financials")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text(project.title)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.black.opacity(0.2))

            ScrollView {
                VStack(spacing: 24) {
                    
                    // Main Profit Card
                    VStack(spacing: 10) {
                        Text("NET PROFIT")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                            .kerning(1)
                        
                        Text(formatCurrency(profit))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(profitColor)
                        
                        if clientPrice > 0 {
                            Text("\(Int(profitMargin * 100))% Margin")
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(profitColor.opacity(0.2))
                                .foregroundStyle(profitColor)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(30)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(profitColor.opacity(0.3), lineWidth: 1))
                    
                    // Inputs Section
                    HStack(alignment: .top, spacing: 16) {
                        // Revenue Side
                        VStack(spacing: 12) {
                            SectionHeader(title: "CLIENT CHARGE", icon: "arrow.down.circle.fill", color: .green)
                            FinancialInputRow(label: "Fixed Price", value: $project.budget)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        // Cost Side
                        VStack(spacing: 12) {
                            SectionHeader(title: "MY COST OF SERVICE", icon: "arrow.up.circle.fill", color: .red)
                            FinancialInputRow(label: "My Hourly Cost", value: $project.internalRate)
                            FinancialInputRow(label: "Expenses", value: $project.additionalCosts)
                            
                            Divider().background(.white.opacity(0.1))
                            
                            HStack {
                                Text("Labor Burn")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.5))
                                Spacer()
                                Text(formatCurrency(laborCost))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    // Task Labor Breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Labor Cost Breakdown")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                        
                        VStack(spacing: 1) {
                            ForEach(project.tasks) { task in
                                TaskLaborRow(task: task, internalRate: project.internalRate)
                            }
                        }
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 550, height: 600)
        .background(Color.black.opacity(0.85))
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .kerning(0.5)
            Spacer()
        }
        .padding(.bottom, 4)
    }
}

struct FinancialInputRow: View {
    let label: String
    @Binding var value: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
            
            TextField("0", value: $value, format: .currency(code: "USD"))
                .font(.system(size: 14, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.1), lineWidth: 1))
        }
    }
}

struct TaskLaborRow: View {
    @Bindable var task: AgencyTask
    let internalRate: Double
    
    var laborCost: Double { task.actualHours * internalRate }
    
    var body: some View {
        HStack {
            Text(task.content)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .lineLimit(1)
            
            Spacer()
            
            // Editable Hours
            HStack(spacing: 6) {
                TextField("0", value: $task.actualHours, format: .number)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 30)
                    .padding(4)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                Text("hrs")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
            }
            
            // Cost
            Text(formatCurrency(laborCost))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.red.opacity(0.8))
                .frame(width: 70, alignment: .trailing)
        }
        .padding(12)
        .background(Color.white.opacity(0.02))
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}