import CoreML
import Foundation
@testable import HappyPianistAVP
import Testing

private func bundledPerformanceRNNModelExists() -> Bool {
    Bundle.main.url(forResource: "AIDuetPerformanceRNN", withExtension: "mlmodelc") != nil ||
        Bundle.main.url(forResource: "AIDuetPerformanceRNN", withExtension: "mlpackage") != nil
}

struct PerformanceRNNCoreMLModelLoaderTests {
    @Test func defaultConfigurationExcludesGPU() {
        #expect(PerformanceRNNCoreMLModelLoader.defaultConfiguration().computeUnits == .cpuAndNeuralEngine)
    }

    @Test func bundledModelLoadsWithoutGPU() async throws {
        guard bundledPerformanceRNNModelExists() else {
            return try await Test.skip("CoreML model is provided by pre-release resources")
        }

        _ = try await PerformanceRNNCoreMLModelLoader().loadStepModel()
    }
}
