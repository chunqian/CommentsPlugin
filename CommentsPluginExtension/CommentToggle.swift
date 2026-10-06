import Foundation

struct CommentPosition: Equatable {
    var line: Int
    var column: Int
}

struct CommentSelectionUpdate: Equatable {
    let startColumn: Int
    let endColumn: Int
    let updatesFirstSelectionOnly: Bool
    let changedLineCount: Int
}

/// Keeps selection mutation and completion handling testable without XcodeKit.
protocol CommentTextRange: AnyObject {
    var commentStart: CommentPosition { get set }
    var commentEnd: CommentPosition { get set }
}

/// XcodeKit buffers synchronize text and selections on every live mutation.
protocol CommentTextBuffer: AnyObject {
    var lines: NSMutableArray { get }
    var selections: NSMutableArray { get }
    var completeBuffer: String { get set }
}

/// Foundation-only core shared by the Xcode extension and the regression suite.
enum CommentToggle {
    // Small and partial edits keep XcodeKit's incremental line-update path.
    static let wholeFileBatchMinimumLines = 256
    private static let nonWhitespace = CharacterSet.whitespaces.inverted
    private static let nonWhitespaceOrNewline = CharacterSet.whitespacesAndNewlines.inverted

    private struct Line {
        let index: Int
        let text: NSString
        let isBlank: Bool
    }

    static func perform(buffer: CommentTextBuffer, completionHandler: (Error?) -> Void) {
        if performWholeFileEdit(buffer) {
            completionHandler(nil)
        } else {
            perform(lines: buffer.lines, selections: buffer.selections, completionHandler: completionHandler)
        }
    }

    private static func performWholeFileEdit(_ buffer: CommentTextBuffer) -> Bool {
        let lines = buffer.lines
        guard lines.count >= wholeFileBatchMinimumLines,
              buffer.selections.count == 1,
              let selection = buffer.selections.firstObject as? CommentTextRange else { return false }
        let start = selection.commentStart
        let end = selection.commentEnd
        guard start.line == 0, start.column >= 0, end.column >= 0,
              end.line >= lines.count - 1,
              let lastLine = lines.lastObject as? NSString else { return false }
        let endLine = end.column == 0 ? end.line - 1 : end.line
        guard endLine >= lines.count - 1 || (endLine == lines.count - 2 && lastLine.length == 0),
              let original = lines as? [String] else { return false }

        // Do not mutate the live XcodeKit lines array thousands of times: calculate
        // with an ordinary array, then cross the editor boundary exactly once.
        let stagedLines = NSMutableArray(array: original)
        guard let update = apply(to: stagedLines, start: start, end: end) else { return false }
        if update.changedLineCount == 0 { return true }
        let replacement = (stagedLines as! [String]).joined()
        buffer.completeBuffer = replacement

        // Setting completeBuffer may adjust or replace the selection objects.
        // Restore both positions from values captured before the live buffer write.
        selection.commentStart = CommentPosition(line: start.line, column: update.startColumn)
        selection.commentEnd = CommentPosition(line: end.line, column: update.endColumn)
        buffer.selections.setArray([selection])
        return true
    }

    static func perform(lines: NSMutableArray, selections: NSArray,
                        completionHandler: (Error?) -> Void) {
        defer { completionHandler(nil) }
        guard let first = selections.firstObject as? CommentTextRange,
              let last = selections.lastObject as? CommentTextRange,
              let update = apply(to: lines, start: first.commentStart, end: last.commentEnd)
        else { return }

        first.commentStart.column = update.startColumn
        if update.updatesFirstSelectionOnly {
            first.commentEnd.column = update.endColumn
        } else {
            last.commentEnd.column = update.endColumn
        }
    }

