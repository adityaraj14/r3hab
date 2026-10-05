import SwiftUI
import SwiftData

/// Settings → Backups. The backups R3hab keeps on this iPhone, newest first.
/// Tap a row to restore it (after a confirmation). Swipe left to delete it.
struct BackupListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    @State private var entries: [BackupLibrary.Entry] = []
    @State private var restoreTarget: BackupLibrary.Entry?
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    private var library: BackupLibrary? { try? BackupLibrary.app() }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    BackupCopy.emptyTitle,
                    systemImage: "archivebox",
                    description: Text(BackupCopy.emptyBody)
                )
            } else {
                Section {
                    ForEach(entries) { entry in
                        Button {
                            restoreTarget = entry
                        } label: {
                            BackupRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("backup-row")
                        .accessibilityHint("Restore")
                    }
                    .onDelete(perform: delete)
                } footer: {
                    Text(BackupCopy.listFooter)
                }
            }
        }
        .appListCanvas()
        .navigationTitle(BackupCopy.listTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .alert(
            BackupCopy.restoreTitle,
            isPresented: Binding(
                get: { restoreTarget != nil },
                set: { if !$0 { restoreTarget = nil } }
            ),
            presenting: restoreTarget
        ) { entry in
            Button(BackupCopy.restoreButton, role: .destructive) { restore(entry) }
            Button("Cancel", role: .cancel) {}
        } message: { entry in
            Text(BackupCopy.restoreMessage(entry.summary))
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func reload() {
        entries = library?.entries() ?? []
    }

    private func delete(at offsets: IndexSet) {
        guard let library else { return }
        for entry in offsets.map({ entries[$0] }) {
            do {
                try library.delete(entry)
            } catch {
                present("Delete failed", error.localizedDescription)
            }
        }
        reload()
    }

    private func restore(_ entry: BackupLibrary.Entry) {
        do {
            guard let library else { throw ExportImportError.decodeFailed }
            // Keep the current data in the list before replace. You can restore it if this was a mistake.
            if let safety = try? ExportImportService.exportBackup(context: modelContext) {
                _ = try? library.add(safety)
            }
            let data = try library.data(for: entry)
            let result = try BackupRestore.restore(data, mode: .replace, context: modelContext)
            router.requestNotificationSync()
            Haptics.light()
            reload()
            present("Restore complete", BackupCopy.restoredMessage(sessions: result.sessions, checkIns: result.checkIns))
        } catch {
            present("Restore failed", error.localizedDescription)
        }
    }

    private func present(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

private struct BackupRow: View {
    let entry: BackupLibrary.Entry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(BackupCopy.made(entry.summary))
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(BackupCopy.counts(entry.summary))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(BackupCopy.range(entry.summary))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(BackupCopy.size(entry.fileSize))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
