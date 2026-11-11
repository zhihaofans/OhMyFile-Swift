//
//  RecentView.swift
//  OhMyFile
//
//  最近打开：按打开时间倒序，支持搜索与清空。
//

import Combine
import SwiftUI

struct RecentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var searchText = ""
    @State private var entries: [RecentEntry] = []
    @State private var showClearConfirmation = false
    @State private var now = Date()
    @State private var selectedEntry: RecentEntry?
    @State private var externalEntry: RecentEntry?
    @State private var openError: String?

    private let store = RecentFilesStore(storageURL: RecentFilesStore.defaultStorageURL)

    private var filteredEntries: [RecentEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return entries }
        return entries.filter { $0.name.localizedStandardContains(query) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredEntries.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty
                            ? LocalizedStringKey("No Recent Files")
                            : LocalizedStringKey("No Results"),
                        systemImage: searchText.isEmpty ? "clock" : "magnifyingglass",
                        description: Text(
                            searchText.isEmpty
                                ? LocalizedStringKey("Files you open will appear here.")
                                : LocalizedStringKey("No files match your search.")
                        )
                    )
                } else {
                    List(filteredEntries) { entry in
                        Button {
                            open(entry)
                        } label: {
                            RecentRow(entry: entry, now: now)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Recent")
            .navigationDestination(item: $selectedEntry) { entry in
                FilePreviewView(file: FileItem(url: entry.url))
            }
            .sheet(item: $externalEntry) { entry in
                ExternalFilePreviewView(url: entry.url)
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { openError != nil },
                    set: { if !$0 { openError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(openError ?? "")
            }
            .searchable(text: $searchText, prompt: "Search")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(entries.isEmpty)
                    .accessibilityLabel("Clear Recent")
                }
            }
            .onAppear {
                Task { await load() }
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await load() }
                }
            }
            .confirmationDialog(
                "Clear Recent?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear", role: .destructive) {
                    store.clear()
                    Task { await load() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    private func open(_ entry: RecentEntry) {
        var resolvedURL = entry.url

        if let bookmark = entry.bookmark {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                resolvedURL = url
            }
        }

        let isExternal = FileLibrary.directory(for: resolvedURL) == nil
        var accessed = false

        if isExternal {
            accessed = resolvedURL.startAccessingSecurityScopedResource()
        }
        defer {
            if accessed {
                resolvedURL.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.fileExists(atPath: resolvedURL.path) else {
            store.remove(entry.url)
            Task { await load() }
            openError = String(localized: "The file no longer exists. Its recent record has been removed.")
            return
        }

        let resolvedEntry = RecentEntry(
            path: resolvedURL.path,
            openedAt: entry.openedAt,
            bookmark: entry.bookmark
        )

        if isExternal {
            externalEntry = resolvedEntry
        } else {
            selectedEntry = resolvedEntry
        }
    }

    private func load() async {
        let loaded = await Task.detached { [store] in
            store.pruneMissing()
        }.value
        entries = loaded
    }
}

private struct RecentRow: View {
    let entry: RecentEntry
    let now: Date

    @AppStorage("settings.relativeTime") private var relativeTime = true

    private var isExternal: Bool {
        FileLibrary.directory(for: entry.url) == nil
    }

    var body: some View {
        HStack(spacing: 12) {
            if isExternal {
                let icon = fileIcon(for: entry.url)

                Image(systemName: icon.symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(icon.color)
                    .frame(width: 36, height: 36)
            } else {
                FileThumbnailView(file: FileItem(url: entry.url), size: 36)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var parts: [String] = []

        if let directory = FileLibrary.directory(for: entry.url) {
            parts.append(directory.localizedTitle)
        } else {
            parts.append(String(localized: "External"))
        }

        parts.append(
            relativeTime
                ? relativeTimeText(for: entry.openedAt, now: now)
                : entry.openedAt.formatted(date: .abbreviated, time: .shortened)
        )

        if let size = FileItem(url: entry.url).size {
            parts.append(formattedFileSize(size))
        }

        return parts.joined(separator: " · ")
    }
}
