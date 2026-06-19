//
//  ShopRow.swift
//  Clicker Scroller Watch App
//
//  One purchasable line in the Workshop list.
//

import SwiftUI

struct ShopRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let costText: String
    let countLabel: String?
    let owned: Int
    let affordable: Bool
    var recommended: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(LinearGradient(colors: [tint.opacity(0.9), tint.opacity(0.45)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.bgBottom)
                }
                .frame(width: 38, height: 38)
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Theme.brassLight.opacity(0.35), lineWidth: 1))

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        if recommended {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8)).foregroundStyle(Theme.amber)
                        }
                        Text(title)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        if owned > 0 {
                            Text("·\(owned)")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.brass)
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.inkDim)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    HStack(spacing: 3) {
                        Image(systemName: "gearshape.fill").font(.system(size: 8))
                        Text(costText).font(.system(size: 11, weight: .heavy, design: .rounded))
                        if let countLabel {
                            Text(countLabel)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.inkDim)
                        }
                    }
                    .foregroundStyle(affordable ? Theme.amber : Theme.inkDim.opacity(0.7))
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .opacity(affordable ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!affordable)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.bgTop.opacity(affordable ? 0.55 : 0.30))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(recommended ? Theme.amber.opacity(0.8)
                            : (affordable ? Theme.brass.opacity(0.45) : .clear),
                            lineWidth: recommended ? 1.5 : 1))
        )
    }
}
