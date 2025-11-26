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
                .frame(minWidth: 1100, minHeight: 750)
                .preferredColorScheme(.light)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1400, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) { }
            
            CommandMenu("View") {
                Button("Dashboard") {
                    appState.showWelcome = false
                    appState.selectedTab = .dashboard
                }
                .keyboardShortcut("1", modifiers: .command)
                
                Button("Map") {
                    appState.showWelcome = false
                    appState.selectedTab = .map
                }
                .keyboardShortcut("2", modifiers: .command)
                
                Button("Surge Prediction") {
                    appState.showWelcome = false
                    appState.selectedTab = .surge
                }
                .keyboardShortcut("3", modifiers: .command)
                
                Button("Hazard Analysis") {
                    appState.showWelcome = false
                    appState.selectedTab = .hazard
                }
                .keyboardShortcut("4", modifiers: .command)
                
                Divider()
                
                Button("Welcome Screen") {
                    appState.showWelcome = true
                }
                .keyboardShortcut("0", modifiers: .command)
            }
            
            CommandMenu("Data") {
                Button("Refresh") {
                    Task {
                        await appState.refreshData()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        
        // Settings Window
        Settings {
            SettingsView()
                .environmentObject(appState)
                .preferredColorScheme(.light)
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
