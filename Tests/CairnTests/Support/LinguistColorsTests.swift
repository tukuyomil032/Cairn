import Foundation
import SwiftUI
import Testing

@testable import Cairn

@Suite("言語カラー")
struct LinguistColorsTests {
    @Test("正常なJSONをデコードできる")
    func decodesValidJSON() throws {
        let json = ##"{"Swift": "#F05138", "Python": "#3572A5"}"##
        let colors = try LinguistColors.decode(Data(json.utf8))
        #expect(colors.hexByLanguage["Swift"] == "#F05138")
        #expect(colors.hexByLanguage["Python"] == "#3572A5")
    }

    @Test("未知の言語はnilを返す")
    func returnsNilForUnknownLanguage() throws {
        let json = ##"{"Swift": "#F05138"}"##
        let colors = try LinguistColors.decode(Data(json.utf8))
        #expect(colors.color(for: "NoSuchLanguage") == nil)
    }

    @Test("不正なHex文字列はColor生成でnilを返す（クラッシュしない）")
    func returnsNilForMalformedHex() throws {
        let json = ##"{"Broken": "not-a-color"}"##
        let colors = try LinguistColors.decode(Data(json.utf8))
        #expect(colors.color(for: "Broken") == nil)
    }

    @Test("Color(hex:)は#付き6桁Hexを正しく解釈する")
    func colorHexInitParsesValidHex() {
        #expect(Color(hex: "#FFFFFF") != nil)
        #expect(Color(hex: "000000") != nil)
        #expect(Color(hex: "#GGGGGG") == nil)
        #expect(Color(hex: "#FFF") == nil)
    }

    @Test("バンドルされたLinguistColors.jsonを実際にロードできる")
    func loadsBundledResource() {
        let colors = LinguistColors.loadBundled()
        #expect(colors.hexByLanguage["Swift"] == "#F05138")
        #expect(colors.hexByLanguage.count > 100)
    }
}
