//
//  appdelegate.swift
//  CommentsPlugin
//
//  Created by 沈莼乾 on 2023/4/23.
//  Copyright © 2023 CHUNQIAN SHEN. All rights reserved.
//

import Cocoa
import SnapKit

// ******************************** AppDelegate ********************************
class TAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    var window: NSWindow!
    var mainMenu: TMainMenu!
    
    override init() {
        // 创建窗口
        window = NSWindow(contentRect: NSMakeRect(335, 390, 640, 360),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "CommentsPlugin"
        
        // 创建菜单
        mainMenu = TMainMenu()
        super.init()
    }

    func windowWillClose(_ notification: Notification) {
        // 关闭应用
        NSApplication.shared.terminate(self)
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 创建文本
        setupContentView()
        // 代理设置
        self.window.delegate = self
        window.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func setupContentView() {
        // 确保窗口已被创建
        guard let contentView = window.contentView else { return }

        // 创建并配置文本域
        let instructionTextField = NSTextField()
        instructionTextField.isEditable = false
        instructionTextField.isBordered = false
        instructionTextField.drawsBackground = false
        instructionTextField.font = NSFont.systemFont(ofSize: 13)
        
        // 设置多行文本
        let textField = """
            Installation
            
            1. Run the application at least once, then close it.
            2. Go to System Preferences -> Extensions -> Xcode Source Editor and enable this extension.
            3. Reopen Xcode and you can find this extension from Xcode menu.
            
            Setting Hot Key
            
            1. After installation, open Xcode > Preferences > Key Bindings.
            2. Search for 'CommentsPlugin'.
            3. Assign it a new hot key, here 'command + /' is recommended.
            """
        instructionTextField.stringValue = textField
        contentView.addSubview(instructionTextField)

        // 使用 SnapKit 设置自动布局
        instructionTextField.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(84)
            make.left.equalToSuperview().offset(37)
            make.right.equalToSuperview().offset(-37)
            make.height.equalTo(192)
        }

        // 创建并配置第二个文本域
        let thanksTextField = NSTextField(labelWithString: "Thanks for using CommentsPlugin")
        thanksTextField.font = NSFont.systemFont(ofSize: 26)
        contentView.addSubview(thanksTextField)

        // 使用 SnapKit 设置自动布局
        thanksTextField.snp.makeConstraints { make in
            make.bottom.equalTo(instructionTextField.snp.top).offset(-19)
            make.left.equalToSuperview().offset(37)
            make.right.equalToSuperview().offset(-37)
            make.height.equalTo(34)
        }
    }
}
