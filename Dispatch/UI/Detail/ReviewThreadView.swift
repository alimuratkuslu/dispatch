import SwiftUI

struct ReviewThreadView: View {
    let thread: ReviewThread
    @Environment(DataStore.self) private var dataStore
    @State private var isExpanded: Bool = true
    @State private var replyBody: String = ""
    @State private var isSubmitting: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thread header: file path + line number
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(thread.path)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let line = thread.line {
                        Text(":\(line)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if thread.isResolved {
                        Text("Resolved")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    Text("\(thread.comments.count) comment\(thread.comments.count == 1 ? "" : "s")")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.secondary.opacity(0.05))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(thread.comments) { comment in
                        let isReply = comment.replyToID != nil
                        CommentRowView(
                            author: comment.author,
                            commentBody: comment.body,
                            date: comment.createdAt,
                            isIndented: isReply
                        )
                        .opacity(comment.isOutdated ? 0.5 : 1.0)
                        if comment != thread.comments.last {
                            Divider().padding(.leading, isReply ? 28 : 12)
                        }
                    }

                    if !thread.isResolved {
                        Divider().padding(.leading, 12)
                        HStack(spacing: 8) {
                            TextField("Reply...", text: $replyBody)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                                .padding(6)
                                .background(.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            
                            if isSubmitting {
                                ProgressView().controlSize(.small)
                            } else {
                                Button("Reply") {
                                    submitReply()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .disabled(replyBody.isEmpty)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                }
                .background(.secondary.opacity(0.02))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(.secondary.opacity(0.3))
                        .frame(width: 2)
                        .padding(.leading, 12)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(.secondary.opacity(0.2), lineWidth: 0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .opacity(thread.isResolved ? 0.65 : 1.0)
    }

    private func submitReply() {
        guard !replyBody.isEmpty else { return }
        isSubmitting = true
        Task {
            do {
                try await dataStore.apiClient.submitThreadReply(threadID: thread.id, body: replyBody)
                replyBody = ""
                // Refreshes the detail view by polling GitHub again
                NotificationCenter.default.post(name: NSNotification.Name("com.dispatch.refreshPR"), object: nil)
            } catch {
                print("Failed to submit reply: \(error)")
            }
            isSubmitting = false
        }
    }
}
