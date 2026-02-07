#if os(macOS)
import SwiftUI
import SwiftData

struct TeamView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Member.name, order: .forward) private var members: [Member]
    
    @State private var showingAddMember = false
    @State private var showCloudInfo = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Main Content
            VStack(alignment: .leading, spacing: 25) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Collaboration")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .kerning(1)
                        
                        Text("Team")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    
                    Button(action: { showCloudInfo = true }) {
                        Image(systemName: "icloud.and.arrow.up.fill")
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(10)
                            .background(.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showCloudInfo) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("iCloud Sync")
                                .font(.headline)
                            Text("To enable real-time sync, open the Xcode project and add the 'iCloud' capability.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Divider()
                            Link("View Instructions", destination: URL(fileURLWithPath: "CLOUD_INSTRUCTIONS.md"))
                                .font(.caption)
                        }
                        .padding()
                        .frame(width: 250)
                    }
                    
                    Button(action: { showingAddMember.toggle() }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Member")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.8))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                
                // Content
                ScrollView {
                    if members.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.white.opacity(0.1))
                            Text("No team members yet")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.4))
                            Button("Add your first member", action: { showingAddMember = true })
                                .buttonStyle(.link)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 20) {
                            ForEach(members) { member in
                                MemberCard(member: member)
                            }
                        }
                    }
                }
            }
            .padding(30)
        }
        .sheet(isPresented: $showingAddMember) {
            AddMemberSheet()
        }
    }
}

struct MemberCard: View {
    let member: Member
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.randomSeeded(member.name))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Text(String(member.name.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text(member.role)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
                
                Menu {
                    Button("Send Email", action: sendEmail)
                    Divider()
                    Button("Remove", role: .destructive) {
                        modelContext.delete(member)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(8)
                        .background(.white.opacity(0.05))
                        .clipShape(Circle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
            }
            
            Divider().background(.white.opacity(0.1))
            
            HStack {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                Text(member.email)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                
                Spacer()
                
                Text("Offline")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.2))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.05))
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
    }
    
    private func sendEmail() {
        let service = NSSharingService(named: NSSharingService.Name.composeEmail)
        service?.recipients = [member.email]
        service?.subject = "Invitation to ANAJ Workspace"
        service?.perform(withItems: ["Hey, I've added you to our ANAJ workspace."])
    }
}

struct AddMemberSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var role = ""
    @State private var email = ""
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Member")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.white.opacity(0.05))
            
            Form {
                TextField("Full Name", text: $name)
                TextField("Role", text: $role)
                TextField("Email", text: $email)
            }
            .padding(20)
            
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add Member") {
                    let newMember = Member(name: name, role: role, email: email)
                    modelContext.insert(newMember)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || email.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 400)
    }
}

extension Color {
    static func randomSeeded(_ seed: String) -> Color {
        let hash = seed.hashValue
        let colors: [Color] = [.blue, .purple, .pink, .orange, .green, .teal]
        return colors[abs(hash) % colors.count]
    }
}
#endif
