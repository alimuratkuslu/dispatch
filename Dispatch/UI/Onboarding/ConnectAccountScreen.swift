import SwiftUI

struct ConnectAccountScreen: View {
    let dataStore: DataStore
    let onNext: () -> Void
    let onSkip: () -> Void

    @State private var mode: AuthMode = .deviceFlow
    @State private var pat = ""
    @State private var isConnecting = false
    @State private var error: String?
    @State private var deviceCodeInfo: DeviceCodeInfo?
    @State private var pollingForToken = false

    enum AuthMode { case deviceFlow, pat }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundStyle(.blue)
                    .padding(.top, 28)

                Text("Connect GitHub Account")
                    .font(.system(size: 22, weight: .bold))

                Text("Dispatch needs a GitHub token to read your pull requests.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 32)

            Picker("Auth Method", selection: $mode) {
                Text("Device Flow (Recommended)").tag(AuthMode.deviceFlow)
                Text("Personal Access Token").tag(AuthMode.pat)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 32)
            .padding(.bottom, 16)

            if mode == .deviceFlow {
                deviceFlowSection
            } else {
                patSection
            }

            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button("Skip — connect later in Preferences", action: onSkip)
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 28)
        }
        .padding(24)
    }

    // MARK: - Device Flow

    private var deviceFlowSection: some View {
        VStack(spacing: 16) {
            if let info = deviceCodeInfo {
                VStack(spacing: 12) {
                    Text("Enter this code at github.com/login/device:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Text(info.userCode)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .tracking(4)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(info.userCode, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                        .help("Copy code")
                    }

                    Button("Open GitHub →") {
                        NSWorkspace.shared.open(info.verificationURI)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                    if pollingForToken {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Waiting for authorization…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
            } else {
                Button(action: { Task { await startDeviceFlow() } }) {
                    HStack {
                        if isConnecting { ProgressView().controlSize(.small) }
                        Text("Start Authorization")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 40)
                .disabled(isConnecting)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - PAT section

    private var patSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Requires scopes: repo, read:user, notifications")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            SecureField("ghp_xxxxxxxxxxxx", text: $pat)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 40)

            Button(action: { Task { await connectWithPAT() } }) {
                HStack {
                    if isConnecting { ProgressView().controlSize(.small) }
                    Text("Connect")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .disabled(pat.isEmpty || isConnecting)
        }
    }

    // MARK: - Actions

    private func startDeviceFlow() async {
        isConnecting = true
        error = nil
        let keychain = KeychainService()
        let client = GitHubAPIClient(keychainService: keychain)
        do {
            let response = try await client.requestDeviceCode(clientID: GitHubOAuth.clientID)
            let info = DeviceCodeInfo(
                deviceCode: response.deviceCode,
                userCode: response.userCode,
                verificationURI: response.verificationURI,
                interval: response.interval
            )
            deviceCodeInfo = info
            // Copy code to clipboard and open browser automatically
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(info.userCode, forType: .string)
            NSWorkspace.shared.open(info.verificationURI)
            isConnecting = false
            pollingForToken = true
            await pollForToken(client: client, deviceCode: response.deviceCode, interval: response.interval)
        } catch let apiErr as APIError {
            switch apiErr {
            case .graphQLError(let msg):
                self.error = msg
            default:
                self.error = "Failed to start authorization: \(apiErr.localizedDescription)"
            }
            isConnecting = false
        } catch {
            self.error = "Failed to start authorization: \(error.localizedDescription)"
            isConnecting = false
        }
    }

    private func pollForToken(client: GitHubAPIClient, deviceCode: String, interval: Int) async {
        var currentInterval = interval
        let maxAttempts = 60
        var attempts = 0
        while attempts < maxAttempts {
            try? await Task.sleep(nanoseconds: UInt64(currentInterval) * 1_000_000_000)
            do {
                let token = try await client.pollForToken(clientID: GitHubOAuth.clientID, deviceCode: deviceCode)
                let keychain = KeychainService()
                let account = try await client.fetchCurrentUser(token: token)
                try await keychain.save(token: token, account: "github")
                await MainActor.run {
                    dataStore.connectedAccount = account
                    dataStore.viewerLogin = account.login
                    UserDefaults.standard.set(account.login, forKey: "connectedAccountLogin")
                    pollingForToken = false
                    onNext()
                }
                return
            } catch APIError.deviceFlowPending {
                attempts += 1
                continue
            } catch APIError.deviceFlowSlowDown {
                currentInterval += 5
                attempts += 1
                continue
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    pollingForToken = false
                }
                return
            }
        }
        await MainActor.run {
            error = "Authorization timed out. Please try again."
            pollingForToken = false
        }
    }

    private func connectWithPAT() async {
        isConnecting = true
        error = nil
        let keychain = KeychainService()
        let client = GitHubAPIClient(keychainService: keychain)
        do {
            let account = try await client.fetchCurrentUser(token: pat)
            try await keychain.save(token: pat, account: "github")
            await MainActor.run {
                dataStore.connectedAccount = account
                dataStore.viewerLogin = account.login
                UserDefaults.standard.set(account.login, forKey: "connectedAccountLogin")
                onNext()
            }
        } catch {
            await MainActor.run {
                self.error = "Invalid token: \(error.localizedDescription)"
            }
        }
        isConnecting = false
    }
}
