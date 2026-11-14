//
//  RealmServerStore.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import Foundation

struct RealmServerStore {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load(for edition: GameEdition) -> [RealmServer] {
        let key = storageKey(for: edition)

        guard let data = userDefaults.data(forKey: key),
              let servers = try? JSONDecoder().decode(
                [RealmServer].self,
                from: data
              ) else {
            return []
        }

        return servers
    }

    @discardableResult
    func add( _ server: RealmServer, for edition: GameEdition) -> Bool {
        var servers = load(for: edition)

        let normalizedAddress = normalize(server.address)

        guard !servers.contains(where: {
            normalize($0.address) == normalizedAddress
        }) else {
            return false
        }

        servers.append(server)
        save(servers, for: edition)

        return true
    }

    @discardableResult
    func update(_ server: RealmServer,for edition: GameEdition) -> Bool {
        var servers = load(for: edition)

        guard let index = servers.firstIndex(
            where: { $0.id == server.id }
        ) else {
            return false
        }

        let normalizedAddress = normalize(server.address)

        let duplicateExists = servers.contains {
            $0.id != server.id &&
            normalize($0.address) == normalizedAddress
        }

        guard !duplicateExists else {
            return false
        }

        servers[index] = server

        save(servers, for: edition)

        return true
    }

    func remove(id: UUID, for edition: GameEdition) {
        var servers = load(for: edition)

        servers.removeAll {
            $0.id == id
        }

        save(servers, for: edition)
    }

    private func normalize(_ address: String) -> String {
        address
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func save(_ servers: [RealmServer],for edition: GameEdition) {
        guard let data = try? JSONEncoder().encode(servers) else {
            return
        }

        userDefaults.set(
            data,
            forKey: storageKey(for: edition)
        )
    }

    private func storageKey(for edition: GameEdition) -> String {
        "AzerothLauncher.Realms.\(edition.rawValue)"
    }
}
