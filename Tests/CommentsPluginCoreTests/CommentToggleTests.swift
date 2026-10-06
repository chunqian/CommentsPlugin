import Foundation
import Testing
@testable import CommentsPluginCore

struct CommentToggleTests {
    private func check(_ input: [String], _ selection: Selection, _ output: [String],
                       _ expectedSelection: Selection? = nil,
                       file: StaticString = #filePath, line: UInt = #line) {
        let actual = current(input, [selection])
        expectEqual(actual.lines, output, file: file, line: line)
        if let expectedSelection = expectedSelection {
            expectEqual(actual.selections, [expectedSelection], file: file, line: line)
        }
        expectEqual(actual, legacy(input, [selection]), file: file, line: line)
    }

    @Test func testSingleLineCommentAndCursor() {
        check(["    let a = 1\n"], Selection(0, 4, 0, 9), ["    // let a = 1\n"], Selection(0, 7, 0, 12))
        check(["    value\n"], Selection(0, 1, 0, 8), ["    // value\n"], Selection(0, 1, 0, 8))
    }

    @Test func testUncommentRemovesOnlyOneOptionalASCIISpace() {
        for (input, output) in [("//value\n", "value\n"), ("// value\n", "value\n"),
                                ("//  value\n", " value\n"), ("//\tvalue\n", "\tvalue\n"),
                                ("/// docs\n", "/ docs\n"), ("////\n", "//\n"),
                                ("//\u{00A0}value\n", "\u{00A0}value\n")] {
            check([input], Selection(0, 2, 0, input.count), [output])
        }
    }

    @Test func testUncommentCursorAlwaysSubtractsThreeEvenWithoutSpace() {
        check(["  //value\n"], Selection(0, 6, 0, 8), ["  value\n"], Selection(0, 3, 0, 5))
        check(["  // value\n"], Selection(0, 2, 0, 3), ["  value\n"], Selection(0, 2, 0, 2))
        check(["  // value\n"], Selection(0, 0, 0, 10), ["  value\n"], Selection(0, 0, 0, 10))
    }

    @Test func testMultilineUsesMinimumIndentAndSkipsBlankLines() {
        check(["    a\n", "\n", "  b\n", " \t\n"], Selection(0, 4, 3, 2),
              ["  //   a\n", "\n", "  // b\n", " \t\n"], Selection(0, 7, 3, 2))
    }

    @Test func testMixedCommentsAreCommentedTogether() {
        check(["  // a\n", "  b\n"], Selection(0, 0, 1, 3),
              ["  // // a\n", "  // b\n"], Selection(0, 0, 1, 6))
    }

    @Test func testUnevenCommentIndentationPreservesLegacyPartialUncomment() {
        check(["  // a\n", "    // b\n"], Selection(0, 4, 1, 7),
              ["  a\n", "    // b\n"], Selection(0, 2, 1, 7))
    }

    @Test func testEndAtColumnZeroExcludesLastLine() {
        check(["a\n", "b\n", "c\n"], Selection(0, 0, 2, 0),
              ["// a\n", "// b\n", "c\n"], Selection(0, 3, 2, 3))
        check(["a\n", "b\n"], Selection(0, 0, 1, 0),
              ["// a\n", "b\n"], Selection(0, 3, 1, 3))
        check(["a\n"], Selection(0, 0, 0, 0), ["// a\n"], Selection(0, 3, 0, 3))
    }

    @Test func testBlankLinesFollowSingleLineColumnAccumulation() {
        check(["\n", "\n", "\n"], Selection(0, 0, 2, 1),
              ["// \n", "// \n", "// \n"], Selection(0, 4, 2, 4))
        check(["    \n"], Selection(0, 0, 0, 0), ["    // \n"], Selection(0, 8, 0, 8))
        check(["  \n", "    \n"], Selection(0, 0, 1, 1),
              ["  // \n", "  //   \n"], Selection(0, 8, 1, 8))
    }

