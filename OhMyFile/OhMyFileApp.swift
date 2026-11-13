//
//  OhMyFileApp.swift
//  OhMyFile
//
//  应用入口。
//

import CrashKit
import SwiftUtils
import SwiftUI

@main
struct OhMyFileApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        CrashRecorder.shared.install()

        #if DEBUG
        let logLevel: LogLevel = .debug
        #else
        let logLevel: LogLevel = .info
        #endif

        SU.configureLogging(
            level: logLevel,
            backend: OSLogBackend(subsystem: AppLog.subsystem, category: "swiftutils")
        )
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
