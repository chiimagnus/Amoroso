import SwiftUI

struct LibraryCrateView: View {
    let entries: [SongLibraryEntry]
    let selectedEntryID: UUID?
    let playingEntryID: UUID?
    let isPlaying: Bool
    let reduceMotion: Bool
    let allowsDestructiveActions: Bool
    let onSelectEntry: (UUID) -> Void
    let onTogglePlayback: (UUID) -> Void
    let onImportMusicXML: () -> Void
    let onBindAudio: (UUID) -> Void
    let onDelete: (UUID) -> Void

    @State private var horizontalDragOffset: CGFloat = 0
    @State private var liftOffset: CGFloat = 0
    @State private var dragIsHorizontal: Bool?

    var body: some View {
        let selectedIndex = entries.firstIndex(where: { $0.id == selectedEntryID }) ?? 0
        let dragProgress = horizontalDragOffset / LibraryDesignTokens.carouselNeighborOffset

        ZStack {
            LibraryImportLiftView(liftOffset: liftOffset)
                .offset(y: LibraryDesignTokens.recordDiameter / 2 - 74)
                .zIndex(1)

            ForEach(entries.enumerated(), id: \.element.id) { index, entry in
                let relativeIndex = index - selectedIndex
                let distance = abs(relativeIndex)

                if distance <= 3 {
                    let isActive = relativeIndex == 0
                    let pose = LibraryCarouselPose(
                        relativePosition: CGFloat(relativeIndex) + dragProgress
                    )
                    let presentation = SongLibraryTrackPresentation(entry: entry, index: index)

                    Button {
                        handleRecordTap(entryID: entry.id, index: index, selectedIndex: selectedIndex)
                    } label: {
                        VinylRecordView(
                            labelColor: presentation.labelColor,
                            isPlaying: isActive && playingEntryID == entry.id && isPlaying,
                            reduceMotion: reduceMotion
                        )
                    }
                    .buttonStyle(.plain)
                    .hoverEffect()
                    .contextMenu {
                        if entry.isBundled != true {
                            Button("导入或替换音频", systemImage: "waveform") {
                                onBindAudio(entry.id)
                            }
                            Button("删除曲目", systemImage: "trash", role: .destructive) {
                                onDelete(entry.id)
                            }
                            .disabled(allowsDestructiveActions == false)
                            .accessibilityHint(
                                allowsDestructiveActions ? "删除当前曲目" : "曲谱导入期间不能删除曲目"
                            )
                        }
                    }
                    // ponytail: visionOS clips rotated record layers; horizontal compression keeps the depth cue.
                    .scaleEffect(x: pose.scale * pose.horizontalScale, y: pose.scale)
                    .opacity(pose.opacity)
                    .saturation(pose.saturation)
                    .offset(
                        x: pose.horizontalOffset,
                        y: isActive ? -liftOffset : 0
                    )
                    .zIndex(pose.zIndex)
                    .animation(reduceMotion ? nil : LibraryDesignTokens.easeOut, value: selectedEntryID)
                    .allowsHitTesting(distance <= 2)
                    .accessibilityHidden(distance > 2)
                    .accessibilityLabel(presentation.title)
                    .accessibilityHint(isActive ? "播放或暂停当前曲目" : "切换到这首曲目")
                    .accessibilityAddTraits(isActive ? .isSelected : [])
                }
            }

            TurntableTonearmView(isPlaying: isPlaying, reduceMotion: reduceMotion)
                .zIndex(30)

            VStack {
                Spacer()
                LibraryPageIndicatorView(count: entries.count, selectedIndex: selectedIndex)
                    .padding(.bottom, 12)
            }
            .zIndex(40)

            HStack {
                Button("上一首", systemImage: "chevron.left") {
                    select(index: selectedIndex - 1)
                }
                .labelStyle(.iconOnly)
                .opacity(selectedIndex > 0 ? 0.95 : 0)
                .disabled(selectedIndex == 0)

                Spacer()

                Button("下一首", systemImage: "chevron.right") {
                    select(index: selectedIndex + 1)
                }
                .labelStyle(.iconOnly)
                .opacity(selectedIndex < entries.count - 1 ? 0.95 : 0)
                .disabled(selectedIndex >= entries.count - 1)
            }
            .padding()
            .zIndex(50)

            VStack {
                Spacer()
                Text("↑ 上拽唱片导入乐谱")
                    .font(.caption)
                    .foregroundStyle(LibraryDesignTokens.faintText)
                    .padding(.bottom, 54)
            }
            .zIndex(35)
            .accessibilityHidden(true)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: LibraryDesignTokens.crateMinimumHeight,
            maxHeight: .infinity
        )
        .contentShape(.rect)
        .highPriorityGesture(dragGesture)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("唱片架，左右滑动选曲")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                select(index: selectedIndex + 1)
            case .decrement:
                select(index: selectedIndex - 1)
            @unknown default:
                break
            }
        }
        .clipped()
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 7)
            .onChanged { value in
                if dragIsHorizontal == nil {
                    dragIsHorizontal = abs(value.translation.width) >= abs(value.translation.height)
                }

                if dragIsHorizontal == true {
                    horizontalDragOffset = min(
                        max(
                            value.translation.width,
                            -LibraryDesignTokens.carouselNeighborOffset
                        ),
                        LibraryDesignTokens.carouselNeighborOffset
                    )
                } else if value.translation.height < 0 {
                    liftOffset = min(-value.translation.height, LibraryDesignTokens.liftMaximum)
                }
            }
            .onEnded { value in
                let selectedIndex = entries.firstIndex(where: { $0.id == selectedEntryID }) ?? 0

                if dragIsHorizontal == true {
                    switch LibraryCarouselSelectionDirection.from(
                        horizontalDragTranslation: value.translation.width
                    ) {
                    case .next:
                        select(index: selectedIndex + 1)
                    case .previous:
                        select(index: selectedIndex - 1)
                    case nil:
                        break
                    }
                } else if liftOffset >= LibraryDesignTokens.liftTrigger {
                    onImportMusicXML()
                }

                withAnimation(reduceMotion ? nil : LibraryDesignTokens.easeOut) {
                    horizontalDragOffset = 0
                    liftOffset = 0
                }
                dragIsHorizontal = nil
            }
    }

    private func handleRecordTap(entryID: UUID, index: Int, selectedIndex: Int) {
        if index == selectedIndex {
            onTogglePlayback(entryID)
        } else {
            select(index: index)
        }
    }

    private func select(index: Int) {
        guard entries.indices.contains(index) else { return }
        let entryID = entries[index].id
        onSelectEntry(entryID)
    }
}

