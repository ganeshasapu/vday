import AppKit
import SwiftUI

@MainActor
final class BirthdayAnimationView: NSView {
    private var backgroundLayer: CALayer?
    private var fireworkLayers: [CAEmitterLayer] = []
    private var fireworkBurstTimer: DispatchSourceTimer?
    private var confettiEmitter: CAEmitterLayer?
    private var sparkleEmitter: CAEmitterLayer?
    private var textContainer: CALayer?
    private var glowTextLayer: CATextLayer?
    private var characterContainers: [CALayer] = []
    private var photoLayer: CALayer?
    private var photoBorderLayer: CALayer?
    private var photoTimer: DispatchSourceTimer?
    private var photos: [(image: NSImage, caption: String?)] = []
    private var currentPhotoIndex = 0
    private var introMessageLayer: CALayer?
    private var finalMessageLayer: CALayer?
    private var onComplete: (() -> Void)?
    private var isStopped = false

    private static let burstColors: [(CGFloat, CGFloat, CGFloat)] = [
        (1.0, 0.2, 0.5),   // hot pink
        (1.0, 0.84, 0.0),  // gold
        (0.3, 0.7, 1.0),   // electric blue
        (0.8, 0.3, 1.0),   // purple
        (1.0, 0.4, 0.1),   // orange
        (0.2, 1.0, 0.6),   // emerald
        (1.0, 1.0, 1.0),   // white
        (1.0, 0.0, 0.0),   // red
    ]

    // Cursive font for the birthday message
    private static let cursiveFont: NSFont = {
        // Zapfino is the most dramatic/ornate script font on macOS (smaller size since it renders large)
        if let font = NSFont(name: "Zapfino", size: 64) { return font }
        if let font = NSFont(name: "Savoye LET", size: 96) { return font }
        if let font = NSFont(name: "Snell Roundhand", size: 96) { return font }
        return NSFont.systemFont(ofSize: 96, weight: .black)
    }()

    override var isFlipped: Bool { true }

    init(frame: NSRect, onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        super.init(frame: frame)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.clear.cgColor
        photos = Self.loadBundledPhotos()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startSequence() {
        // Timeline: intro → photos → final message → grand finale → fade
        let photoCount = max(photos.count, 1)
        let introLine1Start = 5.0
        let introLine2Start = 7.5
        let photoStart = 14.0
        let photoEnd = photoStart + Double(photoCount) * 7.0
        let finalMessageStart = photoEnd
        let grandFinaleStart = photoEnd + 3.0
        let fadeStart = photoEnd + 9.0
        let completeTime = photoEnd + 11.0

        showBackground()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard self?.isStopped != true else { return }
            self?.startFireworks()
            self?.startConfetti()
            self?.startSparkles()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard self?.isStopped != true else { return }
            self?.showText()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + introLine1Start) { [weak self] in
            guard self?.isStopped != true else { return }
            self?.showIntroMessage(line: 1)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + introLine2Start) { [weak self] in
            guard self?.isStopped != true else { return }
            self?.showIntroMessage(line: 2)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + photoStart) { [weak self] in
            guard self?.isStopped != true else { return }
            self?.dismissIntroMessage()
            self?.showFirstPhoto()
            self?.startPhotoCycling()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + finalMessageStart) { [weak self] in
            guard self?.isStopped != true else { return }
            self?.showFinalMessage()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + grandFinaleStart) { [weak self] in
            guard self?.isStopped != true else { return }
            self?.grandFinale()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + fadeStart) { [weak self] in
            guard self?.isStopped != true else { return }
            self?.fadeOutEverything()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + completeTime) { [weak self] in
            guard self?.isStopped != true else { return }
            self?.cleanup()
            self?.onComplete?()
        }
    }

    func stopSequence() {
        isStopped = true
        cleanup()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backgroundLayer?.frame = bounds
        for emitter in fireworkLayers {
            emitter.frame = bounds
        }
        confettiEmitter?.frame = bounds
        confettiEmitter?.emitterPosition = CGPoint(x: bounds.midX, y: -10)
        confettiEmitter?.emitterSize = CGSize(width: bounds.width * 1.2, height: 2)
        sparkleEmitter?.frame = bounds
        sparkleEmitter?.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        sparkleEmitter?.emitterSize = bounds.size
        layoutTextContainer()
        CATransaction.commit()
    }

