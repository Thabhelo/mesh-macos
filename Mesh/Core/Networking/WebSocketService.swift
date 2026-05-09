import Foundation
import Combine

enum WebSocketMessage: Codable {
    case incidentUpdate(IncidentUpdate)
    case surgeAlert(SurgeAlert)
    case hazardUpdate(HazardScore)
    case connectionStatus(connected: Bool)
    
    enum CodingKeys: String, CodingKey {
        case type
        case payload
    }
    
    enum MessageType: String, Codable {
        case incidentUpdate = "incident_update"
        case surgeAlert = "surge_alert"
        case hazardUpdate = "hazard_update"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)
        
        switch type {
        case .incidentUpdate:
            let payload = try container.decode(IncidentUpdate.self, forKey: .payload)
            self = .incidentUpdate(payload)
        case .surgeAlert:
            let payload = try container.decode(SurgeAlert.self, forKey: .payload)
            self = .surgeAlert(payload)
        case .hazardUpdate:
            let payload = try container.decode(HazardScore.self, forKey: .payload)
            self = .hazardUpdate(payload)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .incidentUpdate(let update):
            try container.encode(MessageType.incidentUpdate, forKey: .type)
            try container.encode(update, forKey: .payload)
        case .surgeAlert(let alert):
            try container.encode(MessageType.surgeAlert, forKey: .type)
            try container.encode(alert, forKey: .payload)
        case .hazardUpdate(let score):
            try container.encode(MessageType.hazardUpdate, forKey: .type)
            try container.encode(score, forKey: .payload)
        case .connectionStatus:
            break // Not encoded
        }
    }
}

class WebSocketService: NSObject {
    static let shared = WebSocketService()
    
    // Publishers
    let incidentUpdates = PassthroughSubject<IncidentUpdate, Never>()
    let surgeUpdates = PassthroughSubject<SurgeAlert, Never>()
    let hazardUpdates = PassthroughSubject<HazardScore, Never>()
    let connectionStatus = CurrentValueSubject<Bool, Never>(false)
    
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var isConnected = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private let reconnectDelay: TimeInterval = 5.0
    
    private let baseURL = URL(string: "wss://api.meshofdata.org/ws")!
    private let decoder = JSONDecoder()
    
    private override init() {
        super.init()
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Public Methods
    
    func connect() {
        guard !isConnected else { return }

        /*
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        
        webSocket = session?.webSocketTask(with: baseURL)
        webSocket?.resume()
        
        receiveMessage()
        */
    }
    
    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        isConnected = false
        connectionStatus.send(false)
    }
    
    // MARK: - Real WebSocket Methods
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessage() // Continue listening
                
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self?.handleDisconnection()
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8) else { return }
            parseMessage(data)
            
        case .data(let data):
            parseMessage(data)
            
        @unknown default:
            break
        }
    }
    
    private func parseMessage(_ data: Data) {
        do {
            let message = try decoder.decode(WebSocketMessage.self, from: data)
            
            switch message {
            case .incidentUpdate(let update):
                incidentUpdates.send(update)
                
            case .surgeAlert(let alert):
                surgeUpdates.send(alert)
                
            case .hazardUpdate(let score):
                hazardUpdates.send(score)
                
            case .connectionStatus:
                break
            }
        } catch {
            print("Failed to parse WebSocket message: \(error)")
        }
    }
    
    private func handleDisconnection() {
        isConnected = false
        connectionStatus.send(false)
        
        // Attempt reconnection
        guard reconnectAttempts < maxReconnectAttempts else {
            print("Max reconnection attempts reached")
            return
        }
        
        reconnectAttempts += 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
            self?.connect()
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        isConnected = true
        reconnectAttempts = 0
        connectionStatus.send(true)
        print("WebSocket connected")
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        handleDisconnection()
        print("WebSocket disconnected: \(closeCode)")
    }
}

