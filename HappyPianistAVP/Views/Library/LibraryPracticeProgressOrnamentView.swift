import SwiftUI

struct LibraryPracticeProgressOrnamentView: View {
    let state: SongPracticeLibraryPresentationState

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch state {
            case .noSelection:
                LibraryPracticeMessageView(
                    systemImage: "music.note.list",
                    title: "选择一首曲目",
                    message: "这里会显示当前曲目的真实练习记录。"
                )
            case .loading:
                HStack(spacing: 12) {
                    ProgressView()
                    Text("正在读取练习记录…")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            case .neverPracticed:
                LibraryPracticeNeverView()
            case let .current(snapshot):
                LibraryPracticeCurrentSnapshotView(
                    snapshot: snapshot,
                    differentiateWithoutColor: differentiateWithoutColor
                )
            case let .needsRebuild(_, historyDate):
                LibraryPracticeMessageView(
                    systemImage: "arrow.trianglehead.2.clockwise.rotate.90",
                    title: "当前版本尚未建立进度",
                    message: "保留了历史记录（最近练习：\(historyDate.formatted(date: .abbreviated, time: .shortened))）。开始一次练习后会重建当前结构。"
                )
            case .unavailable:
                LibraryPracticeMessageView(
                    systemImage: "exclamationmark.triangle",
                    title: "暂时无法读取记录",
                    message: "仍可试听或进入练习窗口；已有数据不会在这里被修改。"
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("当前曲目练习概览")
    }
}

private struct LibraryPracticeNeverView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LibraryPracticeEmptyAnimationView()
                .frame(maxWidth: .infinity)

            Text("从第一小节开始")
                .font(.headline)
                .bold()
            Text("完成一次真实练习后，这里会显示稳定小节、练习中小节和恢复位置。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("尚未练习这首曲目")
        .accessibilityValue("完成一次练习后将显示练习事实")
    }
}

private struct LibraryPracticeCurrentSnapshotView: View {
    let snapshot: SongPracticeLibrarySnapshot
    let differentiateWithoutColor: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("练习概览", systemImage: "chart.bar.xaxis")
                .font(.headline)
                .bold()

            LabeledContent("最近练习") {
                Text(snapshot.latestPracticeDate, format: .dateTime.month().day().hour().minute())
            }

            if snapshot.totalSourceMeasureCount > 0 {
                Text("当前曲谱共 \(snapshot.totalSourceMeasureCount.formatted()) 个小节")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let facts = snapshot.currentFacts {
                LabeledContent("当前手别", value: facts.handMode.libraryDisplayName)

                HStack(spacing: 10) {
                    LibraryPracticeCountBadge(
                        title: "稳定",
                        count: facts.stableSourceMeasureCount,
                        systemImage: "checkmark.circle.fill",
                        emphasizedShape: differentiateWithoutColor
                    )
                    LibraryPracticeCountBadge(
                        title: "练习中",
                        count: facts.learningSourceMeasureCount,
                        systemImage: "clock.fill",
                        emphasizedShape: differentiateWithoutColor
                    )
                }

                if let resumeSourceMeasureID = facts.resumeSourceMeasureID {
                    LabeledContent(
                        "恢复位置",
                        value: "第 \(resumeSourceMeasureID.libraryMeasureText) 小节"
                    )
                }

                if let tempo = facts.highestStableTempoScale {
                    LabeledContent("最高稳定速度") {
                        Text(tempo, format: .percent.precision(.fractionLength(0)))
                    }
                }

                if facts.recentIssues.isEmpty == false {
                    Divider()
                    Text("最近需要留意")
                        .font(.subheadline)
                        .bold()
                    ForEach(facts.recentIssues.prefix(3), id: \.sourceMeasureID) { issue in
                        Label(
                            "第 \(issue.sourceMeasureID.libraryMeasureText) 小节 · \(issue.kind.libraryDisplayName)",
                            systemImage: issue.kind.librarySystemImage
                        )
                        .font(.caption)
                    }
                }
            } else {
                Label("当前曲谱版本尚未练习", systemImage: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct LibraryPracticeCountBadge: View {
    let title: String
    let count: Int
    let systemImage: String
    let emphasizedShape: Bool

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(count, format: .number)
                    .font(.title3)
                    .bold()
                Text(title)
                    .font(.caption)
            }
        } icon: {
            Image(systemName: systemImage)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: .rect(cornerRadius: 12))
        .overlay {
            if emphasizedShape {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.primary.opacity(0.35), lineWidth: 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(count.formatted())
    }
}

private struct LibraryPracticeMessageView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .bold()
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private extension PracticeHandMode {
    var libraryDisplayName: String {
        switch self {
        case .both: "双手"
        case .right: "右手"
        case .left: "左手"
        }
    }
}

private extension PracticeSourceMeasureID {
    var libraryMeasureText: String {
        sourceNumberToken ?? (sourceMeasureIndex + 1).formatted()
    }
}

private extension PracticeIssueKind {
    var libraryDisplayName: String {
        switch self {
        case .wrongNote: "错音"
        case .missedNote: "漏音"
        case .incompleteChord: "和弦不完整"
        }
    }

    var librarySystemImage: String {
        switch self {
        case .wrongNote: "music.note"
        case .missedNote: "music.note.slash"
        case .incompleteChord: "square.stack.3d.up"
        }
    }
}
