import Foundation

final class StatusStore: @unchecked Sendable {
    private let baseURL: String

    init(databaseURL: String = "https://mwah-76199-default-rtdb.firebaseio.com") {
        self.baseURL = databaseURL
    }

    func saveDND(dnd: Bool, roomCode: String, senderID: String) {
        let urlString = "\(baseURL)/rooms/\(roomCode)/status/\(senderID).json"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["dnd": dnd]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = data

        URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
    }

    func savePresence(roomCode: String, senderID: String) {
        let urlString = "\(baseURL)/rooms/\(roomCode)/status/\(senderID).json"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{\"lastSeen\":{\".sv\":\"timestamp\"}}".data(using: .utf8)

        URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
    }

    func fetchPartnerPresence(roomCode: String, senderID: String, completion: @Sendable @escaping (Bool) -> Void) {
        let urlString = "\(baseURL)/rooms/\(roomCode)/status.json"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
                completion(false)
                return
            }

            for (id, status) in json where id != senderID {
                if let lastSeen = status["lastSeen"] as? Double {
                    let elapsed = Date().timeIntervalSince1970 * 1000 - lastSeen
                    completion(elapsed < 90_000)
                    return
                }
            }
            completion(false)
        }.resume()
    }

    func fetchPartnerDND(roomCode: String, senderID: String, completion: @Sendable @escaping (Bool) -> Void) {
        let urlString = "\(baseURL)/rooms/\(roomCode)/status.json"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
                return
            }

            for (id, status) in json where id != senderID {
                if let dnd = status["dnd"] as? Bool {
                    completion(dnd)
                    return
                }
            }
        }.resume()
    }
}
