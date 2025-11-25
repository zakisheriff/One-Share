//
//  ClipboardItem.swift
//  Lumen
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import Foundation

struct ClipboardItem {
    let item: FileSystemItem
    let sourceService: FileService
    let isCut: Bool // For future move support
}
