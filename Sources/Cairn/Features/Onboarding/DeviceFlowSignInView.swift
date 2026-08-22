import AppKit
import SwiftUI

/// GitHub OAuth Device Flowによるサインイン画面。
///
/// `.unauthenticated`時はサインインボタンを表示し、`.authenticating`時は
/// user_codeとポーリング中インジケータを表示する。ブラウザ起動とuser_codeの
/// クリップボードコピーは、`authState.status`が`.authenticating`へ遷移したことを
/// `onChange`で検知して行う（`AuthenticationState`側にUI副作用のクロージャを
/// 直接渡すと、Swift 6の並行性チェック下でMainActor隔離クロージャを非隔離の
/// asyncメソッドへ渡すことになるため、状態監視型の設計にしている）。
struct DeviceFlowSignInView: View {
    @Bindable var authState: AuthenticationState

    @State private var signInTask: Task<Void, Never>?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            switch authState.status {
            case .unauthenticated:
                unauthenticatedContent
            case .authenticating(let userCode, let verificationURI):
                authenticatingContent(userCode: userCode, verificationURI: verificationURI)
            case .authenticated:
                authenticatedContent
            case .tokenInvalid:
                tokenInvalidContent
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(minWidth: 320)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .padding(24)
        .onChange(of: authState.status) { _, newStatus in
            if case .authenticating(let userCode, let verificationURI) = newStatus {
                NSWorkspace.shared.open(verificationURI)
                copyToClipboard(userCode)
            }
        }
        .onDisappear {
            signInTask?.cancel()
        }
    }

    private var unauthenticatedContent: some View {
        VStack(spacing: 12) {
            Text("GitHubでサインイン")
                .font(.headline)
            Text("サインインすると検索・API呼び出しの上限が大きく緩和されます。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("サインイン", action: startSignIn)
                .buttonStyle(.borderedProminent)
        }
    }

    private func authenticatingContent(userCode: String, verificationURI: URL) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("ブラウザで以下のコードを入力してください")
                .font(.subheadline)
            Text(userCode)
                .font(.system(.title, design: .monospaced))
                .textSelection(.enabled)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .glassEffect(.regular.interactive(), in: .capsule)
            Button("ブラウザを再度開く") {
                NSWorkspace.shared.open(verificationURI)
            }
            .buttonStyle(.bordered)
        }
    }

    private var authenticatedContent: some View {
        Label("サインイン済み", systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
    }

    private var tokenInvalidContent: some View {
        VStack(spacing: 12) {
            Label("認証が無効になりました", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Button("再サインイン", action: startSignIn)
                .buttonStyle(.borderedProminent)
        }
    }

    private func startSignIn() {
        errorMessage = nil
        signInTask = Task {
            do {
                try await authState.signIn()
            } catch is CancellationError {
                // ビュー破棄によるキャンセルは通常フローなので無視する。
            } catch {
                errorMessage = "サインインに失敗しました。もう一度お試しください。"
            }
        }
    }

    private func copyToClipboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}
