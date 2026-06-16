//
//  ShopView.swift
//  Clicker Scroller Watch App
//
//  The Workshop — where points are spent. This screen IS a List, so the crown
//  scrolls it (which is exactly what you want here, unlike the game screen).
//

import SwiftUI
import WatchKit

struct ShopView: View {
    @EnvironmentObject private var game: GameState

    var body: some View {
        List {
            balanceHeader
                .listRowBackground(Color.clear)

            Section {
                ForEach(Catalog.clickBoosts) { boost in
                    let cost = game.costForBoost(boost)
                    ShopRow(
                        icon: boost.icon, tint: Theme.copper,
                        title: boost.name,
                        subtitle: "+\(boost.perToothBonus.abbreviated())/tooth · \(boost.blurb)",
                        costText: cost.abbreviated(),
                        owned: game.boostCounts[boost.id],
                        affordable: game.canAfford(cost)
                    ) { buyBoost(boost) }
                }
            } header: {
                sectionHeader("Click Boosts", systemImage: "hand.tap.fill")
            }

            Section {
                ForEach(Catalog.generators) { gen in
                    let cost = game.costForGenerator(gen)
                    ShopRow(
                        icon: gen.icon, tint: gen.tint,
                        title: gen.name,
                        subtitle: "+\(gen.baseOutput.abbreviated())/s · \(gen.blurb)",
                        costText: cost.abbreviated(),
                        owned: game.generatorCounts[gen.id],
                        affordable: game.canAfford(cost)
                    ) { buyGenerator(gen) }
                }
            } header: {
                sectionHeader("Automatons", systemImage: "gearshape.2.fill")
            }

            if game.canPrestige || game.goldenGears > 0 {
                Section {
                    prestigeRow
                } header: {
                    sectionHeader("Ascension", systemImage: "sparkles")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Workshop")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Actions -------------------------------------------------------------

    private func buyBoost(_ boost: ClickBoost) {
        if game.buyBoost(boost) { WKInterfaceDevice.current().play(.success) }
        else { WKInterfaceDevice.current().play(.failure) }
    }

    private func buyGenerator(_ gen: Generator) {
        if game.buyGenerator(gen) { WKInterfaceDevice.current().play(.success) }
        else { WKInterfaceDevice.current().play(.failure) }
    }

    // MARK: Pieces --------------------------------------------------------------

    private var balanceHeader: some View {
        VStack(spacing: 2) {
            Text(game.points.abbreviated())
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [Theme.brassLight, Theme.brass],
                                   startPoint: .top, endPoint: .bottom)
                )
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.15), value: game.points)
            Text("\(game.pointsPerSecond.abbreviatedRate()) / sec")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.inkDim)
        }
        .frame(maxWidth: .infinity)
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
            game.prestige()
            WKInterfaceDevice.current().play(.notification)
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
                    Text("Melt to Golden Gears")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.gold)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text("+\(game.pendingGoldenGears) gears · +\(Int(Catalog.prestigeBonusPerGear * 100))% each, forever")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.inkDim)
                        .lineLimit(2).minimumScaleFactor(0.7)
                    Text("Resets points & upgrades")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.copper)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .opacity(game.canPrestige ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!game.canPrestige)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.goldDeep.opacity(game.canPrestige ? 0.35 : 0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.gold.opacity(game.canPrestige ? 0.6 : 0.2), lineWidth: 1)
                )
        )
    }
}