private struct LibraryImportLiftView: View {
    let liftOffset: CGFloat

    var body: some View {
        let progress = min(max(liftOffset / LibraryDesignTokens.liftMaximum, 0), 1)
        let isArmed = liftOffset >= LibraryDesignTokens.liftTrigger

        Label("导入 MusicXML", systemImage: "plus")
            .font(.subheadline)
            .foregroundStyle(isArmed ? LibraryDesignTokens.accentForeground : LibraryDesignTokens.text)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(
                isArmed
                    ? LibraryDesignTokens.accent
                    : Color(red: 30 / 255, green: 27 / 255, blue: 26 / 255).opacity(0.66),
                in: .capsule
            )
            .overlay {
                Capsule()
                    .stroke(
                        isArmed ? LibraryDesignTokens.accent : Color.white.opacity(0.42),
                        style: StrokeStyle(lineWidth: 1, dash: isArmed ? [] : [5, 4])
                    )
            }
            .opacity(progress)
            .scaleEffect(0.92 + 0.08 * progress)
            .offset(y: 66 - 18 * progress)
            .accessibilityHidden(true)
    }
}

private struct LibraryPageIndicatorView: View {
    let count: Int
    let selectedIndex: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if count > 12 {
            Text("\(selectedIndex + 1) / \(count)")
                .font(.caption)
                .foregroundStyle(LibraryDesignTokens.faintText)
                .monospacedDigit()
        } else {
            HStack(spacing: 7) {
                ForEach(0 ..< count, id: \.self) { index in
                    Capsule()
                        .fill(index == selectedIndex ? LibraryDesignTokens.text : Color.white.opacity(0.28))
                        .frame(width: index == selectedIndex ? 22 : 6, height: 6)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.30), value: selectedIndex)
                }
            }
        }
    }
}

#Preview("正在播放的唱片架") {
    LibraryCrateView(
        entries: LibraryCratePreviewFixture.entries,
        selectedEntryID: LibraryCratePreviewFixture.entries[1].id,
        playingEntryID: LibraryCratePreviewFixture.entries[1].id,
        isPlaying: true,
        reduceMotion: false,
        allowsDestructiveActions: true,
        onSelectEntry: { _ in },
        onTogglePlayback: { _ in },
        onImportMusicXML: {},
        onBindAudio: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 1_140, height: 500)
}

private enum LibraryCratePreviewFixture {
    static let entries = [
        entry(named: "Bohemian Rhapsody"),
        entry(named: "Despacito"),
        entry(named: "Under Pressure"),
    ]

    private static func entry(named name: String) -> SongLibraryEntry {
        SongLibraryEntry(
            id: UUID(),
            displayName: name,
            musicXMLFileName: "\(name).musicxml",
            scoreFileVersionID: UUID(),
            importedAt: .now,
            audioFileName: "\(name).mp3",
            isBundled: true
        )
    }
}
