import SwiftUI
import SwiftData

struct ClientsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Client.name, order: .forward) private var clients: [Client]
    
    @State private var showingAddClient = false
    @State private var newClientName = ""
    @State private var newClientIndustry = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Brand Management")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .kerning(1)
                    
                    Text("Clients")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                
                Button(action: { showingAddClient.toggle() }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Client")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            // Client Grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 20)], spacing: 20) {
                    ForEach(clients) { client in
                        ClientCard(client: client)
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .padding(30)
        .sheet(isPresented: $showingAddClient) {
            AddClientSheet()
                .environment(\.modelContext, modelContext)
        }
    }
}

struct ClientCard: View {
    @Bindable var client: Client
    @State private var showingDetails = false
    
    var body: some View {
        Button(action: { showingDetails.toggle() }) {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Circle()
                        .fill(Color(hex: client.brandHex) ?? .blue)
                        .frame(width: 12, height: 12)
                    
                    Text(client.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Text("\(client.projects.count) Projects")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                if !client.industry.isEmpty {
                    Text(client.industry)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Divider().background(.white.opacity(0.1))
                
                // Quick Project List
                VStack(alignment: .leading, spacing: 8) {
                    if client.projects.isEmpty {
                        Text("No projects")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.3))
                            .italic()
                    } else {
                        ForEach(client.projects.prefix(3)) { project in
                            HStack {
                                Circle()
                                    .fill(Color(hex: project.accentHex) ?? .white)
                                    .frame(width: 6, height: 6)
                                Text(project.title)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetails) {
            ClientDetailView(client: client)
                .frame(minWidth: 700, minHeight: 500)
        }
    }
}

struct AddClientSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var industry = ""
    @State private var brandColor = Color.blue
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Client Information") {
                    TextField("Name", text: $name)
                    TextField("Industry", text: $industry)
                }
                
                Section("Branding") {
                    ColorPicker("Brand Color", selection: $brandColor)
                }
            }
            .navigationTitle("New Client")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        saveClient()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .frame(width: 400, height: 300)
    }
    
    private func saveClient() {
        let hex = brandColor.toHex() ?? "#FFFFFF"
        let newClient = Client(name: name, industry: industry, brandHex: hex)
        
        // Use the main context explicitly
        modelContext.insert(newClient)
        
        let activity = Activity(title: "New Client Onboarded", subtitle: name, type: .client)
        modelContext.insert(activity)
        
        do {
            try modelContext.save()
            print("Successfully saved client: \(name)")
            dismiss()
        } catch {
            print("CRITICAL: Failed to save client: \(error.localizedDescription)")
            // Fallback: try to dismiss anyway so the UI doesn't hang
            dismiss()
        }
    }
}
