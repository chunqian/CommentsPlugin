import Foundation
import Testing
@testable import CommentsPluginCore

/// Models the editor boundary. A complete-text write replaces its line view and
/// invalidates selections, so the production adapter must explicitly restore them.
final class RecordingTextBuffer: CommentTextBuffer {
    private(set) var lines: NSMutableArray
    let selections: NSMutableArray
    private(set) var completeBufferWrites = 0
    private(set) var completeBufferReads = 0
    private(set) var committedText: String?

    init(_ lines: [String], _ selections: [Selection]) {
        self.lines = NSMutableArray(array: lines)
        self.selections = NSMutableArray(array: selections.map(LegacyRange.init))
    }

    var completeBuffer: String {
        get {
            completeBufferReads += 1
            return (lines as! [String]).joined()
        }
        set {
            completeBufferWrites += 1
            committedText = newValue
            lines = NSMutableArray(array: splitSourceLines(newValue))
            // Cover a setter that mutates existing range instances AND replaces them.
            for case let range as LegacyRange in selections {
                range.start = CommentPosition(line: 99, column: 99)
                range.end = CommentPosition(line: 99, column: 99)
            }
            selections.setArray([LegacyRange(Selection(0, 0, 0, 0))])
        }
    }

    var snapshot: Snapshot {
        Snapshot(lines: lines as! [String], selections: selections.map {
            let range = $0 as! LegacyRange
            return Selection(range.start.line, range.start.column, range.end.line, range.end.column)
        })
    }
}

func splitSourceLines(_ source: String) -> [String] {
    let text = source as NSString
    var result: [String] = []
    var offset = 0
    while offset < text.length {
        var end = 0
        text.getLineStart(nil, end: &end, contentsEnd: nil, for: NSRange(location: offset, length: 0))
        result.append(text.substring(with: NSRange(location: offset, length: end - offset)))
        offset = end
    }
    // Xcode can represent the insertion point after the final newline as an empty line.
    if source.isEmpty || source.last == "\n" || source.last == "\r" || source.last == "\r\n" {
        result.append("")
    }
    return result
}

struct WholeFileBatchTests {
    private func check(_ input: [String], _ ranges: [Selection], batch: Bool,
                       file: StaticString = #filePath, line: UInt = #line) {
        let reference = legacy(input, ranges)
        let buffer = RecordingTextBuffer(input, ranges)
        let originalLines = buffer.lines
        var completions = 0
        CommentToggle.perform(buffer: buffer) { error in
            expectNil(error)
            completions += 1
            expectEqual((buffer.lines as! [String]).joined(), reference.lines.joined(), file: file, line: line)
            expectEqual(buffer.snapshot.selections, reference.selections, file: file, line: line)
        }
        expectEqual(completions, 1, file: file, line: line)
        expectEqual(buffer.completeBufferWrites, batch ? 1 : 0, file: file, line: line)
        expectEqual(buffer.completeBufferReads, 0, file: file, line: line)
        if batch {
            // No writes to the original editor line array, even before completion.
            expectEqual(originalLines as! [String], input, file: file, line: line)
        }
    }

    @Test func testWholeFileUsesOneCommitAndRestoresSelectionAfterEditorReset() {
        let input = (0..<7_925).map { $0 % 10 == 0 ? "\n" : "    print(\"中文 \($0)\")\n" } + [""]
        check(input, [Selection(0, 0, input.count - 1, 0)], batch: true)
        let first = legacy(input, [Selection(0, 0, input.count - 1, 0)])
        check(first.lines, first.selections, batch: true)
    }

    @Test func testBatchThresholdKeepsSmallEditsIncremental() {
        for count in [255, 256, 257] {
            let input = Array(repeating: "let value = 1\n", count: count)
            check(input, [Selection(0, 0, count, 0)], batch: count >= CommentToggle.wholeFileBatchMinimumLines)
        }
    }

    @Test func testPartialAndMultipleSelectionsKeepIncrementalPath() {
        let input = Array(repeating: "value\n", count: 1_000)
        check(input, [Selection(1, 0, input.count, 0)], batch: false)
        check(input, [Selection(0, 0, input.count - 1, 0)], batch: false)
        check(input, [Selection(0, 0, 2, 1), Selection(990, 0, 999, 1)], batch: false)
        check(input, [], batch: false)
    }

    @Test func testWholeLineCoverageWithNonzeroColumnsAndVirtualEOF() {
        let input = Array(repeating: "  value\n", count: 300)
        for range in [Selection(0, 1, 299, 1), Selection(0, 3, 300, 3),
                      Selection(0, 0, Int.max, 0)] {
            check(input, [range], batch: true)
        }
    }

    @Test func testEmptyNoOpDoesNotCommit() {
        let input = Array(repeating: "", count: 300)
        check(input, [Selection(0, 0, 300, 0)], batch: false)
    }

    @Test func testLineEndingsUnicodeAndMissingFinalNewline() {
        for newline in ["\n", "\r\n", "\r", "\u{2028}", "\u{2029}"] {
            for lastLine in ["", "final 👩‍💻", "final" + newline] {
                let input = (0..<300).map { $0 % 4 == 0 ? " " + newline : "    e\u{301} 中文" + newline } + [lastLine]
                check(input, [Selection(0, 0, input.count, 0)], batch: true)
            }
        }
    }

    @Test func testAllBlankBufferMatchesLegacyColumnAccumulation() {
        for input in [Array(repeating: " \n", count: 300), Array(repeating: "  \r\n", count: 300)] {
            check(input, [Selection(0, 0, input.count, 0)], batch: true)
        }
    }

    @Test func testMalformedAndNonStringBuffersDoNotEnterBatchPath() {
        let input = Array(repeating: "value\n", count: 300)
        for range in [Selection(0, -1, 300, 0), Selection(0, 0, 300, -1)] {
            let buffer = RecordingTextBuffer(input, [range])
            CommentToggle.perform(buffer: buffer) { expectNil($0) }
            expectEqual(buffer.snapshot, Snapshot(lines: input, selections: [range]))
            expectEqual(buffer.completeBufferWrites, 0)
        }
        let buffer = RecordingTextBuffer(input, [Selection(0, 0, 300, 0)])
        buffer.lines[100] = NSNull()
        CommentToggle.perform(buffer: buffer) { expectNil($0) }
        expectEqual(buffer.completeBufferWrites, 0)
        #expect(buffer.lines[100] is NSNull)
        expectEqual(buffer.lines[0] as? String, "// value\n")
    }

    @Test func testSeededWholeFileTogglesMatchLegacyIncludingSelectionPositions() {
        var random = SeededRandom()
        let indents = ["", "  ", "    ", "\t", "\u{3000}"]
        let bodies = ["", "value", "// value", "//value", "/// doc", "👩‍💻 中文", "e\u{301}", "//\u{301}x"]
        for iteration in 0..<200 {
            let ending = random.next(2) == 0 ? "\n" : "\r\n"
            let lines = (0..<(256 + random.next(256))).map { _ in
                indents[random.next(indents.count)] + bodies[random.next(bodies.count)] + ending
            } + [""]
            let ranges = [Selection(0, random.next(5), lines.count - 1, 0)]
            let buffer = RecordingTextBuffer(lines, ranges)
            var reference = Snapshot(lines: lines, selections: ranges)
            for _ in 0..<3 {
                reference = legacy(reference.lines, reference.selections)
                CommentToggle.perform(buffer: buffer) { expectNil($0) }
                expectEqual(buffer.snapshot, reference, "whole-file iteration \(iteration)")
            }
            expectEqual(buffer.completeBufferWrites, 3)
        }
    }
}
