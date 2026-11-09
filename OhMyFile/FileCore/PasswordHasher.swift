//
//  PasswordHasher.swift
//  OhMyFile
//
//  应用锁密码哈希：SHA-256 + 随机盐；只存哈希与盐，不存明文。
//

import CryptoKit
import Foundation

enum PasswordHasher {
    nonisolated static func hash(pin: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data((salt + pin).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func randomSalt() -> String {
        UUID().uuidString
    }

    nonisolated static func verify(pin: String, salt: String, expectedHash: String) -> Bool {
        hash(pin: pin, salt: salt) == expectedHash
    }
}
