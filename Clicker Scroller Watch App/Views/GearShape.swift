//
//  GearShape.swift
//  Clicker Scroller Watch App
//
//  A procedurally generated cogwheel outline. Each "tooth" is one of the pegs
//  that catches the pawl, so the tooth count is also the points-per-revolution.
//

import SwiftUI

struct GearShape: Shape {
    var teeth: Int = 12
    /// How far teeth project beyond the rim, as a fraction of the radius.
    var toothDepth: CGFloat = 0.18
    /// Width of each tooth's flat top as a fraction of one tooth's angular span.
    var toothTopFraction: CGFloat = 0.42

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * (1 - toothDepth)

        let step = (2 * Double.pi) / Double(teeth)
        // Fractions of one tooth period for the four corners of a trapezoid tooth.
        let topHalf = Double(toothTopFraction) / 2
        let riseGap = 0.07                       // angular gap between rim and tooth wall

        func point(angle: Double, radius: CGFloat) -> CGPoint {
            CGPoint(x: center.x + radius * CGFloat(cos(angle)),
                    y: center.y + radius * CGFloat(sin(angle)))
        }

        for i in 0..<teeth {
            let a = Double(i) * step           // tooth center angle
            let toothLead = a - topHalf * step
            let toothTrail = a + topHalf * step
            let valleyLead = a - (0.5 - riseGap) * step
            let valleyTrail = a + (0.5 - riseGap) * step

            if i == 0 {
                path.move(to: point(angle: valleyLead, radius: inner))
            } else {
                path.addLine(to: point(angle: valleyLead, radius: inner))
            }
            // up the leading flank, across the flat top, down the trailing flank
            path.addLine(to: point(angle: toothLead, radius: outer))
            path.addLine(to: point(angle: toothTrail, radius: outer))
            path.addLine(to: point(angle: valleyTrail, radius: inner))
        }
        path.closeSubpath()
        return path
    }
}

/// The single highlighted "catch peg" that visually slams the pawl — purely
/// decorative flair layered on top of the full toothed gear.
struct GearHub: Shape {
    var bolts: Int = 5
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let boltOrbit = r * 0.62
        let boltR = r * 0.10
        for i in 0..<bolts {
            let a = (Double(i) / Double(bolts)) * 2 * Double.pi - .pi / 2
            let c = CGPoint(x: center.x + boltOrbit * CGFloat(cos(a)),
                            y: center.y + boltOrbit * CGFloat(sin(a)))
            path.addEllipse(in: CGRect(x: c.x - boltR, y: c.y - boltR,
                                       width: boltR * 2, height: boltR * 2))
        }
        return path
    }
}
