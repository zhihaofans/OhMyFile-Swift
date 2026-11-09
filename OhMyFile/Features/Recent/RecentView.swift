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
                        NavigationLink {
                            FilePreviewView(file: FileItem(url: entry.url))
                        } label: {
                            RecentRow(entry: entry, now: now)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Recent")
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

    var body: some View {
        HStack(spacing: 12) {
            FileThumbnailView(file: FileItem(url: entry.url), size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)

                Text(
                    relativeTime
                        ? relativeTimeText(for: entry.openedAt, now: now)
                        : entry.openedAt.formatted(date: .abbreviated, time: .shortened)
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