    // MARK: - Background

    private func showBackground() {
        let bg = CALayer()
        bg.frame = bounds
        bg.backgroundColor = NSColor(white: 0, alpha: 0.65).cgColor
        bg.opacity = 0
        layer?.addSublayer(bg)
        backgroundLayer = bg

        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0
        fadeIn.toValue = 1
        fadeIn.duration = 0.8
        fadeIn.timingFunction = CAMediaTimingFunction(name: .easeIn)
        fadeIn.fillMode = .forwards
        fadeIn.isRemovedOnCompletion = false
        bg.add(fadeIn, forKey: "fadeIn")
    }

    // MARK: - Fireworks (point bursts across the screen)

    private static let fireworkSlotCount = 6

    private func startFireworks() {
        for _ in 0..<Self.fireworkSlotCount {
            let emitter = CAEmitterLayer()
            emitter.frame = bounds
            emitter.emitterShape = .point
            emitter.emitterMode = .outline
            emitter.renderMode = .additive
            emitter.seed = UInt32.random(in: UInt32.min...UInt32.max)
            emitter.birthRate = 1
            emitter.emitterPosition = randomFireworkPosition()

            let (r, g, b) = Self.burstColors.randomElement()!
            emitter.emitterCells = makeFireworkCells(r: r, g: g, b: b)

            layer?.addSublayer(emitter)
            fireworkLayers.append(emitter)
        }

        startFireworkBursts()
    }

