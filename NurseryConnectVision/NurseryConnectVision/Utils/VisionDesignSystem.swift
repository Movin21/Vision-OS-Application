// Utils/VisionDesignSystem.swift — NurseryConnectVision
// Shared colour, typography, and date helpers for the visionOS target.
// Mirrors the Clinical Sanctuary palette of the iPad app without UIKit.

import SwiftUI

// MARK: - Hex Colour

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var n: UInt64 = 0
        Scanner(string: h).scanHexInt64(&n)
        let r = Double((n >> 16) & 0xFF) / 255
        let g = Double((n >>  8) & 0xFF) / 255
        let b = Double((n      ) & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b)
    }

    // Clinical Sanctuary palette
    static let ncAccent     = Color(hex: "2a6677")
    static let ncSecondary  = Color(hex: "3b6850")
    static let ncAlert      = Color(hex: "a83836")
    static let ncWarning    = Color(hex: "f0a020")
}

// MARK: - Date helpers

extension Date {
    var shortTime: String    { formatted(.dateTime.hour().minute()) }
    var shortDate: String    { formatted(.dateTime.day().month(.abbreviated)) }
    var fullDateTime: String { formatted(.dateTime.day().month(.abbreviated).year().hour().minute()) }
}
