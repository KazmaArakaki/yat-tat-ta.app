import Foundation

/// 記録の置き場所
///
/// 本番は Firestore（FirestoreRecordStore）。テストと計測モードと演出の見本はメモリ（MemoryRecordStore）で、
/// 仮の記録を利用者の棚に書かない。
protocol RecordStore: AnyObject {
    /// 手元にある記録の全部。足したり消したりすると、すぐにここへ反映する
    var records: [SquatRecord] { get }
    /// サーバーから1度でも答えが返ったか。機種を替えた人の記録は、返るまで手元にない
    var isSynced: Bool { get }
    /// ほかの端末の記録が届いたときや、サーバーの答えが返ったときに呼ぶ。自分で足したり消したりしたときは呼ばない
    var onChange: (() -> Void)? { get set }

    func add(_ record: SquatRecord)
    func delete(_ record: SquatRecord)
    /// アカウントを削除するときに、サーバーの記録を全部消す。電波がなければ失敗する
    func deleteAll() async throws
    /// 届いた記録を受け取るのをやめる。ログアウトするとき
    func stop()
}

/// メモリだけの置き場所。アプリを終えれば消える
final class MemoryRecordStore: RecordStore {
    private(set) var records: [SquatRecord]
    private(set) var isSynced: Bool
    var onChange: (() -> Void)?

    init(records: [SquatRecord] = [], synced: Bool = true) {
        self.records = records
        isSynced = synced
    }

    func add(_ record: SquatRecord) { records.append(record) }
    func delete(_ record: SquatRecord) { records.removeAll { $0.id == record.id } }
    func deleteAll() async throws { records = [] }
    func stop() { onChange = nil }

    /// 全部を入れ替える。計測モードの「もう1回」
    func replace(with records: [SquatRecord]) { self.records = records }

    /// ほかの端末から記録が届いた、サーバーの答えが返った、を真似る。テスト用
    func receive(_ incoming: [SquatRecord] = [], removing removed: [UUID] = []) {
        records.removeAll { removed.contains($0.id) }
        records += incoming
        isSynced = true
        onChange?()
    }
}
