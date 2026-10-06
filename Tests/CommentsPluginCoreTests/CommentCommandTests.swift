import Foundation
import Testing
@testable import CommentsPluginCore

struct CommentCommandTests {
    @Test func testMissingOrInvalidSelectionEndpointsCompleteOnceWithoutChanges() {
        let validRange = LegacyRange(Selection(0, 0, 0, 1))
        let invalidRange = LegacyRange(Selection(-1, 0, 0, 1))
        for selections: [Any] in [[], [NSNull()], [NSNull(), validRange],
                                  [validRange, NSNull()], [invalidRange]] {
            let lines = NSMutableArray(array: ["value\n"])
            var completions = 0
            CommentToggle.perform(lines: lines, selections: NSArray(array: selections)) { error in
                expectNil(error)
                completions += 1
                expectEqual(lines as! [String], ["value\n"])
            }
            expectEqual(completions, 1)
            expectEqual(validRange.start, CommentPosition(line: 0, column: 0))
            expectEqual(validRange.end, CommentPosition(line: 0, column: 1))
        }
    }

    @Test func testCompletionSeesUpdatedTextAndSelectionObjects() {
        let first = LegacyRange(Selection(0, 0, 0, 1))
        let last = LegacyRange(Selection(2, 0, 2, 1))
        let selections = NSMutableArray(array: [first, NSNull(), last])
        let lines = NSMutableArray(array: ["a\n", "b\n", "c\n"])
        var completions = 0
        CommentToggle.perform(lines: lines, selections: selections) { error in
            expectNil(error)
            completions += 1
            expectEqual(lines as! [String], ["// a\n", "// b\n", "// c\n"])
            expectEqual(first.start.column, 3)
            expectEqual(first.end.column, 1)
            expectEqual(last.start.column, 0)
            expectEqual(last.end.column, 4)
            #expect(selections[0] as? LegacyRange === first)
            #expect(selections[2] as? LegacyRange === last)
            #expect(selections[1] is NSNull)
        }
        expectEqual(completions, 1)
    }

    @Test func testSharedFirstAndLastSelectionObject() {
        let range = LegacyRange(Selection(0, 0, 1, 1))
        let selections = NSArray(array: [range, range])
        let lines = NSMutableArray(array: ["a\n", "b\n"])
        CommentToggle.perform(lines: lines, selections: selections) { expectNil($0) }
        expectEqual(lines as! [String], ["// a\n", "// b\n"])
        expectEqual(range.start, CommentPosition(line: 0, column: 3))
        expectEqual(range.end, CommentPosition(line: 1, column: 4))
    }

    @Test func testEmptyBufferStillCompletesAndPreservesLegacySelectionDestination() {
        let first = LegacyRange(Selection(0, 0, 0, 1))
        let last = LegacyRange(Selection(0, 0, 0, 4))
        var completions = 0
        CommentToggle.perform(lines: NSMutableArray(), selections: NSArray(array: [first, last])) { error in
            expectNil(error)
            completions += 1
        }
        expectEqual(completions, 1)
        expectEqual(first.end.column, 4)
        expectEqual(last.end.column, 4)
    }

    @Test func testMutableNSStringInputsAreReplacedWithoutMutatingSharedObjects() {
        let text = NSMutableString(string: "  a\n")
        let lines = NSMutableArray(array: [text, text])
        let range = LegacyRange(Selection(0, 2, 1, 3))
        CommentToggle.perform(lines: lines, selections: NSArray(array: [range])) { expectNil($0) }
        expectEqual(lines as! [String], ["  // a\n", "  // a\n"])
        expectEqual(text as String, "  a\n")
    }
}
