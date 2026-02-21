import SwiftUI

struct WelcomeScreen: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 64, weight: .ultraLight))
                    .foregroundStyle(.blue)

                VStack(spacing: 8) {
                    Text("Welcome to Dispatch")
                        .font(.system(size: 28, weight: .bold))

                    Text("Your GitHub PRs, reviews, and CI status — always in your menu bar.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                FeatureHighlight(icon: "bell.badge.fill", color: .orange, title: "Instant Notifications", description: "Know the moment a PR is reviewed, CI fails, or a comment is posted.")
                FeatureHighlight(icon: "bubble.left.and.bubble.right.fill", color: .blue, title: "Full Comment Viewer", description: "See all comments, reviews, and inline threads without opening GitHub.")
                FeatureHighlight(icon: "cpu.fill", color: .purple, title: "Copilot Reviews", description: "Detect and surface GitHub Copilot code reviews in your detail panel.")
            }
            .padding(.horizontal, 24)

            Spacer()

            Button(action: onNext) {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
        }
        .padding(24)
    }
}

struct FeatureHighlight: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
