import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Apple でのログインに渡す、使い捨ての合言葉（nonce）
///
/// Apple には SHA-256 にした値を渡し、Firebase には元の値を渡す。Apple が返した証明書が、
/// この端末のこの1回のために出されたものかを Firebase が確かめる。
struct AppleNonce {
    let raw: String

    init() {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        raw = String((0..<32).map { _ in chars.randomElement(using: &generator)! })
    }

    var hashed: String {
        SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// ボタンを使わずに Apple のログインのシートを出す。アカウントを削除する前の本人確認で使う
///
/// ログイン画面では、Apple の決まりどおり標準のボタン（SignInWithAppleButton）を使う。
final class AppleSignIn: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    /// 名前とメールアドレスは求めない
    func request(nonce: AppleNonce) async throws -> ASAuthorizationAppleIDCredential {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = []
        request.nonce = nonce.hashed
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation?.resume(returning: credential)
        } else {
            continuation?.resume(throwing: ASAuthorizationError(.invalidResponse))
        }
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

extension Error {
    /// Apple のシートを利用者が閉じた。失敗として伝えない
    var isAppleSignInCanceled: Bool {
        (self as? ASAuthorizationError)?.code == .canceled
    }
}
