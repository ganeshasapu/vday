import AppKit
import SwiftUI

struct HeartBurst {
    let token: UInt64
    let count: Int
}

@MainActor
final class HeartAnimationModel: ObservableObject {
    private static let defaultBurstCount = 150
    private static let maxBurstCount = 10_000
    private static let intensityWindow: TimeInterval = 3.0
    private static let maxBurstsForFullGlow: Double = 5.0
    private static let decayTickInterval: TimeInterval = 0.1
    private static let decayRate: Double = 0.3

    @Published private(set) var burst = HeartBurst(token: 0, count: 0)
    @Published private(set) var glowIntensity: Double = 0
    private let configuredBurstCount: Int
    private var recentBurstTimestamps: [CFTimeInterval] = []
    private var decayTimer: DispatchSourceTimer?

    init() {
        configuredBurstCount = Self.readBurstCountFromEnvironment()
    }

    func addBurst(count: Int? = nil) {
        let requested = count ?? configuredBurstCount
        let clampedCount = min(max(requested, 1), Self.maxBurstCount)
        burst = HeartBurst(token: burst.token &+ 1, count: clampedCount)

        recentBurstTimestamps.append(CACurrentMediaTime())
        recalculateIntensity()
        ensureDecayTimerRunning()
    }

    private func recalculateIntensity() {
        let cutoff = CACurrentMediaTime() - Self.intensityWindow
        recentBurstTimestamps.removeAll { $0 < cutoff }
        let target = min(Double(recentBurstTimestamps.count) / Self.maxBurstsForFullGlow, 1.0)
        setGlowIntensity(max(glowIntensity, target))
    }

    private func ensureDecayTimerRunning() {
        guard decayTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + Self.decayTickInterval, repeating: Self.decayTickInterval)
        timer.setEventHandler { [weak self] in self?.decayTick() }
        timer.resume()
        decayTimer = timer
    }

    private func decayTick() {
        let cutoff = CACurrentMediaTime() - Self.intensityWindow
        recentBurstTimestamps.removeAll { $0 < cutoff }
        let burstTarget = min(Double(recentBurstTimestamps.count) / Self.maxBurstsForFullGlow, 1.0)
        let decayed = glowIntensity - Self.decayRate * Self.decayTickInterval
        setGlowIntensity(max(burstTarget, decayed))

        if glowIntensity <= 0 && recentBurstTimestamps.isEmpty {
            decayTimer?.cancel()
            decayTimer = nil
        }
    }

    private func setGlowIntensity(_ value: Double) {
        let clamped = min(max(value, 0), 1)
        guard abs(clamped - glowIntensity) > 0.005 || (clamped == 0 && glowIntensity != 0) else { return }
        glowIntensity = clamped
    }

    private static func readBurstCountFromEnvironment() -> Int {
        guard
            let rawValue = ProcessInfo.processInfo.environment["MWAH_HEART_BURST_COUNT"],
            let parsed = Int(rawValue)
        else {
            return defaultBurstCount
        }
        return min(max(parsed, 1), maxBurstCount)
    }
}

struct HeartAnimationView: NSViewRepresentable {
    @ObservedObject var model: HeartAnimationModel

    func makeNSView(context: Context) -> HeartEmitterView {
        HeartEmitterView()
    }

    func updateNSView(_ nsView: HeartEmitterView, context: Context) {
        nsView.emitBurst(token: model.burst.token, count: model.burst.count)
        nsView.updateGlow(intensity: model.glowIntensity)
    }
}

@MainActor
final class HeartEmitterView: NSView {
    private static let slotCount = 5
    private static let burstDuration: TimeInterval = 3.0
    private static let prewarmTime: TimeInterval = 4.0
    private static let spawnOffset: CGFloat = 20
    private static let maxBirthRate: Float = 80_000

    private final class EmitterSlot {
        let layer: CAEmitterLayer
        var stopWorkItem: DispatchWorkItem?
        var isEmitting = false

        init(layer: CAEmitterLayer) {
            self.layer = layer
        }
    }

