//
//  AddonCompatibility.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import Foundation

enum AddonCompatibility {
    case compatible
    case outdated
    case newer
    case unknown

    static func check(interfaces: [Int], edition: GameEdition) -> AddonCompatibility {
        guard !interfaces.isEmpty else {
            return .unknown
        }

        let target = interfaceVersion(for: edition)

        if interfaces.contains(target) {
            return .compatible
        }

        if let highest = interfaces.max(), highest < target {
            return .outdated
        }

        if let lowest = interfaces.min(), lowest > target {
            return .newer
        }

        return .unknown
    }

    static func interfaceVersion(for edition: GameEdition) -> Int {
        switch edition {
        case .wrath:
            return 30300
        case .cataclysm:
            return 40400
        case .pandaria:
            return 50400
        }
    }
}
