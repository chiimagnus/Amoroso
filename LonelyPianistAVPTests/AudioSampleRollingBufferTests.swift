import Testing
@testable import LonelyPianistAVP

struct AudioSampleRollingBufferTests {
    @Test func rollingBufferKeepsLatestWindow() {
        var buffer = AudioSampleRollingBuffer(capacity: 4)
        buffer.append([1, 2, 3])
        buffer.append([4, 5])
        #expect(buffer.count == 4)
        #expect(buffer.window(size: 3) == [3, 4, 5])
        buffer.reset()
        #expect(buffer.window(size: 1) == nil)
    }
}
