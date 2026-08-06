//
//  GameState.swift
//  Clicker Scroller Watch App
//
//  The single source of truth for the game: currency, owned upgrades,
//  idle production, persistence, prestige and the temporary "frenzy" boost
//  from catching a Lucky Gear. Points accrue only while the app is open.
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
    @Published private(set) var overdriveOwned: [Bool]

    // MARK: Prestige
    @Published private(set) var goldenGears: Int = 0

    // MARK: Frenzy (temporary all-production multiplier from a Lucky Gear)
    @Published private(set) var frenzyEndsAt: Date? = nil
    @Published private(set) var frenzyFactor: Double = 1

    // MARK: Derived production --------------------------------------------------

    /// Multiplier applied to ALL production from prestige (golden gears).
    var prestigeMultiplier: Double {
        1.0 + Double(goldenGears) * Catalog.prestigeBonusPerGear
    }

    /// Product of every owned one-time Overdrive.
    var overdriveMultiplier: Double {
        var m = 1.0
        for od in Catalog.overdrives where overdriveOwned[od.id] { m *= od.factor }
        return m
    }

    var frenzyActive: Bool { (frenzyEndsAt ?? .distantPast) > Date() }
    var frenzyRemaining: TimeInterval { max(0, (frenzyEndsAt ?? .distantPast).timeIntervalSinceNow) }
    var activeMultiplier: Double { frenzyActive ? frenzyFactor : 1 }

    /// Permanent multipliers (prestige × overdrives) — used for shop read-outs.
    var steadyMultiplier: Double { prestigeMultiplier * overdriveMultiplier }
    /// Everything that scales production right now, including a live frenzy.
    var globalMultiplier: Double { steadyMultiplier * activeMultiplier }

    /// Sum of the starting per-tooth value plus each owned boost's flat bonus
    /// (before multipliers). Spinning starts gentle at 0.1 per tooth.
    private var clickBase: Double {
        var base = 0.1
        for boost in Catalog.clickBoosts {
            base += Double(boostCounts[boost.id]) * boost.perToothBonus
        }
        return base
    }

    /// Sum of every generator's milestone-boosted output (before multipliers).
    private var idleBase: Double {
        var total = 0.0
        for gen in Catalog.generators {
            let c = generatorCounts[gen.id]
            total += Double(c) * gen.baseOutput * Catalog.milestoneMultiplier(owned: c)
        }
        return total
    }

    /// Base points for one tooth — before the live combo multiplier, which the
    /// gameplay layer applies on top (it only rewards *active* spinning).
    var pointsPerTooth: Double { clickBase * globalMultiplier }

    /// Idle income from all automatons, points per second.
    var pointsPerSecond: Double { idleBase * globalMultiplier }

    /// Golden gears the player would receive by prestiging right now.
    var pendingGoldenGears: Int {
        let earned = Int((totalEarned / Catalog.prestigeDivisor).squareRoot())
        return max(0, earned - goldenGears)
    }

    var canPrestige: Bool { pendingGoldenGears > 0 }

    // MARK: Init ----------------------------------------------------------------

    private var idleTimer: AnyCancellable?
    private var saveAccumulator: TimeInterval = 0
    private var lastTickAt: Date = .now
    private let saveKey = "gearclicker.save.v1"

    init() {
        generatorCounts = Array(repeating: 0, count: Catalog.generators.count)
        boostCounts = Array(repeating: 0, count: Catalog.clickBoosts.count)
        overdriveOwned = Array(repeating: false, count: Catalog.overdrives.count)
        load()
        startIdleLoop()
    }

    // MARK: Gameplay actions ----------------------------------------------------

    /// Add freshly-earned points (from spinning). The gameplay layer has already
    /// folded in the combo / crit multipliers.
    func award(_ amount: Double, teeth: Int) {
        guard amount > 0 else { return }
        points += amount
        totalEarned += amount
        totalTeeth += teeth
    }

    func startFrenzy(multiplier: Double, duration: TimeInterval) {
        frenzyFactor = multiplier
        frenzyEndsAt = Date().addingTimeInterval(duration)
    }

    func canAfford(_ amount: Double) -> Bool { points >= amount }

    func costForGenerator(_ gen: Generator) -> Double {
        gen.cost(owned: generatorCounts[gen.id])
    }

    func costForBoost(_ boost: ClickBoost) -> Double {
        boost.cost(owned: boostCounts[boost.id])
    }

    /// Current points/second contributed by everything the player owns of `gen`
    /// (includes its milestone doublings and permanent multipliers).
    func outputForGenerator(_ gen: Generator) -> Double {
        let c = generatorCounts[gen.id]
        return Double(c) * gen.baseOutput * Catalog.milestoneMultiplier(owned: c) * steadyMultiplier
    }

    /// This generator's current milestone multiplier (×1, ×2, ×4 …).
    func milestoneFor(_ gen: Generator) -> Double {
        Catalog.milestoneMultiplier(owned: generatorCounts[gen.id])
    }

    func bonusForBoost(_ boost: ClickBoost) -> Double {
        Double(boostCounts[boost.id]) * boost.perToothBonus * steadyMultiplier
    }

    func isOverdriveOwned(_ od: Overdrive) -> Bool { overdriveOwned[od.id] }

    @discardableResult
    func buyOverdrive(_ od: Overdrive) -> Bool {
        guard !overdriveOwned[od.id], points >= od.cost else { return false }
        points -= od.cost
        overdriveOwned[od.id] = true
        save()
        return true
    }

    // — Bulk pricing (geometric series) —

    func bulkCostGenerator(_ gen: Generator, count: Int) -> Double {
        geometricCost(base: gen.baseCost, growth: 1.15, owned: generatorCounts[gen.id], count: count)
    }

    func bulkCostBoost(_ boost: ClickBoost, count: Int) -> Double {
        geometricCost(base: boost.baseCost, growth: boost.growth, owned: boostCounts[boost.id], count: count)
    }

    func maxAffordableGenerator(_ gen: Generator) -> Int {
        maxAffordable(base: gen.baseCost, growth: 1.15, owned: generatorCounts[gen.id])
    }

    func maxAffordableBoost(_ boost: ClickBoost) -> Int {
        maxAffordable(base: boost.baseCost, growth: boost.growth, owned: boostCounts[boost.id])
    }

    @discardableResult
    func buyGenerator(_ gen: Generator, count: Int = 1) -> Int {
        var bought = 0
        for _ in 0..<max(0, count) {
            let cost = costForGenerator(gen)
            guard points >= cost else { break }
            points -= cost
            generatorCounts[gen.id] += 1
            bought += 1
        }
        if bought > 0 { save() }
        return bought
    }

    @discardableResult
    func buyBoost(_ boost: ClickBoost, count: Int = 1) -> Int {
        var bought = 0
        for _ in 0..<max(0, count) {
            let cost = costForBoost(boost)
            guard points >= cost else { break }
            points -= cost
            boostCounts[boost.id] += 1
            bought += 1
        }
        if bought > 0 { save() }
        return bought
    }

    func prestige() {
        guard canPrestige else { return }
        goldenGears += pendingGoldenGears
        points = 0
        generatorCounts = Array(repeating: 0, count: Catalog.generators.count)
        boostCounts = Array(repeating: 0, count: Catalog.clickBoosts.count)
        overdriveOwned = Array(repeating: false, count: Catalog.overdrives.count)
        frenzyEndsAt = nil
        // totalEarned is kept so the prestige curve keeps climbing.
        save()
    }

    /// Reset the current run but KEEP earned Golden Gears and the lifetime
    /// total — a prestige that simply doesn't award any new gears yet.
    func resetKeepingPrestige() {
        points = 0
        generatorCounts = Array(repeating: 0, count: Catalog.generators.count)
        boostCounts = Array(repeating: 0, count: Catalog.clickBoosts.count)
        overdriveOwned = Array(repeating: false, count: Catalog.overdrives.count)
        frenzyEndsAt = nil
        save()
    }

    /// Lifetime points required before the next Golden Gear is awarded.
    var nextGearAt: Double {
        Double((goldenGears + 1) * (goldenGears + 1)) * Catalog.prestigeDivisor
    }

    /// Full wipe — everything (including golden gears and lifetime totals) goes
    /// back to the very first spin.
    func resetAll() {
        points = 0
        totalEarned = 0
        totalTeeth = 0
        generatorCounts = Array(repeating: 0, count: Catalog.generators.count)
        boostCounts = Array(repeating: 0, count: Catalog.clickBoosts.count)
        overdriveOwned = Array(repeating: false, count: Catalog.overdrives.count)
        goldenGears = 0
        frenzyEndsAt = nil
        save()
    }

    // MARK: Pricing helpers -----------------------------------------------------

    private func geometricCost(base: Double, growth g: Double, owned: Int, count: Int) -> Double {
        guard count > 0 else { return 0 }
        let a = base * pow(g, Double(owned))
        return (a * (pow(g, Double(count)) - 1) / (g - 1)).rounded()
    }

    private func maxAffordable(base: Double, growth g: Double, owned: Int) -> Int {
        let a = base * pow(g, Double(owned))
        let rhs = 1 + points * (g - 1) / a
        guard rhs > 1 else { return 0 }
        // Capped so a huge balance can't trigger a thousands-long buy loop.
        return max(0, min(1000, Int(floor(log(rhs) / log(g)))))
    }

    // MARK: Idle production -----------------------------------------------------

    private func startIdleLoop() {
        // 10 Hz keeps the per-second counter buttery without burning battery.
        lastTickAt = Date()
        idleTimer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    /// Advance by the time that *actually* elapsed rather than the nominal 0.1s.
    /// watchOS coalesces timers freely, so trusting the interval would quietly
    /// short-change the player; the clamp keeps a long stall from paying out as
    /// offline earnings, which this game deliberately doesn't have.
    private func tick() {
        let now = Date()
        let dt = min(max(now.timeIntervalSince(lastTickAt), 0), 0.5)
        lastTickAt = now
        advance(by: dt)
    }

    /// Suspend the whole economy while the app is off-screen: no timer wakeups,
    /// no accrual. Called from the scene-phase observer.
    func setActive(_ active: Bool) {
        if active {
            guard idleTimer == nil else { return }
            startIdleLoop()
        } else if idleTimer != nil {
            idleTimer?.cancel()
            idleTimer = nil
            save()
        }
    }

    private func advance(by dt: TimeInterval) {
        let gain = pointsPerSecond * dt
        if gain > 0 {
            points += gain
            totalEarned += gain
        }
        if let end = frenzyEndsAt, end <= Date() {
            frenzyEndsAt = nil           // expire the frenzy (publishes for the UI)
        }
        saveAccumulator += dt
        if saveAccumulator >= 5 {        // periodic autosave
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
        var overdriveOwned: [Bool]?
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
            overdriveOwned: overdriveOwned,
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
        if let saved = snap.overdriveOwned {
            for i in 0..<min(overdriveOwned.count, saved.count) {
                overdriveOwned[i] = saved[i]
            }
        }
        // No offline earnings: points only accrue while the app is open.
    }
}
