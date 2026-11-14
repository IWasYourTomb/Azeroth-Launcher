//
//  RendererManager.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class RendererManager {
    private let storageKey = "AzerothLauncher.RendererSettings"

    private(set) var selectedRenderers: [GameEdition: RendererType] = [:]

    init() {
        load()
    }

    func renderer(for edition: GameEdition) -> RendererType {
        selectedRenderers[edition] ?? .dxvk
    }

    func select(_ renderer: RendererType, for edition: GameEdition) {
        selectedRenderers[edition] = renderer
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(selectedRenderers)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save renderer settings: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }

        do {
            selectedRenderers = try JSONDecoder().decode(
                [GameEdition: RendererType].self,
                from: data
            )
        } catch {
            print("Failed to load renderer settings: \(error)")
        }
    }
}
