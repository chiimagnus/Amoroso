import SwiftUI

struct LibraryPracticeEmptyAnimationView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      Circle()
        .fill(LibraryDesignTokens.accent.opacity(0.18))
        .frame(width: 190, height: 190)
        .blur(radius: 22)
        .phaseAnimator(reduceMotion ? [false] : [false, true]) { content, expanded in
          content
            .scaleEffect(expanded ? 1.08 : 0.92)
            .opacity(expanded ? 0.84 : 0.58)
        } animation: { _ in
          reduceMotion ? nil : .easeInOut(duration: 1.8)
        }

      LibraryPracticePianoKeysView()
        .offset(y: 38)

      LibraryPracticeFloatingNote(
        systemImage: "music.note",
        horizontalOffset: -76,
        verticalOffset: -54,
        lift: 12,
        delay: 0
      )

      LibraryPracticeFloatingNote(
        systemImage: "music.note.list",
        horizontalOffset: 68,
        verticalOffset: -66,
        lift: 9,
        delay: 0.18
      )

      LibraryPracticeFloatingNote(
        systemImage: "music.quarternote.3",
        horizontalOffset: 10,
        verticalOffset: -96,
        lift: 14,
        delay: 0.34
      )
    }
    .frame(height: 230)
    .accessibilityHidden(true)
  }
}

private struct LibraryPracticePianoKeysView: View {
  private let keyCount = 7

  var body: some View {
    ZStack(alignment: .topLeading) {
      HStack(spacing: 3) {
        ForEach(0..<keyCount, id: \.self) { _ in
          RoundedRectangle(cornerRadius: 6)
            .fill(.regularMaterial)
            .frame(width: 34, height: 82)
            .overlay {
              RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.primary.opacity(0.14), lineWidth: 1)
            }
        }
      }

      HStack(spacing: 0) {
        Color.clear.frame(width: 24)
        LibraryPracticeBlackKey()
        Color.clear.frame(width: 18)
        LibraryPracticeBlackKey()
        Color.clear.frame(width: 55)
        LibraryPracticeBlackKey()
        Color.clear.frame(width: 18)
        LibraryPracticeBlackKey()
        Color.clear.frame(width: 18)
        LibraryPracticeBlackKey()
      }
      .offset(y: -1)
    }
    .padding(10)
    .background(.thinMaterial, in: .rect(cornerRadius: 18))
    .rotation3DEffect(.degrees(7), axis: (x: 1, y: 0, z: 0))
    .shadow(radius: 18, y: 12)
  }
}

private struct LibraryPracticeBlackKey: View {
  var body: some View {
    RoundedRectangle(cornerRadius: 4)
      .fill(.primary.opacity(0.82))
      .frame(width: 18, height: 49)
  }
}

private struct LibraryPracticeFloatingNote: View {
  let systemImage: String
  let horizontalOffset: CGFloat
  let verticalOffset: CGFloat
  let lift: CGFloat
  let delay: TimeInterval

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Image(systemName: systemImage)
      .font(.system(.title2, design: .rounded))
      .foregroundStyle(LibraryDesignTokens.accent)
      .padding(10)
      .background(.thinMaterial, in: .circle)
      .offset(x: horizontalOffset, y: verticalOffset)
      .phaseAnimator(reduceMotion ? [false] : [false, true]) { content, raised in
        content
          .offset(y: raised ? -lift : lift / 3)
          .scaleEffect(raised ? 1.06 : 0.94)
          .opacity(raised ? 1 : 0.72)
      } animation: { _ in
        reduceMotion ? nil : .easeInOut(duration: 1.35).delay(delay)
      }
  }
}
