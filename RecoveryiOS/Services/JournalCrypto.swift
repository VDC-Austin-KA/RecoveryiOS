import Foundation
import CryptoKit
import LocalAuthentication

/// AES-GCM encryption for journal entries. The 256-bit key lives in the Keychain
/// (this-device-only), so entries are unreadable if the SwiftData store is copied off-device.
struct JournalCipher {
    let key: SymmetricKey

    private static let account = "journal.encryption.key"

    static func loadOrCreate() -> JournalCipher {
        if let data = Keychain.data(for: account), data.count == 32 {
            return JournalCipher(key: SymmetricKey(data: data))
        }
        let key = SymmetricKey(size: .bits256)
        Keychain.set(key.withUnsafeBytes { Data($0) }, for: account)
        return JournalCipher(key: key)
    }

    func seal(_ plaintext: String) throws -> Data {
        let box = try AES.GCM.seal(Data(plaintext.utf8), using: key)
        guard let combined = box.combined else { throw CryptoKitError.incorrectParameterSize }
        return combined
    }

    func open(_ sealed: Data) throws -> String {
        let box = try AES.GCM.SealedBox(combined: sealed)
        let data = try AES.GCM.open(box, using: key)
        return String(decoding: data, as: UTF8.self)
    }

    func openOrPlaceholder(_ sealed: Data) -> String {
        (try? open(sealed)) ?? "🔒 This entry can't be decrypted on this device."
    }
}

enum JournalLock {
    /// Face ID / Touch ID with passcode fallback. Devices without a passcode can't be locked,
    /// so they are let through rather than locking the user out of their own journal.
    static func authenticate() async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return true }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your private recovery journal")
        } catch {
            return false
        }
    }
}
