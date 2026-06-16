//
//  GameView.swift
//  Clicker Scroller Watch App
//
//  The play screen. Two ways to spin the cog, both feeding the same scoring
//  pipeline (`applyRotation`):
//    • Digital Crown — bound at the root (NOT to a scroll view), so the screen
//      itself never scrolls.
//    • Drag-to-spin — flick the gear directly like a physical wheel. Handy on a
//      real wrist and essential in the Simulator, where the crown is awkward.
//
//  Focus note: the whole screen is the single focusable surface and the crown
//  is bound at the root. There are deliberately no other focusable controls
//  here (the Workshop opens as a sheet from a tap gesture, not a Button),
//  because a competing focusable element will silently steal the crown.
//

import SwiftUI
import WatchKit

struct GameView: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.scenePhase) private var scenePhase

    // — Crown → gear plumbing —
    @State private var crownValue: Double = 0
    @State private var lastCrown: Double = 0
    @State private var gearAngle: Double = 0          // accumulated degrees (signed)
    @State private var tickCount: Int = 0             // feeds the pawl flick / spark
    @FocusState private var crownFocused: Bool

    // — Drag-to-spin —
    @State private var lastDragAngle: Double? = nil

    // — Juice / nav —
    @State private var floaters: [Floater] = []
    @State private var showOfflineBanner = false
    @State private var showShop = false

    // Tuning. 12 teeth → 30° per tooth. `degPerCrownUnit` is the one knob that
    // sets how fast the gear spins relative to the crown — raise it to spin
    // faster (more points per flick), lower it for a slower grind. Paired with
    // `.medium` crown sensitivity below, this tracks the native list-scroll feel.
    private let teeth = 12
    private var degPerTooth: Double { 360.0 / Double(teeth) }
    private let degPerCrownUnit: Double = 12.0

    var body: some View {
        ZStack {
            Theme.background

            GeometryReader { geo in
                // One explicit gear size, computed from the height left after the
                // header and the pill. Spacers only centre it — they don't size it.
                let gearSide = max(74, min(min(geo.size.width - 14, geo.size.height - 102), 132))
                VStack(spacing: 0) {
                    scoreHeader

                    Spacer(minLength: 8)

                    gearArea
                        .frame(width: gearSide, height: gearSide)

                    Spacer(minLength: 8)

                    workshopPill
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            if showOfflineBanner {
                offlineBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // One focusable surface for the whole screen; the crown drives the gear.
        .focusable(true)
        .focused($crownFocused)
        .digitalCrownRotation(
            $crownValue,
            from: -1_000_000,
            through: 1_000_000,
            by: 0.05,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: false      // we play our own click per tooth
        )
        .onChange(of: crownValue) { _, newValue in
            handleCrown(newValue)
        }
        .onAppear {
            acquireCrownFocus()
            if game.offlineEarnings > 1 {
                showOfflineBanner = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation(.easeInOut) { showOfflineBanner = false }
                    game.offlineEarnings = 0
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { acquireCrownFocus() }
        }
        .onChange(of: showShop) { _, isShowing in
            if !isShowing { acquireCrownFocus() }   // reclaim crown after the shop
        }
        .sheet(isPresented: $showShop) {
            NavigationStack { ShopView() }
        }
        // Put our own content on the system clock's row (top-left), next to the
        // time — the time itself can't be hidden on watchOS.
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if game.goldenGears > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("\(game.goldenGears)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Theme.gold)
                }
            }
        }
    }

    // MARK: Gear ----------------------------------------------------------------

    private var gearArea: some View {
        // The parent gives this a fixed square frame, so the gear simply fills it.
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                GearView(angle: gearAngle, tickCount: tickCount,
                         golden: game.goldenGears > 0)
                    .frame(width: side, height: side)

                ForEach(floaters) { f in
                    FloatingScoreLabel(floater: f) { id in
                        floaters.removeAll { $0.id == id }
                    }
                    .offset(y: -8)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(spinGesture(center: center))
        }
    }

    private func spinGesture(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dx = value.location.x - center.x
                let dy = value.location.y - center.y
                let angle = atan2(dy, dx) * 180 / .pi
                if let prev = lastDragAngle {
                    var d = angle - prev
                    if d > 180 { d -= 360 } else if d < -180 { d += 360 }
                    applyRotation(d)
                }
                lastDragAngle = angle
            }
            .onEnded { _ in lastDragAngle = nil }
    }

    // MARK: Rotation → scoring (shared by crown + drag) -------------------------

    /// Focus must be (re)claimed after the hierarchy settles — doing it only
    /// synchronously is often too early and silently fails, so we set it now
    /// and again once the run loop has cycled.
    private func acquireCrownFocus() {
        crownFocused = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            crownFocused = true
        }
    }

    private func handleCrown(_ newValue: Double) {
        let delta = newValue - lastCrown
        lastCrown = newValue
        applyRotation(delta * degPerCrownUnit)
    }

    /// The single chokepoint: advance the gear by `deltaDeg` and award a point
    /// for every tooth that sweeps past the pawl (either direction).
    private func applyRotation(_ deltaDeg: Double) {
        guard deltaDeg != 0 else { return }

        let before = floor(gearAngle / degPerTooth)
        gearAngle += deltaDeg
        let after = floor(gearAngle / degPerTooth)

        let crossed = Int(after - before)
        guard crossed != 0 else { return }

        let n = min(abs(crossed), 100)          // safety clamp on huge jumps
        let perTooth = game.pointsPerTooth
        for _ in 0..<n { game.registerTooth() }
        tickCount &+= n

        WKInterfaceDevice.current().play(.click)
        spawnFloater(amount: perTooth * Double(n))
    }

    private func spawnFloater(amount: Double) {
        let f = Floater(text: "+\(amount.abbreviated())",
                        xJitter: CGFloat.random(in: -14...14))
        floaters.append(f)
        if floaters.count > 12 { floaters.removeFirst(floaters.count - 12) }
    }

    // MARK: Header --------------------------------------------------------------

    private var scoreHeader: some View {
        VStack(spacing: 1) {
            Text(game.points.abbreviated())
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [Theme.brassLight, Theme.brass],
                                   startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: Theme.amberGlow.opacity(0.5), radius: 4)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.15), value: game.points)

            HStack(spacing: 8) {
                Label("\(game.pointsPerSecond.abbreviatedRate())/s",
                      systemImage: "bolt.fill")
                Label("\(game.pointsPerTooth.abbreviated())", systemImage: "gearshape.2.fill")
            }
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.inkDim)
        }
    }

    // MARK: Workshop affordance (tap, NOT a focusable Button) --------------------

    private var workshopPill: some View {
        HStack(spacing: 5) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 11))
            Text("Workshop")
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(
                LinearGradient(colors: [Theme.brassDeep, Theme.copperDeep],
                               startPoint: .top, endPoint: .bottom)
            )
        )
        .overlay(Capsule().stroke(Theme.brass.opacity(0.6), lineWidth: 1))
        .contentShape(Capsule())
        .onTapGesture {
            WKInterfaceDevice.current().play(.click)
            showShop = true
        }
    }

    // MARK: Offline banner ------------------------------------------------------

    private var offlineBanner: some View {
        VStack {
            HStack(spacing: 6) {
                Image(systemName: "moon.zzz.fill")
                Text("While away: +\(game.offlineEarnings.abbreviated())")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Theme.bgBottom)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.amber))
            .padding(.top, 4)
            Spacer()
        }
    }
}
