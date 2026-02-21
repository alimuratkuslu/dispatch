import SwiftUI

struct CommentRowView: View {
    let author: PRAuthor
    let commentBody: String
    let date: Date
    var isIndented: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isIndented { Spacer().frame(width: 16) }

            AvatarView(url: author.avatarURL, size: 20)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(author.login)
                        .font(.system(size: 11, weight: .semibold))
                    if author.isCopilot {
                        Label("Copilot", systemImage: "cpu")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(.purple.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    } else if author.isBot {
                        Text("Bot")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    Spacer()
                    Text(date, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                LinkedText(commentBody)
                    .font(.system(size: 11))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

/// Renders text with tappable URLs
struct LinkedText: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        // Simple implementation: detect URLs and make them tappable
        let attributed = makeAttributedString()
        Text(attributed)
            .font(.system(size: 11))
            .textSelection(.enabled)
    }

    private func makeAttributedString() -> AttributedString {
        var attributed = AttributedString(text)
        // Find and linkify URLs
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = detector.matches(in: text, options: [], range: range)
            for match in matches {
                guard let range = Range(match.range, in: text),
                      let url = match.url else { continue }
                if let attrRange = Range(range, in: attributed) {
                    attributed[attrRange].link = url
                    attributed[attrRange].foregroundColor = .systemBlue
                }
            }
        }
        return attributed
    }
}
