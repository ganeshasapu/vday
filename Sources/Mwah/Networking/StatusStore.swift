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
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["dnd": dnd]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = data

        URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
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
