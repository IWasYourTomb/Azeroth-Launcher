//
//  GameManager.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class GameManager {
    private let storageKey = "AzerothLauncher.GameInstallations"
    private(set) var installations: [GameInstallation] = []
    private let directoryAccessManager: GameDirectoryAccessManager
    private var accessSessions: [UUID: GameDirectoryAccessSession] = [:]


    init(
        directoryAccessManager: GameDirectoryAccessManager = GameDirectoryAccessManager()
    ) {
        self.directoryAccessManager = directoryAccessManager
        loadInitialState()
    }

    func add(_ installation: GameInstallation) {

        if let existing = installations.first(where: {
            $0.edition == installation.edition
        }) {
            closeAccess(for: existing.id)
        }

        if let index = installations.firstIndex(where: {
            $0.edition == installation.edition
        }) {
            installations[index] = installation
        } else {
            installations.append(installation)
        }

        openAccess(for: installation)
        save()
    }

    func remove(id: UUID) {
        closeAccess(for: id)
        installations.removeAll {
            $0.id == id
        }
        save()
    }

    func remove(edition: GameEdition) {
        guard let installation = installation(for: edition) else {
            return
        }
        remove(id: installation.id)
    }

    func installation(for edition: GameEdition) -> GameInstallation? {
        installations.first {
            $0.edition == edition
        }
    }

    func isInstalled(_ edition: GameEdition) -> Bool {
        guard let installation = installation(for: edition) else {
            return false
        }
        return installation.isInstalled
    }

    func loadInitialState() {
        guard let data = UserDefaults.standard.data(
            forKey: storageKey
        ) else {
            return
        }

        do {
            installations = try JSONDecoder().decode(
                [GameInstallation].self,
                from: data
            )
        } catch {
            print( "[GameManager] Failed to load installations: \(error)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(installations)
            UserDefaults.standard.set(
                data,
                forKey: storageKey
            )
        } catch {
            print("[GameManager] Failed to save installations: \(error)")
        }
    }

    func updateBookmark(_ bookmarkData: Data, for id: UUID) {
        guard let index = installations.firstIndex(where: {
            $0.id == id
        }) else {
            return
        }
        installations[index].bookmarkData = bookmarkData

        save()
    }

    private func openAccess(for installation: GameInstallation) {
        guard let bookmarkData = installation.bookmarkData else {
            print("[GameManager] Bookmark отсутствует: \(installation.edition.title)")
            return
        }

        do {
            let session = try directoryAccessManager.openAccess(
                using: bookmarkData
            )

            accessSessions[installation.id] = session

            if let refreshedBookmark = session.refreshedBookmark {
                updateBookmark(
                    refreshedBookmark,
                    for: installation.id
                )
            }
            print( "[GameManager] Доступ открыт: \(installation.edition.title)")
        } catch {
            print(
                "[GameManager] Не удалось открыть доступ к \(installation.edition.title): \(error.localizedDescription)"
            )
        }
    }

    func restoreDirectoryAccess() {
        for installation in installations {
            guard accessSessions[installation.id] == nil else {
                continue
            }

            guard let bookmarkData = installation.bookmarkData else {
                print( "[GameManager] Bookmark отсутствует: \(installation.edition.title)")
                continue
            }

            do {
                let session = try directoryAccessManager.openAccess(using: bookmarkData)

                accessSessions[installation.id] = session

                if let refreshedBookmark = session.refreshedBookmark {
                    updateBookmark(
                        refreshedBookmark,
                        for: installation.id
                    )
                }

                print( "[GameManager] Доступ восстановлен: \(installation.edition.title)")

            } catch {
                print(
                    "[GameManager] Ошибка восстановления \(installation.edition.title): \(error.localizedDescription)"
                )
            }
        }
    }

    private func closeAccess(for id: UUID) {
        guard let session = accessSessions.removeValue(forKey: id) else {
            return
        }
        session.close()
        print("[GameManager] Доступ закрыт: \(session.directoryURL.path)")
    }
}
