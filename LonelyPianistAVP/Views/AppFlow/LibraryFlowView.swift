import SwiftUI
import UniformTypeIdentifiers

struct LibraryFlowView: View {
    @Environment(AppRouter.self) private var router
    @Bindable var songLibraryViewModel: SongLibraryViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("重新选择钢琴类型") {
                    router.exitToTypePicker(reason: "user tapped back from library")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            SongLibraryView(
                viewModel: songLibraryViewModel,
                onStartPractice: {
                    router.goToPractice()
                }
            )
        }
        .frame(minWidth: 560, idealWidth: 700)
        .fileImporter(
            isPresented: $songLibraryViewModel.isMusicXMLImporterPresented,
            allowedContentTypes: [.xml, .musicXML],
            allowsMultipleSelection: true
        ) { result in
            do {
                let urls = try result.get()
                songLibraryViewModel.importMusicXML(from: urls)
            } catch {
                songLibraryViewModel.errorMessage = "导入失败：\(error.localizedDescription)"
            }
        }
    }
}
