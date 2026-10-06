import Foundation
import Testing
@testable import CommentsPluginCore

// Opt in with COMMENTS_PLUGIN_BENCHMARK=1 swift test -c release --disable-xctest --filter CommentTogglePerformanceTests
// No wall-clock assertions: these measurements should not make normal CI flaky.
@Suite(.serialized)
struct CommentTogglePerformanceTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["COMMENTS_PLUGIN_BENCHMARK"] == "1"))
    func compareWithLegacy() {
        let count = 50_000
        let workloads: [(String, [String])] = [
            ("comment 50k lines", (0..<count).map { "    let value\($0) = \($0)\n" }),
            ("uncomment 50k lines", (0..<count).map { "    // let value\($0) = \($0)\n" }),
            ("mixed Unicode 50k lines", (0..<count).map { $0 % 7 == 0 ? "\n" : "    // print(\"中文 👩‍💻 \($0)\")\n" }),
            ("blank 50k lines", Array(repeating: "    \n", count: count)),
            ("long lines 10 MB", Array(repeating: "    " + String(repeating: "abcdef", count: 1_700) + "\n", count: 1_000))
        ]
        for (name, input) in workloads {
            let selection = Selection(0, 0, input.count - 1, input.last!.count)
            // Warm both paths and verify every workload independently of timing.
            expectEqual(current(input, [selection]), legacy(input, [selection]))
            var oldSamples: [Double] = []
            var newSamples: [Double] = []
            for sample in 0..<7 {
                // Alternate execution order; allocate buffers outside the timed region.
                let oldInvocation = LegacyInvocation(lines: NSMutableArray(array: input), selections: [selection])
                let newLines = NSMutableArray(array: input)
                let newRange = LegacyRange(selection)
                let newSelections = NSArray(array: [newRange])
                let oldRun = {
                    let start = DispatchTime.now().uptimeNanoseconds
                    LegacySourceEditorCommand().perform(with: oldInvocation) { _ in }
                    oldSamples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
                }
                let newRun = {
                    let start = DispatchTime.now().uptimeNanoseconds
                    CommentToggle.perform(lines: newLines, selections: newSelections) { _ in }
                    newSamples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
                }
                if sample.isMultiple(of: 2) { oldRun(); newRun() } else { newRun(); oldRun() }
                expectEqual(newLines, oldInvocation.buffer.lines)
                let oldRange = oldInvocation.buffer.selections[0] as! LegacyRange
                expectEqual(newRange.start, oldRange.start)
                expectEqual(newRange.end, oldRange.end)
            }
            let oldMedian = oldSamples.sorted()[oldSamples.count / 2]
            let newMedian = newSamples.sorted()[newSamples.count / 2]
            print(String(format: "BENCHMARK %@ | legacy %.2f ms | optimized %.2f ms | %.2fx", name, oldMedian, newMedian, oldMedian / newMedian))
        }
    }
}
