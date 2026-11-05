import Foundation

// Sunucudaki tabloların uygulamadaki karşılıkları.
// Her model, sunucudan gelen satırdan (Satir) oluşturulur; eksik alanlar boş kalır, uygulama çökmez.

struct Mevzuat: Identifiable, Hashable {
    let id: Int
    let ad: String
    let tur: String?
    let rgTarihi: String?
    let rgSayisi: String?
    let kaynakURL: URL?
    let aciklama: String?

    init(_ s: Satir) {
        id = s.tamsayi("id")
        ad = s.metin("mevzuat_adi")
        tur = s.secimli("mevzuat_turu")
        rgTarihi = s.secimli("resmi_gazete_tarihi")
        rgSayisi = s.secimli("resmi_gazete_sayisi")
        kaynakURL = Baglanti.url(s.secimli("kaynak_url"))
        aciklama = s.secimli("aciklama")
    }
}

struct Madde: Identifiable, Hashable {
    let id: Int
    let mevzuatId: Int
    let no: String
    let baslik: String?
    let metin: String
    let mevzuatAdi: String?
    let kaynakURL: URL?
    let arama: String

    init(_ s: Satir, mevzuatlar: [Int: Mevzuat]) {
        id = s.tamsayi("id")
        mevzuatId = s.tamsayi("mevzuat_id")
        no = s.metin("madde_no")
        baslik = s.secimli("madde_basligi")
        metin = s.metin("madde_metni")
        let m = mevzuatlar[mevzuatId]
        mevzuatAdi = m?.ad
        kaynakURL = m?.kaynakURL
        arama = Metin.katla(Metin.birlestir([baslik, metin, mevzuatAdi]))
    }

    var gorunenBaslik: String { baslik ?? no }
}

struct Ihlal: Identifiable, Hashable {
    let id: Int
    let kategori: String?
    let ad: String
    let aciklama: String?
    let arama: String

    init(_ s: Satir) {
        id = s.tamsayi("id")
        kategori = s.secimli("kategori")
        ad = s.metin("ihlal_adi")
        aciklama = s.secimli("aciklama")
        arama = Metin.katla(Metin.birlestir([ad, aciklama, kategori]))
    }
}

struct Fiil: Identifiable, Hashable {
    let id: Int
    let fiil: String
    let mevzuat: String
    let madde: String?
    let bent: String?
    let aciklama: String?
    let kapsam: String?
    let dogrulama: String?
    let notlar: String?
    let kaynak: String?
    let arama: String

    init(_ s: Satir) {
        id = s.tamsayi("id")
        fiil = s.metin("fiil")
        mevzuat = s.metin("mevzuat")
        madde = s.secimli("madde")
        bent = s.secimli("bent")
        aciklama = s.secimli("aciklama")
        kapsam = s.secimli("kapsam")
        dogrulama = s.secimli("dogrulama")
        notlar = s.secimli("notlar")
        kaynak = s.secimli("kaynak")
        arama = Metin.katla(Metin.birlestir([fiil, aciklama, kapsam]))
    }

    /// "6/2 Tebliğ (2024/21) · Madde 16/2-b"
    var dayanak: String {
        var parca = mevzuat
        if let m = madde {
            parca += " · Madde " + m
            if let b = bent { parca += "/" + b }
        }
        return parca
    }
}

struct SevkKaydi: Identifiable {
    let id: Int
    let kategori: String
    let yasalMadde: String
    let gerekce: String
    let sevkMakami: String?
    let kontrolDurumu: String
    let kontrolNotu: String
    let islemler: [String]
    let yaptirimlar: [String]
    let dayanaklar: [String]
    let kaynaklar: [String]
    let notlar: [String]
    /// sevk_islemleri.php AramaMetni (normalize edilmiş)
    let aramaNormal: String

