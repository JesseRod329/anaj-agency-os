import SwiftUI

// Define the routes for your sidebar
enum SidebarRoute: String, CaseIterable {
    case dashboard = "Dashboard"
    case projects = "Projects"
    #if os(macOS)
    case studio = "Prompt Studio"
    #endif
    #if os(iOS)
    case create = "Create"
    #endif
    case insights = "Insights"
    case clients = "Clients"
    case knowledge = "Knowledge"
    case memory = "Memory"
    case ledger = "Ledger"
    case team = "Team"
    case calendar = "Calendar"
    case archive = "Archive"
    case settings = "Settings"
    
    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .projects: return "folder.fill"
        #if os(macOS)
        case .studio: return "terminal.fill"
        #endif
        #if os(iOS)
        case .create: return "plus.circle.fill"
        #endif
        case .insights: return "lightbulb.fill"
        case .clients: return "person.2.fill"
        case .knowledge: return "doc.text.fill"
        case .memory: return "brain.head.profile"
        case .ledger: return "creditcard.fill"
        case .team: return "person.3.fill"
        case .calendar: return "calendar"
        case .archive: return "archivebox.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

#if os(macOS)
struct FloatingSidebar: View {
    @Binding var selectedRoute: SidebarRoute
    @State private var hoveredItem: SidebarRoute?
    
    var body: some View {
        GlassView {
            VStack(alignment: .leading, spacing: 25) {
                // Branding
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 20))
                    Text("ANAJ")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.top, 30)
                .padding(.horizontal, 25)
                
                // Navigation Items
                VStack(spacing: 8) {
                    ForEach(SidebarRoute.allCases, id: \.self) { route in
                        SidebarItem(
                            route: route,
                            isSelected: selectedRoute == route,
                            isHovered: hoveredItem == route
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedRoute = route
                            }
                        }
                        .onHover { hovering in
                            hoveredItem = hovering ? route : nil
                        }
                    }
                }
                .padding(.horizontal, 12)
                
                Spacer()
                
                // Bottom Profile Section
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 35, height: 35)
                        .overlay(
                            Text(String(userName.prefix(1)).uppercased())
                                .font(.system(size: 14, weight: .bold))
                        )
                        .overlay(Circle().stroke(.white.opacity(0.2)))
                    
                    VStack(alignment: .leading) {
                        Text(userName)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text(userRole)
                            .font(.system(size: 10))
                            .opacity(0.6)
                    }
                    .foregroundStyle(.white)
                }
                .padding(25)
            }
        }
    }
    
    @AppStorage("userName") private var userName = "Jesse"
    @AppStorage("userRole") private var userRole = "Creative Director"
}

// MARK: - Sidebar Item Component
private struct SidebarItem: View {
    let route: SidebarRoute
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: route.icon)
                    .font(.system(size: 16))
                    .frame(width: 20)
                
                Text(route.rawValue)
                    .font(.system(size: 15, weight: isSelected ? .bold : .medium, design: .rounded))
                
                Spacer()
                
                if isSelected {
                    Circle()
                        .fill(.white)
                        .frame(width: 4, height: 4)
                        .shadow(color: .white, radius: 4)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .foregroundStyle(isSelected ? .white : .white.opacity(isHovered ? 0.9 : 0.6))
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? .white.opacity(0.15) : (isHovered ? .white.opacity(0.05) : .clear))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Fixed Preview Section
#Preview {
    ZStack {
        // Mocking the Liquid Background
        LinearGradient(colors: [.blue, .purple, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        
        // Correctly using the Wrapper to avoid "too few type parameters"
        StatefulPreviewWrapper(SidebarRoute.dashboard) { $route in
            FloatingSidebar(selectedRoute: $route)
                .frame(width: 260)
                .padding(.vertical, 40)
                .padding(.leading, 20)
            
            Spacer()
        }
    }
}

// The generic wrapper with 2 type parameters as expected by the compiler
struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State var value: Value
    var content: (Binding<Value>) -> Content

    init(_ value: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self._value = State(initialValue: value)
        self.content = content
    }

    var body: some View {
        content($value)
    }
}
#endif