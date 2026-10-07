import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation
import UserNotifications

/// アカウント。Apple でログインした人の番号（uid）で、記録の棚を決める
///
/// ログインしたら、その棚の記録で AppModel を作る。ログアウトしたら捨て、端末のキャッシュも消す。
/// 受け取るのは番号だけで、名前とメールアドレスは求めない（docs/features/account）。
@Observable final class Account {
    enum State: Equatable {
        /// 起動して、ログインしているかを確かめている
        case checking
        case signedOut
        case signedIn(uid: String)
    }

    enum Failure: Identifiable {
        case signIn, signOut, delete
        var id: Self { self }

        var message: String {
            switch self {
            case .signIn: String(localized: "つながりませんでした。電波のあるところで、もう一度押してください。")
            case .signOut: String(localized: "ログアウトできませんでした。もう一度試してください。")
            case .delete: String(localized: "削除できませんでした。電波のあるところで、もう一度試してください。")
            }
        }
    }

    private(set) var state = State.checking
    /// ログインした人の画面の状態。ログアウトしたら捨てる
    private(set) var model: AppModel?
    /// ログインした直後。起き上がったスクワットマンを見せてから、ホームへ進む
    private(set) var welcoming = false
    /// ログインや削除の途中。ボタンを押せなくする
    private(set) var busy = false
    var failure: Failure?

    @ObservationIgnored private var store: RecordStore?
    @ObservationIgnored private var nonce: AppleNonce?
    @ObservationIgnored private var listener: AuthStateDidChangeListenerHandle?
    @ObservationIgnored private let appleSignIn = AppleSignIn()

    /// 起き上がったスクワットマンを見せる長さ
    static let welcomeDuration: TimeInterval = 0.6

    init() {
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            MainActor.assumeIsolated { self?.update(uid: user?.uid) }
        }
    }

    private func update(uid: String?) {
        guard let uid else {
            tearDown()
            state = .signedOut
            return
        }
        if state == .signedIn(uid: uid) && model != nil { return }
        let store = FirestoreRecordStore(uid: uid)
        let model = AppModel(store: store)
        model.feel.start()
        model.presentSplashIfNeeded()
        self.store = store
        self.model = model
        state = .signedIn(uid: uid)
    }

    /// ログアウトしたとき、アカウントを消したとき。次にこの端末を使う人に、前の人の記録を残さない
    private func tearDown() {
        guard model != nil || store != nil else { return }
        store?.stop()
        store = nil
        model = nil
        // 今日まだ通知は前の人の記録で予約したもの
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        Task {
            let db = Firestore.firestore()
            do {
                try await db.terminate()
                try await db.clearPersistence()
            } catch {
                print("Firestore: \(error)")
            }
        }
    }

    // MARK: - ログイン

    /// ログイン画面の Apple のボタンを押したとき
    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = AppleNonce()
        self.nonce = nonce
        request.requestedScopes = []
        request.nonce = nonce.hashed
    }

    func complete(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            if !error.isAppleSignInCanceled { failure = .signIn }
        case .success(let authorization):
            guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let credential = firebaseCredential(apple) else {
                failure = .signIn
                return
            }
            busy = true
            welcoming = true
            defer { busy = false }
            do {
                try await Auth.auth().signIn(with: credential)
                try? await Task.sleep(for: .seconds(Self.welcomeDuration))
                welcoming = false
            } catch {
                print("Auth: \(error)")
                welcoming = false
                failure = .signIn
            }
        }
    }

    private func firebaseCredential(_ apple: ASAuthorizationAppleIDCredential) -> AuthCredential? {
        guard let nonce, let token = apple.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else { return nil }
        return OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce.raw, fullName: nil)
    }

    // MARK: - ログアウトと削除

    /// 記録はアカウントに残る。同じ Apple ID でログインすると戻る
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Auth: \(error)")
            failure = .signOut
        }
    }

    /// Apple でもう一度本人を確かめ、記録をすべて消し、Apple との連携を切り、アカウントを消す
    ///
    /// 消す順番は、記録が先。アカウントを先に消すと、自分の棚に書き込む権限がなくなって記録が残る。
    func deleteAccount() async {
        guard let user = Auth.auth().currentUser, let store else { return }
        busy = true
        defer { busy = false }
        do {
            let nonce = AppleNonce()
            self.nonce = nonce
            let apple = try await appleSignIn.request(nonce: nonce)
            guard let credential = firebaseCredential(apple),
                  let code = apple.authorizationCode.flatMap({ String(data: $0, encoding: .utf8) }) else {
                failure = .delete
                return
            }
            try await user.reauthenticate(with: credential)
            try await store.deleteAll()
            try await Auth.auth().revokeToken(withAuthorizationCode: code)
            try await user.delete()
        } catch {
            if error.isAppleSignInCanceled { return }
            print("Account: \(error)")
            failure = .delete
        }
    }
}
