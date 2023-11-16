//
//  main.swift
//  ConsoleLink
//
//  Created by 沈莼乾 on 2023/10/31.
//  Copyright © 2023 CHUNQIAN SHEN. All rights reserved.
//

import Foundation
import AppKit

let app = NSApplication.shared
let appDelegate = TAppDelegate()
app.delegate = appDelegate
app.mainMenu = appDelegate.mainMenu
app.run()
