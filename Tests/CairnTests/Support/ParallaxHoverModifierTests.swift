import Foundation
import Testing

@testable import Cairn

@Suite("3Dパララックスホバーの座標変換")
struct ParallaxHoverModifierTests {
    @Test("ビュー中央は(0, 0)に正規化される")
    func centerIsZero() {
        let offset = ParallaxHover.normalizedOffset(
            location: CGPoint(x: 50, y: 50),
            size: CGSize(width: 100, height: 100)
        )
        #expect(offset.x == 0)
        #expect(offset.y == 0)
    }

    @Test("左上隅は(-1, -1)に近づく")
    func topLeftIsNearNegativeOne() {
        let offset = ParallaxHover.normalizedOffset(
            location: .zero,
            size: CGSize(width: 100, height: 100)
        )
        #expect(offset.x == -1)
        #expect(offset.y == -1)
    }

    @Test("右下隅は(1, 1)に近づく")
    func bottomRightIsNearOne() {
        let offset = ParallaxHover.normalizedOffset(
            location: CGPoint(x: 100, y: 100),
            size: CGSize(width: 100, height: 100)
        )
        #expect(offset.x == 1)
        #expect(offset.y == 1)
    }

    @Test("ビュー範囲外の座標は-1〜1にクランプされる")
    func outOfBoundsIsClamped() {
        let offset = ParallaxHover.normalizedOffset(
            location: CGPoint(x: 500, y: -500),
            size: CGSize(width: 100, height: 100)
        )
        #expect(offset.x == 1)
        #expect(offset.y == -1)
    }

    @Test("サイズが0以下の場合は0除算を避けて.zeroを返す")
    func zeroSizeReturnsZero() {
        let offset = ParallaxHover.normalizedOffset(location: CGPoint(x: 10, y: 10), size: .zero)
        #expect(offset == .zero)
    }
}
