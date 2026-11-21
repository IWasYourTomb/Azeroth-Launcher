//
//  WineRuntimeRelease.swift
//  Azeroth Launcher
//
//  Created by Матвей on 15.11.2026.
//

import Foundation

struct WineRuntimeRelease: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let version: String
    let directoryName: String
    let downloadURL: URL
    let sha256: String
    
    var displayName: String {
        "\(name) \(version)"
    }
    
    var archiveFileName: String {
        "\(id).tar.xz"
    }
    
    var stagingDirectoryName: String {
        ".\(directoryName)-staging"
    }
    
    var backupDirectoryName: String {
        ".\(directoryName)-backup"
    }
    
    static let r17 = WineRuntimeRelease(
        id: "wine-r17",
        name: "WineAndAqua",
        version: "11.13 (r17)",
        directoryName: "Wine-r17",
        downloadURL: URL(
            string: "https://github.com/WoWSilicon/WoWSilicon/releases/download/wine-runtime-r17/WoWSilicon-WineRuntime-r17.tar.xz"
        )!,
        sha256: "dc67cf0c2dd1e4c1cfaffe924f4737aaa594645b135a7973ac3505c83c70f882"
    )
}

enum WineRuntimeCatalog {
    static let releases: [WineRuntimeRelease] = [
        .r17
    ]
    
    static func release(for id: String) -> WineRuntimeRelease? {
        releases.first { $0.id == id }
    }
}
