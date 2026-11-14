//
//  SplashScreenView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 14.11.2026.
//

import SwiftUI

struct SplashScreenView: View {

    @State private var rotation: Double = 0
    @State private var reverseRotation: Double = 0
    @State private var portalPulse = false
    @State private var contentVisible = false

    private let gold = Color(
        red: 0.92,
        green: 0.68,
        blue: 0.28
    )

    private let arcaneBlue = Color(
        red: 0.25,
        green: 0.58,
        blue: 1.0
    )

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                background
                ambientGlow
                portal
                branding
                loadingIndicator
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height
            )
            .opacity(contentVisible ? 1 : 0)
            .onAppear {
                startAnimations()
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.018, green: 0.025, blue: 0.055),
                    Color(red: 0.035, green: 0.045, blue: 0.085),
                    Color(red: 0.055, green: 0.035, blue: 0.065),
                    Color(red: 0.015, green: 0.02, blue: 0.045)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    arcaneBlue.opacity(0.15),
                    .clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 380
            )

            LinearGradient(
                colors: [
                    .black.opacity(0.15),
                    .clear,
                    .black.opacity(0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var ambientGlow: some View {
        ZStack {
            Circle()
                .fill(arcaneBlue.opacity(0.13))
                .frame(width: 340, height: 340)
                .blur(radius: 100)
                .offset(x: -180, y: -80)

            Circle()
                .fill(gold.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: 190, y: 100)

            Circle()
                .fill(arcaneBlue.opacity(0.1))
                .frame(width: 180, height: 180)
                .blur(radius: 70)
                .scaleEffect(portalPulse ? 1.3 : 0.85)
                .animation(
                    .easeInOut(duration: 3)
                        .repeatForever(autoreverses: true),
                    value: portalPulse
                )
        }
    }

    private var portal: some View {
        ZStack {
            Circle()
                .fill(arcaneBlue.opacity(0.08))
                .frame(width: 245, height: 245)
                .blur(radius: 35)

            Circle()
                .stroke(
                    gold.opacity(0.13),
                    style: StrokeStyle(
                        lineWidth: 1,
                        dash: [3, 8]
                    )
                )
                .frame(width: 225, height: 225)
                .rotationEffect(.degrees(rotation * -0.5))

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            gold.opacity(0.05),
                            gold,
                            .white.opacity(0.8),
                            gold.opacity(0.15),
                            gold
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(
                        lineWidth: 2,
                        lineCap: .round
                    )
                )
                .frame(width: 195, height: 195)
                .rotationEffect(.degrees(rotation))

            Circle()
                .trim(from: 0.08, to: 0.92)
                .stroke(
                    AngularGradient(
                        colors: [
                            .clear,
                            arcaneBlue.opacity(0.8),
                            .white.opacity(0.8),
                            arcaneBlue.opacity(0.2),
                            .clear
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(
                        lineWidth: 2,
                        lineCap: .round
                    )
                )
                .frame(width: 168, height: 168)
                .rotationEffect(.degrees(reverseRotation))

            Circle()
                .stroke(
                    gold.opacity(0.35),
                    style: StrokeStyle(
                        lineWidth: 1,
                        dash: [2, 5]
                    )
                )
                .frame(width: 145, height: 145)
                .rotationEffect(.degrees(rotation * 0.7))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            arcaneBlue.opacity(0.65),
                            Color(red: 0.12, green: 0.25, blue: 0.65)
                                .opacity(0.35),
                            Color(red: 0.04, green: 0.08, blue: 0.2)
                                .opacity(0.8),
                            .clear
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 80
                    )
                )
                .frame(width: 135, height: 135)
                .scaleEffect(portalPulse ? 1.08 : 0.92)

            Circle()
                .stroke(
                    arcaneBlue.opacity(0.55),
                    lineWidth: 1
                )
                .frame(width: 118, height: 118)
                .blur(radius: 3)

            Image(systemName: "sparkles")
                .font(.system(size: 47, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            .white,
                            arcaneBlue,
                            gold
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: arcaneBlue.opacity(0.9), radius: 18)
                .scaleEffect(portalPulse ? 1.08 : 0.94)

            portalParticles
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: -55)
    }

    private var portalParticles: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                let angle = Double(index) * 30

                Circle()
                    .fill(index.isMultiple(of: 2) ? gold : arcaneBlue)
                    .frame(
                        width: index.isMultiple(of: 3) ? 4 : 2,
                        height: index.isMultiple(of: 3) ? 4 : 2
                    )
                    .shadow(
                        color: arcaneBlue.opacity(0.8),
                        radius: 5
                    )
                    .offset(y: -108)
                    .rotationEffect(.degrees(angle + rotation))
                    .opacity(portalPulse ? 0.9 : 0.35)
            }
        }
        .offset(y: -55)
    }

    private var branding: some View {
        VStack(spacing: 9) {
            Text("AZEROTH")
                .font(
                    .system(
                        size: 32,
                        weight: .black,
                        design: .serif
                    )
                )
                .tracking(9)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            .white,
                            Color(red: 0.85, green: 0.87, blue: 0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.5), radius: 8)

            HStack(spacing: 12) {
                Rectangle()
                    .fill(gold.opacity(0.5))
                    .frame(width: 32, height: 1)

                Text("LAUNCHER")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(7)
                    .foregroundStyle(gold)

                Rectangle()
                    .fill(gold.opacity(0.5))
                    .frame(width: 32, height: 1)
            }

            Text("YOUR ADVENTURE BEGINS HERE")
                .font(.system(size: 9, weight: .medium))
                .tracking(2.5)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.top, 9)
        }
        .offset(y: 145)
        .opacity(contentVisible ? 1 : 0)
    }

    private var loadingIndicator: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
                .tint(gold)

            Text("PREPARING YOUR REALM")
                .font(.system(size: 9, weight: .medium))
                .tracking(2.5)
                .foregroundStyle(.white.opacity(0.4))
        }
        .offset(y: 255)
        .opacity(contentVisible ? 1 : 0)
    }

    private func startAnimations() {
        withAnimation(.easeOut(duration: 1.0)) {
            contentVisible = true
        }

        withAnimation(
            .linear(duration: 24)
                .repeatForever(autoreverses: false)
        ) {
            rotation = 360
        }

        withAnimation(
            .linear(duration: 16)
                .repeatForever(autoreverses: false)
        ) {
            reverseRotation = -360
        }

        portalPulse = true
    }
}
