import SwiftUI
import AppKit

/// Renders a generated meeting analysis with its summary, key points, and
/// overall assessment.
struct VerdictView: View {
    let verdict: Verdict

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Analysis")
                    .font(.title3.bold())
                Spacer()
                Button {
                    copyVerdict()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Summary")
                    .font(.headline)
                Text(verdict.summary)
                    .textSelection(.enabled)
            }

            if !verdict.keyPoints.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Key Points")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(verdict.keyPoints.enumerated()), id: \.offset) { _, point in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                Text(point)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Verdict")
                    .font(.headline)
                Text(verdict.verdictText)
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func copyVerdict() {
        var text = "Summary:\n\(verdict.summary)\n\n"
        if !verdict.keyPoints.isEmpty {
            text += "Key Points:\n" + verdict.keyPoints.map { "- \($0)" }.joined(separator: "\n") + "\n\n"
        }
        text += "Verdict:\n\(verdict.verdictText)"

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
