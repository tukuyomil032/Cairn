import SwiftUI

/// Discoveryの検索バー。API即応検索(`SearchViewModel`)の入力欄と、未認証時のサインイン誘導バナーを表示する。
///
/// Liquid Glass適用領域（`docs/design/colors-and-materials.md`）: 検索バー領域は`.cairnGlass`。
struct SearchBarView: View {
    @Bindable var searchViewModel: SearchViewModel<ContinuousClock>
    var authenticationState: AuthenticationState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresentingSignIn = false

    private var isUnauthenticated: Bool {
        authenticationState.status == .unauthenticated
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("アプリを検索", text: $searchViewModel.queryText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 7))

            if isUnauthenticated {
                signInBanner
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .cairnGlass(cornerRadius: 0)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75), value: isUnauthenticated)
        .sheet(isPresented: $isPresentingSignIn) {
            DeviceFlowSignInView(authState: authenticationState)
        }
    }

    private var signInBanner: some View {
        Button {
            isPresentingSignIn = true
        } label: {
            Label("サインインでAPI上限を緩和", systemImage: "key.fill")
                .font(.caption)
        }
        .buttonStyle(.pressable)
        .foregroundStyle(.secondary)
    }
}
