import AppKit
import SwiftUI
import ServiceManagement

// MARK: - PreferencesWindow

final class PreferencesWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let dataStore: DataStore
    private let pollingEngine: PollingEngine
    private let notificationManager: NotificationManager

    init(dataStore: DataStore, pollingEngine: PollingEngine, notificationManager: NotificationManager) {
        self.dataStore = dataStore
        self.pollingEngine = pollingEngine
        self.notificationManager = notificationManager
    }

    func show() {
        if window == nil {
            let prefView = PreferencesView(
                dataStore: dataStore,
                pollingEngine: pollingEngine,
                notificationManager: notificationManager
            )
            let controller = NSHostingController(rootView: prefView)
            let win = NSWindow(contentViewController: controller)
            win.title = "Dispatch Preferences"
            win.styleMask = [.titled, .closable, .miniaturizable]
            win.isReleasedWhenClosed = false
            win.delegate = self
            win.center()
            win.setContentSize(NSSize(width: 520, height: 420))
            window = win
        }
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

// MARK: - PreferencesView

struct PreferencesView: View {
    let dataStore: DataStore
    let pollingEngine: PollingEngine
    let notificationManager: NotificationManager

    var body: some View {
        TabView {
            GeneralTab(pollingEngine: pollingEngine)
                .tabItem { Label("General", systemImage: "gear") }

            NotificationsTab(notificationManager: notificationManager)
                .tabItem { Label("Notifications", systemImage: "bell") }

            AccountsTab()
                .tabItem { Label("Accounts", systemImage: "person.circle") }

            RepositoriesTab()
                .tabItem { Label("Repositories", systemImage: "folder") }
        }
        .frame(width: 520, height: 420)
        .padding(.top, 12)
        .environment(dataStore)
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    let pollingEngine: PollingEngine
    @Environment(DataStore.self) var dataStore: DataStore
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("pollInterval") private var pollIntervalRaw: Double = 15
    @AppStorage("openOnLaunch") private var openOnLaunch = false
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        setLaunchAtLogin(newValue)
                    }
                ))
                if let error = launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Toggle("Show popover on launch", isOn: $openOnLaunch)
            }

            Section("Polling") {
                Picker("Poll Interval", selection: Binding(
                    get: { pollIntervalRaw },
                    set: { newVal in
                        pollIntervalRaw = newVal
                        Task { @MainActor in
                            pollingEngine.pollInterval = newVal
                        }
                    }
                )) {
                    Text("10 seconds (Extremely Fast)").tag(10.0)
                    Text("15 seconds (Recommended)").tag(15.0)
                    Text("30 seconds").tag(30.0)
                    Text("1 minute").tag(60.0)
                }
                .pickerStyle(.menu)
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "Launch at login requires app to be in Applications folder."
        }
    }
}

// MARK: - Notifications Tab

struct NotificationsTab: View {
    let notificationManager: NotificationManager
    @AppStorage("notif.enabled") private var masterEnabled = true
    @AppStorage("notif.ciFailEnabled") private var ciFailEnabled = true
    @AppStorage("notif.ciFixEnabled") private var ciFixEnabled = true
    @AppStorage("notif.reviewReqEnabled") private var reviewReqEnabled = true
    @AppStorage("notif.approvalEnabled") private var approvalEnabled = true
    @AppStorage("notif.changesEnabled") private var changesEnabled = true
    @AppStorage("notif.mergeEnabled") private var mergeEnabled = true
    @AppStorage("notif.commentEnabled") private var commentEnabled = true
    @AppStorage("notif.copilotEnabled") private var copilotEnabled = true
    @AppStorage("notif.ignoreSelfActions") private var ignoreSelfActions = false
    @State private var testSent = false

