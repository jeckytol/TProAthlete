import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import SwiftUI

class UserProfileManager: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading: Bool = true

    private let db = Firestore.firestore()
    private let collection = "user_profiles"

    @AppStorage("nickname") var storedNickname: String = "Unknown"

    func getCurrentUserId() -> String {
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown_user"
    }

    func loadProfile(completion: (() -> Void)? = nil) {
        let userId = getCurrentUserId()
        print("[DEBUG] Loading profile for userId: \(userId)")
        isLoading = true

        db.collection(collection).document(userId).getDocument { snapshot, error in
            defer {
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion?()
                }
            }

            if let error = error {
                print("[ERROR] Failed to load profile: \(error)")
                return
            }

            guard let data = snapshot?.data() else {
                print("[DEBUG] No profile found for userId: \(userId)")
                return
            }

            do {
                let loadedProfile = try Firestore.Decoder().decode(UserProfile.self, from: data)
                DispatchQueue.main.async {
                    self.profile = loadedProfile
                    self.storedNickname = loadedProfile.nickname  // 🔁 sync to AppStorage
                    print("[DEBUG] Loaded profile: \(loadedProfile)")
                }
            } catch {
                print("[ERROR] Failed to decode profile: \(error)")
            }
        }
    }

    func saveProfile(_ profile: UserProfile, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try db.collection(collection).document(profile.userId).setData(from: profile) { error in
                if let error = error {
                    print("❌ Firestore save error: \(error)")
                    completion(.failure(error))
                } else {
                    DispatchQueue.main.async {
                        self.profile = profile
                        self.storedNickname = profile.nickname  // 🔁 sync to AppStorage
                        completion(.success(()))
                    }
                }
            }
        } catch {
            print("❌ Encoding error: \(error)")
            completion(.failure(error))
        }
    }
}
