//
//  Haptics.swift
//  Clicker Scroller Watch App
//
//  A clicker on the wrist lives or dies by how it *feels*. The gear's crown
//  detents are switched off (see GameView) so the ratchet can be voiced here
//  instead — one tap per tooth caught, with heavier cues for the big moments.
//
//  Ticks are rate-limited: at full spin the gear can cross dozens of teeth per
//  second, and asking the Taptic engine for all of them would both saturate it
//  (the taps smear into a buzz) and cost real battery.
//

import Foundation
import WatchKit

enum Haptics {

    private static let defaultsKey = "gearclicker.haptics"

    /// Player-facing switch, mirrored into UserDefaults so it survives launches.
    static var enabled: Bool = (UserDefaults.standard.object(forKey: defaultsKey) as? Bool) ?? true {
        didSet { UserDefaults.standard.set(enabled, forKey: defaultsKey) }
    }

    private static var lastTickAt: Date = .distantPast
    private static let minTickInterval: TimeInterval = 0.055   // ~18 taps/sec ceiling

    private static func play(_ type: WKHapticType) {
        guard enabled else { return }
        WKInterfaceDevice.current().play(type)
    }

    /// One tooth caught by the pawl. Silently drops taps that arrive too fast.
    static func tick() {
        guard enabled else { return }
        let now = Date()
        guard now.timeIntervalSince(lastTickAt) >= minTickInterval else { return }
        lastTickAt = now
        WKInterfaceDevice.current().play(.click)
    }

    /// A critical tooth — worth its own distinct kick.
    static func crit() { play(.directionUp) }

    /// Lucky Gear caught; frenzy begins.
    static func frenzy() { play(.success) }

    /// Something was bought in the Workshop.
    static func purchase() { play(.click) }

    /// A prestige / reset went through.
    static func prestige() { play(.notification) }
}
