import SwiftUI

/// Faint, foggy rendering of the live transcript above the cup.
///
/// The last few characters carry a descending alpha so each new letter fades in over several
/// typewriter ticks instead of popping; the whole block is slightly blurred with a soft glow.
struct FoggyTranscriptView: View {
    let text: String
    var fadeTail: Int = 8
    var maxOpacity: Double = 0.58

    var body: some View {
        Text(attributed)
            .font(.system(size: 26, weight: .light, design: .serif))
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .blur(radius: 1.1)
            .shadow(color: .white.opacity(0.35), radius: 7)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .padding(.horizontal, 28)
            .allowsHitTesting(false)
            .accessibilityLabel(Text(text))
    }

    private var attributed: AttributedString {
        let characters = Array(text)
        let count = characters.count
        guard count > 0 else { return AttributedString() }

        let steadyCount = max(0, count - fadeTail)
        var result = AttributedString(String(characters[0..<steadyCount]))
        result.foregroundColor = Color.white.opacity(maxOpacity)

        for i in steadyCount..<count {
            let fromEnd = count - 1 - i          // 0 for the newest character
            let step = Double(fadeTail - fromEnd) // 1...fadeTail
            let alpha = maxOpacity * step / Double(fadeTail + 1)
            var piece = AttributedString(String(characters[i]))
            piece.foregroundColor = Color.white.opacity(alpha)
            result += piece
        }
        return result
    }
}

#Preview {
    ZStack {
        Color.black
        FoggyTranscriptView(text: "Bright citrus up front, then a soft milk chocolate finish that lingers")
    }
}
