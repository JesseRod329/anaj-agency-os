#if os(macOS)
import SwiftUI
import Combine

struct LiquidContainerView<Content: View>: View {
    // 1. Navigation State
    @AppStorage("isLiquidEnabled") private var isLiquidEnabled = true
    @State private var showingCommandMenu = false
    @ObservedObject private var commandCenter = AppCommandCenter.shared
    
    @ViewBuilder var content: Content
    
    var body: some View {
        ZStack {
            // Background Layer
            if isLiquidEnabled {
                LiquidBackground()
                    .ignoresSafeArea()
                    .transition(.opacity)
            } else {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            
            // Layout Layer
            HStack(spacing: 0) {
                
                // Sidebar - Passing the correct binding
                FloatingSidebar(
                    selectedRoute: Binding(
                        get: { commandCenter.route },
                        set: { commandCenter.setRoute($0) }
                    )
                )
                    .frame(width: 260)
                    .padding(.vertical, 20)
                    .padding(.leading, 20)
                
                // Dynamic Content Area
                VStack {
                    switch commandCenter.route {
                    case .dashboard:
                        DashboardView()
                    case .projects:
                        ProjectsView()
                    case .studio:
                        PromptStudioView()
                    case .insights:
                        InsightsView()
                    case .clients:
                        ClientsView()
                    case .knowledge:
                        NotesView()
                    case .memory:
                        DecisionLogView()
                    case .ledger:
                        AgencyLedgerView()
                    case .team:
                        TeamView()
                    case .calendar:
                        CalendarView()
                    case .archive:
                        ArchiveView()
                    case .settings:
                        SettingsView()
                    }
                }
                .padding(20)
            }
            .blur(radius: showingCommandMenu ? 5 : 0) // Reduced blur for performance
            .scaleEffect(showingCommandMenu ? 0.99 : 1.0)
            .opacity(showingCommandMenu ? 0.7 : 1.0)
            // Note: removed drawingGroup() as it breaks interactive controls
            
            // Global Search Overlay (Cmd+K)
            if showingCommandMenu {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) { showingCommandMenu = false }
                    }
                
                GlobalSearchView(isPresented: $showingCommandMenu)
                    .transition(.opacity)
            }
            
            // Window Shade (Blinds) Toggle
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            isLiquidEnabled.toggle()
                        }
                    }) {
                        Image(systemName: isLiquidEnabled ? "window.shade.open" : "window.shade.closed")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white.opacity(0.1), lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    }
                    .buttonStyle(.plain)
                    .padding(25)
                }
                Spacer()
            }
        }
        // Use SwiftUI keyboard shortcuts instead of NSEvent monitors
        .background(
            // Hidden buttons for keyboard shortcuts (doesn't trigger secure input)
            Group {
                Button("") {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showingCommandMenu.toggle()
                    }
                }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
                
                Button("") {
                    if showingCommandMenu {
                        withAnimation(.easeOut(duration: 0.15)) {
                            showingCommandMenu = false
                        }
                    }
                }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
            }
        )
        .onReceive(commandCenter.$refreshToken) { _ in
            NotificationCenter.default.post(name: .anajDataDidChange, object: nil)
        }
    }
}
#endif