    @Test func testWhitespaceWithoutNewlineAndEmptyStrings() {
        for value in ["", " ", "\t", " \t ", "\u{00A0}", "\u{3000}"] {
            check([value], Selection(0, 0, 0, 0), [value], Selection(0, 0, 0, 0))
        }
        check(["\n", "    "], Selection(0, 0, 1, 1), ["// \n", "//     "])
        check(["", "\n", ""], Selection(0, 0, 2, 1), ["", "// \n", ""])
    }

    @Test func testNewlineStylesAndNoFinalNewline() {
        for ending in ["\n", "\r", "\r\n", "\u{2028}", "\u{2029}", ""] {
            check(["  value" + ending], Selection(0, 2, 0, 4), ["  // value" + ending])
            check(["  // value" + ending], Selection(0, 5, 0, 7), ["  value" + ending])
        }
        // CRLF is one Character: the legacy blank-line cursor exception does not treat it as LF.
        check(["  \r\n"], Selection(0, 0, 0, 0), ["  // \r\n"], Selection(0, 0, 0, 0))
    }

    @Test func testTabsAreColumnsNotExpandedIndentation() {
        check(["\tfoo\n", "  bar\n"], Selection(0, 1, 1, 2),
              ["\t// foo\n", " //  bar\n"], Selection(0, 4, 1, 5))
    }

    @Test func testUnicodeContentKeepsLegacyCharacterCountClamping() {
        for text in ["中文", "🙂", "👨‍👩‍👧‍👦", "e\u{301}", "🇨🇳"] {
            let input = "  " + text + "\n"
            check([input], Selection(0, input.utf16.count, 0, input.utf16.count),
                  ["  // " + text + "\n"], Selection(0, input.count + 3, 0, input.count + 3))
        }
    }

    @Test func testCombiningCharactersAtCommentBoundary() {
        for input in ["//\u{301}x\n", "/\u{301}/x\n", "// \u{301}x\n", " \u{301}//x\n",
                      "\u{00A0}\u{301}// x\n", "//\u{FE0F}x\n", "\n//x\n"] {
            expectEqual(current([input], [Selection(0, 0, 0, 8)]),
                           legacy([input], [Selection(0, 0, 0, 8)]), input.debugDescription)
        }
    }

    @Test func testOnlySelectedLinesChange() {
        check(["before\n", "  a\n", "  b\n", "after\n"], Selection(1, 2, 2, 3),
              ["before\n", "  // a\n", "  // b\n", "after\n"])
    }

    @Test func testMultipleSelectionsUseFirstStartAndLastEnd() {
        let input = ["a\n", "b\n", "c\n", "d\n"]
        let ranges = [Selection(0, 0, 0, 1), Selection(2, 0, 2, 1), Selection(3, 0, 3, 1)]
        let actual = current(input, ranges)
        expectEqual(actual.lines, input.map { "// " + $0 })
        expectEqual(actual.selections, [Selection(0, 3, 0, 1), ranges[1], Selection(3, 0, 3, 4)])
        expectEqual(actual, legacy(input, ranges))
    }

    @Test func testBlankMultipleSelectionsUpdateOnlyFirstSelection() {
        let ranges = [Selection(0, 0, 0, 0), Selection(1, 0, 1, 1)]
        let actual = current(["\n", "\n"], ranges)
        expectEqual(actual.selections, [Selection(0, 4, 0, 4), ranges[1]])
        expectEqual(actual, legacy(["\n", "\n"], ranges))
    }

    @Test func testNoSelectionsAndEmptyBuffer() {
        expectEqual(current(["a\n"], []), Snapshot(lines: ["a\n"], selections: []))
        expectEqual(current([], [Selection(0, 0, 0, 0)]), legacy([], [Selection(0, 0, 0, 0)]))
    }

    @Test func testOutOfBoundsEndAndVirtualEOF() {
        for selection in [Selection(0, 0, 2, 0), Selection(0, 0, 8, 1),
                          Selection(2, 0, 2, 0), Selection(9, 0, 10, 0)] {
            expectEqual(current(["a\n", "b"], [selection]), legacy(["a\n", "b"], [selection]))
        }
    }

