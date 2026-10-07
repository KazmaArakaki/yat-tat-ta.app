import FirebaseFirestore
import Foundation

/// Firestore の置き場所。users/{uid}/records/{id} に、記録を1件ずつ置く
///
/// 書き込みは、まず端末のキャッシュに入り、電波が戻ったらサーバーへ送られる。叩いた直後に電波を待たせない。
/// 列を変えたら、firebase/firestore.rules も同じコミットで直す（docs/devops/firebase）。
final class FirestoreRecordStore: RecordStore {
    private(set) var records: [SquatRecord] = []
    private(set) var isSynced = false
    var onChange: (() -> Void)?

    private let collection: CollectionReference
    private var listener: ListenerRegistration?

    init(uid: String, db: Firestore = .firestore()) {
        collection = db.collection("users").document(uid).collection("records")
        // サーバーの答えが返ったこと（isFromCache が false になったこと）も知りたいので、メタデータの変化も受け取る
        listener = collection.addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            MainActor.assumeIsolated {
                guard let self, let snapshot else {
                    if let error { print("Firestore: \(error)") }
                    return
                }
                self.receive(snapshot.documents.compactMap { Self.record(id: $0.documentID, data: $0.data()) },
                             fromServer: !snapshot.metadata.isFromCache)
            }
        }
    }

    deinit { listener?.remove() }

    func add(_ record: SquatRecord) {
        records.append(record)
        collection.document(record.id.uuidString).setData(Self.fields(of: record)) { error in
            if let error { print("Firestore: \(error)") }
        }
    }

    func delete(_ record: SquatRecord) {
        records.removeAll { $0.id == record.id }
        collection.document(record.id.uuidString).delete { error in
            if let error { print("Firestore: \(error)") }
        }
    }

    func deleteAll() async throws {
        // キャッシュではなくサーバーにあるものを消す。1回にまとめて消せるのは500件まで
        let documents = try await collection.getDocuments(source: .server).documents
        for chunk in stride(from: 0, to: documents.count, by: 500).map({ documents[$0..<min($0 + 500, documents.count)] }) {
            let batch = collection.firestore.batch()
            chunk.forEach { batch.deleteDocument($0.reference) }
            try await batch.commit()
        }
        records = []
    }

    func stop() {
        listener?.remove()
        listener = nil
        onChange = nil
    }

    /// 自分の書き込みの知らせでも呼ばれる。中身が変わらず、サーバーの答えも新しくなければ知らせない
    private func receive(_ incoming: [SquatRecord], fromServer: Bool) {
        let changed = Set(incoming.map(\.id)) != Set(records.map(\.id))
        let synced = fromServer && !isSynced
        records = incoming
        if fromServer { isSynced = true }
        if changed || synced { onChange?() }
    }

    // MARK: - 文書との行き来

    static func fields(of record: SquatRecord) -> [String: Any] {
        [
            "startedAt": Timestamp(date: record.startedAt),
            "day": record.day,
            "reps": record.reps,
            "bonusDopa": record.bonusDopa,
            // サーバーが受け取った時刻。あとで「増えた分だけ読む」ときの目印（docs/issues/firestore-read-cost）
            "createdAt": FieldValue.serverTimestamp(),
        ]
    }

    /// 形の合わない文書は読まない
    static func record(id: String, data: [String: Any]) -> SquatRecord? {
        guard let uuid = UUID(uuidString: id),
              let startedAt = data["startedAt"] as? Timestamp,
              let day = (data["day"] as? NSNumber)?.intValue,
              let reps = (data["reps"] as? NSNumber)?.intValue else { return nil }
        let bonus = (data["bonusDopa"] as? NSNumber)?.intValue ?? 0
        return SquatRecord(id: uuid, startedAt: startedAt.dateValue(), day: RecordDay(day), reps: reps, bonusDopa: bonus)
    }
}
