import AppKit
import Foundation

final class HeartChannel: NSObject, @unchecked Sendable {
    private let roomCode: String
    private let senderID: String
    private let baseURL: String
    private var sseSession: URLSession?
    private var sseTask: URLSessionDataTask?
    private var isConnected = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    private var recentMessageIDs: [String] = []
    private let maxRecentIDs = 20

    // SSE parsing state
    private var lineBuffer = ""
    private var currentEventType = ""
    private var currentEventData = ""

    var onHeartReceived: (() -> Void)?
    var onPartnerStatusReceived: ((Bool) -> Void)?
    var onPresenceReceived: (() -> Void)?
    var onLog: ((String) -> Void)?

    init(roomCode: String, senderID: String, databaseURL: String = "https://mwah-76199-default-rtdb.firebaseio.com") {
        self.roomCode = roomCode
        self.senderID = senderID
        self.baseURL = databaseURL
        super.init()
    }

    private var channelURL: String {
        "\(baseURL)/rooms/\(roomCode)/channel/\(senderID).json"
    }

    // MARK: - Send

    func sendHeart() {
        let body: [String: Any] = [
            "type": "heart",
            "id": UUID().uuidString,
            "ts": [".sv": "timestamp"]
        ]
        writeMessage(body) { [weak self] success in
            if success {
                self?.onLog?("Heart sent via network")
            }
        }
    }

    func sendStatus(dnd: Bool) {
        let body: [String: Any] = [
            "type": "status",
            "dnd": dnd,
            "ts": [".sv": "timestamp"]
        ]
        writeMessage(body)
    }

    func sendPresence() {
        let body: [String: Any] = [
            "type": "presence",
            "ts": [".sv": "timestamp"]
        ]
        writeMessage(body)
    }

    private func writeMessage(_ body: [String: Any], completion: (@Sendable (Bool) -> Void)? = nil) {
        guard let url = URL(string: channelURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = data

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            if let error = error {
                self?.onLog?("Send error: \(error.localizedDescription)")
                completion?(false)
                return
            }
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 200 {
                    completion?(true)
                } else {
                    self?.onLog?("Send failed: HTTP \(http.statusCode)")
                    completion?(false)
                }
            }
        }.resume()
    }

    // MARK: - Receive via SSE

    func connect() {
        let urlString = "\(baseURL)/rooms/\(roomCode)/channel.json"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 86400 // 24 hours

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 86400
        config.timeoutIntervalForResource = 86400

        sseSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        sseTask = sseSession?.dataTask(with: request)
        sseTask?.resume()

        isConnected = true
        reconnectAttempts = 0
        lineBuffer = ""
        currentEventType = ""
        currentEventData = ""
        onLog?("SSE connecting to channel/\(roomCode)")

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
        sseTask?.cancel()
        sseTask = nil
        sseSession?.invalidateAndCancel()
        sseSession = nil
        lineBuffer = ""
        DispatchQueue.main.async {
            NSWorkspace.shared.notificationCenter.removeObserver(self)
        }
        onLog?("SSE disconnected")
    }

    // MARK: - SSE Parsing

    private func processLineBuffer() {
        while let newlineRange = lineBuffer.range(of: "\n") {
            let line = String(lineBuffer[lineBuffer.startIndex..<newlineRange.lowerBound])
            lineBuffer = String(lineBuffer[newlineRange.upperBound...])
            processLine(line)
        }
    }

    private func processLine(_ line: String) {
        if line.isEmpty {
            // Blank line = dispatch accumulated event
            if !currentEventData.isEmpty {
                dispatchEvent(type: currentEventType, data: currentEventData)
            }
            currentEventType = ""
            currentEventData = ""
            return
        }

        if line.hasPrefix("event:") {
            currentEventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        } else if line.hasPrefix("data:") {
            let value = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if currentEventData.isEmpty {
                currentEventData = value
            } else {
                currentEventData += "\n" + value
            }
        }
        // Ignore comments (lines starting with :) and other fields
    }

    private func dispatchEvent(type: String, data: String) {
        guard type == "put" else { return }
        guard data != "null" else { return }

        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let path = json["path"] as? String else {
            return
        }

        // Skip initial snapshot (path == "/")
        if path == "/" {
            onLog?("SSE initial snapshot received")
            return
        }

        // path is "/{senderID}" — extract the sender
        let sender = path.hasPrefix("/") ? String(path.dropFirst()) : path

        // Self-filter: skip our own messages
        guard sender != senderID else {
            onLog?("Skipped own message")
            return
        }

        guard let body = json["data"] as? [String: Any] else { return }
        let msgType = body["type"] as? String ?? "heart"

        switch msgType {
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
            onLog?("Heart received from partner")
            onHeartReceived?()
        default:
            onLog?("Unknown message type: \(msgType)")
        }
    }

    // MARK: - Reconnection

    private func attemptReconnect() {
        guard isConnected, reconnectAttempts < maxReconnectAttempts else { return }

        reconnectAttempts += 1
        let delay = min(pow(2.0, Double(reconnectAttempts)), 60.0)
        onLog?("Reconnecting in \(Int(delay))s (attempt \(reconnectAttempts))")

        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.isConnected else { return }
            self.startSSEStream()
        }
    }

    private func startSSEStream() {
        sseTask?.cancel()
        sseTask = nil
        lineBuffer = ""
        currentEventType = ""
        currentEventData = ""

        let urlString = "\(baseURL)/rooms/\(roomCode)/channel.json"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 86400

        sseTask = sseSession?.dataTask(with: request)
        sseTask?.resume()
        onLog?("SSE reconnecting...")
    }

    @objc private func handleWake() {
        onLog?("System woke from sleep, reconnecting...")
        reconnectAttempts = 0
        startSSEStream()
    }
}

extension HeartChannel: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 200 {
                onLog?("SSE connected")
                reconnectAttempts = 0
            } else {
                onLog?("SSE connection failed: HTTP \(http.statusCode)")
            }
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        lineBuffer.append(chunk)
        processLineBuffer()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard isConnected else { return }

        // Don't reconnect on intentional cancellation (e.g. from handleWake or disconnect)
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return
        }

        if let error = error {
            onLog?("SSE stream ended: \(error.localizedDescription)")
        } else {
            onLog?("SSE stream ended unexpectedly")
        }
        attemptReconnect()
    }
}
