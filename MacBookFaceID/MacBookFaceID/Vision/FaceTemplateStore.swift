import AppKit
import Foundation

struct StoredFaceTemplate: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let quality: Float
    let embedding: FaceEmbedding
}

struct EnrollmentRecord: Codable {
    var templates: [StoredFaceTemplate]
    var enrolledAt: Date
    var thumbnailFileName: String
}

enum FaceStoreError: LocalizedError {
    case notEnrolled
    case persistFailed
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .notEnrolled:
            return "No face is enrolled on this Mac."
        case .persistFailed:
            return "Could not save the face template."
        case .decodeFailed:
            return "The saved face template could not be read. Please re-enroll."
        }
    }
}

final class FaceTemplateStore {
    private let folder: URL
    private let recordURL: URL
    private let queue = DispatchQueue(label: "com.plut0000.MacBookFaceID.templates")

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        folder = base.appendingPathComponent("MacBookFaceID", isDirectory: true)
        recordURL = folder.appendingPathComponent("enrollment.json")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    var hasEnrollment: Bool {
        queue.sync { loadRecordUnlocked() != nil }
    }

    func loadRecord() -> EnrollmentRecord? {
        queue.sync { loadRecordUnlocked() }
    }

    private func loadRecordUnlocked() -> EnrollmentRecord? {
        guard let data = try? Data(contentsOf: recordURL) else { return nil }
        return try? JSONDecoder().decode(EnrollmentRecord.self, from: data)
    }

    func loadEmbeddings() throws -> [FaceEmbedding] {
        try queue.sync {
            guard let record = loadRecordUnlocked() else { throw FaceStoreError.notEnrolled }
            let embeddings = record.templates.map(\.embedding).filter {
                $0.version == FaceEmbedding.currentVersion && !$0.values.isEmpty
            }
            if embeddings.isEmpty { throw FaceStoreError.decodeFailed }
            return embeddings
        }
    }

    func loadThumbnail() -> NSImage? {
        queue.sync {
            guard let record = loadRecordUnlocked() else { return nil }
            let url = folder.appendingPathComponent(record.thumbnailFileName)
            return NSImage(contentsOf: url)
        }
    }

    func save(analyses: [FaceFrameAnalysis], thumbnail: NSImage?) throws {
        let templates = analyses.map { analysis in
            StoredFaceTemplate(
                id: UUID(),
                createdAt: Date(),
                quality: analysis.quality,
                embedding: analysis.embedding
            )
        }
        guard !templates.isEmpty else { throw FaceStoreError.persistFailed }

        let thumbName = "enrollment-thumb.jpg"
        if let thumbnail, let tiff = thumbnail.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.72]) {
            try jpeg.write(to: folder.appendingPathComponent(thumbName))
        }

        let record = EnrollmentRecord(
            templates: templates,
            enrolledAt: Date(),
            thumbnailFileName: thumbName
        )
        let data = try JSONEncoder().encode(record)
        try queue.sync {
            try data.write(to: recordURL, options: .atomic)
        }
    }

    func bestDistance(to live: FaceEmbedding) throws -> Float {
        let enrolled = try loadEmbeddings()
        var best = Float.greatestFiniteMagnitude
        for item in enrolled {
            let distance = try FaceAnalyzer.distance(between: live, and: item)
            best = min(best, distance)
        }
        return best
    }

    func erase() throws {
        try queue.sync {
            if FileManager.default.fileExists(atPath: folder.path) {
                try FileManager.default.removeItem(at: folder)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            }
        }
    }
}
