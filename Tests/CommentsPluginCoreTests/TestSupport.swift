import Foundation
import Testing
@testable import CommentsPluginCore

struct Selection: Equatable, CustomStringConvertible {
    var start: CommentPosition
    var end: CommentPosition

    init(_ startLine: Int, _ startColumn: Int, _ endLine: Int, _ endColumn: Int) {
        start = CommentPosition(line: startLine, column: startColumn)
        end = CommentPosition(line: endLine, column: endColumn)
    }

    var description: String { "\(start.line):\(start.column)-\(end.line):\(end.column)" }
}

final class LegacyRange {
    var start: CommentPosition
    var end: CommentPosition
    init(_ selection: Selection) { start = selection.start; end = selection.end }
}

extension LegacyRange: CommentTextRange {
    var commentStart: CommentPosition {
        get { start }
        set { start = newValue }
    }
    var commentEnd: CommentPosition {
        get { end }
        set { end = newValue }
    }
}

final class LegacyInvocation {
    struct Buffer {
        let lines: NSMutableArray
        let selections: NSMutableArray
    }
    let buffer: Buffer
    init(lines: NSMutableArray, selections: [Selection]) {
        buffer = Buffer(lines: lines, selections: NSMutableArray(array: selections.map(LegacyRange.init)))
    }
}

struct Snapshot: Equatable {
    var lines: [String]
    var selections: [Selection]
}

func applyCurrent(to lines: NSMutableArray, selections: [Selection]) -> [Selection] {
    let ranges = selections.map(LegacyRange.init)
    var completions = 0
    CommentToggle.perform(lines: lines, selections: NSArray(array: ranges)) { error in
        expectNil(error)
        completions += 1
    }
    expectEqual(completions, 1)
    return ranges.map { Selection($0.start.line, $0.start.column, $0.end.line, $0.end.column) }
}

func current(_ lines: [String], _ selections: [Selection]) -> Snapshot {
    let buffer = NSMutableArray(array: lines)
    let result = applyCurrent(to: buffer, selections: selections)
    return Snapshot(lines: buffer.map { $0 as! String }, selections: result)
}

func legacy(_ lines: [String], _ selections: [Selection]) -> Snapshot {
    let invocation = LegacyInvocation(lines: NSMutableArray(array: lines), selections: selections)
    var completions = 0
    LegacySourceEditorCommand().perform(with: invocation) { error in
        expectNil(error)
        completions += 1
    }
    expectEqual(completions, 1)
    return Snapshot(lines: invocation.buffer.lines.map { $0 as! String },
                    selections: invocation.buffer.selections.map {
                        let range = $0 as! LegacyRange
                        return Selection(range.start.line, range.start.column, range.end.line, range.end.column)
                    })
}

struct SeededRandom {
    var state: UInt64 = 0xC0FFEE
    mutating func next(_ upperBound: Int) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Int((state >> 32) % UInt64(upperBound))
    }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "",
                               file: StaticString = #filePath, line: UInt = #line) {
    #expect(actual == expected, Comment(rawValue: message),
            sourceLocation: SourceLocation(fileID: "CommentsPluginCoreTests/" + URL(fileURLWithPath: String(describing: file)).lastPathComponent,
                                           filePath: String(describing: file), line: Int(line), column: 1))
}

func expectNil(_ error: Error?) {
    #expect(error == nil)
}
