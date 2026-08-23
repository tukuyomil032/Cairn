import AppKit
import SwiftUI
import os

/// Cairn独自のLiquid Glass背景で使うvariant。
///
/// 非公開クラス`NSGlassEffectView`が内部的に持つvariant値（0〜19、Apple非公開）のうち、
/// Cairnで実際に採用する値だけを意味のある名前で公開する。
enum CairnGlassVariant: Int, Sendable {
    /// サイドバー・検索バー等、通常のコントロール層背景で使う標準variant。
    case standard = 11
}

/// `.cairnGlass`がどの実装経路を使っているかを表す。
enum GlassResolutionStrategy: Sendable, Equatable {
    /// 非公開API`NSGlassEffectView`をランタイム解決できた場合。
    case privateAPI
    /// 非公開APIが解決できず、公開API`.glassEffect(_:in:)`にフォールバックする場合。
    case publicGlassEffect
    /// 公開APIも利用できない場合の最終フォールバック（`.thickMaterial`）。
    /// `Package.swift`がmacOS 26専用の間は到達しないが、将来の最小対応バージョン
    /// 引き下げに備えて経路自体を残す。
    case material
}

/// クラス解決の結果から採用する戦略を決める純粋関数。`NSClassFromString`を直接呼ばず
/// クロージャ注入可能にすることで、実行環境に依存せずユニットテストできるようにしている。
func resolveGlassStrategy(classResolver: (String) -> AnyClass?) -> GlassResolutionStrategy {
    if let resolved = classResolver("NSGlassEffectView"), resolved is NSView.Type {
        return .privateAPI
    }
    return .publicGlassEffect
}

/// アプリ起動中に一度だけ解決した結果をキャッシュし、フォールバック発生を一度だけログに残す。
enum CairnGlass {
    static let strategy: GlassResolutionStrategy = {
        let resolved = resolveGlassStrategy(classResolver: NSClassFromString)
        #if DEBUG
            if resolved != .privateAPI {
                Logger(subsystem: "com.cairn.app", category: "LiquidGlass")
                    .info(
                        "NSGlassEffectView not available; falling back to \(String(describing: resolved), privacy: .public)"
                    )
            }
        #endif
        return resolved
    }()
}

extension View {
    /// Cairn独自のLiquid Glass背景を適用する。内部でNSGlassEffectView（非公開）→
    /// `.glassEffect(_:in:)`（公開）→`.thickMaterial`の順にフォールバックする。
    /// コントロール層（サイドバー・検索バー・ホバーオーバーレイ等）にのみ使うこと
    /// （`docs/design/colors-and-materials.md`のLiquid Glass適用可否表を参照）。
    func cairnGlass(cornerRadius: CGFloat, variant: CairnGlassVariant = .standard) -> some View {
        modifier(CairnGlassModifier(cornerRadius: cornerRadius, variant: variant))
    }
}

private struct CairnGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let variant: CairnGlassVariant

    func body(content: Content) -> some View {
        switch CairnGlass.strategy {
        case .privateAPI:
            content.background(CairnGlassBackgroundView(cornerRadius: cornerRadius, variant: variant))
        case .publicGlassEffect:
            content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        case .material:
            content.background(.thickMaterial, in: .rect(cornerRadius: cornerRadius))
        }
    }
}

/// 非公開API`NSGlassEffectView`をランタイム経由で操作する、コンテンツを持たない背景専用ビュー。
///
/// `.background(_:)`修飾子はSwiftUIが前景コンテンツの実測サイズを自動的に背景へ伝えるため、
/// このビュー自身はサイズ計算を一切実装する必要がない（`NSHostingView`で前景を再ホストする
/// 設計は、SwiftUIのレイアウトシステムに正しいサイズが伝わらず内容が消える不具合の原因になっていた）。
///
/// Objective-Cの例外はSwiftの`try`/`catch`で捕捉できないため、KVC/セレクタ呼び出しの
/// 前に必ず`responds(to:)`で応答可能かを確認し、応答しない場合は呼び出し自体をスキップする
/// （これが唯一有効な防御であり、事後のエラーハンドリングでは代替できない）。
private struct CairnGlassBackgroundView: NSViewRepresentable {
    let cornerRadius: CGFloat
    let variant: CairnGlassVariant

    func makeNSView(context: Context) -> NSView {
        guard let glassClass = NSClassFromString("NSGlassEffectView") as? NSView.Type else {
            return makeFallbackView()
        }
        let glassView = glassClass.init(frame: .zero)
        applyCornerRadius(to: glassView)
        applyVariant(to: glassView)
        return glassView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        applyCornerRadius(to: nsView)
        applyVariant(to: nsView)
    }

    private func makeFallbackView() -> NSView {
        let fallback = NSVisualEffectView()
        fallback.material = .underWindowBackground
        fallback.blendingMode = .behindWindow
        return fallback
    }

    private func applyCornerRadius(to glassView: NSView) {
        guard glassView.responds(to: NSSelectorFromString("setCornerRadius:")) else { return }
        glassView.setValue(cornerRadius, forKey: "cornerRadius")
    }

    private func applyVariant(to glassView: NSView) {
        let selector = NSSelectorFromString("set_variant:")
        guard glassView.responds(to: selector),
            let method = class_getInstanceMethod(object_getClass(glassView), selector)
        else {
            return
        }
        typealias VariantSetterIMP = @convention(c) (AnyObject, Selector, Int) -> Void
        let implementation = method_getImplementation(method)
        let setVariant = unsafeBitCast(implementation, to: VariantSetterIMP.self)
        setVariant(glassView, selector, variant.rawValue)
    }
}
