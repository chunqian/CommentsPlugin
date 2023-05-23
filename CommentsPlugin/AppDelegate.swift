//
//  AppDelegate.swift
//  CommentsPlugin
//
//  Created by 沈莼乾 on 2023/4/23.
//  Copyright © 2023 CHUNQIAN SHEN. All rights reserved.
//

import Cocoa

// ******************************** AppDelegate ********************************
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    @IBOutlet weak var window: NSWindow!

    func windowWillClose(_ notification: Notification) {
        // 关闭应用
        NSApplication.shared.terminate(self)
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        self.window.delegate = self
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}
