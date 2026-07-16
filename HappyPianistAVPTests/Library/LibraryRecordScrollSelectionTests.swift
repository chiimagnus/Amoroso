@testable import HappyPianistAVP
import CoreGraphics
import Testing

@Test
func recordScrollPresentationWeakensWithDistance() {
    let centered = LibraryRecordScrollPresentation(centerDistance: 0)
    let neighbor = LibraryRecordScrollPresentation(
        centerDistance: LibraryDesignTokens.recordDiameter + LibraryDesignTokens.recordSpacing
    )

    #expect(centered.scale == 1)
    #expect(centered.opacity == 1)
    #expect(centered.saturation == 1)
    #expect(neighbor.scale < centered.scale)
    #expect(neighbor.opacity < centered.opacity)
    #expect(neighbor.saturation < centered.saturation)
}

@Test
func recordScrollPresentationIsSymmetricAndClamped() {
    let step = LibraryDesignTokens.recordDiameter + LibraryDesignTokens.recordSpacing
    let left = LibraryRecordScrollPresentation(centerDistance: -step)
    let right = LibraryRecordScrollPresentation(centerDistance: step)
    let far = LibraryRecordScrollPresentation(centerDistance: step * 20)

    #expect(left == right)
    #expect(far.scale == 0.70)
    #expect(far.opacity == 0.40)
    #expect(far.saturation == 0.72)
}

@Test
func recordTapUsesSelectionOnlyForNonselectedRecords() {
    let selectedID = UUID()
    let otherID = UUID()

    #expect(
        LibraryRecordScrollSelection.tapAction(
            entryID: selectedID,
            selectedEntryID: selectedID
        ) == .togglePlayback
    )
    #expect(
        LibraryRecordScrollSelection.tapAction(
            entryID: otherID,
            selectedEntryID: selectedID
        ) == .select
    )
}

@Test
func settledScrollCommitsOnlyAValidChangedIdleTarget() {
    let selectedID = UUID()
    let targetID = UUID()
    let availableIDs = [selectedID, targetID]

    #expect(
        LibraryRecordScrollSelection.settledEntryID(
            scrollTargetID: targetID,
            selectedEntryID: selectedID,
            isIdle: true,
            availableEntryIDs: availableIDs
        ) == targetID
    )
    #expect(
        LibraryRecordScrollSelection.settledEntryID(
            scrollTargetID: targetID,
            selectedEntryID: selectedID,
            isIdle: false,
            availableEntryIDs: availableIDs
        ) == nil
    )
    #expect(
        LibraryRecordScrollSelection.settledEntryID(
            scrollTargetID: selectedID,
            selectedEntryID: selectedID,
            isIdle: true,
            availableEntryIDs: availableIDs
        ) == nil
    )
    #expect(
        LibraryRecordScrollSelection.settledEntryID(
            scrollTargetID: UUID(),
            selectedEntryID: selectedID,
            isIdle: true,
            availableEntryIDs: availableIDs
        ) == nil
    )
}
