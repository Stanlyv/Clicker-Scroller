//
//  GearView.swift
//  Clicker Scroller Watch App
//
//  The hero of the game: a metallic brass cogwheel whose teeth sweep past a
//  side-mounted pawl. Every catch flicks the pawl and throws a spark.
//

import SwiftUI

struct GearView: View {
    /// Current rotation of the gear, in degrees (can be huge — that's fine).
    var angle: Double
    /// Increments by one for every tooth caught; drives the pawl flick + spark.
    var tickCount: Int
    /// Use the prestige (gold) look once the player has ascended.
    var golden: Bool = false
    /// 0…1 "heat" from the live combo — makes the halo bigger, brighter, hotter.
    var intensity: Double = 0

    private let teeth = 12

    @State private var pawlFlick: Double = 0
    @State private var sparkOpacity: Double = 0
    @State private var sparkScale: CGFloat = 0.5
    @State private var pulse: CGFloat = 1
    @State private var tickScale: CGFloat = 1

    private var metal: AngularGradient { golden ? Theme.goldMetal : Theme.brassMetal }

    /// Amber when calm, shifting to hot orange/red as the combo builds.
    private var glowColor: Color {
        let t = min(1, max(0, intensity))
        return Color(red: 1.0, green: 0.66 - 0.34 * t, blue: 0.22 - 0.14 * t)
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let r = size / 2

            ZStack {
                // — Soft ambient glow behind the gear (grows hotter with combo) —
                Circle()
                    .fill(
                        RadialGradient(colors: [glowColor.opacity(0.5 + 0.45 * intensity), .clear],
                                       center: .center, startRadius: r * 0.2, endRadius: r * 1.15)
                    )
                    .frame(width: size * (1.45 + 0.4 * intensity),
                           height: size * (1.45 + 0.4 * intensity))
                    .scaleEffect(pulse)
                    .blur(radius: 6)

                // — The rotating gear body (bounces a touch on each catch) —
                gearBody(size: size)
                    .scaleEffect(tickScale)
                    .rotationEffect(.degrees(angle))
                    .shadow(color: .black.opacity(0.5), radius: 5, y: 3)

                // — Static center cap (the bolt you "turn") —
                centerCap(r: r)

                // — Pawl on the right edge + spark on contact —
                pawl(r: r)
                    .position(x: center.x + r * 0.99, y: center.y - r * 0.34)

                spark(r: r)
                    .position(x: center.x + r * 0.80, y: center.y - r * 0.05)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onChange(of: tickCount) { _, _ in flick() }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                pulse = 1.08
            }
        }
    }

    // MARK: Pieces --------------------------------------------------------------

    private func gearBody(size: CGFloat) -> some View {
        let r = size / 2
        return ZStack {
            // teeth + rim
            GearShape(teeth: teeth, toothDepth: 0.17)
                .fill(metal)
                .overlay(
                    GearShape(teeth: teeth, toothDepth: 0.17)
                        .stroke(Theme.brassShadow.opacity(0.9), lineWidth: 1.2)
                )
                .overlay(
                    // domed sheen
                    Circle()
                        .fill(
                            RadialGradient(colors: [.white.opacity(0.30), .clear],
                                           center: .init(x: 0.34, y: 0.30),
                                           startRadius: 1, endRadius: r * 0.9)
                        )
                        .padding(r * 0.16)
                )

            // inner machined ring
            Circle()
                .stroke(Theme.brassShadow, lineWidth: max(1.5, r * 0.04))
                .padding(r * 0.20)
            Circle()
                .stroke(Theme.brassLight.opacity(0.5), lineWidth: 1)
                .padding(r * 0.26)

            // bolt holes (spin with the gear)
            GearHub(bolts: 5)
                .fill(Theme.bgBottom.opacity(0.85))
                .overlay(GearHub(bolts: 5).stroke(Theme.brassShadow, lineWidth: 1))
                .padding(r * 0.04)
        }
        .frame(width: size, height: size)
    }

    private func centerCap(r: CGFloat) -> some View {
        ZStack {
            Circle().fill(metal).frame(width: r * 0.5, height: r * 0.5)
            Circle().stroke(Theme.brassShadow, lineWidth: 2).frame(width: r * 0.5, height: r * 0.5)
            Circle()
                .fill(RadialGradient(colors: [Theme.brassLight, Theme.brassDeep],
                                     center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: r * 0.28))
                .frame(width: r * 0.32, height: r * 0.32)
            Image(systemName: "gearshape.fill")
                .font(.system(size: r * 0.20, weight: .black))
                .foregroundStyle(Theme.bgBottom.opacity(0.7))
        }
        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
    }

    private func pawl(r: CGFloat) -> some View {
        // Pivot pin at top; stick hangs toward the teeth. Rests at a slight lean
        // and kicks outward (positive) on each catch.
        VStack(spacing: -2) {
            Circle()
                .fill(Theme.copper)
                .overlay(Circle().stroke(Theme.brassShadow, lineWidth: 1))
                .frame(width: r * 0.16, height: r * 0.16)
            Capsule()
                .fill(LinearGradient(colors: [Theme.brassLight, Theme.brass, Theme.brassDeep],
                                     startPoint: .leading, endPoint: .trailing))
                .overlay(Capsule().stroke(Theme.brassShadow.opacity(0.7), lineWidth: 0.8))
                .frame(width: r * 0.085, height: r * 0.42)
            // claw tip that catches the tooth
            Image(systemName: "triangle.fill")
                .font(.system(size: r * 0.14, weight: .black))
                .foregroundStyle(Theme.copperDeep)
                .rotationEffect(.degrees(210))
                .offset(y: -r * 0.04)
        }
        .rotationEffect(.degrees(-22 + pawlFlick), anchor: .top)   // -22° = resting lean toward gear
        .shadow(color: .black.opacity(0.45), radius: 2, x: -1, y: 1)
    }

    private func spark(r: CGFloat) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: r * 0.34, weight: .black))
            .foregroundStyle(Theme.spark)
            .shadow(color: glowColor, radius: 6)
            .scaleEffect(sparkScale)
            .opacity(sparkOpacity)
    }

    // MARK: Animation -----------------------------------------------------------

    private func flick() {
        // Snap the pawl out instantly, then spring it back — a satisfying ratchet.
        pawlFlick = 13
        withAnimation(.spring(response: 0.17, dampingFraction: 0.42)) {
            pawlFlick = 0
        }
        // Gear gives a tiny squash-and-stretch kick.
        tickScale = 1.05
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            tickScale = 1
        }
        // Spark pop.
        sparkOpacity = 1
        sparkScale = 0.5
        withAnimation(.easeOut(duration: 0.28)) {
            sparkOpacity = 0
            sparkScale = 1.25
        }
    }
}
