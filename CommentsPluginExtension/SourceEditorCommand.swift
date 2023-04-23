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
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        
        print("--------------command start--------------")
        let buffer = invocation.buffer
        let selections = buffer.selections
        let lines = buffer.lines

        guard let startRange = selections.firstObject as? XCSourceTextRange,
            let endRange = selections.lastObject as? XCSourceTextRange
        else {
            completionHandler(nil)
            return
        }
        
        print("start at \(startRange)")
        print("end at \(endRange)")
        
        let startLine = startRange.start.line
        
        let endLine: Int
        if endRange.end.column == 0 && endRange.end.line > startLine {
            endLine = endRange.end.line - 1
        } else {
            endLine = endRange.end.line
        }
        
        guard let firstLine = lines.object(at: startLine) as? NSString else {
            completionHandler(nil)
            return
        }
        
        let firstLineRange = firstLine.rangeOfCharacter(from: CharacterSet.whitespaces.inverted)
        let firstNonWhitespaceColumn = firstLineRange.location == NSNotFound ? firstLine.length : firstLineRange.location
        let firstLineCode = firstLine.substring(from: firstNonWhitespaceColumn)
        let shouldComment = !firstLineCode.hasPrefix("// ")
        
        for index in startLine...endLine {
            guard let line = lines.object(at: index) as? NSString else { continue }
            let range = line.rangeOfCharacter(from: CharacterSet.whitespaces.inverted)
            let firstNonWhitespaceColumn = range.location == NSNotFound ? line.length : range.location
            
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmptyLine {
                continue
            } else if firstNonWhitespaceColumn < line.length {
                let linePrefix = line.substring(to: firstNonWhitespaceColumn)
                let code = line.substring(from: firstNonWhitespaceColumn)
                let commented = code.hasPrefix("// ")
                
                if shouldComment && !commented {
                    lines[index] = linePrefix + "// " + code
                } else if !shouldComment && commented {
                    let uncommentedCode = code.replacingOccurrences(of: "// ", with: "", options: .anchored)
                    lines[index] = linePrefix + uncommentedCode
                }
            }
        }

        completionHandler(nil)
        
        print("final selections are \(selections)")
        print("--------------command end--------------")
    }
    
}

extension String {
    var isEmptyLine: Bool {
        var result = true
        for c in self {
            if ![" ", "\t", "\n"].contains(c) {
                result = false
                break
            }
        }
        return result
    }
}

extension XCSourceTextRange {
    var isEmpty: Bool {
        return start.column == end.column && start.line == end.line
    }
}
