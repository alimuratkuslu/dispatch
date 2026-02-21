import SwiftUI

struct DoneScreen: View {
    let onDone: () -> Void
    @State private var showCheckmark = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(.green.opacity(0.12))
                        .frame(width: 100, height: 100)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                        .scaleEffect(showCheckmark ? 1.0 : 0.5)
                        .opacity(showCheckmark ? 1.0 : 0)
                }

                VStack(spacing: 8) {
                    Text("You're all set!")
                        .font(.system(size: 26, weight: .bold))

                    Text("Dispatch is now monitoring your repositories.\nIt lives in your menu bar — click the icon anytime.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                TipRow(icon: "cursorarrow.click", text: "Click the menu bar icon to view your PRs")
                TipRow(icon: "gear", text: "Open Preferences to manage repos and notifications")
                TipRow(icon: "bell.badge", text: "Notifications will alert you of important events")
            }
            .padding(.horizontal, 40)

            Spacer()

            Button(action: onDone) {
                Text("Open Dispatch")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
        }
        .padding(24)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1)) {
                showCheckmark = true
            }
        }
    }
}

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}
