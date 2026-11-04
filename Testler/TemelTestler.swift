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
        {"id": "600", "kategori": "1380 Sy", "yasal_islem_maddesi": "1380 Su Ürünleri Kanunu 23. madde",
         "gerekce": "SERPME AGININ KAPALI IKEN YERDEN YUKSEKLIGI", "sevk_makami": null,
         "kontrol_durumu": "🔴 GÜNCELLEME GEREKLİ", "zengin_dayanaklar": ["1380 m.23/1-a-b", "1380 su ürünleri kanunu 23. MADDE"]}
        """#))
        XCTAssertEqual(s.id, 600)
        XCTAssertNil(s.sevkMakami)
        XCTAssertEqual(s.durum, "red")
        XCTAssertEqual(s.dayanaklar, ["1380 m.23/1-a-b", "1380 su ürünleri kanunu 23. MADDE"])
        // Yasal madde ile aynı olan dayanak tekrar edilmez
        XCTAssertEqual(s.tumDayanaklar, ["1380 Su Ürünleri Kanunu 23. madde", "1380 m.23/1-a-b"])
        XCTAssertTrue(TRMetin.kelimeEslesir(normalMetin: s.aramaNormal, sorgu: "serpme ağın"))
        XCTAssertFalse(TRMetin.kelimeEslesir(normalMetin: s.aramaNormal, sorgu: "zıpkın"))
        XCTAssertEqual(s.aramaKaydi.etiket, "1380 Sy")
        XCTAssertEqual(s.aramaKaydi.mevzuat, "1380 Su Ürünleri Kanunu 23. madde")
    }

    func testAramaEslesmesi() {
        func es(_ fiil: String, _ q: String) -> Bool {
            let qn = TRMetin.normal(q)
            return MevzuatAramaMotoru.eslesir(kelimeler: TRMetin.kelimeler(TRMetin.normal(fiil)), sorgu: qn,
                                              parcalar: qn.split(separator: " ").map(String.init))
        }
        XCTAssertTrue(es("CAN YELEĞİ BULUNDURMAMAK", "can"))
        XCTAssertTrue(es("CAN YELEĞİ BULUNDURMAMAK", "yelek"))
        XCTAssertTrue(es("ZIPKINLA AVCILIK", "zıp"))
        XCTAssertTrue(es("IŞIKLA AVCILIK", "ışık avc"))
        XCTAssertFalse(es("AMATÖR AVCILIKTA CANLI YEM", "yelek"))
        XCTAssertFalse(es("TROL İLE AVCILIK", "gırgır"))
        // 4 harften uzun parça kelime içinde de aranır
        XCTAssertTrue(es("DIP TROLÜ", "rolü"))
        XCTAssertEqual(TRMetin.normal("  İSKELE  Işık "), "iskele ışık")
    }

    func testAramaMotoru() {
        let v5 = [
            AramaKaydi(kaynak: .v5, id: "v1", fiil: "CAN YELEĞİ BULUNDURMAMAK", mevzuat: "Özel Tekneler Yönetmeliği"),
            AramaKaydi(kaynak: .v5, id: "v2", fiil: "CAN", mevzuat: "X"),
        ]
        let sevk = [AramaKaydi(kaynak: .sevk, id: "s1", fiil: "CAN YELEĞİ YOK", mevzuat: "4922", etiket: "4922 Sy Kn")]
        let motor = MevzuatAramaMotoru(eski: [], v5: v5, sevk: sevk)
        let sonuc = motor.ara("can")
        XCTAssertEqual(sonuc.map { $0.id }, ["v2", "v1", "s1"])
        XCTAssertTrue(motor.ara("c").isEmpty)
    }

    func testResmiKaynak() {
        let k = KaynakListesi.gomulu
        XCTAssertFalse(k.mevzuat.isEmpty)
        XCTAssertTrue(k.bul(mevzuat: "6/2 Tebliğ (2024/21)").ad.hasPrefix("6/2"))
        XCTAssertTrue(k.bul(mevzuat: "1380 Su Ürünleri Kanunu-01 Ocak 2020 23.MADDE").ad.contains("1380"))
        let bilinmeyen = k.bul(mevzuat: "Bilinmeyen düzenleme")
        XCTAssertFalse(bilinmeyen.eslesti)
        XCTAssertEqual(bilinmeyen.site, "mevzuat.gov.tr")
        XCTAssertEqual(k.dogrulanmis1380("1380 Su Ürünleri Kanunu 36. MADDE")?.title, "1380 sayılı Su Ürünleri Kanunu – Madde 36")
        XCTAssertEqual(k.dogrulanmis1380("1380 sy kanun EK 4. MADDE")?.title, "1380 sayılı Su Ürünleri Kanunu – Ek Madde 4")
        XCTAssertNil(k.dogrulanmis1380("5237 TCK 33. MADDE"))
    }

    func testGosterim() {
        XCTAssertEqual(AramaGosterim.maddeMetni("Madde 10/13"), "10/13")
        XCTAssertEqual(AramaGosterim.maddeMetni("16"), "16")
        XCTAssertEqual(AramaGosterim.kanunKisa("6/2 Tebliğ (2024/21)"), "6/2 Tebliğ")
        XCTAssertEqual(TRMetin.buyukHarf("Zıpkın ağı"), "ZIPKIN AGI")
        XCTAssertTrue(TRMetin.strcasecmp("abc", "ABD") < 0)
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
