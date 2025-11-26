import Foundation
import UserNotifications
import AppKit

class NotificationService {
    static let shared = NotificationService()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private init() {}
    
    // MARK: - Incident Notifications
    
    func sendIncidentNotification(_ incident: Incident) {
        let content = UNMutableNotificationContent()
        content.title = "\(incident.severity.label) Incident"
        content.subtitle = incident.type
        content.body = "\(incident.address)\n\(incident.description)"
        content.sound = incident.severity == .critical ? .defaultCritical : .default
        content.categoryIdentifier = "INCIDENT"
        content.userInfo = ["incidentId": incident.id]
        
        // Set thread identifier for grouping
        content.threadIdentifier = "incidents"
        
        // Add incident details as custom data
        if incident.severity == .critical {
            content.interruptionLevel = .critical
        } else {
            content.interruptionLevel = .timeSensitive
        }
        
        let request = UNNotificationRequest(
            identifier: "incident-\(incident.id)",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to send incident notification: \(error)")
            }
        }
    }
    
    // MARK: - Surge Notifications
    
    func sendSurgeNotification(_ alert: SurgeAlert) {
        let content = UNMutableNotificationContent()
        content.title = "Surge Alert: \(alert.severity.label)"
        content.subtitle = alert.districtName
        content.body = "Call volume up \(Int(alert.percentageIncrease))% from expected. \(alert.contributingFactors.joined(separator: ", "))"
        content.sound = alert.severity == .critical ? .defaultCritical : .default
        content.categoryIdentifier = "SURGE_ALERT"
        content.userInfo = ["districtId": alert.districtId]
        
        content.threadIdentifier = "surge-alerts"
        
        if alert.severity == .critical {
            content.interruptionLevel = .critical
        } else if alert.severity == .high {
            content.interruptionLevel = .timeSensitive
        }
        
        let request = UNNotificationRequest(
            identifier: "surge-\(alert.id)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to send surge notification: \(error)")
            }
        }
    }
    
    // MARK: - System Status Notifications
    
    func sendSystemStatusNotification(newStatus: SystemStatus, previousStatus: SystemStatus) {
        guard newStatus != previousStatus else { return }
        
        let content = UNMutableNotificationContent()
        
        switch newStatus {
        case .critical:
            content.title = "⚠️ System Status: Critical"
            content.body = "Multiple critical incidents or surges detected. Immediate attention required."
            content.sound = .defaultCritical
            content.interruptionLevel = .critical
            
        case .elevated:
            content.title = "System Status: Elevated"
            content.body = "Increased activity detected across the region."
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            
        case .normal:
            if previousStatus != .normal {
                content.title = "System Status: Normal"
                content.body = "Activity levels have returned to normal."
                content.sound = .default
                content.interruptionLevel = .passive
            } else {
                return // Don't notify if already normal
            }
        }
        
        content.categoryIdentifier = "SYSTEM_STATUS"
        content.threadIdentifier = "system"
        
        let request = UNNotificationRequest(
            identifier: "status-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to send status notification: \(error)")
            }
        }
    }
    
    // MARK: - Hazard Notifications
    
    func sendHazardNotification(_ hazardScore: HazardScore, threshold: Int = 75) {
        guard hazardScore.overallScore >= threshold else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "High Hazard Score: \(hazardScore.overallScore)"
        content.subtitle = hazardScore.statusLabel
        
        // Find the highest contributing factor
        if let highestComponent = hazardScore.components.allComponents.max(by: { $0.score.score < $1.score.score }) {
            content.body = "Primary concern: \(highestComponent.name) (\(highestComponent.score.details))"
        }
        
        content.sound = .defaultCritical
        content.categoryIdentifier = "HAZARD"
        content.interruptionLevel = .timeSensitive
        content.threadIdentifier = "hazard"
        
        let request = UNNotificationRequest(
            identifier: "hazard-\(hazardScore.id)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to send hazard notification: \(error)")
            }
        }
    }
    
    // MARK: - Notification Categories
    
    func registerNotificationCategories() {
        // Incident category with actions
        let viewIncidentAction = UNNotificationAction(
            identifier: "VIEW_INCIDENT",
            title: "View Details",
            options: [.foreground]
        )
        
        let acknowledgeAction = UNNotificationAction(
            identifier: "ACKNOWLEDGE",
            title: "Acknowledge",
            options: []
        )
        
        let incidentCategory = UNNotificationCategory(
            identifier: "INCIDENT",
            actions: [viewIncidentAction, acknowledgeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Surge alert category
        let viewSurgeAction = UNNotificationAction(
            identifier: "VIEW_SURGE",
            title: "View District",
            options: [.foreground]
        )
        
        let surgeCategory = UNNotificationCategory(
            identifier: "SURGE_ALERT",
            actions: [viewSurgeAction, acknowledgeAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Hazard category
        let viewHazardAction = UNNotificationAction(
            identifier: "VIEW_HAZARD",
            title: "View Analysis",
            options: [.foreground]
        )
        
        let hazardCategory = UNNotificationCategory(
            identifier: "HAZARD",
            actions: [viewHazardAction],
            intentIdentifiers: [],
            options: []
        )
        
        // System status category
        let systemCategory = UNNotificationCategory(
            identifier: "SYSTEM_STATUS",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([
            incidentCategory,
            surgeCategory,
            hazardCategory,
            systemCategory
        ])
    }
    
    // MARK: - Badge Management
    
    func updateBadge(count: Int) {
        Task { @MainActor in
            NSApplication.shared.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
        }
    }
    
    func clearBadge() {
        updateBadge(count: 0)
    }
    
    // MARK: - Clear Notifications
    
    func clearAllNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
        notificationCenter.removeAllPendingNotificationRequests()
        clearBadge()
    }
    
    func clearNotifications(for threadIdentifier: String) {
        notificationCenter.getDeliveredNotifications { notifications in
            let identifiersToRemove = notifications
                .filter { $0.request.content.threadIdentifier == threadIdentifier }
                .map { $0.request.identifier }
            
            self.notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
        }
    }
}

