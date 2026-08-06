//
//  GameView.swift
//  Clicker Scroller Watch App
//
//  The play screen. Spin the cog with the Digital Crown OR by flicking it.
//  Fast spinning fills the COMBO ring; random teeth CRIT; a rare Lucky Gear
//  grants a FRENZY. The whole screen earns its keep:
//    • top    — score + live stat chips
//    • middle — gear wrapped in a combo-energy ring
//    • bottom — a progress bar to your next upgrade, tap to open the Workshop
//

import SwiftUI
import Combine

struct GameView: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.scenePhase) private var scenePhase

    // — Crown → gear —
    @State private var crownValue: Double = 0
    @State private var lastCrown: Double = 0
    @State private var gearAngle: Double = 0
    @State private var tickCount: Int = 0
    @FocusState private var crownFocused: Bool

    // — Drag + flywheel momentum —
    @State private var lastDragAngle: Double? = nil
    @State private var lastDragTime: Date = .now
    @State private var dragVelocity: Double = 0
    @State private var spinVelocity: Double = 0
    @State private var isDragging = false

    // — Combo —
    @State private var comboEnergy: Double = 0

    // — Lucky Gear / frenzy —
    @State private var luckyVisible = false
    @State private var luckyNorm = CGPoint(x: 0.5, y: 0.5)
    @State private var luckyDespawnAt: Date = .distantFuture
    @State private var nextLuckyAt: Date = .distantFuture
    @State private var flashOpacity: Double = 0

    // — Juice / nav —
    @State private var floaters: [Floater] = []
    @State private var showShop = false
    @State private var firstHint = true
    @State private var lastFloaterAt: Date = .distantPast

    @State private var frameTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    /// Off-screen frames do no work — see `step()`.
    @State private var isActive = true

    // — Tuning —
    private let teeth = 12
    private var degPerTooth: Double { 360.0 / Double(teeth) }
    private let degPerCrownUnit: Double = 12.0
    private let stepDt = 1.0 / 30.0
    private let maxCombo = 3.0
    private let comboGainPerTooth = 0.035
    private let comboDecayPerStep = 0.02
    private let momentumFriction = 0.90
    private let minSpinVel = 26.0
    private let velCap = 1400.0
    private let critChance = 0.05
    private let critMultiplier = 5.0

    private var comboMultiplier: Double { 1 + comboEnergy * (maxCombo - 1) }
    private var heat: Double { max(comboEnergy, game.frenzyActive ? 0.85 : 0) }
    private func hotColor(_ t: Double) -> Color {
        Color(red: 1.0, green: 0.70 - 0.40 * t, blue: 0.28 - 0.16 * t)
    }

    var body: some View {
        ZStack {
            Theme.background

            GeometryReader { geo in
                let gearOuter = max(86, min(min(geo.size.width - 6, geo.size.height - 92), 150))
                ZStack {
                    VStack(spacing: 0) {
                        scoreHeader
                        Spacer(minLength: 2)
                        gearArea.frame(width: gearOuter, height: gearOuter)
                        Spacer(minLength: 2)
                        upgradesButton
                    }
                    .frame(width: geo.size.width, height: geo.size.height)

                    if luckyVisible {
                        luckyGear
                            .position(x: luckyNorm.x * geo.size.width,
                                      y: luckyNorm.y * geo.size.height)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)

            if flashOpacity > 0 {
                Color.white.opacity(flashOpacity).ignoresSafeArea().allowsHitTesting(false)
            }
        }
        .focusable(true)
        .focused($crownFocused)
        .digitalCrownRotation(
            $crownValue,
            from: -1_000_000, through: 1_000_000, by: 0.05,
            sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: false
        )
        .onChange(of: crownValue) { _, newValue in
            let delta = newValue - lastCrown
            lastCrown = newValue
            spinVelocity = 0
            applyRotation(delta * degPerCrownUnit)
        }
        .onReceive(frameTimer) { _ in step() }
        .onAppear {
            acquireCrownFocus()
            scheduleFirstLucky()
        }
        .onChange(of: scenePhase) { _, phase in
            isActive = (phase == .active)
            if isActive {
                acquireCrownFocus()
                // Coming back from a long absence shouldn't fire a Lucky Gear
                // the instant the screen lights up — the player would never
                // see it before the 6s despawn.
                if nextLuckyAt <= Date() {
                    nextLuckyAt = Date().addingTimeInterval(Double.random(in: 20...45))
                }
            } else {
                // Don't let the flywheel coast (and score) behind a dark screen.
                spinVelocity = 0
                dragVelocity = 0
            }
        }
        .onChange(of: showShop) { _, isShowing in
            if !isShowing { acquireCrownFocus() }
        }
        .sheet(isPresented: $showShop) { NavigationStack { ShopView() } }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if game.goldenGears > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "gearshape.fill").font(.system(size: 11, weight: .bold))
                        Text("\(game.goldenGears)").font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Theme.gold)
                }
            }
        }
    }

    // MARK: Header --------------------------------------------------------------

    private var scoreHeader: some View {
        VStack(spacing: 3) {
            Text(game.points.abbreviated())
                .font(.system(size: 33, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [Theme.brassLight, Theme.brass],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: Theme.amberGlow.opacity(0.5), radius: 4)
                .minimumScaleFactor(0.5).lineLimit(1)

            HStack(spacing: 5) {
                statChip("bolt.fill", "\(game.pointsPerSecond.abbreviatedRate())/s", Theme.amber)
                if game.frenzyActive {
                    frenzyChip
                } else {
                    statChip("hand.tap.fill", "+\(game.pointsPerTooth.abbreviated())", Theme.brass)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Points")
        .accessibilityValue(
            "\(game.points.abbreviated()), earning \(game.pointsPerSecond.abbreviatedRate()) per second"
            + (game.frenzyActive
               ? ", frenzy times \(Int(game.frenzyFactor)) for \(Int(ceil(game.frenzyRemaining))) seconds"
               : ", \(game.pointsPerTooth.abbreviated()) per tooth")
        )
    }

    private func statChip(_ icon: String, _ text: String, _ tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold))
            Text(text).font(.system(size: 11, weight: .bold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(Theme.bgTop.opacity(0.6)))
    }

    private var frenzyChip: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            HStack(spacing: 3) {
                Image(systemName: "flame.fill").font(.system(size: 9, weight: .bold))
                Text("×\(Int(game.frenzyFactor)) · \(Int(ceil(game.frenzyRemaining)))s")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(Theme.bgBottom)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(Theme.amber))
        }
    }

    // MARK: Gear + combo ring ---------------------------------------------------

    private var gearArea: some View {
        GeometryReader { geo in
            let outer = min(geo.size.width, geo.size.height)
            let gear = outer - 14
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                comboRing(diameter: outer)
                GearView(angle: gearAngle, tickCount: tickCount,
                         golden: game.goldenGears > 0, intensity: heat)
                    .frame(width: gear, height: gear)

                ForEach(floaters) { f in
                    FloatingScoreLabel(floater: f) { id in
                        floaters.removeAll { $0.id == id }
                    }
                    .offset(y: -6)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: .top) { comboTag }
            .overlay(alignment: .bottom) {
                if firstHint {
                    Text("spin me ↻")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.inkDim)
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .gesture(spinGesture(center: center))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Gear")
            .accessibilityHint("Swipe up or down to turn the gear one tooth and earn points")
            .accessibilityValue("Combo multiplier \(String(format: "%.1f", comboMultiplier))")
            // VoiceOver claims the Digital Crown for navigation, which would
            // otherwise leave the gear — the whole game — unspinnable. Adjustable
            // actions give it back as a swipe per tooth.
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: applyRotation(degPerTooth)
                case .decrement: applyRotation(-degPerTooth)
                @unknown default: break
                }
            }
        }
    }

    private func comboRing(diameter: CGFloat) -> some View {
        ZStack {
            Circle().stroke(Theme.brassShadow.opacity(0.35), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0.001, comboEnergy))
                .stroke(hotColor(comboEnergy),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: hotColor(comboEnergy).opacity(0.7 * comboEnergy), radius: 4)
        }
        .frame(width: diameter, height: diameter)
    }

    private var comboTag: some View {
        Text("×\(String(format: "%.1f", comboMultiplier))")
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(hotColor(comboEnergy))
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(Capsule().fill(.black.opacity(0.5)))
            .scaleEffect(1 + comboEnergy * 0.15)
            .opacity(comboEnergy > 0.12 ? 1 : 0)
            .offset(y: -3)
    }

    private func spinGesture(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                let now = Date()
                let dx = value.location.x - center.x
                let dy = value.location.y - center.y
                let ang = atan2(dy, dx) * 180 / .pi
                if let prev = lastDragAngle {
                    var d = ang - prev
                    if d > 180 { d -= 360 } else if d < -180 { d += 360 }
                    applyRotation(d)
                    let dt = now.timeIntervalSince(lastDragTime)
                    if dt > 0.001 { dragVelocity = 0.6 * dragVelocity + 0.4 * (d / dt) }
                }
                lastDragAngle = ang
                lastDragTime = now
            }
            .onEnded { _ in
                isDragging = false
                lastDragAngle = nil
                spinVelocity = max(-velCap, min(velCap, dragVelocity))
                dragVelocity = 0
            }
    }

    // MARK: Upgrades button -----------------------------------------------------

    private var upgradesButton: some View {
        HStack(spacing: 6) {
            Image(systemName: "wrench.and.screwdriver.fill").font(.system(size: 12))
            Text("Upgrades").font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Capsule().fill(LinearGradient(colors: [Theme.brassDeep, Theme.copperDeep],
                                                  startPoint: .top, endPoint: .bottom)))
        .overlay(Capsule().stroke(Theme.brass.opacity(0.6), lineWidth: 1))
        .contentShape(Capsule())
        .onTapGesture {
            Haptics.purchase()
            showShop = true
        }
        // Deliberately not a Button: a second focusable view steals the Digital
        // Crown from the gear. The trait restores what VoiceOver would lose.
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Upgrades")
        .accessibilityHint("Opens the Workshop")
        .accessibilityAction { Haptics.purchase(); showShop = true }
    }

    // MARK: Per-frame step ------------------------------------------------------

    private func step() {
        guard isActive else { return }
        if comboEnergy > 0 {
            comboEnergy = max(0, comboEnergy - comboDecayPerStep)
        }
        if !isDragging {
            if abs(spinVelocity) > minSpinVel {
                applyRotation(spinVelocity * stepDt)
                spinVelocity *= momentumFriction
            } else if spinVelocity != 0 {
                spinVelocity = 0
            }
        }
        updateLucky()
    }

    // MARK: Rotation → scoring --------------------------------------------------

    private func applyRotation(_ deltaDeg: Double) {
        guard deltaDeg != 0 else { return }
        if firstHint { withAnimation(.easeOut(duration: 0.4)) { firstHint = false } }

        let before = floor(gearAngle / degPerTooth)
        gearAngle += deltaDeg
        let after = floor(gearAngle / degPerTooth)
        let crossed = Int(after - before)

        // Keep the accumulator bounded over a long session. A full turn is a
        // whole number of teeth (360° / 12), so wrapping is invisible both to
        // tooth counting above and to the rendered rotation.
        if gearAngle > 3600 || gearAngle < -3600 {
            gearAngle -= (gearAngle / 360).rounded(.towardZero) * 360
        }

        guard crossed != 0 else { return }

        let n = min(abs(crossed), 80)
        comboEnergy = min(1, comboEnergy + comboGainPerTooth * Double(n))

        let crit = Double.random(in: 0..<1) < critChance
        var gain = game.pointsPerTooth * comboMultiplier * Double(n)
        if crit { gain *= critMultiplier }
        game.award(gain, teeth: n)
        tickCount &+= n

        let now = Date()
        if crit {
            Haptics.crit()
            spawnFloater(text: "✦ +\(gain.abbreviated())", crit: true)
            lastFloaterAt = now
        } else {
            Haptics.tick()
            if now.timeIntervalSince(lastFloaterAt) > 0.07 {
                spawnFloater(text: "+\(gain.abbreviated())", crit: false)
                lastFloaterAt = now
            }
        }
    }

    private func spawnFloater(text: String, crit: Bool) {
        floaters.append(Floater(text: text, xJitter: CGFloat.random(in: -16...16), isCrit: crit))
        if floaters.count > 14 { floaters.removeFirst(floaters.count - 14) }
    }

    private func acquireCrownFocus() {
        crownFocused = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { crownFocused = true }
    }

    // MARK: Lucky Gear ----------------------------------------------------------

    private var luckyGear: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [Theme.gold.opacity(0.6), .clear],
                                         center: .center, startRadius: 2, endRadius: 30))
                .frame(width: 60, height: 60)
            Image(systemName: "gearshape.fill")
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(Theme.goldMetal)
                .shadow(color: Theme.gold, radius: 6)
                .symbolEffect(.pulse, options: .repeating)
        }
        .frame(width: 52, height: 52)
        .contentShape(Circle())
        .onTapGesture { catchLucky() }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Lucky Gear")
        .accessibilityHint("Tap for a 10 second times 5 frenzy")
        .accessibilityAction { catchLucky() }
    }

    private func scheduleFirstLucky() {
        if nextLuckyAt == .distantFuture {
            nextLuckyAt = Date().addingTimeInterval(Double.random(in: 35...70))
        }
    }

    private func updateLucky() {
        let now = Date()
        if luckyVisible {
            if now >= luckyDespawnAt {
                withAnimation(.easeOut(duration: 0.3)) { luckyVisible = false }
                nextLuckyAt = now.addingTimeInterval(Double.random(in: 70...130))
            }
        } else if now >= nextLuckyAt {
            luckyNorm = CGPoint(x: CGFloat.random(in: 0.2...0.8),
                                y: CGFloat.random(in: 0.34...0.64))
            luckyDespawnAt = now.addingTimeInterval(6)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { luckyVisible = true }
        }
    }

    private func catchLucky() {
        Haptics.frenzy()
        game.startFrenzy(multiplier: 5, duration: 10)
        withAnimation(.easeOut(duration: 0.25)) { luckyVisible = false }
        nextLuckyAt = Date().addingTimeInterval(Double.random(in: 90...150))
        spawnFloater(text: "FRENZY ×5!", crit: true)
        flashOpacity = 0.45
        withAnimation(.easeOut(duration: 0.55)) { flashOpacity = 0 }
    }
}
