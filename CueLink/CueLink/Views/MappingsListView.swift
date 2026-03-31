import SwiftUI

struct MappingsListView: View {
    @EnvironmentObject var appState: AppState
    @State private var editingMapping: CueLinkMapping?
    @State private var isNewMapping = false
    @State private var selectedMappingId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            if appState.mappings.isEmpty {
                Spacer()
                Text("No mappings configured")
                    .foregroundStyle(.secondary)
                Text("Click + to add a MIDI → Webhook mapping")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            } else {
                List(selection: $selectedMappingId) {
                    ForEach(appState.mappings) { mapping in
                        MappingRow(mapping: mapping)
                            .tag(mapping.id)
                            .contextMenu {
                                Button("Edit") { isNewMapping = false; editingMapping = mapping }
                                Button("Duplicate") { appState.duplicateMapping(mapping.id) }
                                Divider()
                                Button("Delete", role: .destructive) { appState.deleteMapping(mapping.id) }
                            }
                            .onTapGesture(count: 2) { isNewMapping = false; editingMapping = mapping }
                    }
                    .onMove { source, destination in
                        appState.moveMappings(from: source, to: destination)
                    }
                }
            }

            Divider()

            HStack {
                Button(action: addNewMapping) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("n", modifiers: .command)

                Button(action: deleteSelected) {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(selectedMappingId == nil)

                Spacer()
            }
            .padding(8)
        }
        .sheet(item: $editingMapping) { mapping in
            MappingEditorView(
                mapping: mapping,
                onSave: { updated in
                    appState.updateMapping(updated)
                    isNewMapping = false
                    editingMapping = nil
                },
                onCancel: {
                    if isNewMapping {
                        appState.deleteMapping(mapping.id)
                        isNewMapping = false
                    }
                    editingMapping = nil
                }
            )
            .environmentObject(appState)
        }
    }

    private func addNewMapping() {
        let newMapping = CueLinkMapping()
        appState.addMapping(newMapping)
        isNewMapping = true
        editingMapping = newMapping
    }

    private func deleteSelected() {
        guard let id = selectedMappingId else { return }
        appState.deleteMapping(id)
        selectedMappingId = nil
    }
}

struct MappingRow: View {
    @EnvironmentObject var appState: AppState
    let mapping: CueLinkMapping

    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { mapping.isEnabled },
                set: { newValue in
                    var updated = mapping
                    updated.isEnabled = newValue
                    appState.updateMapping(updated)
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)

            VStack(alignment: .leading, spacing: 2) {
                Text(mapping.name.isEmpty ? "Untitled" : mapping.name)
                    .fontWeight(.medium)
                Text("Note \(mapping.midiNote) Ch \(mapping.midiChannel + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(mapping.webhookURL)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 200)
        }
        .padding(.vertical, 2)
    }
}
