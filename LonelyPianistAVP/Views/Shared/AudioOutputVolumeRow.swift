import SwiftUI

struct AudioOutputVolumeRow: View {
    @AppStorage(AudioOutputVolumeSettings.userDefaultsKey)
    private var audioOutputVolume = Double(AudioOutputVolumeSettings.defaultValue)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("输出音量")
            HStack {
                Slider(value: $audioOutputVolume, in: 0...1)
                Text(audioOutputVolume, format: .percent)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .trailing)
            }
        }
    }
}