    var body: some View {
        Form {
            Section {
                Toggle("Enable Notifications", isOn: $masterEnabled)
                if masterEnabled {
                    Toggle("Ignore my own actions", isOn: $ignoreSelfActions)
                        .help("Do not notify me when I approve, comment, or merge a PR.")
                }
            }

            if masterEnabled {
                Section("CI") {
                    Toggle("CI check failed (N1)", isOn: $ciFailEnabled)
                    Toggle("CI check fixed (N2)", isOn: $ciFixEnabled)
                }
                Section("Reviews") {
                    Toggle("Review requested from me (N3)", isOn: $reviewReqEnabled)
                    Toggle("My PR approved (N4)", isOn: $approvalEnabled)
                    Toggle("Changes requested on my PR (N5)", isOn: $changesEnabled)
                }
                Section("PRs") {
                    Toggle("PR merged (N6)", isOn: $mergeEnabled)
                    Toggle("New comment (N7)", isOn: $commentEnabled)
                    Toggle("Copilot review ready (N8)", isOn: $copilotEnabled)
                }
            }

            Section {
                Button("Send Test Notification") {
                    notificationManager.sendTestNotification()
                    testSent = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { testSent = false }
                }
                .disabled(!masterEnabled)

                if testSent {
                    Text("Test notification sent!")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Accounts Tab

struct AccountsTab: View {
    @Environment(DataStore.self) var dataStore: DataStore
    @State private var isVerifying = false
    @State private var verifyStatus: String?
    @State private var showingConnectSheet = false

    var body: some View {
        Form {
            if let account = dataStore.connectedAccount {
                Section("Connected Account") {
                    HStack(spacing: 12) {
                        AsyncImage(url: account.avatarURL) { img in
                            img.resizable().clipShape(Circle())
                        } placeholder: {
                            Circle().fill(.secondary.opacity(0.3))
                        }
                        .frame(width: 40, height: 40)

                        VStack(alignment: .leading) {
                            Text(account.login)
                                .font(.headline)
                            Text("GitHub")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if isVerifying {
                            ProgressView().controlSize(.small)
                        } else if let status = verifyStatus {
                            Text(status)
                                .font(.caption)
                                .foregroundStyle(status == "Valid" ? .green : .red)
                        }
                    }

                    Button("Verify Token") {
                        Task { await verifyToken() }
                    }
                    .disabled(isVerifying)

                    Button("Disconnect", role: .destructive) {
                        Task { await disconnectAccount() }
                    }
                }
            } else {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("No GitHub account connected")
                            .foregroundStyle(.secondary)
                        Button("Connect GitHub Account") {
                            showingConnectSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showingConnectSheet) {
            ConnectAccountSheet()
                .environment(dataStore)
        }
    }

    private func verifyToken() async {
        isVerifying = true
        defer { isVerifying = false }
        let keychain = KeychainService()
        guard let token = try? await keychain.load(account: "github") else {
            verifyStatus = "No token"
            return
        }
        let client = GitHubAPIClient(keychainService: keychain)
        do {
            _ = try await client.fetchCurrentUser(token: token)
            verifyStatus = "Valid"
        } catch {
            verifyStatus = "Invalid"
        }
    }

    private func disconnectAccount() async {
        let keychain = KeychainService()
        try? await keychain.delete(account: "github")
        await MainActor.run {
            dataStore.connectedAccount = nil
            dataStore.viewerLogin = ""
            UserDefaults.standard.removeObject(forKey: "connectedAccountLogin")
        }
    }
}

// MARK: - Repositories Tab

struct RepositoriesTab: View {
    @Environment(DataStore.self) var dataStore: DataStore
    @State private var showingAddSheet = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section(header: repoSectionHeader) {
                if dataStore.monitoredRepositories.isEmpty {
                    Text("No repositories added yet.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    ForEach(dataStore.monitoredRepositories) { repo in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(repo.fullName)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            Spacer()
                            Button(role: .destructive) {
                                dataStore.removeRepository(repo)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Section {
                Button("Add Repository…") {
                    showingAddSheet = true
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showingAddSheet) {
            RepoPickerSheet(dataStore: dataStore)
        }
    }

    private var repoSectionHeader: some View {
        HStack {
            Text("Repositories")
            Spacer()
        }
    }
}

// MARK: - RepoPickerSheet (used from Preferences and Onboarding)

struct RepoPickerSheet: View {
    let dataStore: DataStore
    @Environment(\.dismiss) private var dismiss
    @State private var repos: [MonitoredRepo] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedRepo: MonitoredRepo?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Repository")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding()

            Divider()

            if isLoading {
                ProgressView("Loading repositories…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(repos, selection: $selectedRepo) { repo in
                    VStack(alignment: .leading) {
                        Text(repo.fullName).font(.system(size: 13, weight: .medium))
                        Text(repo.defaultBranch)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(repo)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Add") {
                    guard let repo = selectedRepo else { return }
                    do {
                        try dataStore.addRepository(repo)
                        dismiss()
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedRepo == nil)
            }
            .padding()
        }
        .frame(width: 400, height: 440)
        .task { await loadRepos() }
    }

    private func loadRepos() async {
        isLoading = true
        defer { isLoading = false }
        let keychain = KeychainService()
        let client = GitHubAPIClient(keychainService: keychain)
        do {
            repos = try await client.fetchUserRepos()
            // Filter out already added
            let existingIDs = Set(dataStore.monitoredRepositories.map(\.id))
            repos = repos.filter { !existingIDs.contains($0.id) }
        } catch {
            self.error = "Could not load repositories: \(error.localizedDescription)"
        }
    }
}

// MARK: - ConnectAccountSheet (used from Preferences)

struct ConnectAccountSheet: View {
    @Environment(DataStore.self) var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss
    @State private var mode: ConnectMode = .deviceFlow
    @State private var pat = ""
    @State private var isConnecting = false
    @State private var error: String?
    @State private var deviceCodeInfo: DeviceCodeInfo?
    @State private var pollingForToken = false

    enum ConnectMode { case deviceFlow, pat }

    var body: some View {
        VStack(spacing: 20) {
            Text("Connect GitHub Account")
                .font(.headline)

            Picker("Method", selection: $mode) {
                Text("Device Flow").tag(ConnectMode.deviceFlow)
                Text("Personal Access Token").tag(ConnectMode.pat)
            }
            .pickerStyle(.segmented)

            if mode == .deviceFlow {
                deviceFlowContent
            } else {
                patContent
            }

            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
            }
        }
        .padding(24)
        .frame(width: 380)
    }

    private var deviceFlowContent: some View {
        VStack(spacing: 16) {
            if let info = deviceCodeInfo {
                VStack(spacing: 8) {
                    Text("Enter this code on GitHub:")
                        .foregroundStyle(.secondary)
                    Text(info.userCode)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button("Open GitHub →") {
                        NSWorkspace.shared.open(info.verificationURI)
                    }
                    .buttonStyle(.borderedProminent)

                    if pollingForToken {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Waiting for authorization…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Button("Start Authorization") {
                    Task { await startDeviceFlow() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConnecting)
            }
        }
    }

    private var patContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Personal Access Token")
                .font(.caption)
                .foregroundStyle(.secondary)
            SecureField("ghp_xxxxxxxxxxxx", text: $pat)
                .textFieldStyle(.roundedBorder)
            Text("Required scopes: repo, read:user, notifications")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Button("Connect") {
                Task { await connectWithPAT() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(pat.isEmpty || isConnecting)
        }
    }

    private func startDeviceFlow() async {
        isConnecting = true
        error = nil
        let keychain = KeychainService()
        let client = GitHubAPIClient(keychainService: keychain)
        do {
            let response = try await client.requestDeviceCode(clientID: GitHubOAuth.clientID)
            deviceCodeInfo = DeviceCodeInfo(
                deviceCode: response.deviceCode,
                userCode: response.userCode,
                verificationURI: response.verificationURI,
                interval: response.interval
            )
            pollingForToken = true
            await pollForToken(client: client, deviceCode: response.deviceCode, interval: response.interval)
        } catch {
            self.error = error.localizedDescription
        }
        isConnecting = false
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
                    dismiss()
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
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.error = "Invalid token: \(error.localizedDescription)"
            }
        }
        isConnecting = false
    }
}

struct DeviceCodeInfo {
    let deviceCode: String
    let userCode: String
    let verificationURI: URL
    let interval: Int
}
