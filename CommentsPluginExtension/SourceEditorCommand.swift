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
    
    private var cursorShift: Int = 0
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        
        cursorShift = 0
        print("--------------command start--------------")
        let buffer = invocation.buffer
        let selections = buffer.selections
        let numberOfSelections = selections.count
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
        
        var shouldComment = false
        var commentIndex: Int? = nil
        
        // 单行
        if numberOfSelections == 1 {
            for index in startLine...endLine {
                guard let line = lines.object(at: index) as? NSString else { continue }
                let code = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                let range = line.rangeOfCharacter(from: CharacterSet.whitespaces.inverted)
                
                commentIndex = commentIndex == nil ? range.location : min(commentIndex!, range.location)
                if !code.hasPrefix("//") && !code.hasPrefix("// ") {
                    shouldComment = true
                    continue
                }
            }
            
            for index in startLine...endLine {
                guard let line = lines.object(at: index) as? NSString else { continue }
                
                if commentIndex! < line.length {
                    let linePrefix = line.substring(to: commentIndex!)
                    let code = line.substring(from: commentIndex!)
                    let commented = code.hasPrefix("//") || code.hasPrefix("// ")
                    
                    if shouldComment {
                        lines[index] = linePrefix + "// " + code
                        cursorShift += 3
                    } else if !shouldComment && commented {
                        let uncommentedCode = code.replacingOccurrences(of: "^// ?", with: "", options: .regularExpression)
                        lines[index] = linePrefix + uncommentedCode
                        cursorShift -= 3
                    }
                }
            }
            
            startRange.start.column += cursorShift
            endRange.end.column += cursorShift
        }
        
        // 多行
        if numberOfSelections > 1 {
            for index in startLine...endLine {
                guard let line = lines.object(at: index) as? NSString else { continue }
                let code = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                let range = line.rangeOfCharacter(from: CharacterSet.whitespaces.inverted)
                if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmptyLine {
                    continue
                }
                commentIndex = commentIndex == nil ? range.location : min(commentIndex!, range.location)
                if !code.isEmptyLine && !code.hasPrefix("//") && !code.hasPrefix("// ") {
                    shouldComment = true
                    continue
                }
            }
            
            for index in startLine...endLine {
                guard let line = lines.object(at: index) as? NSString else { continue }
                
                if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmptyLine {
                    continue
                } else if commentIndex! < line.length {
                    let linePrefix = line.substring(to: commentIndex!)
                    let code = line.substring(from: commentIndex!)
                    let commented = code.hasPrefix("//") || code.hasPrefix("// ")
                    
                    if shouldComment {
                        lines[index] = linePrefix + "// " + code
                        cursorShift += 3
                    } else if !shouldComment && commented {
                        let uncommentedCode = code.replacingOccurrences(of: "^// ?", with: "", options: .regularExpression)
                        lines[index] = linePrefix + uncommentedCode
                        cursorShift -= 3
                    }
                }
            }
            
            startRange.start.column += cursorShift
            endRange.end.column += cursorShift
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
