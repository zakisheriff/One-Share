//
//  WirelessTypes.swift
//  One Share
//
//  Shared models for wireless transfer
//

import Foundation

struct Peer: Identifiable, Equatable {
    let id: UUID
    let name: String
    let platform: String
    var ip: String?
    var port: UInt16?
    var isPaired: Bool = false
    var lastSeen: Date = Date()
}

struct TransferHistoryItem: Identifiable {
    let id: UUID
    let fileName: String
    let fileSize: Int64
    let isIncoming: Bool
    var progress: Double
    var state: TransferState
    let date: Date
}

enum TransferState {
    case transferring
    case completed
    case failed
    case cancelled
}
