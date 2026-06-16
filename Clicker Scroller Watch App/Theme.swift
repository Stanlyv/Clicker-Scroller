//
//  Theme.swift
//  Clicker Scroller Watch App
//
//  Central palette + reusable visual styling for the steampunk "Gear Clicker".
//

import SwiftUI

/// Warm brass / amber steampunk palette — tuned for the cozy, easy-going
/// Cookie-Clicker vibe while reading great on the small OLED watch screen.
enum Theme {
    // Backgrounds
    static let bgTop = Color(red: 0.17, green: 0.13, blue: 0.10)
    static let bgMid = Color(red: 0.10, green: 0.08, blue: 0.08)
    static let bgBottom = Color(red: 0.03, green: 0.025, blue: 0.04)

    // Brass family
    static let brassLight = Color(red: 1.00, green: 0.88, blue: 0.58)
    static let brass = Color(red: 0.86, green: 0.64, blue: 0.29)
    static let brassDeep = Color(red: 0.55, green: 0.37, blue: 0.15)
    static let brassShadow = Color(red: 0.28, green: 0.18, blue: 0.08)

    // Copper accents
    static let copper = Color(red: 0.82, green: 0.46, blue: 0.27)
    static let copperDeep = Color(red: 0.45, green: 0.22, blue: 0.13)

    // Glow / highlight
    static let amber = Color(red: 1.00, green: 0.76, blue: 0.32)
    static let amberGlow = Color(red: 1.00, green: 0.66, blue: 0.20)
    static let spark = Color(red: 1.00, green: 0.95, blue: 0.80)

    // Text
    static let ink = Color(red: 0.97, green: 0.93, blue: 0.85)
    static let inkDim = Color(red: 0.74, green: 0.67, blue: 0.56)

    // Prestige
    static let gold = Color(red: 1.00, green: 0.83, blue: 0.35)
    static let goldDeep = Color(red: 0.70, green: 0.52, blue: 0.12)

    /// Full-screen background gradient used behind every screen.
    static var background: some View {
        ZStack {
            RadialGradient(
                colors: [bgTop, bgMid, bgBottom],
                center: .init(x: 0.5, y: 0.32),
                startRadius: 4,
                endRadius: 230
            )
            // subtle vignette so the gear pops
            RadialGradient(
                colors: [.clear, .black.opacity(0.55)],
                center: .center,
                startRadius: 70,
                endRadius: 200
            )
        }
        .ignoresSafeArea()
    }

    /// Brushed-metal angular gradient for gear bodies.
    static var brassMetal: AngularGradient {
        AngularGradient(
            colors: [
                brassDeep, brass, brassLight, brass,
                brassDeep, brassShadow, brassDeep, brass,
                brassLight, brass, brassDeep
            ],
            center: .center
        )
    }

    static var goldMetal: AngularGradient {
        AngularGradient(
            colors: [goldDeep, gold, brassLight, gold, goldDeep, goldDeep, gold, brassLight, goldDeep],
            center: .center
        )
    }
}