    private func startFireworkBursts() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 0.4)
        var burstIndex = 0
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let idx = burstIndex % self.fireworkLayers.count
            let emitter = self.fireworkLayers[idx]
            let pos = self.randomFireworkPosition()
            let (r, g, b) = Self.burstColors.randomElement()!

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            emitter.emitterPosition = pos
            for cell in emitter.emitterCells ?? [] {
                cell.color = NSColor(red: r, green: g, blue: b, alpha: 1.0).cgColor
            }
            CATransaction.commit()
            burstIndex += 1
        }
        timer.resume()
        fireworkBurstTimer = timer
    }

    private func randomFireworkPosition() -> CGPoint {
        CGPoint(
            x: CGFloat.random(in: bounds.width * 0.05...bounds.width * 0.95),
            y: CGFloat.random(in: bounds.height * 0.1...bounds.height * 0.65)
        )
    }

    private func makeFireworkCells(r: CGFloat, g: CGFloat, b: CGFloat) -> [CAEmitterCell] {
        let burst = CAEmitterCell()
        burst.name = "burst"
        burst.birthRate = 80
        burst.lifetime = 2.0
        burst.lifetimeRange = 0.8
        burst.velocity = 300
        burst.velocityRange = 150
        burst.emissionRange = .pi * 2
        burst.spin = 1.5
        burst.spinRange = 3
        burst.scale = 0.18
        burst.scaleRange = 0.1
        burst.scaleSpeed = -0.06
        burst.alphaSpeed = -0.4
        burst.contents = Self.sparkImage
        burst.color = NSColor(red: r, green: g, blue: b, alpha: 1.0).cgColor
        burst.redRange = 0.15
        burst.greenRange = 0.15
        burst.blueRange = 0.15

        let trail = CAEmitterCell()
        trail.name = "trail"
        trail.birthRate = 120
        trail.lifetime = 1.2
        trail.lifetimeRange = 0.5
        trail.velocity = 180
        trail.velocityRange = 100
        trail.emissionRange = .pi * 2
        trail.spin = 2
        trail.spinRange = 4
        trail.scale = 0.06
        trail.scaleRange = 0.03
        trail.scaleSpeed = -0.03
        trail.alphaSpeed = -0.7
        trail.contents = Self.sparkImage
        trail.color = NSColor(red: min(r + 0.3, 1), green: min(g + 0.3, 1), blue: min(b + 0.3, 1), alpha: 1.0).cgColor

        let core = CAEmitterCell()
        core.name = "core"
        core.birthRate = 30
        core.lifetime = 0.8
        core.lifetimeRange = 0.3
        core.velocity = 60
        core.velocityRange = 40
        core.emissionRange = .pi * 2
        core.scale = 0.35
        core.scaleRange = 0.15
        core.scaleSpeed = -0.2
        core.alphaSpeed = -0.8
        core.contents = Self.glowImage
        core.color = NSColor.white.cgColor

        return [burst, trail, core]
    }

    // MARK: - Sparkles

    private func startSparkles() {
        let emitter = CAEmitterLayer()
        emitter.frame = bounds
        emitter.emitterShape = .rectangle
        emitter.emitterMode = .surface
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        emitter.emitterSize = bounds.size
        emitter.renderMode = .additive
        emitter.seed = UInt32.random(in: UInt32.min...UInt32.max)

        let sparkle = CAEmitterCell()
        sparkle.birthRate = 15
        sparkle.lifetime = 3
        sparkle.lifetimeRange = 1.5
        sparkle.velocity = 0
        sparkle.scale = 0.08
        sparkle.scaleRange = 0.06
        sparkle.scaleSpeed = -0.01
        sparkle.alphaRange = 0.5
        sparkle.alphaSpeed = -0.2
        sparkle.contents = Self.glowImage
        sparkle.color = NSColor(red: 1.0, green: 0.95, blue: 0.8, alpha: 0.8).cgColor

        emitter.emitterCells = [sparkle]
        layer?.addSublayer(emitter)
        sparkleEmitter = emitter
    }

    // MARK: - Confetti

    private func startConfetti() {
        let emitter = CAEmitterLayer()
        emitter.frame = bounds
        emitter.emitterShape = .line
        emitter.emitterMode = .surface
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: -10)
        emitter.emitterSize = CGSize(width: bounds.width * 1.2, height: 2)
        emitter.seed = UInt32.random(in: UInt32.min...UInt32.max)
        emitter.birthRate = 1

        let colors: [NSColor] = [
            NSColor(red: 1.0, green: 0.2, blue: 0.5, alpha: 1.0),
            NSColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0),
            NSColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0),
            NSColor(red: 0.8, green: 0.3, blue: 1.0, alpha: 1.0),
            NSColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 1.0),
            NSColor(red: 0.2, green: 1.0, blue: 0.5, alpha: 1.0),
            NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
        ]

        var cells: [CAEmitterCell] = []
        for color in colors {
            let cell = CAEmitterCell()
            cell.birthRate = 15
            cell.lifetime = 14
            cell.lifetimeRange = 5
            cell.velocity = 60
            cell.velocityRange = 30
            cell.emissionLongitude = .pi / 2
            cell.emissionRange = .pi / 6
            cell.yAcceleration = 20
            cell.xAcceleration = CGFloat.random(in: -5...5)
            cell.spin = 4
            cell.spinRange = 8
            cell.scale = 0.06
            cell.scaleRange = 0.03
            cell.alphaSpeed = -0.04
            cell.contents = Self.confettiImage
            cell.color = color.cgColor
            cells.append(cell)
        }

        emitter.emitterCells = cells
        layer?.addSublayer(emitter)
        confettiEmitter = emitter
    }

    // MARK: - Text (Cursive)

    private func showText() {
        let container = CALayer()
        container.frame = bounds
        layer?.addSublayer(container)
        textContainer = container

        let font = Self.cursiveFont
        let textString = "Happy Birthday Esther!"
        let screenScale = NSScreen.main?.backingScaleFactor ?? 2.0
        let attrs: [NSAttributedString.Key: Any] = [.font: font]

        let fullSize = (textString as NSString).size(withAttributes: attrs)
        let startX = (bounds.width - fullSize.width) / 2
        let baseY = bounds.height * 0.05

        // Calculate per-character positions using cumulative measurement
        let nsText = textString as NSString
        var charInfos: [(char: String, x: CGFloat, width: CGFloat)] = []
        for i in 0..<nsText.length {
            let prefixWidth = (nsText.substring(to: i) as NSString).size(withAttributes: attrs).width
            let charWidth = (nsText.substring(to: i + 1) as NSString).size(withAttributes: attrs).width - prefixWidth
            charInfos.append((
                char: nsText.substring(with: NSRange(location: i, length: 1)),
                x: prefixWidth,
                width: charWidth
            ))
        }

        characterContainers = []

        for info in charInfos {
            let charContainer = CALayer()
            charContainer.frame = CGRect(
                x: startX + info.x,
                y: baseY,
                width: info.width,
                height: fullSize.height + 20
            )
            charContainer.opacity = 0
            // Fix CATextLayer rendering on macOS flipped views
            charContainer.isGeometryFlipped = true

            let localFrame = CGRect(x: 0, y: 0, width: info.width, height: fullSize.height + 20)

            // Outer glow (pink)
            let outer = CATextLayer()
            outer.string = info.char
            outer.fontSize = font.pointSize
            outer.font = font
            outer.foregroundColor = NSColor(red: 1.0, green: 0.3, blue: 0.6, alpha: 1.0).cgColor
            outer.contentsScale = screenScale
            outer.frame = localFrame
            outer.shadowColor = NSColor(red: 1.0, green: 0.2, blue: 0.5, alpha: 1.0).cgColor
            outer.shadowOffset = .zero
            outer.shadowRadius = 60
            outer.shadowOpacity = 1.0
            charContainer.addSublayer(outer)

            // Mid glow (gold)
            let mid = CATextLayer()
            mid.string = info.char
            mid.fontSize = font.pointSize
            mid.font = font
            mid.foregroundColor = NSColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 1.0).cgColor
            mid.contentsScale = screenScale
            mid.frame = localFrame
            mid.shadowColor = NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0).cgColor
            mid.shadowOffset = .zero
            mid.shadowRadius = 30
            mid.shadowOpacity = 1.0
            charContainer.addSublayer(mid)

            // Main text (white)
            let main = CATextLayer()
            main.string = info.char
            main.fontSize = font.pointSize
            main.font = font
            main.foregroundColor = NSColor.white.cgColor
            main.contentsScale = screenScale
            main.frame = localFrame
            main.shadowColor = NSColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0).cgColor
            main.shadowOffset = .zero
            main.shadowRadius = 15
            main.shadowOpacity = 1.0
            charContainer.addSublayer(main)

            container.addSublayer(charContainer)
            characterContainers.append(charContainer)
        }

        glowTextLayer = characterContainers.first?.sublayers?.first as? CATextLayer

        // Staggered entrance: letters appear one by one
        for (i, charLayer) in characterContainers.enumerated() {
            let delay = Double(i) * 0.05

            let fadeIn = CABasicAnimation(keyPath: "opacity")
            fadeIn.fromValue = 0
            fadeIn.toValue = 1
            fadeIn.duration = 0.5
            fadeIn.beginTime = CACurrentMediaTime() + delay
            fadeIn.fillMode = .forwards
            fadeIn.isRemovedOnCompletion = false

            let scaleUp = CABasicAnimation(keyPath: "transform.scale")
            scaleUp.fromValue = 0.3
            scaleUp.toValue = 1.0
            scaleUp.duration = 0.4
            scaleUp.beginTime = CACurrentMediaTime() + delay
            scaleUp.timingFunction = CAMediaTimingFunction(controlPoints: 0.175, 0.885, 0.32, 1.275)
            scaleUp.fillMode = .forwards
            scaleUp.isRemovedOnCompletion = false

            charLayer.add(fadeIn, forKey: "fadeIn")
            charLayer.add(scaleUp, forKey: "scaleUp")
        }

        // Per-character floating wave after entrance completes
        let entranceEnd = Double(characterContainers.count) * 0.05 + 0.6
        DispatchQueue.main.asyncAfter(deadline: .now() + entranceEnd) { [weak self] in
            guard let self, !self.isStopped else { return }
            for (i, charLayer) in self.characterContainers.enumerated() {
                let wave = CAKeyframeAnimation(keyPath: "transform.translation.y")
                wave.values = [0, -12, 0, 6, 0]
                wave.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
                wave.duration = 2.0
                wave.repeatCount = .infinity
                wave.timeOffset = Double(i) * 0.12
                charLayer.add(wave, forKey: "wave")
            }
        }

        // Pulsing glow on outer layers
        for charLayer in characterContainers {
            if let outerGlow = charLayer.sublayers?.first {
                let pulse = CABasicAnimation(keyPath: "shadowRadius")
                pulse.fromValue = 60
                pulse.toValue = 90
                pulse.duration = 1.5
                pulse.autoreverses = true
                pulse.repeatCount = .infinity
                pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                outerGlow.add(pulse, forKey: "glowPulse")
            }
        }
    }

    private func layoutTextContainer() {
        textContainer?.frame = bounds
        guard !characterContainers.isEmpty else { return }

        let font = Self.cursiveFont
        let textString = "Happy Birthday Esther!"
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let fullSize = (textString as NSString).size(withAttributes: attrs)
        let startX = (bounds.width - fullSize.width) / 2
        let baseY = bounds.height * 0.05
        let nsText = textString as NSString

        for (i, container) in characterContainers.enumerated() {
            let prefixWidth = (nsText.substring(to: i) as NSString).size(withAttributes: attrs).width
            let charWidth = (nsText.substring(to: i + 1) as NSString).size(withAttributes: attrs).width - prefixWidth
            container.frame = CGRect(
                x: startX + prefixWidth,
                y: baseY,
                width: charWidth,
                height: fullSize.height + 20
            )
        }
    }

    // MARK: - Intro Message

    private func showIntroMessage(line: Int) {
        let screenScale = NSScreen.main?.backingScaleFactor ?? 2.0
        let font = NSFont(name: "Zapfino", size: 40) ?? NSFont.systemFont(ofSize: 40, weight: .medium)

        if line == 1 {
            let container = CALayer()
            container.frame = bounds
            container.isGeometryFlipped = true
            layer?.addSublayer(container)
            introMessageLayer = container

            let line1 = CATextLayer()
            line1.name = "line1"
            line1.string = "A lot has happened in the last year,"
            line1.font = font
            line1.fontSize = font.pointSize
            line1.foregroundColor = NSColor.white.cgColor
            line1.alignmentMode = .center
            line1.contentsScale = screenScale
            line1.isWrapped = true
            line1.shadowColor = NSColor(red: 1.0, green: 0.3, blue: 0.6, alpha: 0.8).cgColor
            line1.shadowOffset = .zero
            line1.shadowRadius = 20
            line1.shadowOpacity = 1.0
            line1.opacity = 0

            let textWidth = bounds.width * 0.7
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let rect1 = ("A lot has happened in the last year," as NSString).boundingRect(
                with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs
            )
            let line2Height: CGFloat = {
                let r = ("so here is a quick recap" as NSString).boundingRect(
                    with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attrs
                )
                return ceil(r.height) + 20
            }()
            line1.frame = CGRect(
                x: (bounds.width - textWidth) / 2,
                y: bounds.height * 0.35 + line2Height + 10,
                width: textWidth,
                height: ceil(rect1.height) + 20
            )
            container.addSublayer(line1)

            let fadeIn = CABasicAnimation(keyPath: "opacity")
            fadeIn.fromValue = 0
            fadeIn.toValue = 1
            fadeIn.duration = 1.2
            fadeIn.fillMode = .forwards
            fadeIn.isRemovedOnCompletion = false
            line1.add(fadeIn, forKey: "fadeIn")
        }

        if line == 2, let container = introMessageLayer {
            let line2 = CATextLayer()
            line2.name = "line2"
            line2.string = "so here is a quick recap"
            line2.font = font
            line2.fontSize = font.pointSize
            line2.foregroundColor = NSColor.white.cgColor
            line2.alignmentMode = .center
            line2.contentsScale = screenScale
            line2.isWrapped = true
            line2.shadowColor = NSColor(red: 1.0, green: 0.3, blue: 0.6, alpha: 0.8).cgColor
            line2.shadowOffset = .zero
            line2.shadowRadius = 20
            line2.shadowOpacity = 1.0
            line2.opacity = 0

            let textWidth = bounds.width * 0.7
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let rect2 = ("so here is a quick recap" as NSString).boundingRect(
                with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs
            )
            line2.frame = CGRect(
                x: (bounds.width - textWidth) / 2,
                y: bounds.height * 0.35,
                width: textWidth,
                height: ceil(rect2.height) + 20
            )
            container.addSublayer(line2)

            let fadeIn = CABasicAnimation(keyPath: "opacity")
            fadeIn.fromValue = 0
            fadeIn.toValue = 1
            fadeIn.duration = 1.2
            fadeIn.fillMode = .forwards
            fadeIn.isRemovedOnCompletion = false
            line2.add(fadeIn, forKey: "fadeIn")
        }
    }

    private func dismissIntroMessage() {
        guard let container = introMessageLayer else { return }
        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = 1
        fadeOut.toValue = 0
        fadeOut.duration = 1.0
        fadeOut.fillMode = .forwards
        fadeOut.isRemovedOnCompletion = false
        container.add(fadeOut, forKey: "fadeOut")
        let captured = container
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            captured.removeFromSuperlayer()
        }
        introMessageLayer = nil
    }

    // MARK: - Photos

    private func showFirstPhoto() {
        guard !photos.isEmpty else { return }
        currentPhotoIndex = 0
        showPhoto(at: 0, animated: true)
    }

    private func startPhotoCycling() {
        guard photos.count > 1 else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 7.0, repeating: 7.0)
        timer.setEventHandler { [weak self] in
            guard let self, !self.isStopped else { return }
            let nextIndex = self.currentPhotoIndex + 1
            guard nextIndex < self.photos.count else {
                self.photoTimer?.cancel()
                self.photoTimer = nil
                return
            }
            self.currentPhotoIndex = nextIndex
            self.showPhoto(at: self.currentPhotoIndex, animated: true)
        }
        timer.resume()
        photoTimer = timer
    }

    private func showPhoto(at index: Int, animated: Bool) {
        guard index < photos.count else { return }
        let image = photos[index].image
        let caption = photos[index].caption

        let maxPhotoWidth: CGFloat = min(bounds.width * 0.45, 500)
        let maxPhotoHeight: CGFloat = min(bounds.height * 0.55, 600)
        let imageSize = image.size
        let scale = min(maxPhotoWidth / imageSize.width, maxPhotoHeight / imageSize.height, 1.0)
        let photoWidth = imageSize.width * scale
        let photoHeight = imageSize.height * scale

        let borderPadding: CGFloat = 16
        let hasCaption = caption != nil && !caption!.isEmpty
        let captionFont = NSFont(name: "Bradley Hand", size: 28) ?? NSFont.systemFont(ofSize: 28, weight: .medium)
        let captionAreaWidth = photoWidth + borderPadding
        var bottomPadding: CGFloat = 40
        if hasCaption {
            let attrs: [NSAttributedString.Key: Any] = [.font: captionFont]
            let boundingRect = (caption! as NSString).boundingRect(
                with: CGSize(width: captionAreaWidth - 16, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs
            )
            bottomPadding = ceil(boundingRect.height) + 24
        }
        let totalWidth = photoWidth + borderPadding * 2
        let totalHeight = photoHeight + borderPadding + bottomPadding
        let rotation = CGFloat.random(in: -0.05...0.05)

        if animated, let oldBorder = photoBorderLayer {
            let fadeOut = CABasicAnimation(keyPath: "opacity")
            fadeOut.fromValue = 1
            fadeOut.toValue = 0
            fadeOut.duration = 0.8
            fadeOut.fillMode = .forwards
            fadeOut.isRemovedOnCompletion = false
            oldBorder.add(fadeOut, forKey: "fadeOut")
            let capturedBorder = oldBorder
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                capturedBorder.removeFromSuperlayer()
            }
        }

        let border = CALayer()
        border.frame = CGRect(
            x: (bounds.width - totalWidth) / 2,
            y: (bounds.height - totalHeight) / 2 + bounds.height * 0.05,
            width: totalWidth,
            height: totalHeight
        )
        border.backgroundColor = NSColor.white.cgColor
        border.cornerRadius = 4
        border.shadowColor = NSColor(red: 1.0, green: 0.4, blue: 0.7, alpha: 0.8).cgColor
        border.shadowOffset = .zero
        border.shadowRadius = 30
        border.shadowOpacity = 0.8
        border.setAffineTransform(CGAffineTransform(rotationAngle: rotation))

        let photo = CALayer()
        photo.frame = CGRect(x: borderPadding, y: borderPadding, width: photoWidth, height: photoHeight)
        photo.contents = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        photo.contentsGravity = .resizeAspectFill
        photo.masksToBounds = true
        photo.cornerRadius = 2
        border.addSublayer(photo)

        if hasCaption {
            let captionLayer = CATextLayer()
            captionLayer.string = caption
            captionLayer.font = captionFont
            captionLayer.fontSize = 28
            captionLayer.foregroundColor = NSColor.black.cgColor
            captionLayer.alignmentMode = .center
            captionLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
            captionLayer.isGeometryFlipped = true
            captionLayer.isWrapped = true
            captionLayer.frame = CGRect(
                x: 8,
                y: borderPadding + photoHeight + 6,
                width: captionAreaWidth,
                height: bottomPadding - 10
            )
            border.addSublayer(captionLayer)
        }

        if animated {
            border.opacity = 0
            let fadeIn = CABasicAnimation(keyPath: "opacity")
            fadeIn.fromValue = 0
            fadeIn.toValue = 1
            fadeIn.duration = 0.8
            fadeIn.fillMode = .forwards
            fadeIn.isRemovedOnCompletion = false

            let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
            scaleAnim.fromValue = 0.85
            scaleAnim.toValue = 1.0
            scaleAnim.duration = 0.8
            scaleAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            scaleAnim.fillMode = .forwards
            scaleAnim.isRemovedOnCompletion = false

            let group = CAAnimationGroup()
            group.animations = [fadeIn, scaleAnim]
            group.duration = 0.8
            group.fillMode = .forwards
            group.isRemovedOnCompletion = false
            border.add(group, forKey: "entrance")
        }

        if let textContainer = textContainer {
            layer?.insertSublayer(border, below: textContainer)
        } else {
            layer?.addSublayer(border)
        }

        photoLayer = photo
        photoBorderLayer = border
    }

    // MARK: - Final Message

    private func showFinalMessage() {
        // Fade out the last photo
        if let oldBorder = photoBorderLayer {
            let fadeOut = CABasicAnimation(keyPath: "opacity")
            fadeOut.fromValue = 1
            fadeOut.toValue = 0
            fadeOut.duration = 1.0
            fadeOut.fillMode = .forwards
            fadeOut.isRemovedOnCompletion = false
            oldBorder.add(fadeOut, forKey: "fadeOut")
            let captured = oldBorder
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                captured.removeFromSuperlayer()
            }
            photoBorderLayer = nil
            photoLayer = nil
        }

        let screenScale = NSScreen.main?.backingScaleFactor ?? 2.0
        let font = NSFont(name: "Zapfino", size: 52) ?? NSFont.systemFont(ofSize: 52, weight: .bold)
        let message = "To many more birthdays!!!"

        let container = CALayer()
        container.frame = bounds
        container.opacity = 0
        container.isGeometryFlipped = true

        let textLayer = CATextLayer()
        textLayer.string = message
        textLayer.font = font
        textLayer.fontSize = font.pointSize
        textLayer.foregroundColor = NSColor.white.cgColor
        textLayer.alignmentMode = .center
        textLayer.contentsScale = screenScale
        textLayer.isWrapped = true
        textLayer.shadowColor = NSColor(red: 1.0, green: 0.3, blue: 0.6, alpha: 1.0).cgColor
        textLayer.shadowOffset = .zero
        textLayer.shadowRadius = 40
        textLayer.shadowOpacity = 1.0

        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let textWidth = bounds.width * 0.7
        let boundingRect = (message as NSString).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
        let textHeight = ceil(boundingRect.height) + 20
        textLayer.frame = CGRect(
            x: (bounds.width - textWidth) / 2,
            y: (bounds.height - textHeight) / 2,
            width: textWidth,
            height: textHeight
        )

        container.addSublayer(textLayer)
        layer?.addSublayer(container)
        finalMessageLayer = container

        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0
        fadeIn.toValue = 1
        fadeIn.duration = 1.5
        fadeIn.fillMode = .forwards
        fadeIn.isRemovedOnCompletion = false

        let scaleUp = CABasicAnimation(keyPath: "transform.scale")
        scaleUp.fromValue = 0.7
        scaleUp.toValue = 1.0
        scaleUp.duration = 1.5
        scaleUp.timingFunction = CAMediaTimingFunction(controlPoints: 0.175, 0.885, 0.32, 1.275)
        scaleUp.fillMode = .forwards
        scaleUp.isRemovedOnCompletion = false

        let group = CAAnimationGroup()
        group.animations = [fadeIn, scaleUp]
        group.duration = 1.5
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        container.add(group, forKey: "entrance")
    }

    // MARK: - Grand Finale

    private func grandFinale() {
        // Massively increase firework intensity
        for emitter in fireworkLayers {
            for cell in emitter.emitterCells ?? [] {
                cell.birthRate *= 4
                cell.velocity *= 1.3
            }
        }

        // Speed up burst repositioning
        fireworkBurstTimer?.schedule(deadline: .now(), repeating: 0.15)

        // Crank up confetti
        for cell in confettiEmitter?.emitterCells ?? [] {
            cell.birthRate *= 3
        }

        // Crank up sparkles
        for cell in sparkleEmitter?.emitterCells ?? [] {
            cell.birthRate *= 4
        }
    }

    // MARK: - Fade Out

    private func fadeOutEverything() {
        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = 1
        fadeOut.toValue = 0
        fadeOut.duration = 2.0
        fadeOut.fillMode = .forwards
        fadeOut.isRemovedOnCompletion = false

        layer?.sublayers?.forEach { sublayer in
            sublayer.add(fadeOut, forKey: "finalFadeOut")
        }
    }

    // MARK: - Cleanup

    private func cleanup() {
        fireworkBurstTimer?.cancel()
        fireworkBurstTimer = nil
        fireworkLayers.removeAll()
        characterContainers.removeAll()
        photoTimer?.cancel()
        photoTimer = nil
        layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
    }

    // MARK: - Image Generation

    private static let sparkImage: CGImage? = {
        let size = NSSize(width: 64, height: 64)
        let image = NSImage(size: size)
        image.lockFocus()
        let gradient = NSGradient(colors: [
            NSColor(white: 1.0, alpha: 1.0),
            NSColor(white: 1.0, alpha: 0.8),
            NSColor(white: 1.0, alpha: 0.3),
            NSColor(white: 1.0, alpha: 0.0)
        ], atLocations: [0, 0.15, 0.5, 1.0], colorSpace: .sRGB)
        gradient?.draw(in: NSBezierPath(ovalIn: NSRect(origin: .zero, size: size)), relativeCenterPosition: .zero)
        image.unlockFocus()
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }()

    private static let glowImage: CGImage? = {
        let size = NSSize(width: 128, height: 128)
        let image = NSImage(size: size)
        image.lockFocus()
        let gradient = NSGradient(colors: [
            NSColor(white: 1.0, alpha: 1.0),
            NSColor(white: 1.0, alpha: 0.5),
            NSColor(white: 1.0, alpha: 0.1),
            NSColor(white: 1.0, alpha: 0.0)
        ], atLocations: [0, 0.2, 0.6, 1.0], colorSpace: .sRGB)
        gradient?.draw(in: NSBezierPath(ovalIn: NSRect(origin: .zero, size: size)), relativeCenterPosition: .zero)
        image.unlockFocus()
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }()

    private static let confettiImage: CGImage? = {
        let size = NSSize(width: 12, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 2, yRadius: 2).fill()
        image.unlockFocus()
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }()

    // MARK: - Photo Loading

    private static func loadBundledPhotos() -> [(image: NSImage, caption: String?)] {
        guard let url = Bundle.module.url(forResource: "BirthdayPhotos", withExtension: nil) else { return [] }
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return [] }

        // Load captions from captions.json if it exists
        var captions: [String: String] = [:]
        let captionsURL = url.appendingPathComponent("captions.json")
        if let data = try? Data(contentsOf: captionsURL),
           let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            captions = dict
        }

        let imageExtensions = Set(["jpg", "jpeg", "png", "heic", "webp", "tiff"])
        return files
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { fileURL -> (image: NSImage, caption: String?)? in
                guard let image = NSImage(contentsOf: fileURL) else { return nil }
                return (image: image, caption: captions[fileURL.lastPathComponent])
            }
    }
}
