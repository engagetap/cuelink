import SwiftUI

struct MappingEditorView: View {
    @EnvironmentObject var appState: AppState
    @State var mapping: CueLinkMapping
    var onSave: (CueLinkMapping) -> Void
    var onCancel: () -> Void

    @State private var newHeaderKey = ""
    @State private var newHeaderValue = ""
    @State private var urlError: String?
    @State private var payloadError: String?
    @State private var showLearnSheet = false
    @State private var testResult: String?
    @State private var testInProgress = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("General") {
                    TextField("Name", text: $mapping.name)
                    Toggle("Enabled", isOn: $mapping.isEnabled)
                }

                Section("MIDI") {
                    HStack {
                        LabeledContent("Note") {
                            TextField("Note", value: $mapping.midiNote, format: .number)
                                .frame(width: 60)
                        }
                        LabeledContent("Channel") {
                            TextField("Channel", value: Binding(
                                get: { mapping.midiChannel + 1 },
                                set: { mapping.midiChannel = $0 > 0 ? $0 - 1 : 0 }
                            ), format: .number)
                                .frame(width: 60)
                        }
                        Spacer()
                        Button("Learn") {
                            appState.startLearning(for: mapping.id)
                            showLearnSheet = true
                        }
                    }
                }

                Section("Webhook") {
                    TextField("URL", text: $mapping.webhookURL)
                        .onChange(of: mapping.webhookURL) { _, newValue in
                            validateURL(newValue)
                        }
                    if let urlError {
                        Text(urlError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Picker("Method", selection: $mapping.httpMethod) {
                        ForEach(WebhookHTTPMethod.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }

                Section("Payload") {
                    Picker("Mode", selection: $mapping.payloadMode) {
                        Text("Default").tag(PayloadMode.default)
                        Text("Custom").tag(PayloadMode.custom)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .onChange(of: mapping.payloadMode) { _, newMode in
                        if newMode == .default {
                            payloadError = nil
                        } else {
                            validatePayload(mapping.customPayload)
                        }
                    }

                    if mapping.payloadMode == .default {
                        Text("Sends: {\"cue\": \"\(mapping.name)\", \"note\": \(mapping.midiNote), \"channel\": \(mapping.midiChannel + 1), \"timestamp\": \"...\"}")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        TextEditor(text: Binding(
                            get: { mapping.customPayload ?? "{}" },
                            set: { mapping.customPayload = $0 }
                        ))
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 80)
                        .onChange(of: mapping.customPayload) { _, newValue in
                            validatePayload(newValue)
                        }
                        if let payloadError {
                            Text(payloadError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                Section("Headers") {
                    ForEach(Array(mapping.headers.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text(key)
                                .fontWeight(.medium)
                            Text(mapping.headers[key] ?? "")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button(role: .destructive) {
                                mapping.headers.removeValue(forKey: key)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    HStack {
                        TextField("Key", text: $newHeaderKey)
                            .frame(width: 120)
                        TextField("Value", text: $newHeaderValue)
                        Button(action: {
                            guard !newHeaderKey.isEmpty else { return }
                            mapping.headers[newHeaderKey] = newHeaderValue
                            newHeaderKey = ""
                            newHeaderValue = ""
                        }) {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(newHeaderKey.isEmpty)
                    }
                }

                Section("Retry") {
                    Picker("Retry Count", selection: $mapping.retryCount) {
                        Text("None").tag(0)
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("3").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 250)
                    Text("Number of retries on failure (1s delay between)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if let testResult {
                    Text(testResult)
                        .font(.caption)
                        .foregroundStyle(testResult.hasPrefix("OK") ? .green : .red)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 180)
                }
                Button("Test") {
                    testWebhook()
                }
                .disabled(!isValid || testInProgress)
                Button("Save") {
                    onSave(mapping)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 500, height: 620)
        .sheet(isPresented: $showLearnSheet) {
            MIDILearnSheet(mappingId: mapping.id) {
                showLearnSheet = false
            }
            .environmentObject(appState)
        }
        .onReceive(appState.$mappings) { mappings in
            if let updated = mappings.first(where: { $0.id == mapping.id }) {
                mapping.midiNote = updated.midiNote
                mapping.midiChannel = updated.midiChannel
            }
        }
    }

    private var isValid: Bool {
        urlError == nil && payloadError == nil && !mapping.webhookURL.isEmpty
    }

    private func validateURL(_ url: String) {
        if url.isEmpty {
            urlError = nil
            return
        }
        guard let parsed = URL(string: url),
              let scheme = parsed.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            urlError = "Must be a valid HTTP or HTTPS URL"
            return
        }
        urlError = nil
    }

    private func testWebhook() {
        testInProgress = true
        testResult = nil
        let service = appState.webhookService
        let testMapping = mapping
        Task {
            let result = await service.fire(mapping: testMapping)
            await MainActor.run {
                testInProgress = false
                if result.isSuccess {
                    testResult = "OK \(result.statusCode ?? 200)"
                } else if let code = result.statusCode {
                    testResult = "Failed \(code)"
                } else {
                    testResult = result.error ?? "Failed"
                }
                // Auto-clear after 4 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    await MainActor.run {
                        testResult = nil
                    }
                }
            }
        }
    }

    private func validatePayload(_ payload: String?) {
        guard let payload, mapping.payloadMode == .custom else {
            payloadError = nil
            return
        }
        guard let data = payload.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            payloadError = "Must be valid JSON"
            return
        }
        payloadError = nil
    }
}
