import Foundation
import Testing
@testable import CommentsPluginCore

@Suite(.serialized)
struct ExternalSourcePerformanceTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["COMMENTS_PLUGIN_BENCHMARK_FILE"] != nil))
    func wholeFile() throws {
        let path = try #require(ProcessInfo.processInfo.environment["COMMENTS_PLUGIN_BENCHMARK_FILE"])
        let source = try String(contentsOfFile: path, encoding: .utf8)
        let lines = splitSourceLines(source)
        expectEqual(lines.joined(), source)
        let selection = Selection(0, 0, lines.count - 1, (lines.last! as NSString).length)
        let commented = legacy(lines, [selection])
        for (name, input, selections) in [("comment", lines, [selection]),
                                           ("uncomment", commented.lines, commented.selections)] {
            let reference = legacy(input, selections)
            expectEqual(current(input, selections), reference)
            var samples: [Double] = []
            var stagedSamples: [Double] = []
            for _ in 0..<11 {
                let buffer = NSMutableArray(array: input)
                let ranges = NSArray(array: selections.map(LegacyRange.init))
                let begin = DispatchTime.now().uptimeNanoseconds
                CommentToggle.perform(lines: buffer, selections: ranges) { _ in }
                samples.append(Double(DispatchTime.now().uptimeNanoseconds - begin) / 1_000_000)
                expectEqual(buffer as! [String], reference.lines)

                // Includes staging, joining, and a fake editor text/selection reset.
                // This measures local work, not Xcode UI, IPC, or syntax highlighting.
                let editor = RecordingTextBuffer(input, selections)
                let editorLines = editor.lines
                let stagedBegin = DispatchTime.now().uptimeNanoseconds
                CommentToggle.perform(buffer: editor) { _ in }
                stagedSamples.append(Double(DispatchTime.now().uptimeNanoseconds - stagedBegin) / 1_000_000)
                expectEqual(editor.completeBufferWrites, 1)
                expectEqual(editorLines as! [String], input)
                expectEqual(editor.snapshot, reference)
            }
            print(String(format: "SOURCE BENCHMARK %@ | %d lines | %.3f ms", name, input.count, samples.sorted()[samples.count / 2]))
            print(String(format: "STAGED BENCHMARK %@ | %.3f ms | 1 complete-buffer write, 0 live line writes", name, stagedSamples.sorted()[stagedSamples.count / 2]))
        }
    }
}
