import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permissions
        requestNotificationPermissions()
        
        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Initialize services
        Task {
            await initializeServices()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up WebSocket connections
        WebSocketService.shared.disconnect()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running in menu bar even when window is closed
        return false
    }
    
    // MARK: - Private Methods
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permissions granted")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    private func initializeServices() async {
        // Connect to WebSocket for real-time updates
        WebSocketService.shared.connect()
        
        // Load initial data
        await AppState.shared.loadInitialData()
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo
        
        if let incidentId = userInfo["incidentId"] as? String {
            // Navigate to the incident
            Task { @MainActor in
                AppState.shared.selectedIncidentId = incidentId
                AppState.shared.selectedTab = .dashboard
            }
        }
        
        completionHandler()
    }
}

