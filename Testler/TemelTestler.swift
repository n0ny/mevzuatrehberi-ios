import XCTest
@testable import MevzuatRehberi

final class TemelTestler: XCTestCase {

    private func satir(_ json: String) throws -> Satir {
        let veri = Data(json.utf8)
        return try JSONDecoder().decode(Satir.self, from: veri)
    }

    func testJSONDegerTurleri() throws {
        let s = try satir(#"{"id": 7, "tutar": "16106.00", "bos": null, "aktif": true, "metin": "  Boğaz  "}"#)
        XCTAssertEqual(s.tamsayi("id"), 7)
        XCTAssertEqual(s.ondalik("tutar"), 16106)
        XCTAssertNil(s.secimli("bos"))
        XCTAssertNil(s.secimli("olmayan"))
        XCTAssertEqual(s["aktif"]?.mantik, true)
        XCTAssertEqual(s.metin("metin"), "Boğaz")
        XCTAssertEqual(s.metin("id"), "7")
    }

    func testListeAlani() throws {
        let s = try satir(#"{"a": "[\"bir\", \"iki\"]", "b": "[3, 75]", "c": "düz metin", "d": null}"#)
        XCTAssertEqual(s.liste("a"), ["bir", "iki"])
        XCTAssertEqual(s.liste("b"), ["3", "75"])
        XCTAssertEqual(s.liste("c"), ["düz metin"])
        XCTAssertEqual(s.liste("d"), [])
    }

    func testTurkceKatlama() {
        XCTAssertEqual(Metin.katla("SERPME AĞI IŞIK İzmir"), "serpme agi isik izmir")
        XCTAssertEqual(Metin.kelimeler("  Boğaz   TROL "), ["bogaz", "trol"])
        XCTAssertTrue(Metin.eslesir(Metin.katla("SERPME AGININ KAPALI IKEN"), Metin.kelimeler("ağının kapalı")))
        XCTAssertFalse(Metin.eslesir(Metin.katla("trol avcılığı"), Metin.kelimeler("trol gırgır")))
        XCTAssertFalse(Metin.eslesir("herhangi", []))
    }

    func testParaBicimi() {
        XCTAssertEqual(Para.yaz(16106), "16.106 TL")
        XCTAssertEqual(Para.aralik(9473, 47397), "9.473 – 47.397 TL")
    }

    func testYaptirimTutari() throws {
        let sabit = Yaptirim(try satir(#"{"id": 1, "yil": 2026, "kabahatin_niteligi": "X", "ipc_miktari": "6627.00", "ipc_min_tutar": "6627.00", "ipc_max_tutar": "6627.00"}"#))
        XCTAssertEqual(sabit.tutarMetni, "6.627 TL")
        let aralik = Yaptirim(try satir(#"{"id": 2, "yil": 2026, "kabahatin_niteligi": "Y", "ipc_min_tutar": 9473, "ipc_max_tutar": 47397}"#))
        XCTAssertEqual(aralik.tutarMetni, "9.473 – 47.397 TL")
        let bos = Yaptirim(try satir(#"{"id": 3, "kabahatin_niteligi": "Z"}"#))
        XCTAssertNil(bos.tutarMetni)
    }

    func testSevkKaydi() throws {
        let s = SevkKaydi(try satir(#"""
        {"id": 600, "kategori": "1380 Sy", "yasal_islem_maddesi": "1380 Su Ürünleri Kanunu 23. madde",
         "gerekce": "SERPME AGININ KAPALI IKEN YERDEN YUKSEKLIGI", "sevk_makami": null,
         "dogrulama_durumu": "red", "zengin_dayanaklar": "[\"1380 m.23/1-a-b\"]", "zengin_orijinal_no": "[3, 75]"}
        """#))
        XCTAssertEqual(s.id, 600)
        XCTAssertNil(s.sevkMakami)
        XCTAssertEqual(s.dayanaklar, ["1380 m.23/1-a-b"])
        XCTAssertTrue(Metin.eslesir(s.arama, Metin.kelimeler("serpme ağı")))
    }

    func testTurFotoAdresi() throws {
        let t = Tur(try satir(#"{"id": 1, "ad": "Ahtapot", "grup": "Yumuşakça", "foto_url": "https://sg.barisguresci.com.tr/uploads/turler/a.jpg"}"#))
        XCTAssertEqual(t.fotoURL?.absoluteString, "https://sg.barisguresci.com.tr/uploads/turler/a.jpg")
        let bos = Tur(try satir(#"{"id": 2, "ad": "X", "foto_url": "javascript:alert(1)"}"#))
        XCTAssertNil(bos.fotoURL)
        XCTAssertEqual(bos.grup, "Diğer")
    }

    func testTarih() {
        XCTAssertEqual(Tarih.gunYaz("2026-10-23"), "23 Ekim 2026")
        XCTAssertNil(Tarih.gunYaz(nil))
    }
}
