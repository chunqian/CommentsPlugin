import Foundation
import Testing
@testable import CommentsPluginCore

struct CommentToggleBoundaryTests {
    @Test func testMalformedPositionsAreNoOps() {
        for selection in [Selection(-1, 0, 0, 0), Selection(1, 0, 0, 0),
                          Selection(0, -1, 0, 0), Selection(0, 0, 0, -1),
                          Selection(Int.min, 0, Int.max, 0)] {
            let lines = NSMutableArray(array: ["a\n", "b\n"])
            #expect(CommentToggle.apply(to: lines, start: selection.start, end: selection.end) == nil)
            expectEqual(lines as! [String], ["a\n", "b\n"])
        }
    }

    @Test func testExtremePositionsDoNotOverflowOrIteratePastBuffer() {
        let lines = ["a\n", "b\n"]
        expectEqual(current(lines, [Selection(Int.max, 0, Int.max, 0)]),
                    Snapshot(lines: lines, selections: [Selection(Int.max, 0, Int.max, 0)]))
        expectEqual(current(lines, [Selection(0, 0, Int.max, 1)]),
                    Snapshot(lines: ["// a\n", "// b\n"], selections: [Selection(0, 3, Int.max, 1)]))
        expectEqual(current(["a\n"], [Selection(0, Int.max, 0, Int.max)]),
                    Snapshot(lines: ["// a\n"], selections: [Selection(0, 5, 0, 5)]))
        expectEqual(current(["// a\n"], [Selection(0, Int.max, 0, Int.max)]),
                    Snapshot(lines: ["a\n"], selections: [Selection(0, Int.max - 3, 0, Int.max - 3)]))
    }

    @Test func testAllFoundationWhitespaceScalars() {
        // Foundation whitespace/newline classification is broader than ASCII.
        for codePoint: UInt32 in [0x9, 0xA, 0xB, 0xC, 0xD, 0x20, 0x85, 0xA0, 0x1680,
                                 0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005,
                                 0x2006, 0x2007, 0x2008, 0x2009, 0x200A, 0x200B,
                                 0x2028, 0x2029, 0x202F, 0x205F, 0x3000] {
            let space = String(UnicodeScalar(codePoint)!)
            for input in [[space], [space + "\n"], [space + "x\n", "  y\n"],
                          [space + "// x\n", "// y\n"], [space + "\u{301}//x\n", "\n"]] {
                for startColumn in [0, 1, 3, 10] {
                    let selection = Selection(0, startColumn, input.count - 1, 1)
                    expectEqual(current(input, [selection]), legacy(input, [selection]), "scalar \(codePoint)")
                }
            }
        }
    }

    @Test func testCommentPrefixGraphemeBoundaries() {
        for scalar: UInt32 in [0x0, 0x301, 0x34F, 0xFE0F, 0x200D, 0x20E3, 0x1F3FB, 0x1F600] {
            let suffix = String(UnicodeScalar(scalar)!)
            for prefix in ["//", "// ", "/", "  //", "\n//"] {
                let input = [prefix + suffix + "x\n", "  // y\n"]
                let range = Selection(0, 3, 1, 4)
                expectEqual(current(input, [range]), legacy(input, [range]), "scalar \(scalar), prefix \(prefix)")
            }
        }
    }

    @Test func testLargeBufferMatchesLegacy() {
        let input = (0..<20_000).map { index in
            index % 7 == 0 ? " \t\n" : "    print(\(index)) // 中文 👩‍💻\n"
        }
        let range = Selection(0, 0, input.count, 0)
        let actual = current(input, [range])
        expectEqual(actual, legacy(input, [range]))
        expectEqual(current(actual.lines, actual.selections), legacy(actual.lines, actual.selections))
    }
}
