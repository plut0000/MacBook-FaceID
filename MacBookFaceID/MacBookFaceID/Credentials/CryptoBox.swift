import CryptoKit
import Foundation

enum CryptoBoxError: LocalizedError {
    case sealFailed
    case openFailed

    var errorDescription: String? {
        switch self {
        case .sealFailed:
            return "Could not encrypt Face Unlock data."
        case .openFailed:
            return "Could not decrypt Face Unlock data. Authorize the session and try again."
        }
    }
}

enum CryptoBox {
    static func randomKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    static func key(from data: Data) -> SymmetricKey {
        SymmetricKey(data: data)
    }

    static func data(from key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }

    static func seal(_ plaintext: Data, using key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else {
            throw CryptoBoxError.sealFailed
        }
        return combined
    }

    static func open(_ box: Data, using key: SymmetricKey) throws -> Data {
        do {
            let sealed = try AES.GCM.SealedBox(combined: box)
            return try AES.GCM.open(sealed, using: key)
        } catch {
            throw CryptoBoxError.openFailed
        }
    }
}
