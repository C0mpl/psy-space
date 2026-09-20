//
//  FirestoreAnamnesisService.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 24.08.2026.
//

import FirebaseFirestore
import Foundation

final class FirestoreAnamnesisService: @unchecked Sendable {
    static let shared = FirestoreAnamnesisService()

    private var db: Firestore { Firestore.firestore() }

    private var anamnesisCollection: CollectionReference {
        db.collection("clientAnamnesis")
    }

    func saveAnamnesis(_ anamnesis: ClientAnamnesis) async throws {
        try anamnesisCollection.document(anamnesis.clientId).setData(from: anamnesis)
        #if DEBUG
        print("Anamnesis saved for client: \(anamnesis.clientId)")
        #endif
    }

    func fetchAnamnesis(forClientId clientId: String) async throws -> ClientAnamnesis? {
        let doc = try await anamnesisCollection.document(clientId).getDocument()
        return try? doc.data(as: ClientAnamnesis.self)
    }

    func listenToAnamnesis(
        forClientId clientId: String,
        onChange: @escaping (ClientAnamnesis?) -> Void
    ) -> ListenerRegistration {
        anamnesisCollection.document(clientId).addSnapshotListener { snapshot, error in
            #if DEBUG
            if let error {
                print("FirestoreAnamnesisService: Anamnesis listener error: \(error)")
                return
            }
            #endif
            guard let snapshot, snapshot.exists else {
                onChange(nil)
                return
            }
            let anamnesis = try? snapshot.data(as: ClientAnamnesis.self)
            #if DEBUG
            print("FirestoreAnamnesisService: Anamnesis received for client: \(clientId)")
            #endif
            onChange(anamnesis)
        }
    }
}
