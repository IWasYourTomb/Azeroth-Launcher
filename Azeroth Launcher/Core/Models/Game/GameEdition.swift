//
//  GameEdition.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import Foundation

enum GameEdition: String, Codable, CaseIterable, Identifiable {
    case cataclysm
    case pandaria
    case wrath

    var id: String { rawValue }

    var title: String {
        switch self {
            case .cataclysm: return "Cataclysm"
            case .pandaria: return "Mists of Pandaria"
            case .wrath: return "Wrath of the Lich King"
        }
    }

    var version: String {
        switch self {
            case .cataclysm: return "4.3.4"
            case .pandaria: return "5.4.8"
            case .wrath: return "3.3.5a"
        }
    }

    var backgroundImageName: String {
        switch self {
            case .wrath: return "LichBack"
            case .cataclysm: return "CataclysmBack"
            case .pandaria: return "PandariaBack"
        }
    }
}
