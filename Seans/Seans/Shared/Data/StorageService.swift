//
//  StorageService.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 28.08.2026.
//

import FirebaseStorage
import Foundation

final class StorageService: @unchecked Sendable {
    static let shared = StorageService()

    private var storage: Storage { Storage.storage() }

    private var journalAudioRef: StorageReference {
        storage.reference().child("journalAudio")
    }

    // MARK: - Journal Audio

    func uploadJournalAudio(
        clientId: String,
        entryId: String,
        localURL: URL
    ) async throws -> String {
        let filename = "\(entryId).m4a"
        let ref = journalAudioRef.child(clientId).child(filename)

        let metadata = StorageMetadata()
        metadata.contentType = "audio/m4a"

        _ = try await ref.putFileAsync(from: localURL, metadata: metadata)
        let downloadURL = try await ref.downloadURL()

        #if DEBUG
        print("✅ StorageService: Uploaded audio to \(downloadURL.absoluteString)")
        #endif

        return downloadURL.absoluteString
    }

    func deleteJournalAudio(clientId: String, entryId: String) async throws {
        let filename = "\(entryId).m4a"
        let ref = journalAudioRef.child(clientId).child(filename)

        try await ref.delete()

        #if DEBUG
        print("✅ StorageService: Deleted audio for entry \(entryId)")
        #endif
    }

    func downloadJournalAudio(from urlString: String) async throws -> URL {
        guard URL(string: urlString) != nil else {
            throw StorageError.invalidURL
        }

        let ref = storage.reference(forURL: urlString)
        let localURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        _ = try await ref.writeAsync(toFile: localURL)

        #if DEBUG
        print("✅ StorageService: Downloaded audio to \(localURL.path)")
        #endif

        return localURL
    }
}

enum StorageError: Error {
    case invalidURL
    case uploadFailed
    case downloadFailed
}