    private var slots: [EmitterSlot] = []
    private var activeSlotIndex = 0
    private var latestToken: UInt64 = 0
    private var glowLayer: CAGradientLayer?
    private var currentGlowOpacity: Float = 0

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.clear.cgColor
        setupGlowLayer()
        setupSlots()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glowLayer?.frame = bounds
        for slot in slots {
            slot.layer.frame = bounds
            slot.layer.emitterSize = CGSize(width: bounds.width, height: 2)
            slot.layer.emitterPosition = CGPoint(x: bounds.midX, y: bounds.maxY * 2 + Self.spawnOffset)
        }
        CATransaction.commit()
    }

    func emitBurst(token: UInt64, count: Int) {
        guard token != latestToken else { return }
        latestToken = token

        guard count > 0 else { return }

        var slot = slots[activeSlotIndex]

        if !slot.isEmitting {
            // Advance to the next slot so we get a fresh timeline without disrupting old particles
            activeSlotIndex = (activeSlotIndex + 1) % Self.slotCount
            slot = slots[activeSlotIndex]

            // Prewarm the new slot so hearts appear immediately
            let totalEmissionTime = Self.prewarmTime + Self.burstDuration
            let emissionRate = min(Float(count) / Float(totalEmissionTime), Self.maxBirthRate)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            slot.layer.beginTime = CACurrentMediaTime() - Self.prewarmTime
            slot.layer.setValue(emissionRate, forKeyPath: "emitterCells.heart.birthRate")
            CATransaction.commit()
            slot.isEmitting = true
        }
        // If already emitting on the active slot, just extend the stop timer

        slot.stopWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak slot] in
            guard let slot else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            slot.layer.setValue(0.0, forKeyPath: "emitterCells.heart.birthRate")
            CATransaction.commit()
            slot.isEmitting = false
        }
        slot.stopWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.burstDuration, execute: workItem)
    }

    private func setupGlowLayer() {
        let glow = CAGradientLayer()
        glow.type = .radial
        glow.frame = bounds

        let purple = NSColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 0.12).cgColor
        let midPurple = NSColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 0.04).cgColor
        let clear = NSColor.clear.cgColor

        glow.colors = [clear, midPurple, purple]
        glow.locations = [0.0, 0.55, 1.0]
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 1.0, y: 1.0)
        glow.opacity = 0

        layer?.insertSublayer(glow, at: 0)
        glowLayer = glow
    }

    func updateGlow(intensity: Double) {
        let targetOpacity = Float(intensity)
        guard abs(targetOpacity - currentGlowOpacity) > 0.001 else { return }
        currentGlowOpacity = targetOpacity

        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = glowLayer?.presentation()?.opacity ?? glowLayer?.opacity
        animation.toValue = targetOpacity
        animation.duration = targetOpacity > (glowLayer?.opacity ?? 0) ? 0.3 : 0.8
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false

        glowLayer?.add(animation, forKey: "glowOpacity")

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glowLayer?.opacity = targetOpacity
        CATransaction.commit()
    }

    private func setupSlots() {
        for _ in 0..<Self.slotCount {
            let emitterLayer = CAEmitterLayer()
            emitterLayer.emitterShape = .line
            emitterLayer.emitterMode = .surface
            emitterLayer.renderMode = .unordered
            emitterLayer.seed = UInt32.random(in: UInt32.min...UInt32.max)
            emitterLayer.birthRate = 1
            emitterLayer.beginTime = CACurrentMediaTime()
            emitterLayer.emitterCells = [makeHeartCell()]
            layer?.addSublayer(emitterLayer)
            slots.append(EmitterSlot(layer: emitterLayer))
        }
    }

    private func makeHeartCell() -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.name = "heart"
        cell.contents = Self.heartImage
        cell.birthRate = 0
        cell.lifetime = 15.0
        cell.lifetimeRange = 2.0
        cell.velocity = 250
        cell.velocityRange = 70
        cell.emissionLongitude = 0
        cell.emissionRange = .pi / 12
        cell.yAcceleration = 6
        cell.scale = 0.46
        cell.scaleRange = 0.32
        cell.scaleSpeed = -0.04
        cell.spin = 0.7
        cell.spinRange = 1.8
        cell.alphaRange = 0.2
        cell.alphaSpeed = -0.06
        cell.color = NSColor.systemPurple.cgColor
        cell.redRange = 0.12
        cell.greenRange = 0.08
        cell.blueRange = 0.08
        return cell
    }

    private static let heartImage: CGImage? = {
        let size = NSSize(width: 64, height: 64)
        let image = NSImage(size: size)

        image.lockFocus()
        let heart = NSAttributedString(
            string: "\u{2764}\u{FE0E}",
            attributes: [
                .font: NSFont.systemFont(ofSize: 54, weight: .bold),
                .foregroundColor: NSColor.white
            ]
        )
        let glyphSize = heart.size()
        let drawRect = NSRect(
            x: (size.width - glyphSize.width) / 2,
            y: (size.height - glyphSize.height) / 2 - 2,
            width: glyphSize.width,
            height: glyphSize.height
        )
        heart.draw(in: drawRect)
        image.unlockFocus()

        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }()
}
