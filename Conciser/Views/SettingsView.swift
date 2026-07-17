import SwiftUI

struct SettingsView: View {
    @AppStorage("geminiApiKey") private var apiKey: String = ""
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "id"
    @AppStorage("identifySpeakers") private var identifySpeakers: Bool = true

    var body: some View {
        Form {
            Section("Gemini API Key") {
                SecureField("API Key", text: $apiKey)
                    .textContentType(.password)

                Text("Your transcript is sent to Google Gemini only when you generate a verdict. Transcription & speaker separation run fully on-device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Link("Get an API key at ai.google.dev", destination: URL(string: "https://ai.google.dev")!)
                    .font(.caption)
            }

            Section("Transcription Language") {
                Picker("Language", selection: $selectedLanguage) {
                    Text("Indonesian").tag("id")
                    Text("English").tag("en")
                    Text("Auto-detect").tag("")
                }
                .pickerStyle(.radioGroup)

                Toggle("Identify speakers (who said what)", isOn: $identifySpeakers)

                Text("When off, transcription is faster and produces a single running transcript without speaker labels.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 320)
    }
}

#Preview {
    SettingsView()
}
