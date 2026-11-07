import SwiftUI
import Testing
import UIKit
@testable import OhMyFile

struct AccentColorStorageTests {
    @Test func parsesHexColor() {
        let color = AccentColorStorage.uiColor(from: "#FF0000")
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        #expect(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        #expect(red == 1)
        #expect(green == 0)
        #expect(blue == 0)
    }

    @Test func roundTripsHex() {
        let hex = AccentColorStorage.hex(from: UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
        let color = AccentColorStorage.uiColor(from: hex)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        #expect(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        #expect(abs(red - 0.2) < 0.01)
        #expect(abs(green - 0.4) < 0.01)
        #expect(abs(blue - 0.6) < 0.01)
    }

    @Test func invalidHexFallsBackToSystemBlue() {
        let color = AccentColorStorage.uiColor(from: "not-a-color")
        #expect(color == .systemBlue)
    }
}
