//
//  OhMyFileApp.swift
//  OhMyFile
//
//  应用入口。
//

import CrashKit
import SwiftUI

@main
struct OhMyFileApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        CrashRecorder.shared.install()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
