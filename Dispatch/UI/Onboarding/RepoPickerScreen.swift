import SwiftUI

struct RepoPickerScreen: View {
    let dataStore: DataStore
    let onNext: () -> Void
    let onSkip: () -> Void

    @State private var repos: [MonitoredRepo] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedRepo: MonitoredRepo?
    @State private var addedRepo: MonitoredRepo?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundStyle(.blue)
                    .padding(.top, 28)

                Text("Add a Repository")
                    .font(.system(size: 22, weight: .bold))

                Text("Choose a GitHub repository to monitor. You can add more in Preferences.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 12)

            if let added = addedRepo {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("\(added.fullName) added!")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.green)
                }
                .padding()

                Button(action: onNext) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 40)
                .padding(.bottom, 12)

                Button("Add another repository in Preferences", action: onNext)
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 24)
            } else if isLoading {
                ProgressView("Loading repositories…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("Try Again") { Task { await loadRepos() } }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(repos, selection: $selectedRepo) { repo in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(repo.fullName)
                            .font(.system(size: 13, weight: .medium))
                        Text("Default branch: \(repo.defaultBranch)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .tag(repo)
                }
                .frame(maxWidth: .infinity)

                if let error = error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack {
                    Button("Skip for now", action: onSkip)
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Add Repository") {
                        guard let repo = selectedRepo else { return }
                        addRepository(repo)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedRepo == nil)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
        .padding(16)
        .task { await loadRepos() }
    }

    private func loadRepos() async {
        guard dataStore.connectedAccount != nil else {
            error = "No GitHub account connected. Connect your account first."
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }
        let keychain = KeychainService()
        let client = GitHubAPIClient(keychainService: keychain)
        do {
            repos = try await client.fetchUserRepos()
            let existingIDs = Set(dataStore.monitoredRepositories.map(\.id))
            repos = repos.filter { !existingIDs.contains($0.id) }
        } catch {
            self.error = "Could not load repositories: \(error.localizedDescription)"
        }
    }

    private func addRepository(_ repo: MonitoredRepo) {
        do {
            try dataStore.addRepository(repo)
            addedRepo = repo
        } catch {
            self.error = error.localizedDescription
        }
    }
}
