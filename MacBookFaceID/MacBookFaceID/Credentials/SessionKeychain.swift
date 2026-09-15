import CryptoKit
import Foundation
import LocalAuthentication
import Security

enum KeychainError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case noKey
    case unreadable
    case accessControl

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return message
            }
            return "Keychain error (\(status))"
        case .noKey:
            return "No Face Unlock encryption key is stored in Keychain."
        case .unreadable:
            return "The Keychain item could not be read."
        case .accessControl:
            return "Could not create a Touch ID–protected Keychain item."
        }
    }
}

/// 256-bit AES key in the login keychain, gated by `userPresence`
/// (Touch ID or the device password). The key is only copied into memory
/// while a Face Unlock session is authorized.
enum SessionKeychain {
    static func hasKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConstants.keychainService,
            kSecAttrAccount as String: AppConstants.keychainAccount,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    static func createIfNeeded() throws -> SymmetricKeyHolder {
        if hasKey() {
            return try load(prompt: "Authorize Face Unlock")
        }
        let key = CryptoBox.randomKey()
        let data = CryptoBox.data(from: key)
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            &error
        ) else {
            throw KeychainError.accessControl
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConstants.keychainService,
            kSecAttrAccount as String: AppConstants.keychainAccount,
            kSecAttrLabel as String: "MacBook FaceID vault key",
            kSecAttrComment as String: "AES-256 key that encrypts enrolled embeddings and the saved login password. Protected by Touch ID or your device password.",
            kSecValueData as String: data,
            kSecAttrAccessControl as String: access
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        return SymmetricKeyHolder(key)
    }

    static func load(prompt: String, context: LAContext? = nil) throws -> SymmetricKeyHolder {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConstants.keychainService,
            kSecAttrAccount as String: AppConstants.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseOperationPrompt as String: prompt
        ]
        if let context {
            query[kSecUseAuthenticationContext as String] = context
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            throw KeychainError.noKey
        }
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        guard let data = item as? Data, data.count >= 16 else {
            throw KeychainError.unreadable
        }
        return SymmetricKeyHolder(CryptoBox.key(from: data))
    }

    static func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConstants.keychainService,
            kSecAttrAccount as String: AppConstants.keychainAccount
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

/// Tiny wrapper so the key is not accidentally printed.
struct SymmetricKeyHolder {
    fileprivate let raw: SymmetricKey

    init(_ key: SymmetricKey) {
        self.raw = key
    }

    func seal(_ data: Data) throws -> Data {
        try CryptoBox.seal(data, using: raw)
    }

    func open(_ data: Data) throws -> Data {
        try CryptoBox.open(data, using: raw)
    }
}
