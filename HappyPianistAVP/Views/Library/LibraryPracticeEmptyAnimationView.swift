import SwiftUI

struct LibraryPracticeEmptyAnimationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "music.note")
            .font(.system(.largeTitle, design: .rounded))
            .foregroundStyle(LibraryDesignTokens.accent)
            .padding()
            .background(.thinMaterial, in: .circle)
            .phaseAnimator(reduceMotion ? [false] : [false, true]) { content, lifted in
                content
                    .scaleEffect(lifted ? 1.08 : 0.94)
                    .offset(y: lifted ? -6 : 3)
                    .symbolEffect(.pulse, value: lifted)
            } animation: { _ in
                reduceMotion ? nil : .easeInOut(duration: 1.2)
            }
            .accessibilityHidden(true)
    }
}
