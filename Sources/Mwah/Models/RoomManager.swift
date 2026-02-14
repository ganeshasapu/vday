import Foundation

enum RoomState: Equatable {
    case disconnected
    case creating
    case joining
    case connected
}

@MainActor
class RoomManager: ObservableObject {
    @Published var state: RoomState = .disconnected
    @Published var roomCode: String?
    @Published var errorMessage: String?
    @Published var eventLog: [String] = []
    @Published var doNotDisturb: Bool {
        didSet { UserDefaults.standard.set(doNotDisturb, forKey: "doNotDisturb") }
    }

    let senderID: String
    var onStateChange: (() -> Void)?

    private static let allowedChars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    init() {
        if let saved = UserDefaults.standard.string(forKey: "senderID") {
            senderID = saved
        } else {
            let id = UUID().uuidString
            UserDefaults.standard.set(id, forKey: "senderID")
            senderID = id
        }
        doNotDisturb = UserDefaults.standard.bool(forKey: "doNotDisturb")
    }

    func createRoom() {
        state = .creating
        let code = generateRoomCode()
        roomCode = code
        state = .connected
        log("Created room: \(code)")
        onStateChange?()
    }

    func joinRoom(code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.count == 8 else {
            errorMessage = "Room code must be 8 characters"
            return
        }
        state = .joining
        roomCode = trimmed
        state = .connected
        log("Joined room: \(trimmed)")
        onStateChange?()
    }

    func disconnect() {
        let code = roomCode ?? "unknown"
        roomCode = nil
        state = .disconnected
        log("Disconnected from room: \(code)")
        onStateChange?()
    }

    func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let entry = "[\(timestamp)] \(message)"
        eventLog.append(entry)
        if eventLog.count > 100 {
            eventLog.removeFirst()
        }
    }

    private func generateRoomCode() -> String {
        let chars = RoomManager.allowedChars
        return String((0..<8).map { _ in chars.randomElement()! })
    }
}
