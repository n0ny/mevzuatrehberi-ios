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

    func testYaptirimKurallari() throws {
        XCTAssertEqual(YaptirimKurallari.kosulListesi(notlar: "Eski: x. 2026 CEZA: 36/1-m kişi 9.473 TL. Tekne 47.397 TL; Somut kayıt kontrol",
                                                     kaynakMetni: "", yil: 2026),
                       ["kişi 9.473 TL.", "Tekne 47.397 TL"])
        XCTAssertEqual(YaptirimKurallari.tebligAnahtari("6/1 Tebliğ md. 5"), "teblig61")
        XCTAssertEqual(YaptirimKurallari.tebligAnahtari("16/1"), "")
        XCTAssertEqual(YaptirimKurallari.elKoymaDegeri(" hayır "), "Hayır")
        XCTAssertEqual(YaptirimKurallari.maddeDegeri("Madde 36/1-a"), "36/1-a")
        let ayar = KaynakListesi.gomulu.yaptirimAyari
        XCTAssertEqual(ayar.yil, 2026)
        let t = Yaptirim(try satir(#"{"id": 1, "yil": 2026, "kabahatin_niteligi": "X", "ceza_maddesi": "36/1-t"}"#))
        if case .kosullar(let s, _) = YaptirimKurallari.ceza(t, ayar: ayar) {
            XCTAssertEqual(s.count, 6)
        } else {
            XCTFail("36/1-t koşullu olmalı")
        }
        let dip = Yaptirim(try satir(#"{"id": 2, "yil": 2026, "kabahatin_niteligi": "Y", "ceza_maddesi": "36/1-l", "ipc_hesaplama_tipi": "36/1-l | DIP TROLU | GEMİ BOYU KOŞULLU", "ipc_min_tutar": "66357.00", "ipc_max_tutar": "199071.00"}"#))
        if case .kosullar(let s, _) = YaptirimKurallari.ceza(dip, ayar: ayar) {
            XCTAssertEqual(s[1], "12 metre dahil, 22 metreden küçük gemi: **₺132.714**")
        } else {
            XCTFail("Dip trolü koşullu olmalı")
        }
        let sabit = Yaptirim(try satir(#"{"id": 3, "yil": 2026, "kabahatin_niteligi": "Z", "ceza_maddesi": "36/1-p", "ipc_hesaplama_tipi": "SABİT", "ipc_miktari": "16106.00"}"#))
        if case .tutar(let m) = YaptirimKurallari.ceza(sabit, ayar: ayar) {
            XCTAssertEqual(m, "₺16.106")
        } else {
            XCTFail("Sabit tutar olmalı")
        }
        XCTAssertEqual(YaptirimKurallari.kisaca(sabit, ayar: ayar), "Bu ceza, ilgili fiil için uygulanır. Uygulanacak tutar yukarıda gösterilmiştir.")
        let liste = [t, dip, sabit]
        XCTAssertEqual(YaptirimKurallari.ara(liste, sorgu: "36/1-l", yil: 2026).map { $0.id }, [2])
        XCTAssertTrue(YaptirimKurallari.ara(liste, sorgu: "x", yil: 2026).isEmpty)
    }

    func testBolge() throws {
        let b = Bolge(try satir(#"""
        {"id": "1", "deniz": "Akdeniz", "il": "Hatay", "ilce": "Dörtyol", "baslik": "İsdemir", "teblig_turu": "6/1", "aktif": "1",
         "baslangic_tarihi": "0000-00-00",
         "harita": {"t": "alan", "p": [[36.70, 36.19, "a"], [36.71, 36.19, "b"], [36.71, 36.20, "c"]], "c": [[36.70, 36.19], [36.71, 36.19], [36.71, 36.20]]}}
        """#))
        XCTAssertEqual(b.harita?.tur, "alan")
        XCTAssertEqual(b.harita?.noktalar.count, 3)
        XCTAssertNil(b.baslangic)
        if case .aktif = b.durum(bugun: "2026-11-05") {} else { XCTFail("Aktif olmalı") }
        XCTAssertTrue(b.aramaSite.contains("isdemir"))
        XCTAssertEqual(BolgeKurallari.tarih("2026-03-01"), "01.03.2026")
        XCTAssertEqual(BolgeKurallari.googleHarita(BolgeHaritasi.Nokta(enlem: 36.7, boylam: 36.19, metin: ""))?.absoluteString,
                       "https://www.google.com/maps/search/?api=1&query=36.700000%2C36.190000")
    }

    /// Sunucudaki tekne.json, telefonda saklanan biçimden (Satir) geri okunabilmeli.
    func testTekneIcerikCozumleme() throws {
        let s = try satir(#"""
        {"surum": 1, "kok": "tekne", "sayfalar": {
          "tekne": {"baslik": "Tekne / gemi kontrolü", "aciklama": "Seçin.", "bloklar": [
            {"tur": "etiket", "metin": "Denetim Türü"},
            {"tur": "kartlar", "kartlar": [{"baslik": "Balıkçı Teknesi", "aciklama": "x", "hedef": "balikci"},
                                           {"baslik": "Tür / Boy / Miktar", "yakinda": "Yakında aktif olacak"}]}
          ]},
          "kucuk": {"baslik": "Kontrol Çek Listesi", "bloklar": [
            {"tur": "etiket", "metin": "İSTENEN", "sayi": "10 Kalem"},
            {"tur": "liste", "maddeler": [{"simge": "book", "baslik": "Ruhsatname", "etiket": "Kontrol:", "alt": ["a", "b"]},
                                          {"baslik": "Can Yeleği", "not": "(DEB)"}]},
            {"tur": "kaynak", "baslik": "Resmî kaynak", "ad": "Yönetmelik", "url": "https://www.resmigazete.gov.tr/x.htm", "site": "resmigazete.gov.tr"}
          ]}
        }}
        """#)
        let veri = try JSONEncoder().encode(s)
        let t = try JSONDecoder().decode(TekneIcerik.self, from: veri)
        XCTAssertEqual(t.kokSayfa, "tekne")
        XCTAssertEqual(t.sayfalar.count, 2)
        let kok = try XCTUnwrap(t.sayfalar["tekne"])
        XCTAssertEqual(kok.bloklar[1].kartlar?.first?.hedef, "balikci")
        XCTAssertEqual(kok.bloklar[1].kartlar?.last?.yakinda, "Yakında aktif olacak")
        let liste = try XCTUnwrap(t.sayfalar["kucuk"]?.bloklar[1].maddeler)
        XCTAssertEqual(liste[0].alt ?? [], ["a", "b"])
        XCTAssertEqual(liste[1].not, "(DEB)")
        XCTAssertEqual(t.sayfalar["kucuk"]?.bloklar[0].sayi, "10 Kalem")
        XCTAssertEqual(TekneSimge.madde("lifebuoy"), "lifepreserver")
        XCTAssertEqual(TekneSimge.kart(nil, baslik: "Tür / Boy / Miktar"), "ruler")
    }

    /// api/bilgi.php cevabı (telefona JSONDeger olarak gelir) BilgiVerisi'ne çözülebilmeli.
    func testBilgiVerisiCozumleme() throws {
        let j = try satir(#"""
        {"ok": true, "soru_puani": 20, "yonetici": false, "bekleyen": 1,
         "set": {"id": 1, "baslik": "Hafta 45", "tarih": "3 Kasım 2026 – 9 Kasım 2026", "bitis": "9 Kasım 2026", "acik": true, "arsiv": false},
         "sorular": [
           {"id": 1, "no": 1, "soru": "S1", "siklar": [{"k": "a", "harf": "A", "metin": "2"}, {"k": "b", "harf": "B", "metin": "4"}],
            "kilitli": true, "cevap": {"secilen": "a", "dogru_mu": false}, "dogru": "b", "dogru_harf": "B", "aciklama": "Açıklama", "kaynak": null},
           {"id": 2, "no": 2, "soru": "S2", "siklar": [{"k": "a", "harf": "A", "metin": "x"}], "kilitli": false, "cevap": null}
         ],
         "ozet": {"toplam": 2, "cevap": 1, "dogru": 0, "puan": 0, "tam_puan": 40, "tamamlandi": false, "siram": 0},
         "siralama": {"hafta": {"liste": [{"sira": 1, "ad": "A. Yılmaz", "puan": 20, "ben": false}], "siram": 0, "katilimci": 1},
                      "genel": {"liste": [], "siram": 0, "katilimci": 0}},
         "gecmis": [{"id": 2, "baslik": "Hafta 44", "tarih": "27 Ekim 2026 – 2 Kasım 2026", "katildi": true, "puan": 20}]}
        """#)
        let veri = try JSONEncoder().encode(j)
        let c = JSONDecoder()
        c.keyDecodingStrategy = .convertFromSnakeCase
        let v = try c.decode(BilgiVerisi.self, from: veri)
        XCTAssertEqual(v.soruPuani, 20)
        XCTAssertEqual(v.bekleyen, 1)
        XCTAssertEqual(v.set?.acik, true)
        XCTAssertEqual(v.sorular.count, 2)
        XCTAssertEqual(v.sorular[0].cevap?.dogruMu, false)
        XCTAssertEqual(v.sorular[0].dogruHarf, "B")
        XCTAssertNil(v.sorular[0].kaynak)
        XCTAssertNil(v.sorular[1].dogru)
        XCTAssertEqual(v.ozet.tamPuan, 40)
        XCTAssertEqual(v.siralama.hafta?.liste.first?.ad, "A. Yılmaz")
        XCTAssertEqual(v.gecmis.first?.katildi, true)
    }

    /// Yönetim listesi: admin/index.php sıralaması ve arama.
    func testYonetimSiralamaVeArama() throws {
        let j = try satir(#"""
        {"toplam": 4, "bekleyen": 1, "kullanicilar": [
          {"id": 1, "kullanici_adi": "zeki", "ad": "Zeki Kaya", "eposta": "z@a.com", "rol": "admin", "aktif": true, "durum": "approved", "yeni": false, "son_giris": "05.11.2026 20:08", "son_giris_ts": 200, "giris_sayisi": 11, "ben": true},
          {"id": 2, "kullanici_adi": "ali", "ad": "Ali Şahin", "eposta": "a@a.com", "rol": "personel", "aktif": true, "durum": "approved", "yeni": true, "son_giris": null, "son_giris_ts": 0, "giris_sayisi": 0, "ben": false},
          {"id": 3, "kullanici_adi": "bekleyen", "ad": "", "eposta": "b@a.com", "rol": "personel", "aktif": false, "durum": "pending", "yeni": false, "son_giris": null, "son_giris_ts": 0, "giris_sayisi": 0, "ben": false},
          {"id": 4, "kullanici_adi": "red", "ad": "", "eposta": "", "rol": "personel", "aktif": false, "durum": "rejected", "yeni": false, "son_giris": "01.11.2026 10:00", "son_giris_ts": 100, "giris_sayisi": 2, "ben": false}
        ]}
        """#)
        let veri = try JSONEncoder().encode(j)
        let c = JSONDecoder()
        c.keyDecodingStrategy = .convertFromSnakeCase
        let v = try c.decode(YonetimVerisi.self, from: veri)
        XCTAssertEqual(v.kullanicilar.first?.girisSayisi, 11)
        XCTAssertEqual(YonetimKurallari.sirala(v.kullanicilar, "yeni").map { $0.id }, [3, 2, 1, 4])
        XCTAssertEqual(YonetimKurallari.sirala(v.kullanicilar, "giris").map { $0.id }, [3, 1, 2, 4])
        XCTAssertEqual(YonetimKurallari.sirala(v.kullanicilar, "ad").map { $0.id }, [3, 2, 1, 4])
        XCTAssertEqual(YonetimKurallari.ara(v.kullanicilar, "şahin").map { $0.id }, [2])
        XCTAssertEqual(YonetimKurallari.ara(v.kullanicilar, "B@A").map { $0.id }, [3])
        XCTAssertEqual(v.kullanicilar[1].basHarf, "A")
    }

    /// Yakında eklenecekler: iPhone uygulamasını duyuran madde iPhone'da gizlenir.
    func testYakindaFiltre() throws {
        let j = try satir(#"""
        {"baslik": "Yakında eklenecek özellikler", "aciklama": "a", "etiket": "Yol haritası", "not": "n",
         "maddeler": [
           {"baslik": "iPhone (iOS) uygulaması", "durum": "Yakında", "durum_turu": "next", "metin": "x", "renk": "navy"},
           {"baslik": "Gece modu", "durum": "Eklendi", "durum_turu": "done", "metin": "y", "renk": "green"}
         ]}
        """#)
        let c = JSONDecoder()
        c.keyDecodingStrategy = .convertFromSnakeCase
        let y = try c.decode(YakindaIcerik.self, from: JSONEncoder().encode(j))
        XCTAssertEqual(y.maddeler.count, 2)
        XCTAssertEqual(y.uygulamaMaddeleri.map { $0.baslik }, ["Gece modu"])
        XCTAssertEqual(y.maddeler[1].durumTuru, "done")
    }

    /// Yönetim > Haftanın soruları: set ayrıntısı çözümü (boş şıklar gizlenir, boş cevap hücresi olur).
    func testSoruSetiAyrintisiCozumleme() throws {
        let j = try satir(#"""
        {"ok": true, "personel_sayisi": 5,
         "set": {"id": 1, "baslik": "Hafta 45", "baslangic": "2026-11-03", "bitis": "2026-11-09", "tarih": "3 Kasım 2026 – 9 Kasım 2026",
                 "aktif": true, "durum": "Yayında", "durum_turu": "yayinda", "duyuruldu": null},
         "sorular": [{"id": 1, "no": 1, "sira": 1, "soru": "S?", "sik_a": "2", "sik_b": "4", "sik_c": "", "sik_d": "",
                      "dogru": "a", "aciklama": "", "kaynak": "6/2", "cevap_sayisi": 2,
                      "dagilim": {"a": 1, "b": 1, "c": 0, "d": 0}, "dagilim_toplam": 2, "dogru_orani": 50}],
         "katilimci": 1,
         "kisiler": [{"ad": "Ali", "kullanici_adi": "ali", "admin": false, "dogru": 0, "son": "5 Kasım 2026 19:30",
                      "cevaplar": [{"secilen": "B", "dogru_mu": false}, null]}],
         "katilmayanlar": [{"ad": "Veli", "kullanici_adi": "veli", "son_giris": null}]}
        """#)
        let c = JSONDecoder()
        c.keyDecodingStrategy = .convertFromSnakeCase
        let v = try c.decode(SoruSetiAyrintisi.self, from: JSONEncoder().encode(j))
        XCTAssertTrue(v.yayinda)
        XCTAssertEqual(v.sorular[0].siklar.map { $0.harf }, ["A", "B"])
        XCTAssertEqual(v.sorular[0].dogruOrani, 50)
        XCTAssertEqual(v.kisiler[0].cevaplar.count, 2)
        XCTAssertNil(v.kisiler[0].cevaplar[1])
        XCTAssertEqual(v.katilmayanlar[0].kullaniciAdi, "veli")
        XCTAssertEqual(GunBicimi.metin(GunBicimi.tarih("2026-11-03")), "2026-11-03")
    }

    /// Yönetim > Tür kartları: liste çözümü ve arama.
    func testTurYonetimiCozumlemeVeArama() throws {
        let j = try satir(#"""
        {"ok": true, "fotosuz": 1, "gruplar": ["Balık", "Kabuklu", "Yumuşakça", "İçsu", "Diğer"],
         "kaynak_onerileri": [{"ad": "6/1 Ticari Tebliğ (2024/20)", "url": "https://resmigazete.gov.tr/eskiler/2024/08/20240811-3.htm"}],
         "turler": [
           {"id": 55, "ad": "Ahtapot", "diger_adlar": "", "bilimsel_ad": "Octopus vulgaris", "grup": "Yumuşakça", "foto_url": null,
            "foto_kredi": "", "boy_ticari": "750 g", "boy_amator": "750 g", "yasak_donemi": "", "notlar": "", "kaynak": "", "kaynak_url": "", "aktif": true},
           {"id": 7, "ad": "Hamsi", "diger_adlar": "Hamsi balığı", "bilimsel_ad": "Engraulis encrasicolus", "grup": "Balık", "foto_url": "https://x/a.jpg",
            "foto_kredi": "A · CC BY", "boy_ticari": "9 cm", "boy_amator": "9 cm", "yasak_donemi": "", "notlar": "", "kaynak": "", "kaynak_url": "", "aktif": false}
         ]}
        """#)
        let c = JSONDecoder()
        c.keyDecodingStrategy = .convertFromSnakeCase
        let v = try c.decode(TurYonetimVerisi.self, from: JSONEncoder().encode(j))
        XCTAssertEqual(v.turler.count, 2)
        XCTAssertNil(v.turler[0].fotoUrl)
        XCTAssertEqual(v.turler[1].aktif, false)
        XCTAssertEqual(v.kaynakOnerileri.first?.ad, "6/1 Ticari Tebliğ (2024/20)")
        XCTAssertEqual(TurYonetimKurallari.ara(v.turler, "engraulis").map { $0.id }, [7])
        XCTAssertEqual(TurYonetimKurallari.ara(v.turler, "yumusakca").map { $0.id }, [55])
    }

    /// Yönetim > Yenilikler: liste çözümü.
    func testYenilikYonetimiCozumleme() throws {
        let j = try satir(#"""
        {"ok": true, "bugun": "2026-11-06", "kategoriler": ["Mevzuat", "Yeni özellik", "Düzeltme", "Duyuru"],
         "kayitlar": [{"id": 10, "baslik": "B", "aciklama": "- a", "kategori": "Duyuru", "tarih": "2026-11-01",
                       "tarih_yazi": "1 Kasım 2026", "link": "oneri.php", "aktif": true, "durum": "Yayında",
                       "durum_turu": "yayinda", "bildirim": null}]}
        """#)
        let c = JSONDecoder()
        c.keyDecodingStrategy = .convertFromSnakeCase
        let v = try c.decode(YenilikYonetimVerisi.self, from: JSONEncoder().encode(j))
        XCTAssertEqual(v.kategoriler.count, 4)
        XCTAssertEqual(v.kayitlar[0].tarihYazi, "1 Kasım 2026")
        XCTAssertEqual(v.kayitlar[0].durumTuru, "yayinda")
        XCTAssertNil(v.kayitlar[0].bildirim)
    }
}
