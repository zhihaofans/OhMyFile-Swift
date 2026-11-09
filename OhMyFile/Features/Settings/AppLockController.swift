//
//  AppLockController.swift
//  OhMyFile
//
//  应用锁状态：PIN 哈希 + Keychain、Face ID / Touch ID、锁定 / 解锁。
//

import LocalAuthentication
import Observation

@MainActor
@Observable
final class AppLockController {
    private(set) var isEnabled: Bool
    private(set) var isLocked: Bool

    private(set) var isBiometricAvailable = false
    private(set) var biometricType: LABiometryType = .none

    private let service = "me.zzhhoo.OhMyFile.AppLock"
    private let hashAccount = "pinHash"
    private let saltAccount = "pinSalt"

    init() {
        let enabled = KeychainStore.get(service: service, account: hashAccount) != nil
        isEnabled = enabled
        isLocked = enabled
        refreshBiometrics()
    }

    var biometricLabel: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return String(localized: "Biometrics")
        }
    }

    func enable(pin: String) throws {
        let salt = PasswordHasher.randomSalt()
        let hash = PasswordHasher.hash(pin: pin, salt: salt)

        try KeychainStore.set(hash, service: service, account: hashAccount)
        try KeychainStore.set(salt, service: service, account: saltAccount)

        isEnabled = true
        isLocked = false
    }

    func disable() {
        KeychainStore.delete(service: service, account: hashAccount)
        KeychainStore.delete(service: service, account: saltAccount)

        isEnabled = false
        isLocked = false
    }

    func verify(pin: String) -> Bool {
        guard let hash = KeychainStore.get(service: service, account: hashAccount),
              let salt = KeychainStore.get(service: service, account: saltAccount) else {
            return false
        }

        return PasswordHasher.verify(pin: pin, salt: salt, expectedHash: hash)
    }

    func unlock(pin: String) -> Bool {
        guard verify(pin: pin) else { return false }

        isLocked = false
        return true
    }

    func lock() {
        guard isEnabled else { return }
        isLocked = true
    }

    func refreshBiometrics() {
        let context = LAContext()
        var error: NSError?

        isBiometricAvailable = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
        biometricType = isBiometricAvailable ? context.biometryType : .none
    }

    func authenticateWithBiometrics() async -> Bool {
        refreshBiometrics()

        guard isBiometricAvailable else { return false }

        let context = LAContext()

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: String(localized: "Unlock OhMyFile")
            )

            if success {
                isLocked = false
            }

            return success
        } catch {
            return false
        }
    }
}
