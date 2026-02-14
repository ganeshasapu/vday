import AppKit
import HotKey

@MainActor
class GlobalShortcut {
    private var sendHeartHotKey: HotKey?
    private var debugHotKey: HotKey?

    init(onSendHeart: @escaping () -> Void, onToggleDebug: @escaping () -> Void) {
        sendHeartHotKey = HotKey(key: .h, modifiers: [.command, .shift])
        sendHeartHotKey?.keyDownHandler = {
            onSendHeart()
        }

        debugHotKey = HotKey(key: .d, modifiers: [.command, .shift])
        debugHotKey?.keyDownHandler = {
            onToggleDebug()
        }
    }
}
