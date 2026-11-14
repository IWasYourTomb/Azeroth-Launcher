//
//  GameLaunchSettings.swift
//  Azeroth Launcher
//
//  Created by Матвей on 08.11.2026.
//

import Foundation

struct GameLaunchSettings: Codable, Equatable {
    var dxvkAsyncEnabled: Bool
    var wineDebug: String
    var dllOverrides: [String: String]
    var launchArguments: [String]
    var environmentVariables: [String: String]
    var virtualDesktopEnabled: Bool
    var virtualDesktopWidth: Int
    var virtualDesktopHeight: Int


    static let `default` = GameLaunchSettings(
        dxvkAsyncEnabled: true,
        wineDebug: "-all",
        dllOverrides: [:],
        launchArguments: [],
        environmentVariables: [:],
        virtualDesktopEnabled: false,
        virtualDesktopWidth: 1920,
        virtualDesktopHeight: 1080
    )
}
