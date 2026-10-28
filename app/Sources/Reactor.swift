// JARVIS's on-screen presence while you talk to it (Right Option): a glowing reactor of particle
// rings around a hexagon core. Dictation (fn) keeps the plain pill in main.swift.
//
//   listening: the rings ripple with your voice
//   thinking:  the rings settle and a light sweeps round the inner ring
//   speaking:  the rings and core pulse with JARVIS's voice, ripples run outwards
//
// An original drawing in the style of the film's HUD, not a copy of anyone's artwork.
import Cocoa

enum ReactorMode { case listening, thinking, speaking }

private let cyan = (r: CGFloat(0.30), g: CGFloat(0.93), b: CGFloat(1.0))

private func cyanColor(_ alpha: CGFloat) -> CGColor {
    CGColor(red: cyan.r, green: cyan.g, blue: cyan.b, alpha: max(0, min(1, alpha)))
}

/// Draw one frame. `level` is 0...1 (voice loudness), `appear` 0...1 (fade/grow in).
func drawReactor(_ ctx: CGContext, size: CGFloat, t: Double, level: CGFloat, mode: ReactorMode, appear: CGFloat) {
    let c = CGPoint(x: size / 2, y: size / 2)
    let ease = 1 - pow(1 - appear, 3)
    ctx.saveGState()
    ctx.translateBy(x: c.x, y: c.y)
    ctx.scaleBy(x: 0.72 + 0.28 * ease, y: 0.72 + 0.28 * ease)
    ctx.setAlpha(ease)

    let R = size * 0.38
    // Dark halo so it reads on any wallpaper
    let space = CGColorSpaceCreateDeviceRGB()
    if let halo = CGGradient(colorsSpace: space, colors: [CGColor(red: 0, green: 0.05, blue: 0.07, alpha: 0.95),
                                                          CGColor(red: 0, green: 0.04, blue: 0.06, alpha: 0.9),
                                                          CGColor(red: 0, green: 0.03, blue: 0.05, alpha: 0.55),
                                                          CGColor(red: 0, green: 0, blue: 0, alpha: 0)] as CFArray,
                             locations: [0, 0.8, 0.9, 1]) {
        ctx.drawRadialGradient(halo, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: size / 2, options: [])
    }
    ctx.setBlendMode(.plusLighter)
    ctx.setLineCap(.round)

    // Particle ribbons: dotted strands whose wobble follows the voice
    let energy: CGFloat = mode == .thinking ? 0.22 : 0.30 + 1.9 * level
    for s in 0..<8 {
        let sf = Double(s)
        let base = R * (0.88 + 0.02 * CGFloat(s))
        let spin = t * (0.08 + 0.02 * sf) * (s % 2 == 0 ? 1 : -1)
        let path = CGMutablePath()
        let steps = 240
        for i in 0...steps {
            let a = Double(i) / Double(steps) * 2 * .pi
            // Shared waves keep the strands together as one ribbon; a small per-strand wave gives it depth
            let w = sin(3 * a + t * 1.3) + 0.6 * sin(5 * a - t * 1.9 + 0.8) + 0.35 * sin(9 * a + t * 2.7)
                + 0.45 * sin(4 * a + t * 1.1 + sf * 0.9)
            let r = base + R * 0.06 * energy * CGFloat(w)
            let p = CGPoint(x: r * CGFloat(cos(a + spin)), y: r * CGFloat(sin(a + spin)))
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        ctx.addPath(path)
        ctx.setLineDash(phase: 0, lengths: [])
        ctx.setStrokeColor(cyanColor(0.07 + 0.06 * level))
        ctx.setLineWidth(0.6)
        ctx.strokePath()
        ctx.addPath(path)
        ctx.setLineDash(phase: CGFloat(t * (4 + sf)), lengths: [0.01, 1.7 + CGFloat(s % 3) * 0.6])
        ctx.setStrokeColor(cyanColor(0.36 + 0.30 * level))
        ctx.setLineWidth(1.3)
        ctx.strokePath()
    }
    ctx.setLineDash(phase: 0, lengths: [])

    // Inner instrument rings: a slow tick ring, a hairline, a counter-rotating dashed ring
    let tickR = R * 0.70
    let tickSpin = t * 0.15
    for i in 0..<72 {
        let a = Double(i) / 72 * 2 * .pi + tickSpin
        let long = i % 6 == 0
        let r0 = tickR - (long ? 7 : 3)
        ctx.move(to: CGPoint(x: r0 * CGFloat(cos(a)), y: r0 * CGFloat(sin(a))))
        ctx.addLine(to: CGPoint(x: tickR * CGFloat(cos(a)), y: tickR * CGFloat(sin(a))))
    }
    ctx.setStrokeColor(cyanColor(0.42))
    ctx.setLineWidth(1)
    ctx.strokePath()
    ctx.addEllipse(in: CGRect(x: -R * 0.77, y: -R * 0.77, width: R * 1.54, height: R * 1.54))
    ctx.setStrokeColor(cyanColor(0.22))
    ctx.setLineWidth(0.8)
    ctx.strokePath()
    ctx.saveGState()
    ctx.rotate(by: CGFloat(-t * 0.35))
    ctx.addEllipse(in: CGRect(x: -R * 0.60, y: -R * 0.60, width: R * 1.2, height: R * 1.2))
    ctx.setLineDash(phase: 0, lengths: [10, 6, 2, 6])
    ctx.setStrokeColor(cyanColor(0.30))
    ctx.setLineWidth(1.2)
    ctx.strokePath()
    ctx.restoreGState()
    ctx.setLineDash(phase: 0, lengths: [])

    // Thinking: a light sweeping round the tick ring
    if mode == .thinking {
        let head = t * 4.2
        for k in 0..<16 {
            let a0 = head - Double(k) * 0.075
            ctx.addArc(center: .zero, radius: tickR + 2, startAngle: CGFloat(a0 - 0.075), endAngle: CGFloat(a0), clockwise: false)
            ctx.setStrokeColor(cyanColor(0.95 * (1 - CGFloat(k) / 16)))
            ctx.setLineWidth(2.6)
            ctx.strokePath()
        }
    }

    // Speaking: ripples running out from the core
    let coreR = R * 0.30 * (1 + 0.10 * level)
    if mode == .speaking {
        for k in 0..<2 {
            let phase = (t / 1.4 + Double(k) * 0.5).truncatingRemainder(dividingBy: 1)
            let r = coreR + (R * 0.85 - coreR) * CGFloat(phase)
            ctx.addEllipse(in: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r))
            ctx.setStrokeColor(cyanColor((1 - CGFloat(phase)) * (0.15 + 0.6 * level)))
            ctx.setLineWidth(1.4)
            ctx.strokePath()
        }
    }

    // Core: a glowing disc with a hexagon mesh
    if let glow = CGGradient(colorsSpace: space, colors: [cyanColor(0.30 + 0.40 * level), cyanColor(0.08), cyanColor(0)] as CFArray,
                             locations: [0, 0.75, 1]) {
        ctx.drawRadialGradient(glow, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: coreR * 1.35, options: [])
    }
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: -coreR, y: -coreR, width: 2 * coreR, height: 2 * coreR))
    ctx.clip()
    let hex = coreR / 6.5
    let rowH = hex * sqrt(3)
    var row = -12
    while CGFloat(row) * rowH * 0.5 < coreR + rowH {
        for col in -5...5 {
            let x = CGFloat(col) * hex * 3 + (row % 2 == 0 ? 0 : hex * 1.5)
            let y = CGFloat(row) * rowH * 0.5
            for j in 0..<6 {
                let a = Double(j) * .pi / 3
                let p = CGPoint(x: x + hex * CGFloat(cos(a)), y: y + hex * CGFloat(sin(a)))
                j == 0 ? ctx.move(to: p) : ctx.addLine(to: p)
            }
            ctx.closePath()
        }
        row += 1
    }
    let shimmer = 0.5 + 0.5 * CGFloat(sin(t * 2.2))
    ctx.setStrokeColor(cyanColor(0.30 + 0.25 * shimmer * (mode == .thinking ? 1 : 0.4) + 0.45 * level))
    ctx.setLineWidth(0.6)
    ctx.strokePath()
    ctx.restoreGState()
    ctx.addEllipse(in: CGRect(x: -coreR, y: -coreR, width: 2 * coreR, height: 2 * coreR))
    ctx.setStrokeColor(cyanColor(0.85))
    ctx.setLineWidth(1.3)
    ctx.strokePath()
    ctx.restoreGState()
}

