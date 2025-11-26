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
                .onAppear {
                    // Configure window appearance
                    configureWindow()
                }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1400, height: 900)
        .commands {
            // Remove default new window command
            CommandGroup(replacing: .newItem) { }
            
            // Navigation commands
            CommandMenu("Navigate") {
                Button("Home") {
                    Task { @MainActor in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            appState.showWelcome = true
                        }
                    }
                }
                .keyboardShortcut("0", modifiers: .command)
                
                Divider()
                
                Button("Dashboard") {
                    navigateTo(.dashboard)
                }
                .keyboardShortcut("1", modifiers: .command)
                
                Button("Map") {
                    navigateTo(.map)
                }
                .keyboardShortcut("2", modifiers: .command)
                
                Button("Surge Prediction") {
                    navigateTo(.surge)
                }
                .keyboardShortcut("3", modifiers: .command)
                
                Button("Hazard Analysis") {
                    navigateTo(.hazard)
                }
                .keyboardShortcut("4", modifiers: .command)
            }
            
            // Data commands
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
    
    // MARK: - Helper Methods
    
    private func navigateTo(_ tab: AppTab) {
        Task { @MainActor in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appState.showWelcome = false
                appState.selectedTab = tab
            }
        }
    }
    
    private func configureWindow() {
        // Ensure light appearance
        NSApp.appearance = NSAppearance(named: .aqua)
    }
}
