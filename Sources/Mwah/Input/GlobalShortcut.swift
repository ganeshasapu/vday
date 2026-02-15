import AppKit
import HotKey

@MainActor
class GlobalShortcut: ObservableObject {
    private var sendHeartHotKey: HotKey?
    private var debugHotKey: HotKey?

    private let onSendHeart: () -> Void
    private let onToggleDebug: () -> Void

    @Published var sendHeartCombo: KeyCombo
    @Published var debugCombo: KeyCombo

    private static let defaultSendHeartCombo = KeyCombo(key: .h, modifiers: [.command, .shift])
    private static let defaultDebugCombo = KeyCombo(key: .d, modifiers: [.command, .shift])

    init(onSendHeart: @escaping () -> Void, onToggleDebug: @escaping () -> Void) {
        self.onSendHeart = onSendHeart
        self.onToggleDebug = onToggleDebug

        self.sendHeartCombo = Self.loadCombo(prefix: "hotkey.sendHeart") ?? Self.defaultSendHeartCombo
        self.debugCombo = Self.loadCombo(prefix: "hotkey.debug") ?? Self.defaultDebugCombo

        registerSendHeart()
        registerDebug()
    }

    func updateSendHeartCombo(_ combo: KeyCombo) {
        sendHeartCombo = combo
        Self.saveCombo(combo, prefix: "hotkey.sendHeart")
        registerSendHeart()
    }

    func updateDebugCombo(_ combo: KeyCombo) {
        debugCombo = combo
        Self.saveCombo(combo, prefix: "hotkey.debug")
        registerDebug()
    }

    var sendHeartDisplayString: String {
        "\(sendHeartCombo.modifiers)\(sendHeartCombo.key?.description ?? "")"
    }

    var debugDisplayString: String {
        "\(debugCombo.modifiers)\(debugCombo.key?.description ?? "")"
    }

    // MARK: - Private

    private func registerSendHeart() {
        sendHeartHotKey = nil
        let hk = HotKey(keyCombo: sendHeartCombo)
        hk.keyDownHandler = { [weak self] in self?.onSendHeart() }
        sendHeartHotKey = hk
    }

    private func registerDebug() {
        debugHotKey = nil
        let hk = HotKey(keyCombo: debugCombo)
        hk.keyDownHandler = { [weak self] in self?.onToggleDebug() }
        debugHotKey = hk
    }

    private static func saveCombo(_ combo: KeyCombo, prefix: String) {
        UserDefaults.standard.set(combo.carbonKeyCode, forKey: "\(prefix).keyCode")
        UserDefaults.standard.set(combo.carbonModifiers, forKey: "\(prefix).modifiers")
    }

    private static func loadCombo(prefix: String) -> KeyCombo? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "\(prefix).keyCode") != nil else { return nil }
        let keyCode = UInt32(defaults.integer(forKey: "\(prefix).keyCode"))
        let modifiers = UInt32(defaults.integer(forKey: "\(prefix).modifiers"))
        return KeyCombo(carbonKeyCode: keyCode, carbonModifiers: modifiers)
    }
}
