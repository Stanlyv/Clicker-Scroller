//
//  Catalog.swift
//  Clicker Scroller Watch App
//
//  Everything the player can buy. Four families:
//   • Generator  — automatons that produce points/second on their own. Each
//                  also gets free "milestone" output doublings as you stock up.
//   • ClickBoost — repeatable, adds to the points earned per tooth (per spin).
//   • Overdrive  — one-time purchases that multiply ALL production.
//   • Prestige   — Golden Gears, a permanent +% to everything.
//
//  Generator costs follow the long-proven Cookie-Clicker curve (×1.15 per copy
//  with a ~10–15× jump and ~6× output per tier), which keeps the climb feeling
//  "evenly easy and hard" from the first key to the last cosmic clock.
//

import SwiftUI

// MARK: - Generators ----------------------------------------------------------

struct Generator: Identifiable {
    let id: Int
    let name: String
    let blurb: String
    let icon: String
    let baseCost: Double
    /// Points per second produced by ONE copy, before milestones / multipliers.
    let baseOutput: Double
    let tint: Color

    func cost(owned: Int) -> Double { (baseCost * pow(1.15, Double(owned))).rounded() }
}

// MARK: - Click boosts --------------------------------------------------------

struct ClickBoost: Identifiable {
    let id: Int
    let name: String
    let blurb: String
    let icon: String
    let baseCost: Double
    /// Points-per-tooth added by each copy owned.
    let perToothBonus: Double
    let growth: Double

    func cost(owned: Int) -> Double { (baseCost * pow(growth, Double(owned))).rounded() }
}

// MARK: - Overdrives (one-time global multipliers) ----------------------------

struct Overdrive: Identifiable {
    let id: Int
    let name: String
    let blurb: String
    let icon: String
    let cost: Double
    /// Multiplies ALL production (idle + clicks) while owned.
    let factor: Double
    let tint: Color
}

enum Catalog {

    static let generators: [Generator] = [
        Generator(id: 0,  name: "Wind-up Key",       blurb: "A patient little spring.",   icon: "key.fill",
                  baseCost: 160,                  baseOutput: 0.05,       tint: Theme.brass),
        Generator(id: 1,  name: "Pendulum",          blurb: "Tick. Tock. Tick.",          icon: "metronome.fill",
                  baseCost: 1_800,                baseOutput: 0.5,        tint: Theme.copper),
        Generator(id: 2,  name: "Steam Piston",      blurb: "Hisses with purpose.",       icon: "flame.fill",
                  baseCost: 20_000,               baseOutput: 4,          tint: Theme.amber),
        Generator(id: 3,  name: "Clockwork Heart",   blurb: "Beats in brass time.",       icon: "heart.fill",
                  baseCost: 240_000,              baseOutput: 25,         tint: Theme.copperDeep),
        Generator(id: 4,  name: "Brass Automaton",   blurb: "Cranks the gears for you.",  icon: "figure.walk",
                  baseCost: 2_600_000,            baseOutput: 150,        tint: Theme.brassDeep),
        Generator(id: 5,  name: "Gear Foundry",      blurb: "Pours molten cogs all day.", icon: "building.2.fill",
                  baseCost: 30_000_000,           baseOutput: 900,        tint: Theme.amberGlow),
        Generator(id: 6,  name: "Chrono Engine",     blurb: "Bends a minute into more.",  icon: "clock.fill",
                  baseCost: 400_000_000,          baseOutput: 5_500,      tint: Theme.gold),
        Generator(id: 7,  name: "Orrery of Cogs",    blurb: "A galaxy of turning teeth.", icon: "globe.europe.africa.fill",
                  baseCost: 6_000_000_000,        baseOutput: 36_000,     tint: Theme.brassLight),
        Generator(id: 8,  name: "Aether Turbine",    blurb: "Spins on thin air itself.",  icon: "tornado",
                  baseCost: 90_000_000_000,       baseOutput: 230_000,    tint: Theme.copper),
        Generator(id: 9,  name: "Quantum Escapement",blurb: "Ticks in every timeline.",   icon: "atom",
                  baseCost: 1_400_000_000_000,    baseOutput: 1_500_000,  tint: Theme.amber),
        Generator(id: 10, name: "Cosmic Clockwork",  blurb: "Winds the universe.",        icon: "sparkles",
                  baseCost: 20_000_000_000_000,   baseOutput: 10_000_000, tint: Theme.gold),
    ]

