//
//  SignInScreen.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import SwiftUI

struct SignInScreen: View {
    @Environment(UserRepository.self) private var userRepo
    @ScaledMetric(relativeTo: .largeTitle) private var logoSize: CGFloat = 64

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundLayer(in: geometry)

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: geometry.size.height * 0.08)

                        brandingSection

                        Spacer()

                        signInSection

                        Spacer(minLength: Spacing.lg)
                    }
                    .frame(minHeight: geometry.size.height)
                    .padding(.horizontal, Spacing.lg)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationBarBackButtonHidden()
    }

    private func backgroundLayer(in geometry: GeometryProxy) -> some View {
        ZStack {
            Color.psyspaceBackgroundWarm
                .ignoresSafeArea()

            Circle()
                .fill(Color.psyspaceDecorative1)
                .frame(width: geometry.size.width * 0.7)
                .blur(radius: 60)
                .offset(x: geometry.size.width * 0.4, y: -geometry.size.height * 0.15)

            Circle()
                .fill(Color.psyspaceDecorative2)
                .frame(width: geometry.size.width * 0.6)
                .blur(radius: 50)
                .offset(x: -geometry.size.width * 0.35, y: geometry.size.height * 0.35)

            Ellipse()
                .fill(Color.psyspaceDecorative3)
                .frame(width: geometry.size.width * 0.5, height: geometry.size.width * 0.3)
                .blur(radius: 40)
                .offset(y: geometry.size.height * 0.1)
        }
    }

    private var brandingSection: some View {
        VStack(spacing: Spacing.lg) {
            logoView

            VStack(spacing: Spacing.sm) {
                Text("PsySpace")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.psyspaceTextPrimary)

                Text("Ваш шлях до гармонії,\nкрок за кроком")
                    .font(.title3)
                    .foregroundStyle(Color.psyspaceTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
    }

    private var logoView: some View {
        ZStack {
            Circle()
                .fill(Color.psyspacePrimary.opacity(0.15))
                .frame(width: logoSize * 2.4, height: logoSize * 2.4)

            Circle()
                .fill(Color.psyspacePrimary.opacity(0.25))
                .frame(width: logoSize * 1.8, height: logoSize * 1.8)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.psyspacePrimary, Color.psyspaceAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: logoSize * 1.3, height: logoSize * 1.3)

            Image(systemName: "brain.head.profile")
                .font(.system(size: logoSize * 0.6))
                .foregroundStyle(.white)
        }
    }

    private var signInSection: some View {
        VStack(spacing: Spacing.md) {
            googleSignInButton

            Text("Продовжуючи, ви погоджуєтесь з Умовами використання та Політикою конфіденційності")
                .font(.caption)
                .foregroundStyle(Color.psyspaceTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.xs)
                .frame(maxWidth: 400)
        }
    }

    private var googleSignInButton: some View {
        Button(action: signInWithGoogle) {
            HStack(spacing: Spacing.sm) {
                GoogleLogo()
                    .frame(width: 20, height: 20)

                Text("Увійти з Google")
            }
            .frame(maxWidth: 400)
        }
        .buttonStyle(PsySpaceSecondaryButtonStyle(isLoading: userRepo.isLoading))
        .disabled(userRepo.isLoading)
    }

    private func signInWithGoogle() {
        Task {
            await userRepo.signInWithGoogle()
        }
    }
}

private struct GoogleLogo: View {
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(size.width, size.height) / 2

            var bluePath = Path()
            bluePath.move(to: center)
            bluePath.addArc(center: center, radius: radius, startAngle: .degrees(-45), endAngle: .degrees(45), clockwise: false)
            bluePath.closeSubpath()
            context.fill(bluePath, with: .color(Color(red: 0.26, green: 0.52, blue: 0.96)))

            var greenPath = Path()
            greenPath.move(to: center)
            greenPath.addArc(center: center, radius: radius, startAngle: .degrees(45), endAngle: .degrees(135), clockwise: false)
            greenPath.closeSubpath()
            context.fill(greenPath, with: .color(Color(red: 0.20, green: 0.66, blue: 0.33)))

            var yellowPath = Path()
            yellowPath.move(to: center)
            yellowPath.addArc(center: center, radius: radius, startAngle: .degrees(135), endAngle: .degrees(225), clockwise: false)
            yellowPath.closeSubpath()
            context.fill(yellowPath, with: .color(Color(red: 0.98, green: 0.74, blue: 0.02)))

            var redPath = Path()
            redPath.move(to: center)
            redPath.addArc(center: center, radius: radius, startAngle: .degrees(225), endAngle: .degrees(315), clockwise: false)
            redPath.closeSubpath()
            context.fill(redPath, with: .color(Color(red: 0.92, green: 0.26, blue: 0.21)))

            let innerRadius = radius * 0.5
            var whitePath = Path()
            whitePath.addEllipse(in: CGRect(
                x: center.x - innerRadius,
                y: center.y - innerRadius,
                width: innerRadius * 2,
                height: innerRadius * 2
            ))
            context.fill(whitePath, with: .color(.white))
        }
    }
}

#Preview {
    NavigationStack {
        SignInScreen()
            .environment(UserRepository())
    }
}
