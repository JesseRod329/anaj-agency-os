#if os(macOS)
import SwiftUI
import Combine

struct LiquidContainerView<Content: View>: View {
    // 1. Navigation State
    @State private var selectedRoute: SidebarRoute = .dashboard
    @AppStorage("isLiquidEnabled") private var isLiquidEnabled = true
    @State private var showingCommandMenu = false
    @StateObject private var commandCenter = AppCommandCenter.shared
    @State private var didInitialRouteSync = false
    
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
                FloatingSidebar(selectedRoute: $selectedRoute)
                    .frame(width: 260)
                    .padding(.vertical, 20)
                    .padding(.leading, 20)
                
                // Dynamic Content Area
                VStack {
                    switch selectedRoute {
                    case .dashboard:
                        DashboardView()
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                    case .projects:
                        ProjectsView()
                            .transition(.opacity)
                    case .studio:
                        PromptStudioView()
                            .transition(.opacity)
                    case .insights:
                        InsightsView()
                            .transition(.opacity)
                    case .clients:
                        ClientsView()
                            .transition(.opacity)
                    case .knowledge:
                        NotesView()
                            .transition(.opacity)
                    case .memory:
                        DecisionLogView()
                            .transition(.opacity)
                    case .ledger:
                        AgencyLedgerView()
                            .transition(.opacity)
                    case .team:
                        TeamView()
                            .transition(.opacity)
                    case .calendar:
                        CalendarView()
                            .transition(.opacity)
                    case .archive:
                        ArchiveView()
                            .transition(.opacity)
                    case .settings:
                        SettingsView()
                            .transition(.opacity)
                    }
                }
                .padding(20)
                .animation(.easeInOut(duration: 0.2), value: selectedRoute) // Faster, simpler animation
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
        .onAppear {
            guard !didInitialRouteSync else { return }
            selectedRoute = commandCenter.route
            didInitialRouteSync = true
        }
        .onReceive(commandCenter.$route.removeDuplicates()) { route in
            if route != selectedRoute {
                selectedRoute = route
            }
        }
        .onReceive(commandCenter.$refreshToken) { _ in
            NotificationCenter.default.post(name: .anajDataDidChange, object: nil)
        }
        .onChange(of: selectedRoute) {
            if commandCenter.route != selectedRoute {
                commandCenter.setRoute(selectedRoute)
            }
        }
    }
}
#endif
