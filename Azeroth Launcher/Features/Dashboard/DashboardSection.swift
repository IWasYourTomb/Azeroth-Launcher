//
//  DashboardSection.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import SwiftUI

enum DashboardSection: String, CaseIterable, Identifiable {
    case home
    case games
    case settings

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
            case .home: return "Home"
            case .games: return "Games"
            case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
            case .home: return "house.fill"
            case .games: return "gamecontroller.fill"
            case .settings: return "gearshape.fill"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
            case .home: return "Welcome back to Azeroth"
            case .games: return "Manage your game installations"
            case .settings: return "Customize your launcher"
        }
    }
}
