//
//  RealmServer.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import Foundation

struct RealmServer: Identifiable, Codable, Hashable{
    let id: UUID
    var name: String
    var address: String
    
    init(id: UUID = UUID(), name: String, address: String) {
        self.id = id
        self.name = name
        self.address = address
    }
}