    static func apply(to lines: NSMutableArray, start: CommentPosition,
                      end: CommentPosition) -> CommentSelectionUpdate? {
        // Xcode normally supplies ordered, nonnegative positions. Treat malformed
        // ranges as a no-op instead of constructing a trapping range or array index.
        guard start.line >= 0, end.line >= start.line,
              start.column >= 0, end.column >= 0 else { return nil }

        let endLine = end.column == 0 && end.line > start.line ? end.line - 1 : end.line
        var startColumn = start.column
        var endColumn = end.column
        var changedLineCount = 0
        var selectedLines: [Line] = []
        var minimumIndent = NSNotFound
        var minimumCodeIndent = NSNotFound
        var hasCode = false
        var hasUncommentedLine = false
        var hasUncommentedCode = false

        // Analyze each selected line once. Scan prefixes instead of trimming whole
        // line bodies; only unusual Unicode comment prefixes need a String fallback.
        let limit = min(endLine, lines.count - 1)
        if start.line <= limit {
            selectedLines.reserveCapacity(limit - start.line + 1)
            for index in start.line...limit {
                guard let text = lines[index] as? NSString else { continue }
                let indent = text.rangeOfCharacter(from: nonWhitespace).location
                let codeStart = text.rangeOfCharacter(from: nonWhitespaceOrNewline).location
                let isBlank = codeStart == NSNotFound
                let isCommented = !isBlank && hasCommentPrefix(text, at: codeStart)
                selectedLines.append(Line(index: index, text: text, isBlank: isBlank))
                minimumIndent = min(minimumIndent, indent)
                hasUncommentedLine = hasUncommentedLine || !isCommented
                if !isBlank {
                    hasCode = true
                    minimumCodeIndent = min(minimumCodeIndent, indent)
                    hasUncommentedCode = hasUncommentedCode || !isCommented
                }
            }
        }

        let multiline = endLine > start.line && hasCode
        let commentIndex = multiline ? minimumCodeIndent : minimumIndent
        let shouldComment = multiline ? hasUncommentedCode : hasUncommentedLine

        for line in selectedLines {
            if multiline && line.isBlank { continue }
            guard commentIndex < line.text.length else { continue }

            let updated: String
            if shouldComment {
                updated = line.text.substring(to: commentIndex) + "// " + line.text.substring(from: commentIndex)
            } else {
                // Preserve the legacy behavior: only uncomment at the shared
                // indentation, even if a deeper-indented line also starts with //.
                guard hasCommentPrefix(line.text, at: commentIndex) else { continue }
                let spaceIndex = commentIndex + 2
                let removalCount = spaceIndex < line.text.length && line.text.character(at: spaceIndex) == 0x20 ? 3 : 2
                updated = line.text.substring(to: commentIndex) + line.text.substring(from: commentIndex + removalCount)
            }
            lines[line.index] = updated
            changedLineCount += 1

            // Interior lines do not affect a multiline selection. Avoid computing
            // their Swift Character counts (especially expensive for long Unicode lines).
            guard !multiline || line.index == start.line || line.index == endLine else { continue }
            let prefixCount = line.text.substring(to: commentIndex).count
            if !multiline {
                if startColumn >= prefixCount {
                    if shouldComment {
                        let count = updated.count
                        startColumn = addingMarker(to: startColumn, clampedTo: count)
                        endColumn = addingMarker(to: endColumn, clampedTo: count)
                    } else {
                        startColumn = max(startColumn - 3, commentIndex)
                        endColumn = max(endColumn - 3, commentIndex)
                    }
                } else if shouldComment && isLegacyEmptyLine(line.text.substring(from: commentIndex)) {
                    startColumn = updated.count
                    endColumn = startColumn
                }
            } else {
                if line.index == start.line && startColumn >= prefixCount {
                    startColumn = shouldComment
                        ? addingMarker(to: startColumn, clampedTo: updated.count)
                        : max(startColumn - 3, commentIndex)
                }
                if line.index == endLine && endColumn >= prefixCount {
                    endColumn = shouldComment
                        ? addingMarker(to: endColumn, clampedTo: updated.count)
                        : max(endColumn - 3, commentIndex)
                }
            }
        }

        // Intentionally retain the old all-blank/single-line selection destination
        // and Character-count column clamping, including their Unicode quirks.
        return CommentSelectionUpdate(startColumn: startColumn, endColumn: endColumn,
                                      updatesFirstSelectionOnly: !multiline,
                                      changedLineCount: changedLineCount)
    }

    private static func hasCommentPrefix(_ text: NSString, at offset: Int) -> Bool {
        guard offset < text.length - 1,
              text.character(at: offset) == 0x2F, text.character(at: offset + 1) == 0x2F else { return false }
        // An ASCII character after // guarantees a grapheme boundary. For Unicode,
        // retain String.hasPrefix semantics (e.g. // followed by a combining mark).
        if offset + 2 == text.length || text.character(at: offset + 2) < 0x80 { return true }
        return text.substring(from: offset).hasPrefix("//")
    }

    private static func addingMarker(to column: Int, clampedTo length: Int) -> Int {
        column > Int.max - 3 ? length : min(column + 3, length)
    }

    private static func isLegacyEmptyLine(_ text: String) -> Bool {
        text.allSatisfy { $0 == " " || $0 == "\t" || $0 == "\n" }
    }
}