    init(_ s: Satir) {
        id = s.tamsayi("id")
        kategori = s.metin("kategori")
        yasalMadde = s.metin("yasal_islem_maddesi")
        gerekce = s.metin("gerekce")
        sevkMakami = s.secimli("sevk_makami")
        kontrolDurumu = s.metin("kontrol_durumu")
        kontrolNotu = s.metin("kontrol_notu")
        islemler = s.liste("zengin_islemler")
        yaptirimlar = s.liste("zengin_yaptirimlar")
        dayanaklar = s.liste("zengin_dayanaklar")
        kaynaklar = s.liste("zengin_kaynaklar")
        notlar = s.liste("zengin_notlar")
        let parcalar: [String] = [
            kategori, yasalMadde, gerekce, sevkMakami ?? "", kontrolDurumu, kontrolNotu,
            islemler.joined(separator: " | "), yaptirimlar.joined(separator: " | "),
            dayanaklar.joined(separator: " | "), kaynaklar.joined(separator: " | "),
            notlar.joined(separator: " | "),
        ]
        let aramaMetni = parcalar.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: " | ")
        aramaNormal = TRMetin.buyukHarf(aramaMetni)
    }

    /// statusType: 🟢 yeşil, 🔴 kırmızı, diğerleri sarı.
    var durum: String {
        let s = kontrolDurumu.uppercased()
        if s.contains("🟢") { return "green" }
        if s.contains("🔴") { return "red" }
        return "yellow"
    }

    /// Yasal madde + ek dayanaklar (tekrarsız).
    var tumDayanaklar: [String] {
        var liste: [String] = []
        if !yasalMadde.isEmpty { liste.append(yasalMadde) }
        for d in dayanaklar {
            let t = d.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty && !liste.contains(where: { TRMetin.buyukHarf($0) == TRMetin.buyukHarf(t) }) {
                liste.append(t)
            }
        }
        return liste
    }

    /// Mevzuat aramasına giden kayıt (mevzuat.php 2b bölümü).
    var aramaKaydi: AramaKaydi {
        var dayanak: [String] = []
        var gorulen = Set<String>()
        for d in [yasalMadde] + dayanaklar {
            let t = d.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { continue }
            let n = TRMetin.normal(t)
            if gorulen.contains(n) { continue }
            gorulen.insert(n)
            dayanak.append(t)
        }
        return AramaKaydi(kaynak: .sevk, id: "s\(id)", fiil: gerekce,
                          mevzuat: yasalMadde.isEmpty ? (dayanak.first ?? "") : yasalMadde,
                          etiket: kategori, dayanaklar: dayanak)
    }
}

struct Yaptirim: Identifiable, Hashable {
    let id: Int
    let yil: Int
    let olayTuru: String
    let nitelik: String
    let kanunMaddesi: String?
    let yonetmelikMaddesi: String?
    let tebligMaddesi: String?
    let cezaMaddesi: String?
    let miktar: Double?
    let enAz: Double?
    let enCok: Double?
    let hesaplamaTipi: String?
    let kaynakMetni: String?
    let suUrunuElKoyma: String?
    let vasitaElKoyma: String?
    let notlar: String?
    let arama: String
    let aramaSite: String

    init(_ s: Satir) {
        id = s.tamsayi("id")
        yil = s.tamsayi("yil")
        olayTuru = s.metin("olay_turu")
        nitelik = s.metin("kabahatin_niteligi")
        kanunMaddesi = s.secimli("kanun_maddesi")
        yonetmelikMaddesi = s.secimli("yonetmelik_maddesi")
        tebligMaddesi = s.secimli("teblig_maddesi")
        cezaMaddesi = s.secimli("ceza_maddesi")
        miktar = s.ondalik("ipc_miktari")
        enAz = s.ondalik("ipc_min_tutar")
        enCok = s.ondalik("ipc_max_tutar")
        hesaplamaTipi = s.secimli("ipc_hesaplama_tipi")
        kaynakMetni = s.secimli("ipc_kaynak_metni")
        suUrunuElKoyma = s.secimli("su_urunlerine_el_koyma")
        vasitaElKoyma = s.secimli("istihsal_vasitasina_el_koyma")
        notlar = s.secimli("notlar")
        arama = Metin.katla(Metin.birlestir([nitelik, olayTuru, kanunMaddesi, cezaMaddesi, tebligMaddesi]))
        // idari_yaptirim.php: her kelime bu alanlardan herhangi birinde geçmeli (LIKE).
        let alanlar: [String?] = [olayTuru, nitelik, kanunMaddesi, yonetmelikMaddesi, tebligMaddesi, cezaMaddesi,
                                  kaynakMetni, suUrunuElKoyma, vasitaElKoyma, notlar]
        aramaSite = alanlar.map { ($0 ?? "").lowercased(with: TRMetin.tr) }.joined(separator: "\u{1}")
    }