final class ReactorView: NSView {
    var mode = ReactorMode.listening
    var targetLevel: CGFloat = 0
    var level: CGFloat = 0
    var appear: CGFloat = 0
    var fadingOut = false
    let start = Date()

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        drawReactor(ctx, size: bounds.width, t: Date().timeIntervalSince(start), level: level, mode: mode, appear: appear)
    }
}

/// The floating reactor, bottom centre of the screen with the mouse.
final class ReactorOrb {
    static let size: CGFloat = 210
    private var panel: NSPanel!
    private let view = ReactorView(frame: NSRect(x: 0, y: 0, width: ReactorOrb.size, height: ReactorOrb.size))
    private var timer: Timer?
    var micLevel: (() -> Float)?
    var voiceLevel: (() -> Float)?
    var speakingNow: (() -> Bool)?
    private(set) var visible = false
    private var quietSince = Date()

    init() {
        panel = NSPanel(contentRect: view.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = view
    }

    func show(_ mode: ReactorMode) {
        view.mode = mode
        view.fadingOut = false
        quietSince = Date()
        visible = true
        if timer == nil {             // not on screen (or still fading out: carry on from there)
            view.appear = 0
            let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main!
            let f = screen.visibleFrame
            panel.setFrame(NSRect(x: f.midX - ReactorOrb.size / 2, y: f.minY + 6, width: ReactorOrb.size, height: ReactorOrb.size),
                           display: false)
            panel.orderFrontRegardless()
        }
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
            RunLoop.main.add(timer!, forMode: .common)
        }
    }

    func hide() {
        guard visible else { return }
        visible = false
        view.fadingOut = true
    }

    private func tick() {
        switch view.mode {
        case .listening: view.targetLevel = CGFloat(min(1, (micLevel?() ?? 0) * 14))
        case .speaking: view.targetLevel = CGFloat(min(1, voiceLevel?() ?? 0))
        case .thinking: view.targetLevel = 0
        }
        // Safety net: if the voice never arrives (server down), don't stay up forever
        if view.mode == .speaking && visible {
            if speakingNow?() == true { quietSince = Date() }
            else if Date().timeIntervalSince(quietSince) > 4 { hide() }
        }
        view.level += (view.targetLevel - view.level) * (view.targetLevel > view.level ? 0.35 : 0.12)
        if view.fadingOut {
            view.appear = max(0, view.appear - 1.0 / 12)
            if view.appear == 0 {
                timer?.invalidate()
                timer = nil
                panel.orderOut(nil)
                return
            }
        } else {
            view.appear = min(1, view.appear + 1.0 / 14)
        }
        view.needsDisplay = true
    }
}
