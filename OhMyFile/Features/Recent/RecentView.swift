//
//  RecentView.swift
//  OhMyFile
//
//  最近页：最近打开的文件列表空状态。
//

import SwiftUI

struct RecentView: View {
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No Recent Files",
                systemImage: "clock",
                description: Text("Files you open will appear here.")
            )
            .navigationTitle("Recent")
            .searchable(text: $searchText, prompt: "Search")
        }
    }
}
