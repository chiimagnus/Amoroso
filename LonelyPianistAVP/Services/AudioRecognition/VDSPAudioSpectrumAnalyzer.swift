import Foundation
#if canImport(Accelerate)
import Accelerate
#endif

protocol AudioSpectrumAnalyzing: Sendable {
    func analyze(samples: [Float], sampleRate: Double, timestamp: Date) throws -> AudioSpectrumFrame
}

struct VDSPAudioSpectrumAnalyzer: AudioSpectrumAnalyzing {
    enum AnalyzerError: LocalizedError {
        case invalidInput
        var errorDescription: String? { "Invalid audio samples for spectrum analysis." }
    }

    init() {}

    func analyze(samples: [Float], sampleRate: Double, timestamp: Date) throws -> AudioSpectrumFrame {
        guard samples.isEmpty == false, sampleRate > 0 else { throw AnalyzerError.invalidInput }
        let rms = Self.rms(samples)
        let onsetScore = rms > 0 ? 1.0 : 0.0
        let spectrum = Self.magnitudeSpectrum(samples: samples, sampleRate: sampleRate)
        return AudioSpectrumFrame(
            sampleRate: sampleRate,
            windowSize: samples.count,
            rms: rms,
            noiseFloor: 1e-9,
            onsetScore: onsetScore,
            isOnset: onsetScore >= 0.25,
            timestamp: timestamp,
            frequencyBins: spectrum.frequencies,
            magnitudes: spectrum.magnitudes
        )
    }

    private static func rms(_ samples: [Float]) -> Double {
        let sum = samples.reduce(0.0) { $0 + Double($1 * $1) }
        return sqrt(sum / Double(max(samples.count, 1)))
    }

    private static func magnitudeSpectrum(samples: [Float], sampleRate: Double) -> (frequencies: [Double], magnitudes: [Double]) {
        #if canImport(Accelerate)
        if let accelerated = accelerateMagnitudeSpectrum(samples: samples, sampleRate: sampleRate) {
            return accelerated
        }
        #endif
        return naiveMagnitudeSpectrum(samples: samples, sampleRate: sampleRate)
    }

    #if canImport(Accelerate)
    private static func accelerateMagnitudeSpectrum(samples: [Float], sampleRate: Double) -> (frequencies: [Double], magnitudes: [Double])? {
        let count = samples.count
        guard count >= 2, count.isPowerOfTwo else { return nil }
        let halfCount = count / 2
        let log2n = vDSP_Length(log2(Double(count)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return nil }
        defer { vDSP_destroy_fftsetup(setup) }

        var window = [Float](repeating: 0, count: count)
        vDSP_hann_window(&window, vDSP_Length(count), Int32(vDSP_HANN_NORM))
        var windowed = [Float](repeating: 0, count: count)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(count))

        var real = [Float](repeating: 0, count: halfCount)
        var imag = [Float](repeating: 0, count: halfCount)
        return real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                windowed.withUnsafeBufferPointer { windowedPtr in
                    windowedPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfCount) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(halfCount))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                var magnitudes = [Float](repeating: 0, count: halfCount)
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(halfCount))
                let frequencies = (0..<halfCount).map { Double($0) * sampleRate / Double(count) }
                return (frequencies, magnitudes.map(Double.init))
            }
        }
    }
    #endif

    private static func naiveMagnitudeSpectrum(samples: [Float], sampleRate: Double) -> (frequencies: [Double], magnitudes: [Double]) {
        let count = samples.count
        guard count > 1 else { return ([], []) }
        let binCount = count / 2
        var frequencies: [Double] = []
        var magnitudes: [Double] = []
        let maxStoredBins = 1024
        let step = max(1, binCount / maxStoredBins)
        var bin = 1
        while bin < binCount {
            let frequency = Double(bin) * sampleRate / Double(count)
            var real = 0.0
            var imaginary = 0.0
            for index in samples.indices {
                let phase = 2.0 * Double.pi * Double(bin) * Double(index) / Double(count)
                let window = 0.5 - 0.5 * cos(2.0 * Double.pi * Double(index) / Double(max(count - 1, 1)))
                let value = Double(samples[index]) * window
                real += value * cos(phase)
                imaginary -= value * sin(phase)
            }
            frequencies.append(frequency)
            magnitudes.append(real * real + imaginary * imaginary)
            bin += step
        }
        return (frequencies, magnitudes)
    }
}

private extension Int {
    var isPowerOfTwo: Bool {
        self > 0 && (self & (self - 1)) == 0
    }
}