    /// "16.106 TL" veya "9.473 – 47.397 TL"
    var tutarMetni: String? {
        if let a = enAz, let c = enCok, a != c {
            return Para.aralik(a, c)
        }
        if let m = miktar ?? enAz ?? enCok, m > 0 {
            return Para.yaz(m)
        }
        return nil
    }
}

struct Tur: Identifiable, Hashable {
    let id: Int
    let ad: String
    let digerAdlar: String?
    let bilimselAd: String?
    let grup: String
    let fotoURL: URL?
    let fotoKredi: String?
    let fotoKaynakURL: URL?
    let boyTicari: String?
    let boyAmator: String?
    let yasakDonemi: String?
    let notlar: String?
    let kaynak: String?
    let kaynakURL: URL?
    let guncelleme: String?
    let arama: String
    /// turler.php data-ara: "ad diğer_adlar bilimsel_ad" (Türkçe küçük harf)
    let aramaSite: String

    init(_ s: Satir) {
        id = s.tamsayi("id")
        ad = s.metin("ad")
        digerAdlar = s.secimli("diger_adlar")
        bilimselAd = s.secimli("bilimsel_ad")
        grup = s.secimli("grup") ?? "Diğer"
        fotoURL = Baglanti.url(s.secimli("foto_url"))
        fotoKredi = s.secimli("foto_kredi")
        fotoKaynakURL = Baglanti.url(s.secimli("foto_kaynak_url"))
        boyTicari = s.secimli("boy_ticari")
        boyAmator = s.secimli("boy_amator")
        yasakDonemi = s.secimli("yasak_donemi")
        notlar = s.secimli("notlar")
        kaynak = s.secimli("kaynak")
        kaynakURL = Baglanti.url(s.secimli("kaynak_url"))
        guncelleme = s.secimli("updated_at")
        arama = Metin.katla(Metin.birlestir([ad, digerAdlar, bilimselAd]))
        let birlesik = ad + " " + (digerAdlar ?? "") + " " + (bilimselAd ?? "")
        aramaSite = birlesik.trimmingCharacters(in: .whitespaces).lowercased(with: TRMetin.tr)
    }

    /// Listede gösterilen kısa bilgi.
    var ozet: String {
        if let y = yasakDonemi { return y }
        if let b = boyTicari { return "Ticari boy: " + b }
        return grup
    }
}

/// bolge_yasaklari.php harita_cizim() sonucu (sunucuda aynı fonksiyonla hesaplanır).
struct BolgeHaritasi: Hashable {
    struct Nokta: Hashable {
        let enlem: Double
        let boylam: Double
        let metin: String
    }

    /// "alan", "hat" veya "nokta"
    let tur: String
    let noktalar: [Nokta]
    let cizim: [Nokta]

    init?(_ deger: JSONDeger?) {
        guard let o = deger?.nesne else { return nil }
        func oku(_ a: JSONDeger) -> Nokta? {
            guard let d = a.dizi, d.count >= 2, let e = d[0].ondalik, let b = d[1].ondalik else { return nil }
            return Nokta(enlem: e, boylam: b, metin: d.count > 2 ? (d[2].metin ?? "") : "")
        }
        tur = o.metin("t")
        noktalar = (o["p"]?.dizi ?? []).compactMap(oku)
        let c = (o["c"]?.dizi ?? []).compactMap(oku)
        cizim = c.isEmpty ? noktalar : c
        if noktalar.isEmpty { return nil }
    }
}

struct Bolge: Identifiable, Hashable {
    let id: Int
    let deniz: String
    let il: String
    let ilce: String?
    let baslik: String
    let aciklama: String?
    let yasakTuru: String?
    let izinliAvAraci: String?
    let mevzuatAdi: String?
    let mevzuatMadde: String?
    let tebligTuru: String?
    let koordinatlar: String?
    let baslangic: String?
    let bitis: String?
    let aktif: Bool
    let harita: BolgeHaritasi?
    /// bolge_yasaklari.php LIKE araması yapılan alanlar (Türkçe küçük harf)
    let aramaSite: String