    @Test func testNonStringBufferEntriesAreSkipped() {
        for input: [Any] in [[NSNumber(value: 7)], ["  a\n", NSNumber(value: 7), "  b\n"],
                             [NSNull(), "\n", "    "]] {
            let selection = Selection(0, 0, input.count - 1, 1)
            let actual = NSMutableArray(array: input)
            let ranges = applyCurrent(to: actual, selections: [selection])
            let reference = LegacyInvocation(lines: NSMutableArray(array: input), selections: [selection])
            LegacySourceEditorCommand().perform(with: reference) { expectNil($0) }
            expectEqual(actual, reference.buffer.lines)
            let range = reference.buffer.selections[0] as! LegacyRange
            expectEqual(ranges, [Selection(range.start.line, range.start.column, range.end.line, range.end.column)])
        }
    }

    @Test func testDoubleToggleRestoresUniformUncommentedText() {
        let input = ["  let a = 1\n", "\n", "  print(a)\n"]
        let selection = Selection(0, 2, 2, 10)
        let first = current(input, [selection])
        let second = current(first.lines, first.selections)
        expectEqual(second, Snapshot(lines: input, selections: [selection]))
    }

    @Test func testLongLineAndDeepIndentation() {
        for input in [String(repeating: " ", count: 40_000) + "value\n",
                      "  " + String(repeating: "👩‍💻abc", count: 20_000) + "\n"] {
            let range = Selection(0, input.utf16.count, 0, input.utf16.count)
            expectEqual(current([input], [range]), legacy([input], [range]))
        }
    }

    @Test func testExhaustiveSingleLineColumnBoundaries() {
        let samples = ["", "\n", "  \n", "\t\n", "   ", "a", " a\n", "//", "// ",
                       "  //a\n", "  // a\n", "//\t\n", "🙂\n", "e\u{301}\r\n", "\u{3000}x\n"]
        for input in samples {
            for start in 0...(input.utf16.count + 2) {
                for end in start...(input.utf16.count + 2) {
                    let selection = Selection(0, start, 0, end)
                    expectEqual(current([input], [selection]), legacy([input], [selection]),
                                   "input=\(input.debugDescription), selection=\(selection)")
                }
            }
        }
    }

    @Test func testSeededDifferentialSelectionsAndRepeatedToggles() {
        let indents = ["", " ", "    ", "\t", "\t ", "\u{00A0}", "\u{3000}", "\u{2003}", "\u{200B}"]
        let contents = ["", " ", "a", "let x = 1", "//", "// ", "// x", "//x", "/// doc", "/* x */",
                        "👩‍💻", "e\u{301}", "中文", "//\u{301}x", "// \u{301}", "\n// x", "\u{301}//x"]
        let endings = ["", "\n", "\r", "\r\n", "\u{2028}", "\u{2029}", "\u{0085}", "\u{000B}", "\u{000C}"]
        var random = SeededRandom()
        for iteration in 0..<10_000 {
            let input = (0..<random.next(15)).map { _ in
                indents[random.next(indents.count)] + contents[random.next(contents.count)] + endings[random.next(endings.count)]
            }
            let start = random.next(input.count + 2)
            let end = start + random.next(input.count + 3 - start)
            let first = Selection(start, random.next(18), end, random.next(18))
            var selections = [first]
            if random.next(3) == 0 {
                selections = [Selection(start, first.start.column, start, random.next(12)),
                              Selection(end, random.next(12), end, first.end.column)]
            }
            var actual = current(input, selections)
            var reference = legacy(input, selections)
            expectEqual(actual, reference, "seed iteration \(iteration), input=\(input), selections=\(selections)")
            for _ in 0..<2 {
                actual = current(actual.lines, actual.selections)
                reference = legacy(reference.lines, reference.selections)
                expectEqual(actual, reference, "repeated toggle, iteration \(iteration)")
            }
        }
    }
}
