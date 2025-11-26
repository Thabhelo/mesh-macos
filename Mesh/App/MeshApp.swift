import SwiftUI

@main
struct MeshApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    
    var body: some Scene {
        // Main Window
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1400, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("View") {
                Button("Dashboard") {
                    appState.selectedTab = .dashboard
                }
                .keyboardShortcut("1", modifiers: .command)
                
                Button("Map") {
                    appState.selectedTab = .map
                }
                .keyboardShortcut("2", modifiers: .command)
                
                Button("Surge Prediction") {
                    appState.selectedTab = .surge
                }
                .keyboardShortcut("3", modifiers: .command)
                
                Button("Hazard Analysis") {
                    appState.selectedTab = .hazard
                }
                .keyboardShortcut("4", modifiers: .command)
            }
        }
        
        // Settings Window
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
        
        // Menu Bar Extra
        MenuBarExtra {
            MenuBarPopoverView()
                .environmentObject(appState)
        } label: {
            MenuBarIconView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
}

