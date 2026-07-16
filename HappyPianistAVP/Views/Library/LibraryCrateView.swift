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
    let onImmediateDelete: (UUID) -> Void

    @State private var scrollTargetID: UUID?
    @State private var crateWidth: CGFloat = 0
    @State private var liftOffset: CGFloat = 0
    @State private var downwardDragOffset: CGFloat = 0
    @State private var verticalDragIsActive: Bool?
    @State private var deletionHoldEntryID: UUID?
    @State private var deletionHoldStartedAt: Date?
    @State private var didDeleteDuringDrag = false

    private static let scrollCoordinateSpace = "LibraryRecordScroll"

    private var selectedEntry: SongLibraryEntry? {
        entries.first(where: { $0.id == selectedEntryID })
    }

    var body: some View {
        let selectedIndex = entries.firstIndex(where: { $0.id == selectedEntryID }) ?? 0
        let selectedEntry = entries.indices.contains(selectedIndex) ? entries[selectedIndex] : nil
        let horizontalContentMargin = max(
            0,
            (crateWidth - LibraryDesignTokens.recordDiameter) / 2
        )

        ZStack {
            LibraryImportLiftView(liftOffset: liftOffset)
                .offset(y: LibraryDesignTokens.recordDiameter / 2 - 74)
                .zIndex(1)

            LibraryDeleteHoldView(
                downwardDragOffset: downwardDragOffset,
                holdStartedAt: deletionHoldStartedAt,
                isBundled: selectedEntry?.isBundled == true,
                allowsDestructiveActions: allowsDestructiveActions
            )
            .offset(y: 74 - LibraryDesignTokens.recordDiameter / 2)
            .zIndex(1)

            ScrollView(.horizontal) {
                LazyHStack(spacing: LibraryDesignTokens.recordSpacing) {
                    ForEach(entries.enumerated(), id: \.element.id) { index, entry in
                        let isSelected = entry.id == selectedEntryID
                        let presentation = SongLibraryTrackPresentation(entry: entry, index: index)

                        Button {
                            handleRecordTap(entryID: entry.id)
                        } label: {
                            VinylRecordView(
                                labelColor: presentation.labelColor,
                                isPlaying: isSelected && playingEntryID == entry.id && isPlaying,
                                reduceMotion: reduceMotion
                            )
                            .visualEffect { content, geometry in
                                let frame = geometry.frame(in: .named(Self.scrollCoordinateSpace))
                                let scrollPresentation = LibraryRecordScrollPresentation(
                                    centerDistance: frame.midX - crateWidth / 2
                                )

                                content
                                    .scaleEffect(scrollPresentation.scale)
                                    .opacity(scrollPresentation.opacity)
                                    .saturation(scrollPresentation.saturation)
                            }
                        }
                        .buttonStyle(.plain)
                        .hoverEffect()
                        .frame(
                            width: LibraryDesignTokens.recordDiameter,
                            height: LibraryDesignTokens.recordDiameter
                        )
                        .contentShape(.rect)
                        .offset(y: isSelected ? downwardDragOffset - liftOffset : 0)
                        .id(entry.id)
                        .accessibilityLabel(presentation.title)
                        .accessibilityHint(isSelected ? "播放或暂停当前曲目" : "将这首曲目移到中央并选中")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .frame(maxHeight: .infinity)
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, horizontalContentMargin, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(anchor: .center))
            .scrollPosition(id: $scrollTargetID, anchor: .center)
            .coordinateSpace(.named(Self.scrollCoordinateSpace))
            .onScrollPhaseChange { _, newPhase in
                guard let settledEntryID = LibraryRecordScrollSelection.settledEntryID(
                    scrollTargetID: scrollTargetID,
                    selectedEntryID: selectedEntryID,
                    isIdle: newPhase == .idle,
                    availableEntryIDs: entries.map(\.id)
                ) else {
                    return
                }

                onSelectEntry(settledEntryID)
            }
            .zIndex(10)

            TurntableTonearmView(isPlaying: isPlaying, reduceMotion: reduceMotion)
                .zIndex(30)

            VStack {
                Spacer()
                LibraryPageIndicatorView(count: entries.count, selectedIndex: selectedIndex)
                    .padding(.bottom, 12)
            }
            .zIndex(40)

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
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width in
            crateWidth = width
        }
        .simultaneousGesture(verticalDragGesture)
        .task(id: deletionHoldEntryID) {
            guard let entryID = deletionHoldEntryID else { return }

            do {
                try await Task.sleep(for: LibraryDesignTokens.deletionHoldDuration)
            } catch {
                return
            }

            guard deletionHoldEntryID == entryID,
                  allowsDestructiveActions,
                  entries.contains(where: { $0.id == entryID && $0.isBundled != true })
            else {
                return
            }

            onImmediateDelete(entryID)
            didDeleteDuringDrag = true
            cancelDeletionHold()
        }
        .onAppear {
            synchronizeScrollTarget(with: selectedEntryID)
        }
        .onChange(of: entries.map(\.id)) { _, entryIDs in
            if let scrollTargetID, entryIDs.contains(scrollTargetID) == false {
                self.scrollTargetID = nil
            }
            synchronizeScrollTarget(with: selectedEntryID)
        }
        .onChange(of: allowsDestructiveActions) { _, allowsDestructiveActions in
            if allowsDestructiveActions == false {
                cancelDeletionHold()
            }
        }
        .onChange(of: selectedEntryID) { _, selectedEntryID in
            cancelDeletionHold()
            synchronizeScrollTarget(with: selectedEntryID)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("唱片架，左右滚动选曲")
        .accessibilityAction(named: "删除曲目") {
            guard let selectedEntry,
                  selectedEntry.isBundled != true,
                  allowsDestructiveActions
            else {
                return
            }
            onImmediateDelete(selectedEntry.id)
        }
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

    private var verticalDragGesture: some Gesture {
        DragGesture(minimumDistance: 7)
            .onChanged { value in
                if verticalDragIsActive == nil {
                    verticalDragIsActive = abs(value.translation.height) > abs(value.translation.width)
                }

                guard verticalDragIsActive == true else { return }

                if value.translation.height < 0 {
                    cancelDeletionHold()
                    downwardDragOffset = 0
                    liftOffset = min(-value.translation.height, LibraryDesignTokens.liftMaximum)
                } else {
                    liftOffset = 0
                    downwardDragOffset = min(value.translation.height, LibraryDesignTokens.liftMaximum)
                    updateDeletionHold(for: value.translation.height)
                }
            }
            .onEnded { _ in
                if verticalDragIsActive == true,
                   liftOffset >= LibraryDesignTokens.liftTrigger,
                   didDeleteDuringDrag == false
                {
                    onImportMusicXML()
                }

                withAnimation(reduceMotion ? nil : LibraryDesignTokens.easeOut) {
                    liftOffset = 0
                    downwardDragOffset = 0
                }
                cancelDeletionHold()
                didDeleteDuringDrag = false
                verticalDragIsActive = nil
            }
    }

    private func updateDeletionHold(for downwardDragTranslation: CGFloat) {
        guard didDeleteDuringDrag == false,
              let selectedEntry,
              LibraryDeletionHoldPolicy.isArmed(
                  downwardDragTranslation: downwardDragTranslation,
                  isBundled: selectedEntry.isBundled == true,
                  allowsDestructiveActions: allowsDestructiveActions
              )
        else {
            cancelDeletionHold()
            return
        }

        guard deletionHoldEntryID != selectedEntry.id else { return }
        deletionHoldEntryID = selectedEntry.id
        deletionHoldStartedAt = .now
    }

    private func cancelDeletionHold() {
        deletionHoldEntryID = nil
        deletionHoldStartedAt = nil
    }

    private func handleRecordTap(entryID: UUID) {
        switch LibraryRecordScrollSelection.tapAction(
            entryID: entryID,
            selectedEntryID: selectedEntryID
        ) {
        case .togglePlayback:
            onTogglePlayback(entryID)
        case .select:
            select(entryID: entryID)
        }
    }

    private func select(index: Int) {
        guard entries.indices.contains(index) else { return }
        select(entryID: entries[index].id)
    }

    private func select(entryID: UUID) {
        withAnimation(reduceMotion ? nil : LibraryDesignTokens.easeOut) {
            scrollTargetID = entryID
        }
        onSelectEntry(entryID)
    }

    private func synchronizeScrollTarget(with selectedEntryID: UUID?) {
        guard let selectedEntryID,
              entries.contains(where: { $0.id == selectedEntryID })
        else {
            scrollTargetID = nil
            return
        }
        scrollTargetID = selectedEntryID
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
        onImmediateDelete: { _ in }
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
