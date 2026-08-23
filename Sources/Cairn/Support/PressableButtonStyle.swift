import SwiftUI

/// 押下時にわずかに縮み、離すとバウンスして戻るボタンスタイル。
///
/// `docs/design/motion.md`の「ボタン押下バウンス」（response 0.3, dampingFraction 0.3）に対応する。
/// Reduce Motion有効時はアニメーション自体を無効化し、scale変化は即時に切り替える。
struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.3), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}
