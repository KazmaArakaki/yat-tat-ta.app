import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation
import UserNotifications

/// アカウント。Firebase が割り当てる番号（uid）で、記録の棚を決める
///
/// 最初の起動では、何も聞かずに匿名のアカウントを作り、すぐ叩けるようにする。Apple でのログインは設定シートから、
/// 好きなときに。匿名のアカウントを Apple に引き継ぐので、uid も棚も変わらない（docs/features/account）。
/// ログインしたら、その棚の記録で AppModel を作る。ログアウトしたら捨て、端末のキャッシュも消す。
/// 受け取るのは番号だけで、名前とメールアドレスは求めない。
@Observable final class Account {
    enum State: Equatable {
        /// 起動して、ログインしているかを確かめている
        case checking
        /// 匿名のアカウントを作っている
        case starting
        /// 匿名のアカウントを作れなかった。はじめての起動に電波がなかった
        case offline
        case signedIn(uid: String)
    }

    enum Failure: Identifiable {
        case start, signIn, signOut, delete
        var id: Self { self }

        var message: String {
            switch self {
            case .start: String(localized: "はじめての起動は、電波が要ります。電波のあるところで、もう一度押してください。")
            case .signIn: String(localized: "つながりませんでした。電波のあるところで、もう一度押してください。")
            case .signOut: String(localized: "ログアウトできませんでした。もう一度試してください。")
            case .delete: String(localized: "削除できませんでした。電波のあるところで、もう一度試してください。")
            }
        }
    }

    private(set) var state = State.checking
    /// ログインした人の画面の状態。ログアウトしたら捨てる
    private(set) var model: AppModel?
    /// 匿名のアカウント。まだ Apple でログインしていない
    private(set) var isGuest = false
    /// はじめの画面からつながった直後。起き上がったスクワットマンを見せてから、ホームへ進む
    private(set) var welcoming = false
    /// ログインや削除の途中。ボタンを押せなくする
    private(set) var busy = false
    var failure: Failure?
    /// 引き継ごうとした Apple ID に、もう別のアカウントがある。切り替えるかを確かめる
    var pendingSwitch: AuthCredential?

