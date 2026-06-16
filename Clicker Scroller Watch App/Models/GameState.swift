//
//  GameState.swift
//  Clicker Scroller Watch App
//
//  The single source of truth for the game: currency, owned upgrades,
//  idle production, persistence, offline earnings and prestige.
//

import SwiftUI
import Combine

@MainActor
final class GameState: ObservableObject {

    // MARK: Currency
    @Published var points: Double = 0
    @Published private(set) var totalEarned: Double = 0
    @Published private(set) var totalTeeth: Int = 0

    // MARK: Ownership (indices align with Catalog arrays)
    @Published private(set) var generatorCounts: [Int]
    @Published private(set) var boostCounts: [Int]

    // MARK: Prestige
    @Published private(set) var goldenGears: Int = 0

    /// Transient: points granted while the app was suspended. Drives the
    /// "welcome back" banner; cleared once shown.
    @Published var offlineEarnings: Double = 0

    // MARK: Derived production --------------------------------------------------

    /// Multiplier applied to ALL production from prestige (golden gears).
    var prestigeMultiplier: Double {
        1.0 + Double(goldenGears) * Catalog.prestigeBonusPerGear
    }

    /// Points earned every time a tooth passes the pawl.
    var pointsPerTooth: Double {
        var base = 1.0
        for boost in Catalog.clickBoosts {
            base += Double(boostCounts[boost.id]) * boost.perToothBonus
        }
        return base * prestigeMultiplier
    }

    /// Idle income from all automatons, points per second.
    var pointsPerSecond: Double {
        var total = 0.0
        for gen in Catalog.generators {
            total += Double(generatorCounts[gen.id]) * gen.baseOutput
        }
        return total * prestigeMultiplier
    }

    /// Golden gears the player would receive by prestiging right now.
    var pendingGoldenGears: Int {
        let earned = Int((totalEarned / Catalog.prestigeDivisor).squareRoot())
        return max(0, earned - goldenGears)
    }

    var canPrestige: Bool { pendingGoldenGears > 0 }

    // MARK: Init ----------------------------------------------------------------

    private var idleTimer: AnyCancellable?
    private var saveAccumulator: TimeInterval = 0
    private let saveKey = "gearclicker.save.v1"

    init() {
        generatorCounts = Array(repeating: 0, count: Catalog.generators.count)
        boostCounts = Array(repeating: 0, count: Catalog.clickBoosts.count)
        load()
        startIdleLoop()
    }

    // MARK: Gameplay actions ----------------------------------------------------

    /// Called once for every gear tooth that sweeps past the pawl.
    func registerTooth() {
        let gain = pointsPerTooth
        points += gain
        totalEarned += gain
        totalTeeth += 1
    }

    func canAfford(_ amount: Double) -> Bool { points >= amount }

    func costForGenerator(_ gen: Generator) -> Double {
        gen.cost(owned: generatorCounts[gen.id])
    }

    func costForBoost(_ boost: ClickBoost) -> Double {
        boost.cost(owned: boostCounts[boost.id])
    }

    @discardableResult
    func buyGenerator(_ gen: Generator) -> Bool {
        let cost = costForGenerator(gen)
        guard points >= cost else { return false }
        points -= cost
        generatorCounts[gen.id] += 1
        save()
        return true
    }

    @discardableResult
    func buyBoost(_ boost: ClickBoost) -> Bool {
        let cost = costForBoost(boost)
        guard points >= cost else { return false }
        points -= cost
        boostCounts[boost.id] += 1
        save()
        return true
    }

    func prestige() {
        guard canPrestige else { return }
        goldenGears += pendingGoldenGears
        points = 0
        generatorCounts = Array(repeating: 0, count: Catalog.generators.count)
        boostCounts = Array(repeating: 0, count: Catalog.clickBoosts.count)
        // totalEarned is kept so the prestige curve keeps climbing.
        save()
    }

    // MARK: Idle production -----------------------------------------------------

    private func startIdleLoop() {
        // 10 Hz keeps the per-second counter buttery without burning battery.
        idleTimer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.advance(by: 0.1) }
    }

    private func advance(by dt: TimeInterval) {
        let gain = pointsPerSecond * dt
        if gain > 0 {
            points += gain
            totalEarned += gain
        }
        saveAccumulator += dt
        if saveAccumulator >= 5 {       // periodic autosave
            saveAccumulator = 0
            save()
        }
    }

    // MARK: Persistence ---------------------------------------------------------

    private struct Snapshot: Codable {
        var points: Double
        var totalEarned: Double
        var totalTeeth: Int
        var generatorCounts: [Int]
        var boostCounts: [Int]
        var goldenGears: Int
        var savedAt: TimeInterval
    }

    func save() {
        let snap = Snapshot(
            points: points,
            totalEarned: totalEarned,
            totalTeeth: totalTeeth,
            generatorCounts: generatorCounts,
            boostCounts: boostCounts,
            goldenGears: goldenGears,
            savedAt: Date().timeIntervalSince1970
        )
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: saveKey),
            let snap = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return }

        points = snap.points
        totalEarned = snap.totalEarned
        totalTeeth = snap.totalTeeth
        goldenGears = snap.goldenGears
        // Resize-safe copy in case the catalog grew between versions.
        for i in 0..<min(generatorCounts.count, snap.generatorCounts.count) {
            generatorCounts[i] = snap.generatorCounts[i]
        }
        for i in 0..<min(boostCounts.count, snap.boostCounts.count) {
            boostCounts[i] = snap.boostCounts[i]
        }

        creditOfflineEarnings(since: snap.savedAt)
    }

    /// Credit a capped amount of idle income earned while suspended.
    private func creditOfflineEarnings(since savedAt: TimeInterval) {
        let elapsed = Date().timeIntervalSince1970 - savedAt
        guard elapsed > 5 else { return }
        let capped = min(elapsed, 8 * 3600)          // cap at 8 hours
        let gain = pointsPerSecond * capped * 0.5    // offline runs at half rate
        guard gain > 1 else { return }
        points += gain
        totalEarned += gain
        offlineEarnings = gain
    }
}
