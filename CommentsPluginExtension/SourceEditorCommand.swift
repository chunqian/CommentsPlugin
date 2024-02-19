//
//  SourceEditorCommand.swift
//  CommentsPluginExtension
//
//  Created by 沈莼乾 on 2023/4/23.
//  Copyright © 2023 CHUNQIAN SHEN. All rights reserved.
//

import Foundation
import XcodeKit

// ******************************** SourceEditorCommand ********************************
class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        
        print("--------------command start--------------")
        let buffer = invocation.buffer
        let selections = buffer.selections
        let lines = buffer.lines
        
        var startColumn: Int = 0
        var endColumn: Int = 0
        var numberOfSelectionLines: Int = 0
        
        guard let startRange = selections.firstObject as? XCSourceTextRange,
            let endRange = selections.lastObject as? XCSourceTextRange
        else {
            completionHandler(nil)
            return
        }
        
        startColumn = startRange.start.column
        endColumn = endRange.end.column
        
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
        
        // 空行
        var isEmptyLines = true
        for index in startLine...endLine {
            if index >= lines.count {
                break
            }
            guard let line = lines.object(at: index) as? NSString else { continue }
            let code = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !code.isEmptyLine {
                isEmptyLines = false
                break
            }
        }
        
        // 单行
        if numberOfSelectionLines == 0 || isEmptyLines {
            for index in startLine...endLine {
                if index >= lines.count {
                    break
                }
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
                if index >= lines.count {
                    break
                }
                guard let line = lines.object(at: index) as? NSString else { continue }
                
                if commentIndex! < line.length {
                    let linePrefix = line.substring(to: commentIndex!)
                    let code = line.substring(from: commentIndex!)
                    let commented = code.hasPrefix("//") || code.hasPrefix("// ")
                    
                    if shouldComment {
                        lines[index] = linePrefix + "// " + code
                        if startColumn >= linePrefix.count {
                            startColumn = min(startColumn + 3, (lines[index] as? String)?.count ?? 0)
                            endColumn = min(endColumn + 3, (lines[index] as? String)?.count ?? 0)
                        } else {
                            if code.isEmptyLine {
                                startColumn = (lines[index] as? String)?.count ?? 0 + 3
                                endColumn = (lines[index] as? String)?.count ?? 0 + 3
                            }
                        }
                    } else if !shouldComment && commented {
                        let uncommentedCode = code.replacingOccurrences(of: "^// ?", with: "", options: .regularExpression)
                        lines[index] = linePrefix + uncommentedCode
                        if startColumn >= linePrefix.count {
                            startColumn = max(startColumn - 3, commentIndex!)
                            endColumn = max(endColumn - 3, commentIndex!)
                        }
                    }
                }
            }
            
            startRange.start.column = startColumn
            startRange.end.column = endColumn
        }
        
        // 多行
        if numberOfSelectionLines > 0 && !isEmptyLines {
            for index in startLine...endLine {
                if index >= lines.count {
                    break
                }
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
                if index >= lines.count {
                    break
                }
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
                            if startColumn >= linePrefix.count {
                                startColumn = min(startColumn + 3, (lines[index] as? String)?.count ?? 0)
                            }
                        }
                        if index == endLine {
                            if endColumn >= linePrefix.count {
                                endColumn = min(endColumn + 3, (lines[index] as? String)?.count ?? 0)
                            }
                        }
                    } else if !shouldComment && commented {
                        let uncommentedCode = code.replacingOccurrences(of: "^// ?", with: "", options: .regularExpression)
                        lines[index] = linePrefix + uncommentedCode
                        if index == startLine {
                            if startColumn >= linePrefix.count {
                                startColumn = max(startColumn - 3, commentIndex!)
                            }
                        }
                        if index == endLine {
                            if endColumn >= linePrefix.count {
                                endColumn = max(endColumn - 3, commentIndex!)
                            }
                        }
                    }
                }
            }
            
            startRange.start.column = startColumn
            endRange.end.column = endColumn
        }
        
        completionHandler(nil)
        
        print("final selections are \(selections)")
        print("--------------command end--------------")
    }
    
}

// ******************************** String ********************************
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

// ******************************** XCSourceTextRange ********************************
extension XCSourceTextRange {
    var isEmpty: Bool {
        return start.column == end.column && start.line == end.line
    }
}
