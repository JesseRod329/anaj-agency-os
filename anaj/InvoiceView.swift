import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

// MARK: - Invoice Creation Sheet

struct InvoiceFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @Query private var projects: [Project]
    @Query private var clients: [Client]
    
    @State private var invoiceNumber: String = ""
    @State private var selectedProject: Project?
    @State private var selectedClient: Client?
    @State private var issueDate = Date()
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var notes: String = ""
    @State private var taxRate: Double = 0
    @State private var discount: Double = 0
    
    // Business Info
    @State private var businessName: String = ""
    @State private var businessAddress: String = ""
    @State private var businessEmail: String = ""
    @State private var businessPhone: String = ""
    
    // Line Items
    @State private var lineItems: [TempLineItem] = [TempLineItem()]
    
    struct TempLineItem: Identifiable {
        let id = UUID()
        var description: String = ""
        var quantity: Double = 1
        var rate: Double = 0
        
        var amount: Double { quantity * rate }
    }
    
    var subtotal: Double {
        lineItems.reduce(0) { $0 + $1.amount }
    }
    
    var taxAmount: Double {
        subtotal * (taxRate / 100)
    }
    
    var total: Double {
        subtotal + taxAmount - discount
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Invoice")
                    .font(AppFonts.display(24))
                    .foregroundStyle(AppColors.textPrimary)
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(AppSpacing.xxl)
            .background(AppColors.bgSecondary)
            
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xxl) {
                    // Invoice Details Section
                    InvoiceSectionCard(title: "INVOICE DETAILS") {
                        HStack(spacing: 20) {
                            InvoiceTextField(title: "Invoice #", text: $invoiceNumber, placeholder: "INV-001")
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Issue Date")
                                    .font(AppFonts.caption(11).weight(.bold))
                                    .foregroundStyle(AppColors.textSecondary)
                                DatePicker("", selection: $issueDate, displayedComponents: .date)
                                    .labelsHidden()
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Due Date")
                                    .font(AppFonts.caption(11).weight(.bold))
                                    .foregroundStyle(AppColors.textSecondary)
                                DatePicker("", selection: $dueDate, displayedComponents: .date)
                                    .labelsHidden()
                            }
                        }
                        
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Project")
                                    .font(AppFonts.caption(11).weight(.bold))
                                    .foregroundStyle(AppColors.textSecondary)
                                Picker("", selection: $selectedProject) {
                                    Text("None").tag(nil as Project?)
                                    ForEach(projects) { project in
                                        Text(project.title).tag(project as Project?)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Client")
                                    .font(AppFonts.caption(11).weight(.bold))
                                    .foregroundStyle(AppColors.textSecondary)
                                Picker("", selection: $selectedClient) {
                                    Text("None").tag(nil as Client?)
                                    ForEach(clients) { client in
                                        Text(client.name).tag(client as Client?)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }
                        }
                    }
                    
                    // Business Info Section
                    InvoiceSectionCard(title: "YOUR BUSINESS INFO") {
                        HStack(spacing: 20) {
                            InvoiceTextField(title: "Business Name", text: $businessName, placeholder: "Your Company")
                            InvoiceTextField(title: "Email", text: $businessEmail, placeholder: "billing@company.com")
                        }
                        HStack(spacing: 20) {
                            InvoiceTextField(title: "Address", text: $businessAddress, placeholder: "123 Main St, City")
                            InvoiceTextField(title: "Phone", text: $businessPhone, placeholder: "(555) 123-4567")
                        }
                    }
                    
                    // Line Items Section
                    InvoiceSectionCard(title: "LINE ITEMS") {
                        VStack(spacing: AppSpacing.md) {
                            // Header Row
                            HStack(spacing: 15) {
                                Text("Description")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("Qty")
                                    .frame(width: 60)
                                Text("Rate")
                                    .frame(width: 100)
                                Text("Amount")
                                    .frame(width: 100)
                                Text("")
                                    .frame(width: 30)
                            }
                            .font(AppFonts.caption(10).weight(.bold))
                            .foregroundStyle(AppColors.textSecondary)
                            
                            Divider().overlay(AppColors.borderSubtle)
                            
                            // Line Items
                            ForEach($lineItems) { $item in
                                HStack(spacing: 15) {
                                    TextField("Service description", text: $item.description)
                                        .textFieldStyle(.plain)
                                        .padding(10)
                                        .background(AppColors.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                                        .foregroundStyle(AppColors.textPrimary)
                                    
                                    TextField("1", value: $item.quantity, format: .number)
                                        .textFieldStyle(.plain)
                                        .multilineTextAlignment(.center)
                                        .padding(10)
                                        .frame(width: 60)
                                        .background(AppColors.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                                        .foregroundStyle(AppColors.textPrimary)
                                    
                                    TextField("$0", value: $item.rate, format: .currency(code: "USD"))
                                        .textFieldStyle(.plain)
                                        .multilineTextAlignment(.trailing)
                                        .padding(10)
                                        .frame(width: 100)
                                        .background(AppColors.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                                        .foregroundStyle(AppColors.textPrimary)
                                    
                                    Text(formatCurrency(item.amount))
                                        .font(AppFonts.code(14).weight(.semibold))
                                        .foregroundStyle(AppColors.textPrimary)
                                        .frame(width: 100, alignment: .trailing)
                                    
                                    Button {
                                        lineItems.removeAll { $0.id == item.id }
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(AppColors.accentRed.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                    .frame(width: 30)
                                    .opacity(lineItems.count > 1 ? 1 : 0.3)
                                    .disabled(lineItems.count <= 1)
                                }
                            }
                            
                            Button {
                                lineItems.append(TempLineItem())
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Line Item")
                                }
                                .font(AppFonts.caption(13).weight(.semibold))
                                .foregroundStyle(AppColors.accentBlue)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                        }
                    }
                    
                    // Totals Section
                    HStack {
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 12) {
                            HStack(spacing: 20) {
                                Text("Subtotal")
                                    .foregroundStyle(AppColors.textSecondary)
                                Text(formatCurrency(subtotal))
                                    .font(AppFonts.code(16).weight(.semibold))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .frame(width: 120, alignment: .trailing)
                            }
                            
                            HStack(spacing: 20) {
                                HStack(spacing: 8) {
                                    Text("Tax")
                                        .foregroundStyle(AppColors.textSecondary)
                                    TextField("0", value: $taxRate, format: .number)
                                        .textFieldStyle(.plain)
                                        .multilineTextAlignment(.trailing)
                                        .padding(6)
                                        .frame(width: 50)
                                        .background(AppColors.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text("%")
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                                Text(formatCurrency(taxAmount))
                                    .font(AppFonts.code(16).weight(.semibold))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .frame(width: 120, alignment: .trailing)
                            }
                            
                            HStack(spacing: 20) {
                                Text("Discount")
                                    .foregroundStyle(AppColors.textSecondary)
                                TextField("$0", value: $discount, format: .currency(code: "USD"))
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .padding(6)
                                    .frame(width: 100)
                                    .background(AppColors.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                                    .foregroundStyle(AppColors.textPrimary)
                            }
                            
                            Divider().frame(width: 250).overlay(AppColors.borderSubtle)
                            
                            HStack(spacing: 20) {
                                Text("Total")
                                    .font(AppFonts.title(18).weight(.bold))
                                    .foregroundStyle(AppColors.textPrimary)
                                Text(formatCurrency(total))
                                    .font(AppFonts.code(24).weight(.bold))
                                    .foregroundStyle(AppColors.accentGreen)
                                    .frame(width: 120, alignment: .trailing)
                            }
                        }
                        .padding(AppSpacing.xl)
                        .background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
                    }
                    
                    // Notes Section
                    InvoiceSectionCard(title: "NOTES") {
                        TextEditor(text: $notes)
                            .scrollContentBackground(.hidden)
                            .font(AppFonts.body())
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(minHeight: 80)
                            .padding(AppSpacing.md)
                            .background(AppColors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    }
                }
                .padding(AppSpacing.xxl)
            }
            
            // Action Buttons
            HStack(spacing: AppSpacing.lg) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(AppFonts.body().weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, AppSpacing.xxl)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    saveInvoice(asDraft: true)
                } label: {
                    Text("Save as Draft")
                        .font(AppFonts.body().weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, AppSpacing.xxl)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.surfaceStrong)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                }
                .buttonStyle(.plain)
                
                Button {
                    saveInvoice(asDraft: false)
                    exportToPDF()
                } label: {
                    HStack {
                        Image(systemName: "doc.fill")
                        Text("Create & Export PDF")
                    }
                    .font(AppFonts.body().weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xxl)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.accentBlue)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                }
                .buttonStyle(.plain)
            }
            .padding(AppSpacing.xxl)
            .background(AppColors.bgSecondary)
        }
        .frame(width: 900, height: 800)
        .background(.regularMaterial)
        .onAppear {
            generateInvoiceNumber()
        }
    }
    
    private func generateInvoiceNumber() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateStr = dateFormatter.string(from: Date())
        let random = Int.random(in: 100...999)
        invoiceNumber = "INV-\(dateStr)-\(random)"
    }
    
    private func saveInvoice(asDraft: Bool) {
        let invoice = Invoice(
            invoiceNumber: invoiceNumber,
            issueDate: issueDate,
            dueDate: dueDate,
            status: asDraft ? .draft : .sent,
            notes: notes,
            taxRate: taxRate,
            discount: discount,
            businessName: businessName,
            businessAddress: businessAddress,
            businessEmail: businessEmail,
            businessPhone: businessPhone
        )
        
        invoice.project = selectedProject
        invoice.client = selectedClient
        
        // Add line items
        for item in lineItems where !item.description.isEmpty {
            let invoiceItem = InvoiceItem(
                itemDescription: item.description,
                quantity: item.quantity,
                rate: item.rate
            )
            invoiceItem.invoice = invoice
            invoice.lineItems.append(invoiceItem)
            modelContext.insert(invoiceItem)
        }
        
        modelContext.insert(invoice)
        
        // Also add to project/client relationships
        selectedProject?.invoices.append(invoice)
        selectedClient?.invoices.append(invoice)
        
        try? modelContext.save()
    }
    
    private func exportToPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(invoiceNumber).pdf"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                generatePDF(to: url)
            }
        }
        
        dismiss()
    }
    
    private func generatePDF(to url: URL) {
        let pdfContent = createPDFContent()
        let printInfo = NSPrintInfo.shared
        printInfo.paperSize = NSSize(width: 612, height: 792)
        printInfo.topMargin = 50
        printInfo.bottomMargin = 50
        printInfo.leftMargin = 50
        printInfo.rightMargin = 50
        
        let view = NSHostingView(rootView: pdfContent)
        view.frame = NSRect(x: 0, y: 0, width: 512, height: 692)
        
        let _ = NSMutableData()
        let printOp = view.dataWithPDF(inside: view.bounds)
        
        try? printOp.write(to: url)
    }
    
    @ViewBuilder
    private func createPDFContent() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(businessName.isEmpty ? "Your Business" : businessName)
                        .font(.title.bold())
                    Text(businessAddress)
                        .font(.caption)
                    Text(businessEmail)
                        .font(.caption)
                    Text(businessPhone)
                        .font(.caption)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("INVOICE")
                        .font(.largeTitle.bold())
                    Text(invoiceNumber)
                        .font(.title3)
                }
            }
            
            Divider()
            
            // Client Info
            if let client = selectedClient {
                VStack(alignment: .leading) {
                    Text("Bill To:")
                        .font(.caption.bold())
                    Text(client.name)
                        .font(.body)
                }
            }
            
            // Dates
            HStack {
                VStack(alignment: .leading) {
                    Text("Issue Date: \(issueDate.formatted(date: .abbreviated, time: .omitted))")
                    Text("Due Date: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                }
                .font(.caption)
                Spacer()
            }
            
            // Line Items
            VStack(spacing: 8) {
                HStack {
                    Text("Description").bold()
                    Spacer()
                    Text("Qty").bold().frame(width: 50)
                    Text("Rate").bold().frame(width: 80)
                    Text("Amount").bold().frame(width: 80)
                }
                .font(.caption)
                
                Divider()
                
                ForEach(lineItems.filter { !$0.description.isEmpty }) { item in
                    HStack {
                        Text(item.description)
                        Spacer()
                        Text("\(item.quantity, specifier: "%.1f")").frame(width: 50)
                        Text(formatCurrency(item.rate)).frame(width: 80)
                        Text(formatCurrency(item.amount)).frame(width: 80)
                    }
                    .font(.caption)
                }
            }
            
            Divider()
            
            // Totals
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Text("Subtotal:")
                        Text(formatCurrency(subtotal))
                    }
                    if taxRate > 0 {
                        HStack {
                            Text("Tax (\(taxRate, specifier: "%.1f")%):")
                            Text(formatCurrency(taxAmount))
                        }
                    }
                    if discount > 0 {
                        HStack {
                            Text("Discount:")
                            Text("-\(formatCurrency(discount))")
                        }
                    }
                    HStack {
                        Text("Total:").bold()
                        Text(formatCurrency(total)).bold()
                    }
                }
                .font(.caption)
            }
            
            if !notes.isEmpty {
                Divider()
                Text("Notes:")
                    .font(.caption.bold())
                Text(notes)
                    .font(.caption)
            }
            
            Spacer()
        }
        .padding()
        .foregroundStyle(.black)
        .background(.white)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// MARK: - Supporting Views

