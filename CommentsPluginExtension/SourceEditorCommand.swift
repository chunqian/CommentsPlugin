//
//  SourceEditorCommand.swift
//  CommentsPluginExtension
//
//  Created by 沈莼乾 on 2023/4/23.
//  Copyright © 2023 CHUNQIAN SHEN. All rights reserved.
//

import Foundation
import XcodeKit

class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void) {
        CommentToggle.perform(buffer: invocation.buffer, completionHandler: completionHandler)
    }
}

extension XCSourceTextBuffer: CommentTextBuffer {}

extension XCSourceTextRange: CommentTextRange {
    var commentStart: CommentPosition {
        get { CommentPosition(line: start.line, column: start.column) }
        set {
            start.line = newValue.line
            start.column = newValue.column
        }
    }

    var commentEnd: CommentPosition {
        get { CommentPosition(line: end.line, column: end.column) }
        set {
            end.line = newValue.line
            end.column = newValue.column
        }
    }

    var isEmpty: Bool {
        start.column == end.column && start.line == end.line
    }
}
