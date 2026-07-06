import Foundation
import CryptoKit
import CommonCrypto

/// Passcode-derived encryption for locked entries.
///
/// One passcode covers the whole journal; individual entries opt into it.
/// Locked entries store an AES-GCM sealed blob of their title and body; the
/// plaintext never touches disk while locked. The passcode itself is never
/// stored: only a random salt and a SHA-256 verifier of the derived key.
/// A forgotten passcode makes locked entries unrecoverable by design.
enum Crypto {

    static func randomSalt(_ count: Int = 16) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }

    /// PBKDF2-HMAC-SHA256, 200k rounds, 32-byte key.
    static func deriveKey(passcode: String, salt: Data, iterations: Int = 200_000) -> SymmetricKey {
        let passData = Data(passcode.utf8)
        var derived = [UInt8](repeating: 0, count: 32)
        passData.withUnsafeBytes { (p: UnsafeRawBufferPointer) in
            salt.withUnsafeBytes { (s: UnsafeRawBufferPointer) in
                _ = CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    p.baseAddress?.assumingMemoryBound(to: Int8.self), passData.count,
                    s.baseAddress?.assumingMemoryBound(to: UInt8.self), salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    &derived, derived.count)
            }
        }
        return SymmetricKey(data: Data(derived))
    }

    /// Stored next to the salt so a passcode attempt can be checked without
    /// keeping anything decryptable around.
    static func verifier(for key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data(SHA256.hash(data: Data($0))) }
    }

    static func seal(_ plaintext: Data, key: SymmetricKey) throws -> Data {
        guard let combined = try AES.GCM.seal(plaintext, using: key).combined else {
            throw CocoaError(.coderInvalidValue)
        }
        return combined
    }

    static func open(_ combined: Data, key: SymmetricKey) throws -> Data {
        try AES.GCM.open(AES.GCM.SealedBox(combined: combined), using: key)
    }
}
