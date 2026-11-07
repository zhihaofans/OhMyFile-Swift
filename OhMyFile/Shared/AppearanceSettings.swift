//
//  AppearanceSettings.swift
//  OhMyFile
//
//  外观模式与强调色存取；纯值类型 + 颜色转换。
//

import SwiftUI
import UIKit

enum AppearanceMode: String, CaseIterable, Sendable {
    case system
    case light
    case dark

    nonisolated var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum AccentColorStorage {
    nonisolated static let defaultLightHex = "#007AFF"
    nonisolated static let defaultDarkHex = "#0A84FF"

    nonisolated static func color(from hex: String) -> Color {
        Color(uiColor: uiColor(from: hex))
    }

    nonisolated static func hex(from color: Color) -> String {
        hex(from: UIColor(color))
    }

    nonisolated static func uiColor(from hex: String) -> UIColor {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))

        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            return .systemBlue
        }

        return UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    nonisolated static func hex(from color: UIColor) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return defaultLightHex
        }

        return String(
            format: "#%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255))
        )
    }
}
