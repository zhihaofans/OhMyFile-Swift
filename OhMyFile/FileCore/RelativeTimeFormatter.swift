//
//  RelativeTimeFormatter.swift
//  OhMyFile
//
//  相对时间分档：刚刚 / 分钟前 / 小时前 / 天前 / 超过 30 天显示日期。
//  纯内核代码，now 可注入，便于测试。
//

import Foundation

nonisolated enum RelativeTimeUnit: Equatable {
    case justNow
    case minutes(Int)
    case hours(Int)
    case days(Int)
    case absolute(Date)
}

enum RelativeTimeFormatter {
    nonisolated static func unit(for date: Date, now: Date = Date()) -> RelativeTimeUnit {
        let interval = now.timeIntervalSince(date)

        guard interval >= 60 else {
            return .justNow
        }
        if interval < 3600 {
            return .minutes(Int(interval / 60))
        }
        if interval < 86_400 {
            return .hours(Int(interval / 3600))
        }
        if interval < 30 * 86_400 {
            return .days(Int(interval / 86_400))
        }

        return .absolute(date)
    }
}
