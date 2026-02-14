import AppKit
import SwiftUI

struct HeartBurst {
    let token: UInt64
    let count: Int
}

@MainActor
final class HeartAnimationModel: ObservableObject {
    private static let defaultBurstCount = 150
    private static let maxBurstCount = 1000

    @Published private(set) var burst = HeartBurst(token: 0, count: 0)
    private let configuredBurstCount: Int

    init() {
        configuredBurstCount = Self.readBurstCountFromEnvironment()
    }

    func addBurst(count: Int? = nil) {
        let requested = count ?? configuredBurstCount
        let clampedCount = min(max(requested, 1), Self.maxBurstCount)
        burst = HeartBurst(token: burst.token &+ 1, count: clampedCount)
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
    }
}

@MainActor
final class HeartEmitterView: NSView {
    private static let burstDuration: TimeInterval = 0.18
    private static let maxBirthRate: Float = 80_000

    private let emitterLayer = CAEmitterLayer()
    private var latestToken: UInt64 = 0
    private var stopEmissionWorkItem: DispatchWorkItem?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.clear.cgColor
        setupEmitterLayer()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        emitterLayer.frame = bounds
        emitterLayer.emitterSize = CGSize(width: bounds.width, height: 2)
        emitterLayer.emitterPosition = CGPoint(x: bounds.midX, y: bounds.maxY + 24)
        CATransaction.commit()
    }

    func emitBurst(token: UInt64, count: Int) {
        guard token != latestToken else { return }
        latestToken = token

        guard count > 0 else { return }

        let emissionRate = min(Float(count) / Float(Self.burstDuration), Self.maxBirthRate)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        emitterLayer.setValue(emissionRate, forKeyPath: "emitterCells.heart.birthRate")
        CATransaction.commit()

        stopEmissionWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.emitterLayer.setValue(0.0, forKeyPath: "emitterCells.heart.birthRate")
            CATransaction.commit()
        }
        stopEmissionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.burstDuration, execute: workItem)
    }

    private func setupEmitterLayer() {
        emitterLayer.emitterShape = .line
        emitterLayer.emitterMode = .surface
        emitterLayer.renderMode = .unordered
        emitterLayer.seed = UInt32.random(in: UInt32.min...UInt32.max)
        emitterLayer.birthRate = 1
        emitterLayer.beginTime = CACurrentMediaTime()
        emitterLayer.emitterCells = [makeHeartCell()]
        layer?.addSublayer(emitterLayer)
    }

    private func makeHeartCell() -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.name = "heart"
        cell.contents = Self.heartImage
        cell.birthRate = 0
        cell.lifetime = 3.4
        cell.lifetimeRange = 1.0
        cell.velocity = 360
        cell.velocityRange = 160
        cell.emissionLongitude = 0
        cell.emissionRange = .pi / 10
        cell.yAcceleration = 70
        cell.scale = 0.46
        cell.scaleRange = 0.32
        cell.scaleSpeed = -0.07
        cell.spin = 0.7
        cell.spinRange = 1.8
        cell.alphaRange = 0.2
        cell.alphaSpeed = -0.3
        cell.color = NSColor.systemPink.cgColor
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
