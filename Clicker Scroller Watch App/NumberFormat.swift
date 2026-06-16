//
//  NumberFormat.swift
//  Clicker Scroller Watch App
//
//  Compact "idle game" number formatting — 1.2K, 3.4M, 5.6B, 7.8T …
//

import Foundation

extension Double {
    private static let suffixes = [
        "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
        "UDc", "DDc", "TDc", "QaDc", "QiDc"
    ]

    /// Short human-readable form suited to tiny watch labels.
    /// Below 1,000 shows whole numbers; above that uses 3 significant digits + suffix.
    func abbreviated() -> String {
        if !isFinite { return "∞" }
        let n = self
        let sign = n < 0 ? "-" : ""
        let value = Swift.abs(n)

        if value < 1000 {
            // Whole numbers stay crisp; small fractions get one decimal.
            if value == value.rounded() { return sign + String(format: "%.0f", value) }
            return sign + String(format: "%.1f", value)
        }

        let exp = Int(log10(value) / 3.0)
        let clamped = Swift.min(exp, Double.suffixes.count - 1)
        let scaled = value / pow(1000.0, Double(clamped))
        let suffix = Double.suffixes[clamped]

        // Keep ~3 significant figures: 12.3K, 1.23M, 123M …
        let formatted: String
        if scaled >= 100 {
            formatted = String(format: "%.0f", scaled)
        } else if scaled >= 10 {
            formatted = String(format: "%.1f", scaled)
        } else {
            formatted = String(format: "%.2f", scaled)
        }
        return sign + formatted + suffix
    }

    /// Slightly richer form for "per second" readouts (keeps 1 decimal under 10).
    func abbreviatedRate() -> String {
        if self == 0 { return "0" }
        if Swift.abs(self) < 10 && self == self.rounded() { return String(format: "%.0f", self) }
        if Swift.abs(self) < 10 { return String(format: "%.1f", self) }
        return abbreviated()
    }
}
