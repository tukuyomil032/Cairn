import SwiftUI

/// カーソル位置に応じて3Dパララックス回転とわずかな拡大を加えるホバーモディファイア。
///
/// `docs/design/motion.md`の3Dパララックスホバーの推奨spring値を使う。Reduce Motion有効時は
/// 回転角を常に0に固定する（ホバー自体のフィードバック=拡大は維持し、奥行き表現のみ止める）。
enum ParallaxHover {
    /// カーソル位置をビューの左上原点(0,0)〜右下(size.width, size.height)から
    /// -1〜1に正規化する純粋関数。`size`が0以下の場合は`.zero`を返す（0除算を避ける）。
    static func normalizedOffset(location: CGPoint, size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return .zero }
        let normalizedX = min(max((location.x / size.width) * 2 - 1, -1), 1)
        let normalizedY = min(max((location.y / size.height) * 2 - 1, -1), 1)
        return CGPoint(x: normalizedX, y: normalizedY)
    }
}

extension View {
    /// カーソル位置に応じた3Dパララックス回転+微小拡大を加える。
    /// - Parameter maxAngle: X/Y軸それぞれの最大回転角度（度）。既定8度。
    func parallaxHover(maxAngle: Double = 8) -> some View {
        modifier(ParallaxHoverModifier(maxAngle: maxAngle))
    }
}

private struct ParallaxHoverModifier: ViewModifier {
    var maxAngle: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewSize: CGSize = .zero
    @State private var offset: CGPoint = .zero
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .overlay(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { viewSize = proxy.size }
                        .onChange(of: proxy.size) { _, newSize in viewSize = newSize }
                }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let normalized = ParallaxHover.normalizedOffset(location: location, size: viewSize)
                    withAnimation(reduceMotion ? nil : .interactiveSpring(response: 0.1, dampingFraction: 0.5)) {
                        offset = normalized
                        isHovering = true
                    }
                case .ended:
                    withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.6)) {
                        offset = .zero
                        isHovering = false
                    }
                }
            }
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : offset.y * maxAngle),
                axis: (x: 1, y: 0, z: 0)
            )
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : offset.x * -maxAngle),
                axis: (x: 0, y: 1, z: 0)
            )
            .scaleEffect(isHovering ? 1.02 : 1)
    }
}
