//
//  FirestoreFieldRenamer.swift
//  TProAthlete
//
//  Created by Jecky Toledo on 02/08/2025.
//

import Foundation
import FirebaseFirestore

class FirestoreFieldRenamer {
    private let db = Firestore.firestore()

    /// Renames a field in all documents of a collection.
    /// - Parameters:
    ///   - collectionName: The Firestore collection to update.
    ///   - oldField: The current field name to replace.
    ///   - newField: The new field name to use.
    ///   - completion: Optional completion callback.
    func renameField(in collectionName: String, from oldField: String, to newField: String, completion: (() -> Void)? = nil) {
        let collectionRef = db.collection(collectionName)

        collectionRef.getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error fetching documents: \(error.localizedDescription)")
                return
            }

            guard let documents = snapshot?.documents else {
                print("⚠️ No documents found in collection: \(collectionName)")
                return
            }

            print("🔄 Starting rename of '\(oldField)' to '\(newField)' in \(documents.count) documents...")

            let group = DispatchGroup()

            for doc in documents {
                let data = doc.data()
                guard let value = data[oldField] else { continue }

                group.enter()

                doc.reference.setData([
                    newField: value
                ], merge: true) { setError in
                    if let setError = setError {
                        print("❌ Error setting new field in \(doc.documentID): \(setError.localizedDescription)")
                        group.leave()
                        return
                    }

                    doc.reference.updateData([
                        oldField: FieldValue.delete()
                    ]) { deleteError in
                        if let deleteError = deleteError {
                            print("⚠️ Field renamed but failed to delete old field in \(doc.documentID): \(deleteError.localizedDescription)")
                        } else {
                            print("✅ Renamed field in \(doc.documentID)")
                        }
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                print("🎉 Field rename complete for '\(collectionName)'.")
                completion?()
            }
        }
    }
    
    func renameFieldInArray(
        collection: String,
        arrayField: String,
        oldField: String,
        newField: String
    ) {
        let db = Firestore.firestore()

        db.collection(collection).getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error fetching documents: \(error)")
                return
            }

            guard let documents = snapshot?.documents else {
                print("❌ No documents found in collection: \(collection)")
                return
            }

            for doc in documents {
                var data = doc.data()
                var updatedArray: [[String: Any]] = []

                if let originalArray = data[arrayField] as? [[String: Any]] {
                    for var item in originalArray {
                        if let value = item[oldField] {
                            item[newField] = value
                            item.removeValue(forKey: oldField)
                        }
                        updatedArray.append(item)
                    }

                    // Compare using JSON serialization to avoid type mismatch
                    let originalData = try? JSONSerialization.data(withJSONObject: originalArray, options: [.sortedKeys])
                    let updatedData = try? JSONSerialization.data(withJSONObject: updatedArray, options: [.sortedKeys])

                    if originalData != updatedData {
                        db.collection(collection).document(doc.documentID).updateData([
                            arrayField: updatedArray
                        ]) { error in
                            if let error = error {
                                print("❌ Failed to update \(doc.documentID): \(error)")
                            } else {
                                print("✅ Updated \(doc.documentID): \(oldField) → \(newField) in \(arrayField)")
                            }
                        }
                    }
                }
            }
        }
    }
}
