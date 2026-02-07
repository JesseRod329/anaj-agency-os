import SwiftUI
import SwiftData

struct ClientDetailView: View {
    @Bindable var client: Client
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(client.industry.uppercased())
                        .font(.system(size: 11, weight: .black))
                        .kerning(1.5)
                        .foregroundStyle(Color(hex: client.brandHex) ?? .white)
                    
                    Text(client.name)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 20) {
                // Projects List
                VStack(alignment: .leading, spacing: 15) {
                    Text("Associated Projects")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    ScrollView {
                        VStack(spacing: 12) {
                            if client.projects.isEmpty {
                                Text("No projects assigned to this client yet.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.3))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 10)
                            } else {
                                ForEach(client.projects) { project in
                                    HStack {
                                        Circle()
                                            .fill(Color(hex: project.accentHex) ?? .white)
                                            .frame(width: 8, height: 8)
                                        Text(project.title)
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.white.opacity(0.3))
                                    }
                                    .padding(15)
                                    .background(.white.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Brand Summary
                VStack(alignment: .leading, spacing: 20) {
                    Text("Brand Palette")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: client.brandHex) ?? .blue)
                        .frame(height: 120)
                        .overlay(
                            Text(client.brandHex)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .padding(6)
                                .background(.black.opacity(0.3))
                                .clipShape(Capsule())
                        )
                    
                    VStack(alignment: .leading, spacing: 10) {
                        InfoRow(label: "Industry", value: client.industry)
                        InfoRow(label: "Created", value: "Dec 21, 2025")
                    }
                    
                    Spacer()
                    
                    Button(role: .destructive) {
                        modelContext.delete(client)
                        dismiss()
                    } label: {
                        Text("Delete Client")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 250)
                .padding(20)
                .background(.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
        }
        .padding(30)
        .background(LiquidBackground().opacity(0.5))
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.4))
            Text(value).font(.system(size: 13)).foregroundStyle(.white)
        }
    }
}
