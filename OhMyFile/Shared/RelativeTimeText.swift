//
//  RelativeTimeText.swift
//  OhMyFile
//
//  把 RelativeTimeUnit 转成界面文案；超过 30 天沿用系统日期时间格式。
//

import Foundation

func relativeTimeText(for date: Date, now: Date = Date()) -> String {
    switch RelativeTimeFormatter.unit(for: date, now: now) {
    case .justNow:
        return String(localized: "Just Now")
    case .minutes(let minutes):
        return String(format: String(localized: "%ld minutes ago"), minutes)
    case .hours(let hours):
        return String(format: String(localized: "%ld hours ago"), hours)
    case .days(let days):
        return String(format: String(localized: "%ld days ago"), days)
    case .absolute(let date):
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
