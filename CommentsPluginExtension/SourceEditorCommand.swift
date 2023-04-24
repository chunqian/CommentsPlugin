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
        
        var startSelection: (start: Int, end: Int) = (0, 0)
        var endSelection: (start: Int, end: Int) = (0, 0)
        var numberOfSelectionLines: Int = 0
        
        guard let startRange = selections.firstObject as? XCSourceTextRange,
            let endRange = selections.lastObject as? XCSourceTextRange
        else {
            completionHandler(nil)
            return
        }
        
        startSelection = (startRange.start.column, startRange.end.column)
        endSelection = (endRange.start.column, endRange.end.column)
        
        
        print("start at \(startRange)")
        print("end at \(endRange)")
        
        let startLine = startRange.start.line
        
        let endLine: Int
        if endRange.end.column == 0 && endRange.end.line > startLine {
            endLine = endRange.end.line - 1
        } else {
            endLine = endRange.end.line
        }
        numberOfSelectionLines = endLine - startLine
        
        var shouldComment = false
        var commentIndex: Int? = nil
        
        // 单行
        if numberOfSelectionLines == 0 {
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
                        if startSelection.start > linePrefix.count {
                            startSelection.start = min(startSelection.start + 3, (lines[index] as? String)?.count ?? 0)
                            startSelection.end = min(startSelection.end + 3, (lines[index] as? String)?.count ?? 0)
                        } else {
                            if code.isEmptyLine {
                                startSelection.start = (lines[index] as? String)?.count ?? 0 + 3
                                startSelection.end = (lines[index] as? String)?.count ?? 0 + 3
                            }
                        }
                    } else if !shouldComment && commented {
                        let uncommentedCode = code.replacingOccurrences(of: "^// ?", with: "", options: .regularExpression)
                        lines[index] = linePrefix + uncommentedCode
                        if startSelection.start > linePrefix.count {
                            startSelection.start = max(startSelection.start - 3, commentIndex!)
                            startSelection.end = max(startSelection.end - 3, commentIndex!)
                        }
                    }
                }
            }
            
            startRange.start.column = startSelection.start
            startRange.end.column = startSelection.end
        }
        
        // 多行
        if numberOfSelectionLines > 0 {
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
                        if index == startLine {
                            if startSelection.start > linePrefix.count {
                                startSelection.start = min(startSelection.start + 3, (lines[index] as? String)?.count ?? 0)
                                startSelection.end = min(startSelection.end + 3, (lines[index] as? String)?.count ?? 0)
                            }
                        }
                        if index == endLine {
                            if endSelection.start > linePrefix.count {
                                endSelection.start = min(endSelection.start + 3, (lines[index] as? String)?.count ?? 0)
                                endSelection.end = min(endSelection.end + 3, (lines[index] as? String)?.count ?? 0)
                            }
                        }
                    } else if !shouldComment && commented {
                        let uncommentedCode = code.replacingOccurrences(of: "^// ?", with: "", options: .regularExpression)
                        lines[index] = linePrefix + uncommentedCode
                        if index == startLine {
                            if startSelection.start > linePrefix.count {
                                startSelection.start = max(startSelection.start - 3, commentIndex!)
                                startSelection.end = max(startSelection.end - 3, commentIndex!)
                            }
                        }
                        if index == endLine {
                            if endSelection.start > linePrefix.count {
                                endSelection.start = max(endSelection.start - 3, commentIndex!)
                                endSelection.end = max(endSelection.end - 3, commentIndex!)
                            }
                        }
                    }
                }
            }
            
            startRange.start.column = startSelection.start
            startRange.end.column = startSelection.end
            endRange.start.column = endSelection.start
            endRange.end.column = endSelection.end
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
