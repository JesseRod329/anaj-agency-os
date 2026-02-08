//
//  anajApp.swift
//  anaj
//
//  Created by Jesse Rodriguez on 12/21/25.
//

import SwiftUI
import SwiftData

@main
struct anajApp: App {
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .background(.clear)
                .onAppear {
                    makeWindowTransparent()
                    setDockIcon()
                    ANAJAPIServer.shared.start(modelContainer: sharedModelContainer)
                    Task {
                        await TaskNotificationManager.shared.requestAuthorizationIfNeeded()
                    }
                }
            #elseif os(iOS)
            iOSRootView()
                .onAppear {
                    Task {
                        await TaskNotificationManager.shared.requestAuthorizationIfNeeded()
                    }
                }
            #endif
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // File menu shortcuts
            CommandGroup(replacing: .newItem) {
                Button("New Project") {
                    NotificationCenter.default.post(name: .createNewProject, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                
                Button("New Note") {
                    NotificationCenter.default.post(name: .createNewNote, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
                
                Button("New Task") {
                    NotificationCenter.default.post(name: .createNewTask, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command])
                
                Divider()
                
                Button("Export Backup...") {
                    NotificationCenter.default.post(name: .exportBackup, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
            
            // View menu shortcuts
            CommandGroup(after: .toolbar) {
                Button("Toggle Sidebar") {
                    NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }
        }
        #endif
        .modelContainer(sharedModelContainer)
        
        #if os(macOS)
        // Menu Bar Widget
        MenuBarExtra("ANAJ", systemImage: "drop.fill") {
            QuickAddMenuBar()
                .modelContainer(sharedModelContainer)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Client.self,
            Project.self,
            AgencyTask.self,
            Member.self,
            Note.self,
            Activity.self,
            Decision.self,
            Prompt.self,
            ChatMessage.self,
            ChatInsight.self,
            Invoice.self,
            InvoiceItem.self,
            Tag.self,
            IntegrationEvent.self,
            CommandExecution.self,
            AgentRun.self,
            MemorySyncCursor.self
        ])
        
        // Use lightweight migration to PRESERVE DATA on schema changes
        let modelConfiguration = ModelConfiguration(
            "anaj_v2", 
            schema: schema, 
            isStoredInMemoryOnly: false
        )
        
        do {
            // Try to create with automatic lightweight migration
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Log the error but DO NOT DELETE THE DATABASE
            print("⚠️ ModelContainer creation failed: \(error)")
            print("⚠️ Database may need manual migration. NOT deleting data.")
            
            // Try one more time - SwiftData often self-corrects on second attempt
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                // As absolute last resort, create in-memory only to prevent crash
                // But warn user that data is not being saved
                print("❌ CRITICAL: Using in-memory database. Data will NOT persist!")
                let memoryConfig = ModelConfiguration(
                    "anaj_temp",
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                do {
                    return try ModelContainer(for: schema, configurations: [memoryConfig])
                } catch {
                    fatalError("Could not create any ModelContainer: \(error)")
                }
            }
        }
    }()
}

// Helper to set custom dock icon from SVG
private func setDockIcon() {
    #if os(macOS)
    // Try to load from the bundle resources
    if let image = NSImage(named: "AppIcon.svg") {
        NSApplication.shared.applicationIconImage = image
        return
    }
    
    // Fallback: Try looking for the file directly in Resources
    if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "svg"),
       let image = NSImage(contentsOf: url) {
        NSApplication.shared.applicationIconImage = image
    }
    #endif
}

private func makeWindowTransparent() {
    #if os(macOS)
    DispatchQueue.main.async {
        if let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? NSApplication.shared.windows.first {
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
        }
    }
    #endif
}

// MARK: - Keyboard Shortcut Notifications

extension Notification.Name {
    static let createNewProject = Notification.Name("createNewProject")
    static let createNewNote = Notification.Name("createNewNote")
    static let createNewTask = Notification.Name("createNewTask")
    static let exportBackup = Notification.Name("exportBackup")
    static let toggleSidebar = Notification.Name("toggleSidebar")
    static let openGlobalSearch = Notification.Name("openGlobalSearch")
    static let anajDataDidChange = Notification.Name("anajDataDidChange")
}
