//
//  GameDirectoryAccessManager.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import Foundation

final class GameDirectoryAccessManager {
    func createBookmark(for directory: URL) throws -> Data {
        try directory.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    func resolveBookmark(_ bookmarkData: Data) throws -> ResolvedDirectory {
        var isStale = false

        let directory = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        let refreshedBookmark: Data?

        if isStale {
            refreshedBookmark = try createBookmark(for: directory)
        } else {
            refreshedBookmark = nil
        }

        return ResolvedDirectory(
            url: directory,
            refreshedBookmark: refreshedBookmark
        )
    }

    func openAccess(using bookmarkData: Data) throws -> GameDirectoryAccessSession {
        let resolved = try resolveBookmark(bookmarkData)
        let didStartAccessing = resolved.url.startAccessingSecurityScopedResource()

        guard didStartAccessing else {
            throw GameDirectoryAccessError.unableToStartAccess(resolved.url)
        }

        return GameDirectoryAccessSession(
            directoryURL: resolved.url,
            refreshedBookmark: resolved.refreshedBookmark,
            didStartAccessing: true
        )
    }
    
    enum GameDirectoryAccessError: LocalizedError {
        case unableToStartAccess(URL)
        var errorDescription: String? {
            switch self {
            case .unableToStartAccess(let url):
                return "Не удалось получить доступ к директории: \(url.path)"
            }
        }
    }

    struct ResolvedDirectory {
        let url: URL
        let refreshedBookmark: Data?
    }
}

final class GameDirectoryAccessSession {
    let directoryURL: URL
    let refreshedBookmark: Data?

    private let didStartAccessing: Bool
    private var isClosed = false

    init(
        directoryURL: URL,
        refreshedBookmark: Data?,
        didStartAccessing: Bool
    ) {
        self.directoryURL = directoryURL
        self.refreshedBookmark = refreshedBookmark
        self.didStartAccessing = didStartAccessing
    }

    func close() {
        guard !isClosed else {
            return
        }
        if didStartAccessing {
            directoryURL.stopAccessingSecurityScopedResource()
        }
        isClosed = true
    }

    deinit {
        close()
    }
}
