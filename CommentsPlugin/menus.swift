//
//  menus.swift
//  CommentsPlugin
//
//  Created by 沈莼乾 on 2024/2/1.
//  Copyright © 2024 CHUNQIAN SHEN. All rights reserved.
//

import Foundation
import AppKit

// ******************************** TMainMenu ********************************
class TMainMenu: NSMenu {
    var commentsPluginMenuItem: NSMenuItem
    
    init() {
        commentsPluginMenuItem = NSMenuItem()
        commentsPluginMenuItem.submenu = TCommentsPluginMenu()
        super.init(title: "MainMenu")
        
        addItem(commentsPluginMenuItem)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// ******************************** TCommentsPluginMenu ********************************
class TCommentsPluginMenu: NSMenu {
    var aboutMenuItem: TAboutMenuItem
    var quitMenuItem: TQuitMenuItem
    
    init() {
        aboutMenuItem = TAboutMenuItem()
        quitMenuItem = TQuitMenuItem()
        super.init(title: "CommentsPlugin")
        
        addItem(aboutMenuItem)
        addItem(NSMenuItem.separator())
        addItem(quitMenuItem)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// ******************************** TAboutMenuItem ********************************
class TAboutMenuItem: NSMenuItem {
    init() {
        super.init(title: "About CommentsPlugin", action: #selector(orderFrontStandardAboutPanel), keyEquivalent: "")
        target = self
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func orderFrontStandardAboutPanel() {
        NSApplication.shared.orderFrontStandardAboutPanel(self)
    }
}

// ******************************** TQuitMenuItem ********************************
class TQuitMenuItem: NSMenuItem {
    init() {
        super.init(title: "Quit CommentsPlugin", action: #selector(terminate), keyEquivalent: "q")
        target = self
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func terminate() {
        NSApplication.shared.terminate(self)
    }
}
