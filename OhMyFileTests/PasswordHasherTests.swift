import Foundation
import Testing
@testable import OhMyFile

struct PasswordHasherTests {
    @Test func hashesAreStable() {
        let first = PasswordHasher.hash(pin: "123456", salt: "salt")
        let second = PasswordHasher.hash(pin: "123456", salt: "salt")

        #expect(first == second)
        #expect(first.count == 64)
    }

    @Test func differentPinsProduceDifferentHashes() {
        let first = PasswordHasher.hash(pin: "123456", salt: "salt")
        let second = PasswordHasher.hash(pin: "123457", salt: "salt")

        #expect(first != second)
    }

    @Test func differentSaltsProduceDifferentHashes() {
        let first = PasswordHasher.hash(pin: "123456", salt: "salt-a")
        let second = PasswordHasher.hash(pin: "123456", salt: "salt-b")

        #expect(first != second)
    }

    @Test func verifiesCorrectPin() {
        let salt = PasswordHasher.randomSalt()
        let hash = PasswordHasher.hash(pin: "123456", salt: salt)

        #expect(PasswordHasher.verify(pin: "123456", salt: salt, expectedHash: hash))
        #expect(!PasswordHasher.verify(pin: "000000", salt: salt, expectedHash: hash))
    }
}
