import SwiftUI

extension View {
    /// Cairnのサイドバー・検索バー等コントロール層で使う背景マテリアル
    /// （`docs/design/colors-and-materials.md`のLiquid Glass適用可否表を参照）。
    ///
    /// 非公開API`NSGlassEffectView`をランタイム解決する実装を試みたが、検索バーが非表示になる・
    /// サイドバーがピン留め中だけガラスが消える、という不具合を連続して起こした（`CABackdropLayer`が
    /// ウィンドウサーバー登録状態に依存する既知の癖を持ち、確実に機能させるには追加のワークアラウンドが
    /// 必要だった）。MITライセンスの参考ネイティブアプリ2件（msitarzewski/brew-browser,
    /// steipete/CodexBar）を調査した結果、いずれも独自のガラス実装は持たず、標準の
    /// `NavigationSplitView`のサイドバーマテリアルや`NSMenu`のvibrancyなど「システムのネイティブ
    /// サーフェスにそのまま乗る」ことで見栄えの良い半透明を実現していると判明した。Cairnは独自の
    /// ホバー展開インタラクションのためNavigationSplitViewを使えないが、同じ発想で「自前のガラス
    /// 実装を作り込まず、標準の`Material`（`NSVisualEffectView`ベース、Finder/Mailのサイドバーと
    /// 同じ技術）に任せる」方針に変更した。
    ///
    /// `.thickMaterial`を選ぶ理由: `bg-sidebar`トークン（light: `rgba(246,246,248,0.86)`,
    /// dark: `rgba(40,40,43,0.86)`）が86%程度の不透明度を想定しており、`.regularMaterial`より近い。
    ///
    /// 小さい単体コントロール（サイドバーのピン留めトグルボタン等）には、この関数ではなく
    /// 公式API`.glassEffect(_:in:)`を直接使うこと（`DeviceFlowSignInView`のuser_codeカプセルと
    /// 同じ使い方）。
    func cairnGlass(cornerRadius: CGFloat) -> some View {
        background(.thickMaterial, in: .rect(cornerRadius: cornerRadius))
    }
}
