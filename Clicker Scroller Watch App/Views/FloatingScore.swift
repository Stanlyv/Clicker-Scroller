//
//  FloatingScore.swift
//  Clicker Scroller Watch App
//
//  The little "+N" labels that spring off the gear on every catch. Crits and
//  special call-outs (e.g. FRENZY) pop bigger and hotter.
//

import SwiftUI

struct Floater: Identifiable {
    let id = UUID()
    let text: String
    let xJitter: CGFloat
    var isCrit: Bool = false
    let createdAt: Date = Date()
}

/// A self-animating label that drifts up, fades, and reports when it's done.
struct FloatingScoreLabel: View {
    let floater: Floater
    let onFinished: (UUID) -> Void

    @State private var rise: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.4

    private var color: Color { floater.isCrit ? Theme.copper : Theme.brassLight }
    private var size: CGFloat { floater.isCrit ? 22 : 17 }

    var body: some View {
        Text(floater.text)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(floater.isCrit
                             ? AnyShapeStyle(LinearGradient(colors: [Theme.amber, Theme.copper],
                                                            startPoint: .top, endPoint: .bottom))
                             : AnyShapeStyle(color))
            .shadow(color: (floater.isCrit ? Theme.copper : Theme.amberGlow).opacity(0.9), radius: 5)
            .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(x: floater.xJitter, y: rise)
            .onAppear {
                withAnimation(.spring(response: 0.25, dampingFraction: floater.isCrit ? 0.4 : 0.55)) {
                    scale = floater.isCrit ? 1.25 : 1.0
                    opacity = 1.0
                }
                withAnimation(.easeOut(duration: floater.isCrit ? 1.05 : 0.9)) {
                    rise = floater.isCrit ? -58 : -46
                }
                withAnimation(.easeIn(duration: 0.4).delay(floater.isCrit ? 0.65 : 0.5)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + (floater.isCrit ? 1.1 : 0.95)) {
                    onFinished(floater.id)
                }
            }
    }
}