    init(_ s: Satir) {
        id = s.tamsayi("id")
        deniz = s.metin("deniz")
        il = s.metin("il")
        ilce = s.secimli("ilce")
        baslik = s.metin("baslik")
        aciklama = s.secimli("aciklama")
        yasakTuru = s.secimli("yasak_turu")
        izinliAvAraci = s.secimli("izinli_av_araci")
        mevzuatAdi = s.secimli("mevzuat_adi")
        mevzuatMadde = s.secimli("mevzuat_madde")
        tebligTuru = s.secimli("teblig_turu")
        koordinatlar = s.secimli("koordinatlar")
        baslangic = Bolge.tarihVar(s.secimli("baslangic_tarihi"))
        bitis = Bolge.tarihVar(s.secimli("bitis_tarihi"))
        aktif = s["aktif"] == nil ? true : s.tamsayi("aktif") != 0
        harita = BolgeHaritasi(s["harita"])
        let alanlar: [String?] = [baslik, aciklama, il, ilce, mevzuatAdi, mevzuatMadde]
        aramaSite = alanlar.map { ($0 ?? "").lowercased(with: TRMetin.tr) }.joined(separator: "\u{1}")
    }

    /// "0000-00-00" tarih sayılmaz (tarih_var).
    static func tarihVar(_ s: String?) -> String? {
        guard let t = s?.trimmingCharacters(in: .whitespaces), !t.isEmpty, !t.hasPrefix("0000-00-00") else { return nil }
        return t
    }

    var yer: String {
        return [il, ilce ?? ""].filter { !$0.isEmpty }.joined(separator: " / ")
    }

    enum Durum {
        case aktif, pasif(String)
    }

    /// status(): pasif kayıt, başlangıç bekleniyor, süresi bitmiş, aktif.
    func durum(bugun: String) -> Durum {
        if !aktif { return .pasif("Pasif kayıt") }
        if let b = baslangic, bugun < String(b.prefix(10)) { return .pasif("Başlangıç tarihi bekleniyor") }
        if let b = bitis, bugun > String(b.prefix(10)) { return .pasif("Süresi sona ermiş") }
        return .aktif
    }
}

struct Yenilik: Identifiable, Hashable {
    let id: Int
    let baslik: String
    let aciklama: String
    let kategori: String
    let tarih: String?
    let link: String?
    let olusturma: String?

    init(_ s: Satir) {
        id = s.tamsayi("id")
        baslik = s.metin("baslik")
        aciklama = s.metin("aciklama")
        kategori = s.secimli("kategori") ?? "Duyuru"
        tarih = s.secimli("tarih")
        link = s.secimli("link")
        olusturma = s.secimli("created_at")
    }
}

// MARK: - Tekne / Gemi Kontrolü (tekne.php ve alt sayfaları)

/// Sunucudaki api/tekne.json: sitedeki tekne sayfalarının metinleri birebir.
struct TekneIcerik: Codable {
    let kok: String?
    let sayfalar: [String: TekneSayfa]

    var kokSayfa: String { return kok ?? "tekne" }
}

struct TekneSayfa: Codable {
    let baslik: String
    let aciklama: String?
    let bloklar: [TekneBlok]
}

/// Sayfadaki bir bölüm. "tur": etiket, kartlar, liste, bilgi, dayanak, aciklama, acilir, uyari, not, kaynak, altnot
struct TekneBlok: Codable {
    let tur: String
    let metin: String?
    let sayi: String?
    let baslik: String?
    let kartlar: [TekneKart]?
    let maddeler: [TekneMadde]?
    let simge: String?
    let ozet: String?
    let aciklama: String?
    let mevzuat: String?
    let ad: String?
    let url: String?
    let site: String?
}

struct TekneKart: Codable {
    let baslik: String
    let aciklama: String?
    let hedef: String?
    let yakinda: String?
}

struct TekneMadde: Codable {
    let baslik: String
    let not: String?
    let simge: String?
    let etiket: String?
    let alt: [String]?
}
