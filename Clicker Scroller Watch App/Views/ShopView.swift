//
//  ShopView.swift
//  Clicker Scroller Watch App
//
//  The Workshop — where points are spent. This screen IS a List, so the crown
//  scrolls it (which is exactly what you want here, unlike the game screen).
//

import SwiftUI

enum BuyQty: CaseIterable {
    case one, ten, max
    var label: String { self == .one ? "×1" : self == .ten ? "×10" : "Max" }
}

struct ShopView: View {
    @EnvironmentObject private var game: GameState
    @State private var qty: BuyQty = .one
    @State private var showPrestige = false

    var body: some View {
        List {
            balanceHeader.listRowBackground(Color.clear)
            quantityPicker.listRowBackground(Color.clear)

            Section {
                ForEach(Catalog.clickBoosts) { boost in
                    let p = boostPurchase(boost)
                    ShopRow(
                        icon: boost.icon, tint: Theme.copper,
                        title: boost.name,
                        subtitle: game.boostCounts[boost.id] > 0
                            ? "now +\(game.bonusForBoost(boost).abbreviated())/tooth"
                            : "+\(boost.perToothBonus.abbreviated())/tooth · \(boost.blurb)",
                        costText: p.cost.abbreviated(),
                        countLabel: p.countLabel,
                        owned: game.boostCounts[boost.id],
                        affordable: p.affordable,
                        recommended: recommendedID == "b\(boost.id)"
                    ) { buy { game.buyBoost(boost, count: p.buyCount) } }
                }
            } header: { sectionHeader("Click Boosts", systemImage: "hand.tap.fill") }

            Section {
                ForEach(Catalog.generators) { gen in
                    let p = genPurchase(gen)
                    ShopRow(
                        icon: gen.icon, tint: gen.tint,
                        title: gen.name,
                        subtitle: genSubtitle(gen),
                        costText: p.cost.abbreviated(),
                        countLabel: p.countLabel,
                        owned: game.generatorCounts[gen.id],
                        affordable: p.affordable,
                        recommended: recommendedID == "g\(gen.id)"
                    ) { buy { game.buyGenerator(gen, count: p.buyCount) } }
                }
            } header: { sectionHeader("Automatons", systemImage: "gearshape.2.fill") }

            Section {
                ForEach(Catalog.overdrives) { od in
                    let owned = game.isOverdriveOwned(od)
                    ShopRow(
                        icon: od.icon, tint: od.tint,
                        title: od.name,
                        subtitle: owned ? "Installed ✓" : od.blurb,
                        costText: owned ? "owned" : od.cost.abbreviated(),
                        countLabel: nil,
                        owned: 0,
                        affordable: !owned && game.canAfford(od.cost),
                        recommended: false
                    ) {
                        _ = game.buyOverdrive(od)
                    }
                }
            } header: { sectionHeader("Overdrives · ×\(Int(game.overdriveMultiplier))", systemImage: "bolt.fill") }

            Section {
                prestigeRow
            } header: { sectionHeader("Prestige", systemImage: "sparkles") }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Workshop")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Prestige", isPresented: $showPrestige, titleVisibility: .visible) {
            if game.canPrestige {
                Button("Prestige · +\(game.pendingGoldenGears) gears", role: .destructive) {
                    game.prestige()
                }
            } else if game.goldenGears > 0 {
                Button("Reset · keep \(game.goldenGears) gears", role: .destructive) {
                    game.resetKeepingPrestige()
                }
                Button("Full reset · lose gears", role: .destructive) {
                    game.resetAll()
                }
            } else {
                Button("Reset everything", role: .destructive) {
                    game.resetAll()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(prestigeMessage)
        }
    }

    private var prestigeMessage: String {
        if game.canPrestige {
            return "Resets your points & upgrades. You keep your Golden Gears and gain \(game.pendingGoldenGears) more (+\(Int(Catalog.prestigeBonusPerGear * 100))% each, forever)."
        } else if game.goldenGears > 0 {
            return "No new gears yet. Restart your run — keep your \(game.goldenGears) Golden Gears, or wipe everything."
        } else {
            return "Restart your run from the very first spin."
        }
    }

    // MARK: Purchase resolution -------------------------------------------------

    private struct Purchase { let cost: Double; let countLabel: String?; let affordable: Bool; let buyCount: Int }

    private func genPurchase(_ gen: Generator) -> Purchase {
        let maxA = game.maxAffordableGenerator(gen)
        let wanted = qty == .one ? 1 : qty == .ten ? 10 : max(maxA, 0)
        let display = Swift.max(wanted, 1)
        let cost = game.bulkCostGenerator(gen, count: display)
        let affordable = qty == .max ? maxA >= 1 : game.points >= cost
        let buyCount = qty == .max ? maxA : wanted
        return Purchase(cost: cost, countLabel: display > 1 ? "×\(display)" : nil,
                        affordable: affordable, buyCount: buyCount)
    }

    private func boostPurchase(_ boost: ClickBoost) -> Purchase {
        let maxA = game.maxAffordableBoost(boost)
        let wanted = qty == .one ? 1 : qty == .ten ? 10 : max(maxA, 0)
        let display = Swift.max(wanted, 1)
        let cost = game.bulkCostBoost(boost, count: display)
        let affordable = qty == .max ? maxA >= 1 : game.points >= cost
        let buyCount = qty == .max ? maxA : wanted
        return Purchase(cost: cost, countLabel: display > 1 ? "×\(display)" : nil,
                        affordable: affordable, buyCount: buyCount)
    }

    /// Cheapest single item the player can afford right now — flagged with a star.
    private var recommendedID: String? {
        var best: (id: String, cost: Double)? = nil
        for b in Catalog.clickBoosts where game.points >= game.costForBoost(b) {
            let c = game.costForBoost(b)
            if best == nil || c < best!.cost { best = ("b\(b.id)", c) }
        }
        for g in Catalog.generators where game.points >= game.costForGenerator(g) {
            let c = game.costForGenerator(g)
            if best == nil || c < best!.cost { best = ("g\(g.id)", c) }
        }
        return best?.id
    }

    private func buy(_ action: () -> Int) {
        _ = action()
    }

    private func genSubtitle(_ gen: Generator) -> String {
        let owned = game.generatorCounts[gen.id]
        if owned == 0 { return "+\(gen.baseOutput.abbreviated())/s · \(gen.blurb)" }
        var s = "now +\(game.outputForGenerator(gen).abbreviatedRate())/s"
        let m = game.milestoneFor(gen)
        if m > 1 { s += " · ×\(Int(m))" }
        if let next = Catalog.nextMilestone(owned: owned) { s += " (→\(next))" }
        return s
    }

    // MARK: Pieces --------------------------------------------------------------

    private var balanceHeader: some View {
        VStack(spacing: 2) {
            Text(game.points.abbreviated())
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [Theme.brassLight, Theme.brass],
                                                startPoint: .top, endPoint: .bottom))
                .minimumScaleFactor(0.5).lineLimit(1)
            Text("\(game.pointsPerSecond.abbreviatedRate()) / sec")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.inkDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    private var quantityPicker: some View {
        HStack(spacing: 6) {
            ForEach(BuyQty.allCases, id: \.self) { q in
                let on = qty == q
                Text(q.label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(on ? Theme.bgBottom : Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(on ? Theme.brass : Theme.bgTop.opacity(0.6)))
                    .contentShape(Capsule())
                    .onTapGesture { qty = q }
            }
        }
        .padding(.vertical, 2)
    }

    private func sectionHeader(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.brass)
            .textCase(nil)
    }

    private var prestigeRow: some View {
        Button {
            showPrestige = true
        } label: {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.goldMetal)
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Theme.bgBottom)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Prestige")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.gold)
                    Text(game.canPrestige
                         ? "Reset for +\(game.pendingGoldenGears) Golden Gear\(game.pendingGoldenGears == 1 ? "" : "s")"
                         : "Reset & restart your run")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.inkDim)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(game.goldenGears > 0
                         ? "\(game.goldenGears) gears · +\(Int(Double(game.goldenGears) * Catalog.prestigeBonusPerGear * 100))% forever"
                         : "next gear at \(game.nextGearAt.abbreviated()) earned")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.copper)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.goldDeep.opacity(game.canPrestige ? 0.35 : 0.18))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.gold.opacity(game.canPrestige ? 0.7 : 0.3), lineWidth: 1))
        )
    }
}
