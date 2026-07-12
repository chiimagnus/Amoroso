import SwiftUI

struct LibraryPracticeSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("练习概览")
                    .font(.headline)
                Text("正在准备曲谱…")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                LibraryPracticeSkeletonLine(width: 180)
                LibraryPracticeSkeletonLine(width: 250)
                LibraryPracticeSkeletonLine(width: 220)
            }

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                Text("练习设置")
                    .font(.headline)
                LibraryPracticeSkeletonControl()
                LibraryPracticeSkeletonControl()
                LibraryPracticeSkeletonControl()
                LibraryPracticeSkeletonControl()
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("正在准备曲谱")
    }
}

private struct LibraryPracticeSkeletonLine: View {
    let width: CGFloat

    var body: some View {
        Text("占位内容")
            .frame(width: width, alignment: .leading)
    }
}

private struct LibraryPracticeSkeletonControl: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.quaternary)
            .frame(height: 42)
    }
}
