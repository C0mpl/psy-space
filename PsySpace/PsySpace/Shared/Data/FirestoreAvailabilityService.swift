//
//  FirestoreAvailabilityService.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 24.08.2026.
//

import FirebaseFirestore
import Foundation

final class FirestoreAvailabilityService: @unchecked Sendable {
    static let shared = FirestoreAvailabilityService()

    private var db: Firestore { Firestore.firestore() }

    private var availabilityDocument: DocumentReference {
        db.collection("config").document("availability")
    }

    func fetchAvailability() async throws -> AvailabilitySettings {
        let snapshot = try await availabilityDocument.getDocument()

        guard let data = snapshot.data(),
              let jsonData = try? JSONSerialization.data(withJSONObject: data),
              let settings = try? JSONDecoder().decode(AvailabilitySettings.self, from: jsonData) else {
            return .default
        }

        return settings
    }

    func saveAvailability(_ settings: AvailabilitySettings) async throws {
        let data = try JSONEncoder().encode(settings)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        try await availabilityDocument.setData(dict)
        #if DEBUG
        print("✅ Availability saved to Firestore")
        #endif
    }

    func listenToAvailability(onChange: @escaping (AvailabilitySettings) -> Void) -> ListenerRegistration {
        availabilityDocument.addSnapshotListener { snapshot, error in
            #if DEBUG
            if let error {
                print("❌ Firestore availability error: \(error.localizedDescription)")
                return
            }
            #endif

            guard let data = snapshot?.data() else {
                #if DEBUG
                print("⚠️ No availability data in Firestore yet")
                #endif
                return
            }

            guard let jsonData = try? JSONSerialization.data(withJSONObject: data),
                  let settings = try? JSONDecoder().decode(AvailabilitySettings.self, from: jsonData) else {
                #if DEBUG
                print("❌ Failed to decode availability data")
                #endif
                return
            }

            #if DEBUG
            print("✅ Availability loaded: \(settings.weeklySchedule)")
            #endif
            onChange(settings)
        }
    }
}
