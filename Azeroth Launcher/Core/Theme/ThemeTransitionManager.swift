//
//  ThemeTransitionManager.swift
//  Azeroth Launcher
//
//  Created by Матвей on 14.11.2026.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class ThemeTransitionManager {
    var veilOpacity: Double = 0
    var glowOpacity: Double = 0
    var isTransitioning = false

    var transitionColor: Color = Color(
        red: 9 / 255,
        green: 13 / 255,
        blue: 24 / 255
    )

    func transition(
        from currentAppearance: String,
        to newAppearance: String,
        apply: @escaping () -> Void
    ) {
        guard !isTransitioning,
              currentAppearance != newAppearance else {
            return
        }

        isTransitioning = true

        transitionColor = currentAppearance == "dark"
            ? Color(red: 9 / 255, green: 13 / 255, blue: 24 / 255)
            : Color(red: 243 / 255, green: 241 / 255, blue: 236 / 255)

        withAnimation(.easeIn(duration: 0.28)) {
            veilOpacity = 1
            glowOpacity = 1
        }

        Task {
            try? await Task.sleep(for: .milliseconds(300))

            apply()

            try? await Task.sleep(for: .milliseconds(120))

            withAnimation(.easeInOut(duration: 0.75)) {
                veilOpacity = 0
                glowOpacity = 0
            }

            try? await Task.sleep(for: .milliseconds(800))

            isTransitioning = false
        }
    }
}
