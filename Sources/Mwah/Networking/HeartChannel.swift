import AppKit
import Foundation

final class HeartChannel: NSObject, @unchecked Sendable {
    private let roomCode: String
    private let senderID: String
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var isConnected = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    private var recentMessageIDs: [String] = []
    private let maxRecentIDs = 20

    var onHeartReceived: (() -> Void)?
    var onPartnerStatusReceived: ((Bool) -> Void)?
    var onPresenceReceived: (() -> Void)?
    var onLog: ((String) -> Void)?

    init(roomCode: String, senderID: String) {
        self.roomCode = roomCode
        self.senderID = senderID
        super.init()
    }

    private var topicName: String {
        "mwah-\(roomCode)"
    }

    // MARK: - Send

    func sendHeart() {
        let urlString = "https://ntfy.sh/\(topicName)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "sender": senderID,
            "type": "heart",
            "id": UUID().uuidString
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = data

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            if let error = error {
                self?.onLog?("Send error: \(error.localizedDescription)")
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                self?.onLog?("Heart sent via network")
            }
        }.resume()
    }

    func sendStatus(dnd: Bool) {
        let urlString = "https://ntfy.sh/\(topicName)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "sender": senderID,
            "type": "status",
            "dnd": dnd
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = data

        URLSession.shared.dataTask(with: request) { [weak self] _, _, error in
            if let error = error {
                self?.onLog?("Status send error: \(error.localizedDescription)")
            }
        }.resume()
    }

    func sendPresence() {
        let urlString = "https://ntfy.sh/\(topicName)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "sender": senderID,
            "type": "presence"
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = data

        URLSession.shared.dataTask(with: request) { [weak self] _, _, error in
            if let error = error {
                self?.onLog?("Presence send error: \(error.localizedDescription)")
            }
        }.resume()
    }

    // MARK: - Receive via WebSocket

    func connect() {
        let urlString = "wss://ntfy.sh/\(topicName)/ws"
        guard let url = URL(string: urlString) else { return }

        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        reconnectAttempts = 0
        onLog?("WebSocket connecting to \(topicName)")
        receiveMessage()

        DispatchQueue.main.async {
            let center = NSWorkspace.shared.notificationCenter
            center.addObserver(
                self,
                selector: #selector(self.handleWake),
                name: NSWorkspace.didWakeNotification,
                object: nil
            )
        }
    }

    func disconnect() {
        isConnected = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        DispatchQueue.main.async {
            NSWorkspace.shared.notificationCenter.removeObserver(self)
        }
        onLog?("WebSocket disconnected")
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self, self.isConnected else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessage()
            case .failure(let error):
                self.onLog?("WebSocket error: \(error.localizedDescription)")
                self.attemptReconnect()
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        var data: Data?
        switch message {
        case .string(let text):
            data = text.data(using: .utf8)
        case .data(let d):
            data = d
        @unknown default:
            return
        }

        guard let data = data else { return }

        // ntfy.sh sends JSON messages with an "event" field
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        // Only process "message" events (skip keepalive, open, etc.)
        guard let event = json["event"] as? String, event == "message" else { return }

        // The actual message body is in the "message" field
        guard let messageBody = json["message"] as? String,
              let bodyData = messageBody.data(using: .utf8),
              let body = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return
        }

        // Self-filter: skip our own messages
        guard let sender = body["sender"] as? String, sender != senderID else {
            onLog?("Skipped own message")
            return
        }

        let type = body["type"] as? String ?? "heart"

        switch type {
        case "status":
            if let dnd = body["dnd"] as? Bool {
                onLog?("Partner DND: \(dnd ? "on" : "off")")
                onPartnerStatusReceived?(dnd)
            }
        case "presence":
            onLog?("Partner presence ping received")
            onPresenceReceived?()
        case "heart":
            if let id = body["id"] as? String {
                if recentMessageIDs.contains(id) {
                    onLog?("Skipped duplicate heart \(id.prefix(8))...")
                    return
                }
                recentMessageIDs.append(id)
                if recentMessageIDs.count > maxRecentIDs {
                    recentMessageIDs.removeFirst()
                }
            }
            onLog?("Heart received from \(sender.prefix(8))...")
            onHeartReceived?()
        default:
            onLog?("Unknown message type: \(type)")
        }
    }

    private func attemptReconnect() {
        guard isConnected, reconnectAttempts < maxReconnectAttempts else { return }

        reconnectAttempts += 1
        let delay = min(pow(2.0, Double(reconnectAttempts)), 60.0)
        onLog?("Reconnecting in \(Int(delay))s (attempt \(reconnectAttempts))")

        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.isConnected else { return }
            self.webSocketTask?.cancel(with: .goingAway, reason: nil)
            self.webSocketTask = nil

            let urlString = "wss://ntfy.sh/\(self.topicName)/ws"
            guard let url = URL(string: urlString) else { return }
            self.webSocketTask = self.urlSession?.webSocketTask(with: url)
            self.webSocketTask?.resume()
            self.receiveMessage()
            self.onLog?("WebSocket reconnected")
        }
    }

    @objc private func handleWake() {
        onLog?("System woke from sleep, reconnecting...")
        attemptReconnect()
    }
}

extension HeartChannel: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        onLog?("WebSocket connected")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        onLog?("WebSocket closed: \(closeCode.rawValue)")
        if isConnected {
            attemptReconnect()
        }
    }
}