struct InvoiceSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text(title)
                .font(AppFonts.caption(11).weight(.black))
                .kerning(1.5)
                .foregroundStyle(AppColors.textSecondary)
            
            content
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.xl).stroke(AppColors.borderSubtle, lineWidth: 1))
    }
}

struct InvoiceTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppFonts.caption(11).weight(.bold))
                .foregroundStyle(AppColors.textSecondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(AppSpacing.md)
                .background(AppColors.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(AppColors.borderSubtle, lineWidth: 1))
        }
    }
}

// MARK: - Invoice List Row

struct InvoiceRow: View {
    let invoice: Invoice
    
    var body: some View {
        HStack(spacing: AppSpacing.xl) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(invoice.status.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: statusIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(invoice.status.color)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.invoiceNumber)
                    .font(AppFonts.title())
                    .foregroundStyle(AppColors.textPrimary)
                
                HStack(spacing: 10) {
                    if let client = invoice.client {
                        Text(client.name)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Text("Due: \(invoice.dueDate.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundStyle(AppColors.textTertiary)
                }
                .font(AppFonts.caption())
            }
            
            Spacer()
            
            // Total
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(invoice.total))
                    .font(AppFonts.code(16).weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                
                Text(invoice.status.rawValue)
                    .font(AppFonts.caption(10).weight(.bold))
                    .foregroundStyle(invoice.status.color)
            }
            
            // Status Badge
            Text(invoice.status.rawValue)
                .font(AppFonts.caption().weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(invoice.status.color.opacity(0.2))
                .foregroundStyle(invoice.status.color)
                .clipShape(Capsule())
        }
        .padding(AppSpacing.xl)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.xl).stroke(AppColors.borderSubtle, lineWidth: 1))
    }
    
    private var statusIcon: String {
        switch invoice.status {
        case .draft: return "doc"
        case .sent: return "paperplane"
        case .paid: return "checkmark"
        case .overdue: return "exclamationmark.triangle"
        case .cancelled: return "xmark"
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}
