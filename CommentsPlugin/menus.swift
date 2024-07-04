//
//  menus.swift
//  CommentsPlugin
//
//  Created by 沈莼乾 on 2024/2/1.
//  Copyright © 2024 CHUNQIAN SHEN. All rights reserved.
//

import Foundation
import AppKit

// ------------------------------------
class TMainMenu: NSMenu {
    // ------------------
    var commentsPlugin: NSMenuItem
    
    // ------------------
    init() {
        commentsPlugin = NSMenuItem()
        commentsPlugin.submenu = TCommentsPluginMenu()
        super.init(title: "MainMenu")
        
        addItem(commentsPlugin)
    }
    
    // ------------------
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// ------------------------------------
class TCommentsPluginMenu: NSMenu {
    // ------------------
    var about: TAboutMenuItem
    var quit: TQuitMenuItem
    
    // ------------------
    init() {
        about = TAboutMenuItem()
        quit = TQuitMenuItem()
        super.init(title: "CommentsPlugin")
        
        addItem(about)
        addItem(NSMenuItem.separator())
        addItem(quit)
    }
    
    // ------------------
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// ------------------------------------
class TAboutMenuItem: NSMenuItem {
    // ------------------
    init() {
        super.init(title: "About CommentsPlugin", action: #selector(orderFrontStandardAboutPanel), keyEquivalent: "")
        target = self
    }
    
    // ------------------
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // ------------------
    @objc func orderFrontStandardAboutPanel() {
        NSApplication.shared.orderFrontStandardAboutPanel(self)
    }
}

// ------------------------------------
class TQuitMenuItem: NSMenuItem {
    // ------------------
    init() {
        super.init(title: "Quit CommentsPlugin", action: #selector(terminate), keyEquivalent: "q")
        target = self
    }
    
    // ------------------
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // ------------------
    @objc func terminate() {
        NSApplication.shared.terminate(self)
    }
}
