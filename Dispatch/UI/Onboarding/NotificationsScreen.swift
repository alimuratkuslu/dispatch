import SwiftUI

struct NotificationsScreen: View {
    let notificationManager: NotificationManager
    let onNext: () -> Void

    @State private var permissionStatus: String = "Not determined"
    @State private var isRequesting = false
    @State private var granted = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 52, weight: .ultraLight))
                    .foregroundStyle(.orange)
                    .padding(.top, 32)

                Text("Enable Notifications")
                    .font(.system(size: 24, weight: .bold))

                Text("Dispatch needs permission to send you alerts for CI failures, new reviews, comments, and more.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
            }

            Spacer()

            // Notification types preview
            VStack(alignment: .leading, spacing: 10) {
                NotifTypeRow(icon: "xmark.octagon.fill", color: .red, text: "CI check failed or fixed")
                NotifTypeRow(icon: "person.crop.circle.badge.checkmark", color: .green, text: "PR approved or changes requested")
                NotifTypeRow(icon: "person.fill.viewfinder", color: .blue, text: "Review requested from you")
                NotifTypeRow(icon: "bubble.left.fill", color: .indigo, text: "New comment on your PRs")
                NotifTypeRow(icon: "cpu.fill", color: .purple, text: "Copilot review ready")
            }
            .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 12) {
                if granted {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Notifications enabled!")
                            .foregroundStyle(.green)
                            .font(.system(size: 13, weight: .medium))
                    }
                    Button(action: onNext) {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button(action: { Task { await requestPermission() } }) {
                        HStack {
                            if isRequesting { ProgressView().controlSize(.small) }
                            Text("Enable Notifications")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isRequesting)

                    Button("Skip for now", action: onNext)
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
        }
        .padding(24)
        .task { await checkCurrentStatus() }
    }

    private func checkCurrentStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        granted = settings.authorizationStatus == .authorized
    }

    private func requestPermission() async {
        isRequesting = true
        await notificationManager.requestPermission()
        await checkCurrentStatus()
        isRequesting = false
        if granted { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { onNext() } }
    }
}

struct NotifTypeRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
        }
    }
}

// Needed for notification permission checking
import UserNotifications
