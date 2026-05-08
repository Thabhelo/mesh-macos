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
        // Clean up polling and any legacy WebSocket connections
        stopIncidentPollingSynchronously()
        WebSocketService.shared.disconnect()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running in menu bar even when window is closed
        return false
    }
    
    // MARK: - Private Methods
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                AppState.shared.notificationsEnabled = granted
                if !granted, let error, error.localizedDescription != "Notifications are not allowed for this application" {
                    #if DEBUG
                    print("Notifications disabled: \(error.localizedDescription)")
                    #endif
                }
            }
        }
    }
    
    private func initializeServices() async {
        // Load initial data
        await AppState.shared.loadInitialData()
        await AppState.shared.startIncidentPolling()
    }

    private func stopIncidentPollingSynchronously() {
        let stopPolling = {
            MainActor.assumeIsolated {
                AppState.shared.stopIncidentPolling()
            }
        }

        if Thread.isMainThread {
            stopPolling()
        } else {
            DispatchQueue.main.sync(execute: stopPolling)
        }
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
            // Schedule UI navigation, then finish the notification delegate callback synchronously.
            Task { @MainActor in
                AppState.shared.selectedIncidentId = incidentId
                AppState.shared.selectedTab = .dashboard
            }
        }

        completionHandler()
    }
}
