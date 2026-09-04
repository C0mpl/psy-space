//
//  StorageService.swift
//  PsySpace
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

    // MARK: - Homework Attachments

    private var homeworkAttachmentsRef: StorageReference {
        storage.reference().child("homeworkAttachments")
    }

    func uploadHomeworkAttachment(
        clientId: String,
        homeworkId: String,
        attachmentId: String,
        localURL: URL
    ) async throws -> String {
        let filename = "\(attachmentId).pdf"
        let ref = homeworkAttachmentsRef.child(clientId).child(homeworkId).child(filename)

        #if DEBUG
        print("📤 StorageService: Uploading PDF from \(localURL.path)")
        print("   File exists: \(FileManager.default.fileExists(atPath: localURL.path))")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: localURL.path) {
            print("   File size: \(attrs[.size] ?? "unknown")")
        }
        #endif

        let metadata = StorageMetadata()
        metadata.contentType = "application/pdf"

        do {
            _ = try await ref.putFileAsync(from: localURL, metadata: metadata)
            let downloadURL = try await ref.downloadURL()

            #if DEBUG
            print("✅ StorageService: Uploaded PDF to \(downloadURL.absoluteString)")
            #endif

            return downloadURL.absoluteString
        } catch {
            #if DEBUG
            print("❌ StorageService: PDF upload failed: \(error)")
            print("   Error details: \(error.localizedDescription)")
            #endif
            throw error
        }
    }

    func deleteHomeworkAttachment(
        clientId: String,
        homeworkId: String,
        attachmentId: String
    ) async throws {
        let filename = "\(attachmentId).pdf"
        let ref = homeworkAttachmentsRef.child(clientId).child(homeworkId).child(filename)

        try await ref.delete()

        #if DEBUG
        print("✅ StorageService: Deleted PDF attachment \(attachmentId)")
        #endif
    }

    func downloadHomeworkAttachment(from urlString: String) async throws -> URL {
        guard URL(string: urlString) != nil else {
            throw StorageError.invalidURL
        }

        let ref = storage.reference(forURL: urlString)
        let localURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")

        _ = try await ref.writeAsync(toFile: localURL)

        #if DEBUG
        print("✅ StorageService: Downloaded PDF to \(localURL.path)")
        #endif

        return localURL
    }
}

enum StorageError: Error {
    case invalidURL
    case uploadFailed
    case downloadFailed
}
