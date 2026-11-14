//
//  OnboardingView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 14.11.2026.
//

import SwiftUI

struct OnboardingView: View{
    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var isContentVisible = false
    @State private var isAnimating = false
    @State private var isCompleting = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "sparkles",
            title: "Welcome to Azeroth",
            subtitle: "Your adventure begins here.",
            description: "Azeroth Launcher brings your favorite World of Warcraft game editions together in one place.",
            accent: Color(red: 0.92, green: 0.66, blue: 0.30),
            secondaryAccent: Color(red: 0.35, green: 0.55, blue: 0.95),
            caption: "A WORLD OF ADVENTURES"
        ),
        OnboardingPage(
            icon: "globe.americas.fill",
            title: "Your Worlds",
            subtitle: "One launcher. Multiple adventures.",
            description: "Manage Wrath of the Lich King, Cataclysm and Mists of Pandaria installations independently.",
            accent: Color(red: 0.35, green: 0.65, blue: 1.0),
            secondaryAccent: Color(red: 0.45, green: 0.85, blue: 0.85),
            caption: "THREE ERAS. ONE HOME."
        ),
        OnboardingPage(
            icon: "gamecontroller.fill",
            title: "Ready for Adventure?",
            subtitle: "Your journey starts now.",
            description: "Add your game client, configure Wine Runtime and graphics, and return to Azeroth.",
            accent: Color(red: 0.95, green: 0.66, blue: 0.30),
            secondaryAccent: Color(red: 0.45, green: 0.60, blue: 1.0),
            caption: "YOUR NEXT ADVENTURE AWAITS"
        )
    ]

    private var page: OnboardingPage {
        pages[currentPage]
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                background

                ambientLighting
                ArcaneParticleView(
                    particleCount: 38,
                    intensity: 0.55
                )

                VStack(spacing: 0) {
                    topBar

                    Spacer(minLength: 8)

                    pageContent
                        .frame(maxWidth: .infinity)

                    Spacer(minLength: 8)

                    bottomControls
                }
                .padding(.horizontal, 45)
                .padding(.vertical, 22)
                .frame(
                    width: min(geometry.size.width, 1000),
                    height: min(geometry.size.height, 760)
                )
            }
            .opacity(isCompleting ? 0 : 1)
            .scaleEffect(isCompleting ? 0.96 : 1)
            .offset(y: isCompleting ? 18 : 0)
            .animation(
                .easeInOut(duration: 0.55),
                value: isCompleting
            )
            .allowsHitTesting(!isCompleting)
            .frame(
                width: geometry.size.width,
                height: geometry.size.height
            )
            .frame(minWidth: 800, minHeight: 600)
            .onAppear {
                startAnimations()
            }
        }
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
                    page.accent.opacity(0.10),
                    .clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 450
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
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.7), value: currentPage)
    }

    private var ambientLighting: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .fill(page.accent.opacity(0.12))
                    .frame(width: 350, height: 350)
                    .blur(radius: 110)
                    .offset(
                        x: geometry.size.width * 0.28,
                        y: -geometry.size.height * 0.25
                    )

                Circle()
                    .fill(page.secondaryAccent.opacity(0.10))
                    .frame(width: 350, height: 350)
                    .blur(radius: 110)
                    .offset(
                        x: -geometry.size.width * 0.30,
                        y: geometry.size.height * 0.28
                    )
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.8), value: currentPage)
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 11) {
                ZStack {
                    Circle()
                        .fill(page.accent.opacity(0.12))
                        .frame(width: 34, height: 34)

                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(page.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("AZEROTH")
                        .font(.system(size: 11, weight: .black))
                        .tracking(2.5)
                        .foregroundStyle(.white.opacity(0.9))

                    Text("LAUNCHER")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(2.5)
                        .foregroundStyle(page.accent)
                }
            }

            Spacer()

            Button {
                completeOnboarding()
            } label: {
                HStack(spacing: 7) {
                    Text("Skip")

                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.white.opacity(0.045))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var pageContent: some View {
        VStack(spacing: 16) {
            scene

            VStack(spacing: 13) {
                Text(page.caption)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(page.accent)
                    .padding(.bottom, 2)

                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(page.accent)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .frame(maxWidth: 470)
                    .padding(.top, 5)
            }
            .opacity(isContentVisible ? 1 : 0)
            .offset(y: isContentVisible ? 0 : 15)
            .id(currentPage)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        .animation(.easeInOut(duration: 0.4), value: currentPage)
    }

    private var scene: some View {
        ZStack {
            Circle()
                .fill(page.accent.opacity(0.07))
                .frame(width: 250, height: 250)
                .blur(radius: 45)

            Circle()
                .stroke(
                    page.accent.opacity(0.12),
                    style: StrokeStyle(
                        lineWidth: 1,
                        dash: [3, 9]
                    )
                )
                .frame(width: 230, height: 230)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            page.accent.opacity(0.05),
                            page.accent,
                            .white.opacity(0.7),
                            page.accent.opacity(0.1)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        lineCap: .round
                    )
                )
                .frame(width: 195, height: 195)
                .rotationEffect(.degrees(isAnimating ? -360 : 0))

            Circle()
                .stroke(
                    page.secondaryAccent.opacity(0.35),
                    style: StrokeStyle(
                        lineWidth: 1,
                        dash: [2, 6]
                    )
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(isAnimating ? 180 : 0))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            page.accent.opacity(0.25),
                            page.secondaryAccent.opacity(0.12),
                            .clear
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 85
                    )
                )
                .frame(width: 150, height: 150)
                .scaleEffect(isAnimating ? 1.08 : 0.94)

            Circle()
                .stroke(page.accent.opacity(0.4), lineWidth: 1)
                .frame(width: 115, height: 115)
                .blur(radius: 2)

            Image(systemName: page.icon)
                .font(.system(size: 54, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            .white,
                            page.accent,
                            page.secondaryAccent
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: page.accent.opacity(0.7), radius: 22)
                .scaleEffect(isAnimating ? 1.06 : 0.94)

            sceneParticles
        }
        .scaleEffect(0.78)
        .frame(width: 205, height: 205)
        .id(currentPage)
        .transition(.opacity.combined(with: .scale(scale: 0.85)))
        .animation(.easeInOut(duration: 0.5), value: currentPage)
    }

    private var sceneParticles: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                let angle = Double(index) * 30

                Circle()
                    .fill(
                        index.isMultiple(of: 2)
                            ? page.accent
                            : page.secondaryAccent
                    )
                    .frame(
                        width: index.isMultiple(of: 3) ? 4 : 2,
                        height: index.isMultiple(of: 3) ? 4 : 2
                    )
                    .shadow(
                        color: page.accent.opacity(0.8),
                        radius: 5
                    )
                    .offset(y: -119)
                    .rotationEffect(
                        .degrees(angle + (isAnimating ? 360 : 0))
                    )
                    .opacity(isAnimating ? 0.9 : 0.35)
            }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 25) {
            pageIndicator

            HStack {
                Button {
                    changePage(to: currentPage - 1)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")

                        Text("Back")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(currentPage == 0 ? 0 : 1)
                .disabled(currentPage == 0)

                Spacer()

                Button {
                    if currentPage == pages.count - 1 {
                        completeOnboarding()
                    } else {
                        changePage(to: currentPage + 1)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text(
                            currentPage == pages.count - 1
                                ? "Get Started"
                                : "Continue"
                        )

                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(
                        Color(red: 0.08, green: 0.07, blue: 0.06)
                    )
                    .padding(.horizontal, 25)
                    .frame(height: 44)
                    .background(
                        LinearGradient(
                            colors: [
                                page.accent,
                                page.accent.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .shadow(
                        color: page.accent.opacity(0.2),
                        radius: 15,
                        y: 5
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 9) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(
                        index == currentPage
                            ? page.accent
                            : Color.white.opacity(0.18)
                    )
                    .frame(
                        width: index == currentPage ? 30 : 7,
                        height: 7
                    )
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.8),
                        value: currentPage
                    )
            }
        }
    }

    private func changePage(to index: Int) {
        guard pages.indices.contains(index) else {
            return
        }

        withAnimation(
            reduceMotion
                ? .linear(duration: 0.15)
                : .easeInOut(duration: 0.4)
        ) {
            isContentVisible = false
            currentPage = index
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)

            withAnimation(.easeOut(duration: 0.45)) {
                isContentVisible = true
            }
        }
    }

    private func completeOnboarding() {
        guard !isCompleting else {
            return
        }

        withAnimation(.easeInOut(duration: 0.55)) {
            isCompleting = true
            isContentVisible = false
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            onComplete()
        }
    }

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.8)) {
            isContentVisible = true
        }

        guard !reduceMotion else {
            return
        }

        withAnimation(
            .linear(duration: 30)
                .repeatForever(autoreverses: false)
        ) {
            isAnimating = true
        }
    }
}

private struct OnboardingPage {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let description: LocalizedStringKey
    let accent: Color
    let secondaryAccent: Color
    let caption: LocalizedStringKey
}
