//
//  RealmConnectionStatus.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import Foundation
import Network

enum RealmConnectionStatus: Equatable {
    case unknown
    case checking
    case online
    case offline
}
