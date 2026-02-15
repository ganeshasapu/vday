import Foundation

@MainActor
final class HeartQueue {
    private var pending = 0
    private var drainTimer: DispatchSourceTimer?
    private let drainInterval: TimeInterval
    private let maxQueueSize: Int
    private let onDrain: () -> Void

    init(drainInterval: TimeInterval = 0.25, maxQueueSize: Int = 50, onDrain: @escaping () -> Void) {
        self.drainInterval = drainInterval
        self.maxQueueSize = maxQueueSize
        self.onDrain = onDrain
    }

    func enqueue() {
        guard pending < maxQueueSize else { return }
        pending += 1

        if drainTimer == nil {
            // First heart: process immediately, then start periodic drain
            drainOne()
            startDrainTimer()
        }
    }

    func cancelAll() {
        pending = 0
        stopDrainTimer()
    }

    private func drainOne() {
        guard pending > 0 else {
            stopDrainTimer()
            return
        }
        pending -= 1
        onDrain()
    }

    private func startDrainTimer() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + drainInterval, repeating: drainInterval)
        timer.setEventHandler { [weak self] in
            self?.drainOne()
        }
        timer.resume()
        drainTimer = timer
    }

    private func stopDrainTimer() {
        drainTimer?.cancel()
        drainTimer = nil
    }
}
