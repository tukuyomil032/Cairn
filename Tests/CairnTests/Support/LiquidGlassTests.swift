import AppKit
import Testing

@testable import Cairn

@Suite("Liquid Glass戦略解決")
struct LiquidGlassTests {
    @Test("NSGlassEffectViewが解決できればprivateAPIを選ぶ")
    func choosesPrivateAPIWhenClassResolves() {
        let strategy = resolveGlassStrategy { name in
            name == "NSGlassEffectView" ? NSView.self : nil
        }
        #expect(strategy == .privateAPI)
    }

    @Test("クラスが解決できなければpublicGlassEffectへフォールバックする")
    func fallsBackToPublicGlassEffectWhenClassMissing() {
        let strategy = resolveGlassStrategy { _ in nil }
        #expect(strategy == .publicGlassEffect)
    }

    @Test("解決できたクラスがNSViewのサブクラスでなければpublicGlassEffectへフォールバックする")
    func fallsBackWhenResolvedClassIsNotAViewType() {
        let strategy = resolveGlassStrategy { name in
            name == "NSGlassEffectView" ? NSObject.self : nil
        }
        #expect(strategy == .publicGlassEffect)
    }
}
