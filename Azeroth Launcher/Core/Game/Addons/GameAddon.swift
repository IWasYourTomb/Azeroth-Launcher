//
//  GameAddon.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import Foundation

struct GameAddon: Identifiable, Hashable {
    let id: String
    let name: String
    let folderName: String
    let version: String?
    let author: String?
    let notes: String?
    let supportedInterfaces: [Int]

    let directoryURL: URL
    let tocURL: URL

    let isEnabled: Bool

    var displayVersion: String {
        version ?? "Unknown"
    }

    var displayAuthor: String {
        author ?? "Unknown"
    }
}
