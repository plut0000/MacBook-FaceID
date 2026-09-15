import Foundation

struct PoseEmbedding: Codable, Identifiable {
    var id: UUID
    var pose: HeadPose
    var embedding: FaceEmbedding
    var quality: Float
    var capturedAt: Date
}

struct IdentityRecord: Codable, Identifiable {
    var id: UUID
    var name: String
    var enabled: Bool
    var createdAt: Date
    var embeddings: [PoseEmbedding]
}

struct VaultPayload: Codable {
    var identities: [IdentityRecord]
    var passwordUTF8: Data?
    var updatedAt: Date
}

enum VaultError: LocalizedError {
    case locked
    case persistFailed
    case empty

    var errorDescription: String? {
        switch self {
        case .locked:
            return "Authorize Face Unlock with Touch ID (or your device password) first."
        case .persistFailed:
            return "Could not save Face Unlock data."
        case .empty:
            return "No identities are enrolled yet."
        }
    }
}

final class IdentityVault {
    private let folder: URL
    private let boxURL: URL
    private let queue = DispatchQueue(label: "com.plut0000.MacBookFaceID.vault")
    private var cache: VaultPayload?

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        folder = base.appendingPathComponent("MacBookFaceID", isDirectory: true)
        boxURL = folder.appendingPathComponent("vault.box")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    var boxExists: Bool {
        FileManager.default.fileExists(atPath: boxURL.path)
    }

    func load(using key: SymmetricKeyHolder) throws -> VaultPayload {
        try queue.sync {
            if let cache { return cache }
            guard FileManager.default.fileExists(atPath: boxURL.path) else {
                let empty = VaultPayload(identities: [], passwordUTF8: nil, updatedAt: Date())
                cache = empty
                return empty
            }
            let box = try Data(contentsOf: boxURL)
            let plain = try key.open(box)
            let payload = try JSONDecoder().decode(VaultPayload.self, from: plain)
            cache = payload
            return payload
        }
    }

    func save(_ payload: VaultPayload, using key: SymmetricKeyHolder) throws {
        try queue.sync {
            var next = payload
            next.updatedAt = Date()
            let plain = try JSONEncoder().encode(next)
            let box = try key.seal(plain)
            try box.write(to: boxURL, options: .atomic)
            cache = next
        }
    }

    func peekIdentities(using key: SymmetricKeyHolder) -> [IdentityRecord] {
        (try? load(using: key).identities) ?? []
    }

    func enabledEmbeddings(using key: SymmetricKeyHolder) throws -> [(IdentityRecord, FaceEmbedding)] {
        let payload = try load(using: key)
        var pairs: [(IdentityRecord, FaceEmbedding)] = []
        for identity in payload.identities where identity.enabled {
            for item in identity.embeddings {
                pairs.append((identity, item.embedding))
            }
        }
        if pairs.isEmpty { throw VaultError.empty }
        return pairs
    }

    func upsertIdentity(_ identity: IdentityRecord, using key: SymmetricKeyHolder) throws {
        var payload = try load(using: key)
        if let index = payload.identities.firstIndex(where: { $0.id == identity.id }) {
            payload.identities[index] = identity
        } else {
            payload.identities.append(identity)
        }
        try save(payload, using: key)
    }

    func deleteIdentity(id: UUID, using key: SymmetricKeyHolder) throws {
        var payload = try load(using: key)
        payload.identities.removeAll { $0.id == id }
        try save(payload, using: key)
    }

    func setPassword(_ password: String, using key: SymmetricKeyHolder) throws {
        var payload = try load(using: key)
        payload.passwordUTF8 = Data(password.utf8)
        try save(payload, using: key)
    }

    func password(using key: SymmetricKeyHolder) throws -> String {
        let payload = try load(using: key)
        guard let data = payload.passwordUTF8, let value = String(data: data, encoding: .utf8), !value.isEmpty else {
            throw VaultError.empty
        }
        return value
    }

    func hasPassword(using key: SymmetricKeyHolder) -> Bool {
        ((try? load(using: key).passwordUTF8)?.isEmpty == false)
    }

    func invalidateCache() {
        queue.sync { cache = nil }
    }

    func eraseAll() throws {
        try queue.sync {
            cache = nil
            if FileManager.default.fileExists(atPath: folder.path) {
                try FileManager.default.removeItem(at: folder)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            }
        }
    }
}

enum MatchEngine {
    static func bestMatch(
        live: FaceEmbedding,
        gallery: [(IdentityRecord, FaceEmbedding)],
        threshold: Float
    ) throws -> (identity: IdentityRecord, similarity: Float, passed: Bool) {
        guard let first = gallery.first else { throw VaultError.empty }
        var bestIdentity = first.0
        var best: Float = -1
        for (identity, embedding) in gallery {
            let score = try FaceEmbedder.cosine(live, embedding)
            if score > best {
                best = score
                bestIdentity = identity
            }
        }
        return (bestIdentity, best, best >= threshold)
    }
}