    @ObservationIgnored private var store: RecordStore?
    /// 前の人のキャッシュを消している途中。終わるまで、次の棚を開かない
    @ObservationIgnored private var cleaning: Task<Void, Never>?
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
            startGuest()
            return
        }
        isGuest = Auth.auth().currentUser?.isAnonymous ?? false
        if state == .signedIn(uid: uid) && model != nil { return }
        if model != nil { tearDown() }
        state = .signedIn(uid: uid)
        Task {
            await cleaning?.value
            // 待っているあいだに、別の人に替わった
            guard state == .signedIn(uid: uid), model == nil else { return }
            let store = FirestoreRecordStore(uid: uid)
            let model = AppModel(store: store)
            model.feel.start()
            model.presentSplashIfNeeded()
            self.store = store
            self.model = model
        }
    }

    /// ログアウトしたとき、アカウントを消したとき。次にこの端末を使う人に、前の人の記録を残さない
    private func tearDown() {
        guard model != nil || store != nil else { return }
        store?.stop()
        store = nil
        model = nil
        // 今日まだ通知は前の人の記録で予約したもの
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let previous = cleaning
        cleaning = Task {
            await previous?.value
            let db = Firestore.firestore()
            do {
                try await db.terminate()
                try await db.clearPersistence()
            } catch {
                print("Firestore: \(error)")
            }
        }
    }

    // MARK: - 匿名で始める

    /// 名前もメールアドレスも聞かずに、匿名のアカウントを作る。審査ガイドライン 5.1.1(v)
    private func startGuest() {
        state = .starting
        Task {
            await cleaning?.value
            do {
                try await Auth.auth().signInAnonymously()
            } catch {
                print("Auth: \(error)")
                state = .offline
            }
        }
    }

    /// はじめの画面の「もう一度」
    func retryStart() async {
        failure = nil
        busy = true
        welcoming = true
        state = .starting
        defer { busy = false }
        do {
            try await Auth.auth().signInAnonymously()
            try? await Task.sleep(for: .seconds(Self.welcomeDuration))
            welcoming = false
        } catch {
            print("Auth: \(error)")
            welcoming = false
            state = .offline
            failure = .start
        }
    }

    // MARK: - ログイン

    /// 設定シートの Apple のボタンを押したとき
    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = AppleNonce()
        self.nonce = nonce
        request.requestedScopes = []
        request.nonce = nonce.hashed
    }

    /// 設定シートの Apple のボタンを押したあと。匿名のアカウントを Apple に引き継ぐ
    ///
    /// 引き継ぐと uid が変わらないので、記録はそのまま残る。Apple ID にもう別のアカウントがあれば、
    /// 切り替えるかを確かめる（pendingSwitch）。記録がなければ、確かめずに切り替える。
    func complete(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            guard !error.isAppleSignInCanceled else { return }
            print("Apple: \(error)")
            failure = .signIn
        case .success(let authorization):
            guard let user = Auth.auth().currentUser,
                  let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let credential = firebaseCredential(apple) else {
                print("Auth: Apple の証明を Firebase に渡せない")
                failure = .signIn
                return
            }
            busy = true
            defer { busy = false }
            do {
                try await user.link(with: credential)
                isGuest = false
            } catch let error as NSError where error.domain == AuthErrorDomain && error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                guard let updated = error.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential else {
                    print("Auth: 切り替え用の証明がない: \(error)")
                    failure = .signIn
                    return
                }
                if model?.recordCount ?? 0 == 0 {
                    await switchAccount(to: updated)
                } else {
                    pendingSwitch = updated
                }
            } catch {
                print("Auth: 引き継げない: \(error)")
                failure = .signIn
            }
        }
    }

    /// Apple ID のほうのアカウントへ切り替える。匿名で付けた記録は消す
    ///
    /// 消す順番は、記録が先。Apple のアカウントに替わると、匿名の棚に書き込む権限がなくなって記録が残る。
    /// 匿名のアカウント自体は消さず、空のまま残す。消すには直前（約5分以内）のログインが要り、
    /// 匿名のアカウントはログインし直して確かめることができない。
    func switchAccount(to credential: AuthCredential) async {
        pendingSwitch = nil
        guard let guest = Auth.auth().currentUser, guest.isAnonymous, let store else { return }
        busy = true
        defer { busy = false }
        do {
            try await store.deleteAll()
        } catch {
            print("Account: 匿名の記録を消せない: \(error)")
            failure = .signIn
            return
        }
        do {
            try await Auth.auth().signIn(with: credential)
        } catch {
            // 記録はもう消えている。空の匿名のアカウントのまま続ける
            print("Auth: Apple のアカウントへ切り替えられない: \(error)")
            failure = .signIn
        }
    }

    private func firebaseCredential(_ apple: ASAuthorizationAppleIDCredential) -> AuthCredential? {
        guard let nonce, let token = apple.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else { return nil }
        return OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce.raw, fullName: nil)
    }

    // MARK: - ログアウトと削除

    /// 記録はアカウントに残る。同じ Apple ID でログインすると戻る。この端末は、新しい匿名のアカウントで始め直す
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
    /// 匿名のアカウントなら、本人確認と連携の解除はいらない。記録を消し、アカウントも消せれば消す。
    /// 消す順番は、記録が先。アカウントを先に消すと、自分の棚に書き込む権限がなくなって記録が残る。
    func deleteAccount() async {
        guard let user = Auth.auth().currentUser, let store else { return }
        busy = true
        defer { busy = false }
        if user.isAnonymous {
            do {
                try await store.deleteAll()
            } catch {
                print("Account: \(error)")
                failure = .delete
                return
            }
            // 消すには直前のログインが要り、匿名では確かめ直せない。消せなければ、空のアカウントを手放す
            do {
                try await user.delete()
            } catch {
                print("Account: 匿名のアカウントを消せない。手放す: \(error)")
                try? Auth.auth().signOut()
            }
            return
        }
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
