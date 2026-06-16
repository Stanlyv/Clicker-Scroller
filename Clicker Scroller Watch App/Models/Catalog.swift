//
//  Catalog.swift
//  Clicker Scroller Watch App
//
//  Static definitions of everything the player can buy. Two families:
//   • ClickBoost  — increases points earned each time a tooth passes the pawl.
//   • Generator   — automatons that produce points per second on their own.
//
//  Costs follow the well-loved Cookie-Clicker curve (cost × 1.15 per copy),
//  which keeps purchases feeling "evenly easy and hard" the whole way up.
//

import SwiftUI

/// A repeatable upgrade that adds to the points earned per tooth (per "click").
struct ClickBoost: Identifiable {
    let id: Int
    let name: String
    let blurb: String
    let icon: String
    let baseCost: Double
    /// Points-per-tooth added by each copy owned.
    let perToothBonus: Double
    /// Cost growth per copy owned.
    let growth: Double

    func cost(owned: Int) -> Double {
        (baseCost * pow(growth, Double(owned))).rounded()
    }
}

/// An automaton that yields a steady stream of points per second.
struct Generator: Identifiable {
    let id: Int
    let name: String
    let blurb: String
    let icon: String
    let baseCost: Double
    /// Points per second produced by each copy.
    let baseOutput: Double
    let tint: Color

    func cost(owned: Int) -> Double {
        (baseCost * pow(1.15, Double(owned))).rounded()
    }
}

enum Catalog {
    /// Hand-tuned so every purchase costs ~10–14× the previous tier's first copy,
    /// while producing ~6–8× the points — the classic incremental ramp.
    static let generators: [Generator] = [
        Generator(id: 0, name: "Wind-up Key", blurb: "A patient little spring.", icon: "key.fill",
                  baseCost: 15, baseOutput: 0.1, tint: Theme.brass),
        Generator(id: 1, name: "Pendulum", blurb: "Tick. Tock. Tick.", icon: "metronome.fill",
                  baseCost: 110, baseOutput: 1, tint: Theme.copper),
        Generator(id: 2, name: "Steam Piston", blurb: "Hisses with purpose.", icon: "flame.fill",
                  baseCost: 1_200, baseOutput: 8, tint: Theme.amber),
        Generator(id: 3, name: "Clockwork Heart", blurb: "Beats in brass time.", icon: "heart.fill",
                  baseCost: 13_000, baseOutput: 47, tint: Theme.copperDeep),
        Generator(id: 4, name: "Brass Automaton", blurb: "Cranks the gears for you.", icon: "figure.walk",
                  baseCost: 140_000, baseOutput: 260, tint: Theme.brassDeep),
        Generator(id: 5, name: "Gear Foundry", blurb: "Pours molten cogs all day.", icon: "building.2.fill",
                  baseCost: 1_600_000, baseOutput: 1_400, tint: Theme.amberGlow),
        Generator(id: 6, name: "Chrono Engine", blurb: "Bends a minute into more.", icon: "clock.fill",
                  baseCost: 20_000_000, baseOutput: 7_800, tint: Theme.gold),
        Generator(id: 7, name: "Orrery of Cogs", blurb: "A galaxy of turning teeth.", icon: "globe.europe.africa.fill",
                  baseCost: 330_000_000, baseOutput: 44_000, tint: Theme.brassLight),
    ]

    static let clickBoosts: [ClickBoost] = [
        ClickBoost(id: 0, name: "Oiled Bearings", blurb: "Smoother catch on the pawl.",
                   icon: "drop.fill", baseCost: 50, perToothBonus: 1, growth: 1.16),
        ClickBoost(id: 1, name: "Tungsten Teeth", blurb: "Bite deeper into each turn.",
                   icon: "gearshape.2.fill", baseCost: 1_400, perToothBonus: 8, growth: 1.18),
        ClickBoost(id: 2, name: "Diamond Pawl", blurb: "Never slips, never dulls.",
                   icon: "diamond.fill", baseCost: 33_000, perToothBonus: 55, growth: 1.20),
        ClickBoost(id: 3, name: "Resonant Flywheel", blurb: "Each click rings the next.",
                   icon: "rays", baseCost: 850_000, perToothBonus: 380, growth: 1.22),
    ]

    /// Prestige tuning: golden gears earned ≈ sqrt(totalEarned / 1e6),
    /// and each one grants +2% to ALL production.
    static let prestigeDivisor: Double = 1_000_000
    static let prestigeBonusPerGear: Double = 0.02
}