    static let clickBoosts: [ClickBoost] = [
        ClickBoost(id: 0, name: "Oiled Bearings",    blurb: "Smoother catch on the pawl.", icon: "drop.fill",
                   baseCost: 100,         perToothBonus: 0.1,    growth: 1.15),
        ClickBoost(id: 1, name: "Tungsten Teeth",    blurb: "Bite deeper into each turn.", icon: "gearshape.2.fill",
                   baseCost: 1_400,       perToothBonus: 0.5,    growth: 1.16),
        ClickBoost(id: 2, name: "Diamond Pawl",      blurb: "Never slips, never dulls.",   icon: "diamond.fill",
                   baseCost: 30_000,      perToothBonus: 3,      growth: 1.17),
        ClickBoost(id: 3, name: "Resonant Flywheel", blurb: "Each click rings the next.",  icon: "rays",
                   baseCost: 800_000,     perToothBonus: 20,     growth: 1.18),
        ClickBoost(id: 4, name: "Mythril Escapement",blurb: "Featherlight, iron-strong.",  icon: "bolt.fill",
                   baseCost: 20_000_000,  perToothBonus: 130,    growth: 1.19),
        ClickBoost(id: 5, name: "Singularity Cog",   blurb: "Folds points out of nothing.",icon: "sparkle",
                   baseCost: 600_000_000, perToothBonus: 900,    growth: 1.20),
    ]

    static let overdrives: [Overdrive] = [
        Overdrive(id: 0, name: "Polished Mainspring", blurb: "×2 to everything.", icon: "bolt.circle.fill",
                  cost: 50_000,                 factor: 2, tint: Theme.brass),
        Overdrive(id: 1, name: "Reinforced Frame",    blurb: "×2 to everything.", icon: "shield.fill",
                  cost: 2_400_000,              factor: 2, tint: Theme.copper),
        Overdrive(id: 2, name: "Synchronized Gears",  blurb: "×2 to everything.", icon: "circle.hexagongrid.fill",
                  cost: 120_000_000,            factor: 2, tint: Theme.amber),
        Overdrive(id: 3, name: "Overclocked Core",    blurb: "×3 to everything.", icon: "gauge.high",
                  cost: 6_000_000_000,          factor: 3, tint: Theme.copperDeep),
        Overdrive(id: 4, name: "Harmonic Resonator",  blurb: "×3 to everything.", icon: "waveform",
                  cost: 300_000_000_000,        factor: 3, tint: Theme.amberGlow),
        Overdrive(id: 5, name: "Temporal Lubricant",  blurb: "×4 to everything.", icon: "hourglass",
                  cost: 12_000_000_000_000,     factor: 4, tint: Theme.gold),
        Overdrive(id: 6, name: "Aetheric Infusion",   blurb: "×4 to everything.", icon: "sparkles",
                  cost: 600_000_000_000_000,    factor: 4, tint: Theme.brassLight),
        Overdrive(id: 7, name: "Cosmic Alignment",    blurb: "×5 to everything.", icon: "star.circle.fill",
                  cost: 24_000_000_000_000_000, factor: 5, tint: Theme.gold),
    ]

    // MARK: Generator milestones (free output doublings as you stock up) ------

    /// Owning this many copies of a generator doubles its output, cumulatively.
    static let genMilestones = [25, 50, 100, 150, 200, 250, 300]

    static func milestoneMultiplier(owned: Int) -> Double {
        var m = 1.0
        for t in genMilestones where owned >= t { m *= 2 }
        return m
    }

    /// The next milestone count not yet reached (nil once all are unlocked).
    static func nextMilestone(owned: Int) -> Int? {
        genMilestones.first { owned < $0 }
    }

    // MARK: Prestige ----------------------------------------------------------

    static let prestigeDivisor: Double = 1_000_000
    static let prestigeBonusPerGear: Double = 0.02
}
