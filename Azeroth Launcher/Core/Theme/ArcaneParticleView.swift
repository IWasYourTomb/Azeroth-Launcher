//
//  ArcaneParticleView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 14.11.2026.
//

import SwiftUI

struct ArcaneParticleView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var particleCount: Int = 35
    var intensity: Double = 1

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 30.0,
                paused: reduceMotion
            )
        ) { timeline in
            Canvas { context, size in
                let time = reduceMotion
                    ? 0
                    : timeline.date.timeIntervalSinceReferenceDate

                for index in 0..<particleCount {
                    drawParticle(
                        index: index,
                        time: time,
                        size: size,
                        context: &context
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawParticle(
        index: Int,
        time: TimeInterval,
        size: CGSize,
        context: inout GraphicsContext
    ) {
        guard size.width > 0, size.height > 0 else {
            return
        }

        let seed = Double(index)

        let baseX = pseudoRandom(seed * 17.31)
        let baseY = pseudoRandom(seed * 31.73)

        let speed = 0.012 + pseudoRandom(seed * 11.17) * 0.025
        let amplitude = 8 + pseudoRandom(seed * 7.91) * 20

        let verticalProgress = (baseY + time * speed)
            .truncatingRemainder(dividingBy: 1)

        let horizontalOffset = sin(time * 0.35 + seed) * amplitude

        let x = baseX * size.width + horizontalOffset
        let y = verticalProgress * size.height

        let radius = 1.0 + pseudoRandom(seed * 13.41) * 1.8

        let phase = time * 1.4 + seed
        let twinkle = 0.55 + 0.45 * sin(phase)

        let opacity = (
            (0.12 + pseudoRandom(seed * 19.83) * 0.3) *
            twinkle *
            intensity
        )

        let isBlue = index.isMultiple(of: 3)

        let particleColor = isBlue
            ? LauncherTheme.accentSecondary
            : LauncherTheme.accent

        let glowRect = CGRect(
            x: x - radius * 3,
            y: y - radius * 3,
            width: radius * 6,
            height: radius * 6
        )

        let particleRect = CGRect(
            x: x - radius / 2,
            y: y - radius / 2,
            width: radius,
            height: radius
        )

        let glow = Gradient(
            colors: [
                particleColor.opacity(opacity * 0.45),
                particleColor.opacity(0)
            ]
        )

        context.fill(
            Path(ellipseIn: glowRect),
            with: .radialGradient(
                glow,
                center: CGPoint(x: x, y: y),
                startRadius: 0,
                endRadius: radius * 3
            )
        )

        context.fill(
            Path(ellipseIn: particleRect),
            with: .color(
                particleColor.opacity(opacity)
            )
        )
    }

    private func pseudoRandom(_ value: Double) -> Double {
        let result = sin(value * 127.1) * 43758.5453
        return result - floor(result)
    }
}
