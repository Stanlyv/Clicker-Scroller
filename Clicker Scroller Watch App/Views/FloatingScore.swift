//
//  FloatingScore.swift
//  Clicker Scroller Watch App
//
//  The little "+N" labels that spring off the pawl on every catch.
//

import SwiftUI

struct Floater: Identifiable {
    let id = UUID()
    let text: String
    let xJitter: CGFloat
    let createdAt: Date = Date()
}

/// A self-animating "+N" that drifts up, fades, and reports when it's done.
struct FloatingScoreLabel: View {
    let floater: Floater
    let onFinished: (UUID) -> Void

    @State private var rise: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.4

    var body: some View {
        Text(floater.text)
            .font(.system(size: 17, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.brassLight)
            .shadow(color: Theme.amberGlow.opacity(0.9), radius: 4)
            .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(x: floater.xJitter, y: rise)
            .onAppear {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                    scale = 1.0
                    opacity = 1.0
                }
                withAnimation(.easeOut(duration: 0.9)) {
                    rise = -46
                }
                withAnimation(.easeIn(duration: 0.4).delay(0.5)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                    onFinished(floater.id)
                }
            }
    }
}
