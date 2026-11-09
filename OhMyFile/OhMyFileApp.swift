//
//  OhMyFileApp.swift
//  OhMyFile
//
//  应用入口。
//

import SwiftUI

@main
struct OhMyFileApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
