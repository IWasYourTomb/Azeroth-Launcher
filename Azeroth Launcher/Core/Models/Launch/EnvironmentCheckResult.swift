//
//  EnvironmentCheckResult.swift
//  Azeroth Launcher
//
//  Created by Матвей on 14.11.2026.
//

import Foundation

enum EnvironmentCheckStatus: String, Codable {
    case ready
    case warning
    case error
}

struct EnvironmentCheckResult: Identifiable {
    let id: String
    let title: String
    let details: String
    let status: EnvironmentCheckStatus
}

struct EnvironmentValidationReport {

    let installationID: UUID
    let checks: [EnvironmentCheckResult]

    var hasErrors: Bool {
        checks.contains { $0.status == .error }
    }

    var hasWarnings: Bool {
        checks.contains { $0.status == .warning }
    }

    var isReady: Bool {
        !hasErrors
    }

    var readyCount: Int {
        checks.filter { $0.status == .ready }.count
    }

    var warningCount: Int {
        checks.filter { $0.status == .warning }.count
    }

    var errorCount: Int {
        checks.filter { $0.status == .error }.count
    }
}
