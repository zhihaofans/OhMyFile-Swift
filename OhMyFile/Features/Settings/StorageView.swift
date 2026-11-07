//
//  StorageView.swift
//  OhMyFile
//
//  设置 → 存储空间：总占用、分类占用、清理缓存、清空回收站。
//

import SwiftUI

struct StorageView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var usage: StorageUsage?
    @State private var pendingAction: StorageAction?
    @State private var statusMessage: String?

    private let library = FileLibrary()

    var body: some View {
        List {
            Section {
                if let usage {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Total Usage")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(formattedFileSize(usage.totalBytes))
                            .font(.largeTitle.bold())

                        Text(String(format: String(localized: "%ld files"), usage.totalFileCount))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }

            Section("By Category") {
                if let usage {
                    ForEach(usage.categories) { item in
                        HStack {
                            Label(title(for: item.category), systemImage: symbol(for: item.category))

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formattedFileSize(item.bytes))

                                Text(String(format: String(localized: "%ld files"), item.fileCount))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    pendingAction = .clearCache
                } label: {
                    Label("Clear Cache", systemImage: "trash")
                }

                Button(role: .destructive) {
                    pendingAction = .emptyTrash
                } label: {
                    Label("Empty Trash", systemImage: "trash.slash")
                }
            }
        }
        .navigationTitle("Storage")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await reload() }
            }
        }
        .alert(
            pendingAction != nil ? confirmationTitle : String(localized: "Done"),
            isPresented: Binding(
                get: { pendingAction != nil || statusMessage != nil },
                set: {
                    if !$0 {
                        pendingAction = nil
                        statusMessage = nil
                    }
                }
            )
        ) {
            if pendingAction != nil {
                Button(confirmationButtonTitle, role: .destructive) {
                    performAction()
                }
                Button("Cancel", role: .cancel) {
                    pendingAction = nil
                }
            } else {
                Button("OK", role: .cancel) {
                    statusMessage = nil
                }
            }
        } message: {
            Text(pendingAction != nil ? confirmationMessage : (statusMessage ?? ""))
        }
    }

    private func reload() async {
        let loaded = await Task.detached { [library] in
            library.storageUsage()
        }.value
        usage = loaded
    }

    private func performAction() {
        guard let action = pendingAction else { return }

        do {
            switch action {
            case .clearCache:
                try library.clearCache()
            case .emptyTrash:
                try library.emptyTrash()
            }
            statusMessage = action == .clearCache
                ? String(localized: "Cache Cleared")
                : String(localized: "Trash Cleared")
            pendingAction = nil
            Task { await reload() }
        } catch {
            pendingAction = nil
            statusMessage = error.localizedDescription
        }
    }

    private func title(for category: StorageCategory) -> LocalizedStringKey {
        switch category {
        case .inbox:
            return "Inbox"
        case .downloads:
            return "Downloads"
        case .trash:
            return "Trash"
        case .cache:
            return "Cache"
        case .temporary:
            return "Temporary"
        }
    }

    private func symbol(for category: StorageCategory) -> String {
        switch category {
        case .inbox:
            return "tray.fill"
        case .downloads:
            return "arrow.down.circle.fill"
        case .trash:
            return "trash.fill"
        case .cache:
            return "internaldrive"
        case .temporary:
            return "clock"
        }
    }

    private var confirmationTitle: String {
        switch pendingAction {
        case .clearCache:
            return String(localized: "Clear Cache?")
        case .emptyTrash:
            return String(localized: "Empty Trash?")
        case .none:
            return ""
        }
    }

    private var confirmationButtonTitle: LocalizedStringKey {
        switch pendingAction {
        case .clearCache:
            return "Clear Cache"
        case .emptyTrash:
            return "Empty Trash"
        case .none:
            return "Delete"
        }
    }

    private var confirmationMessage: String {
        switch pendingAction {
        case .clearCache:
            return String(localized: "Cache will be cleared. Files are not affected.")
        case .emptyTrash:
            return String(localized: "All files will be permanently deleted.")
        case .none:
            return ""
        }
    }
}

private enum StorageAction {
    case clearCache
    case emptyTrash
}
