//
//  DCCurrencyText.swift
//  The Rug
//
//  Custom image-based currency display using the DC Circuit-Metal green font.
//
//  Usage:
//    DCCurrencyText(amount: 670, size: 64)
//    DCCurrencyText(amount: 80,  size: 40, showSign: true)
//    DCCurrencyText(amount: 670, size: 64, showDollar: false)
//

import SwiftUI

// MARK: - Single Glyph

private struct DCGlyph: View {
    let char: Character
    let size: CGFloat

    private var assetName: String? {
        switch char {
        case "0": return "DCFont_green_0"
        case "1": return "DCFont_green_1"
        case "2": return "DCFont_green_2"
        case "3": return "DCFont_green_3"
        case "4": return "DCFont_green_4"
        case "5": return "DCFont_green_5"
        case "6": return "DCFont_green_6"
        case "7": return "DCFont_green_7"
        case "8": return "DCFont_green_8"
        case "9": return "DCFont_green_9"
        case "$": return "DCFont_green_dollar"
        default:  return nil
        }
    }

    private var widthRatio: CGFloat {
        switch char {
        case "1":       return 0.44
        case "$":       return 0.62
        case "+", "-":  return 0.38
        default:        return 0.60
        }
    }

    var body: some View {
        if let name = assetName {
            Image(name)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: size * widthRatio, height: size)
        } else {
            Text(String(char))
                .font(.system(size: size * 0.72, weight: .black))
                .foregroundStyle(Color(red: 0.25, green: 0.75, blue: 0.45))
                .frame(width: size * 0.42, height: size)
        }
    }
}

// MARK: - Currency Text

struct DCCurrencyText: View {
    let amount: Double
    let size: CGFloat
    var showSign: Bool   = false
    var showDollar: Bool = true

    private var characters: [Character] {
        var str = ""
        if showSign && amount > 0 { str += "+" }
        if showDollar { str += "$" }
        str += "\(abs(Int(amount)))"
        return Array(str)
    }

    var body: some View {
        HStack(spacing: -(size * 0.14)) {
            ForEach(Array(characters.enumerated()), id: \.offset) { _, char in
                DCGlyph(char: char, size: size)
            }
        }
    }
}
