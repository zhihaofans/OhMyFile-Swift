//
//  AppDelegate.swift
//  OhMyFile
//
//  接收后台 URLSession 完成事件（下载管理）。
//

import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        DownloadManager.shared.backgroundSessionCompletionHandler = completionHandler
    }
}
