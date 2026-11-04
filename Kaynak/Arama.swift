import Foundation

// Sitedeki arama ve eşleştirme kurallarının birebir karşılığı:
// - mevzuat.php  → MevzuatAramaMotoru (normal, eslesir, skor, sıralama)
// - assets/kaynaklar.js → KaynakListesi.bul (resmî kaynak eşleştirme)
// - sevk_islemleri.php → TRMetin.buyukHarf + kelimeEslesir

enum TRMetin {
    static let tr = Locale(identifier: "tr_TR")

    /// mevzuat.php $normalize: Türkçe kurallarla küçük harf, boşluklar teklenir.
    static func normal(_ s: String) -> String {
        let kucuk = s.lowercased(with: tr)
        return kucuk.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static func harfVeyaRakam(_ u: Unicode.Scalar) -> Bool {
        switch u.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .decimalNumber, .letterNumber, .otherNumber:
            return true
        default:
            return false
        }
    }

    /// preg_split('/[^\p{L}\p{N}]+/u', ...)
    static func kelimeler(_ s: String) -> [String] {
        var sonuc: [String] = []
        var mevcut = String.UnicodeScalarView()
        for u in s.unicodeScalars {
            if harfVeyaRakam(u) {
                mevcut.append(u)
            } else if !mevcut.isEmpty {
                sonuc.append(String(mevcut))
                mevcut = String.UnicodeScalarView()
            }
        }
        if !mevcut.isEmpty {
            sonuc.append(String(mevcut))
        }
        return sonuc
    }

    static func basliyor(_ metin: String, _ onek: String) -> Bool {
        return metin.unicodeScalars.starts(with: onek.unicodeScalars)
    }

    static func iceriyor(_ metin: String, _ parca: String) -> Bool {
        if parca.isEmpty { return true }
        return metin.range(of: parca, options: .literal) != nil
    }

    static func uzunluk(_ s: String) -> Int {
        return s.unicodeScalars.count
    }

    /// U+0300–U+036F birleşik işaretlerini siler (JS: normalize('NFD').replace(/[̀-ͯ]/g,'')).
    static func isaretleriSil(_ s: String) -> String {
        var v = String.UnicodeScalarView()
        for u in s.decomposedStringWithCanonicalMapping.unicodeScalars where !(0x300...0x36F).contains(u.value) {
            v.append(u)
        }
        return String(v)
    }

    /// JS buyukHarf / sevk normalize: Türkçe harfler sadeleşir, BÜYÜK harf.
    static func buyukHarf(_ s: String) -> String {
        var t = s
        let degisim: [(String, String)] = [("İ", "I"), ("ı", "i"), ("Ş", "S"), ("ş", "s"), ("Ğ", "G"), ("ğ", "g"),
                                            ("Ü", "U"), ("ü", "u"), ("Ö", "O"), ("ö", "o"), ("Ç", "C"), ("ç", "c")]
        for (a, b) in degisim {
            t = t.replacingOccurrences(of: a, with: b)
        }
        return isaretleriSil(t).uppercased()
    }

    /// sevk_islemleri.php wordMatch: sorgudaki her parça metinde geçmeli.
    static func kelimeEslesir(normalMetin: String, sorgu: String) -> Bool {
        let q = buyukHarf(sorgu).trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return true }
        let parcalar = q.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        for p in parcalar where !normalMetin.contains(p) {
            return false
        }
        return true
    }

    /// PHP strcasecmp (yalnızca ASCII harfler küçültülür, bayt bayt karşılaştırma).
    static func strcasecmp(_ a: String, _ b: String) -> Int {
        let x = Array(a.utf8)
        let y = Array(b.utf8)
        func kucuk(_ c: UInt8) -> UInt8 { return (c >= 65 && c <= 90) ? c + 32 : c }
        let n = min(x.count, y.count)
        var i = 0
        while i < n {
            let c1 = kucuk(x[i])
            let c2 = kucuk(y[i])
            if c1 != c2 { return Int(c1) - Int(c2) }
            i += 1
        }
        return x.count - y.count
    }

    static func ilkGrup(_ desen: String, _ metin: String) -> String? {
        guard let r = try? NSRegularExpression(pattern: desen, options: []) else { return nil }
        let aralik = NSRange(metin.startIndex..<metin.endIndex, in: metin)
        guard let m = r.firstMatch(in: metin, options: [], range: aralik), m.numberOfRanges > 1,
              let g = Range(m.range(at: 1), in: metin) else { return nil }
        return String(metin[g])
    }

    static func eslesirMi(_ desen: String, _ metin: String, buyukKucukDuyarsiz: Bool = false) -> Bool {
        guard let r = try? NSRegularExpression(pattern: desen, options: buyukKucukDuyarsiz ? [.caseInsensitive] : []) else {
            return false
        }
        let aralik = NSRange(metin.startIndex..<metin.endIndex, in: metin)
        return r.firstMatch(in: metin, options: [], range: aralik) != nil
    }
}

/// Mevzuat aramasındaki tek bir sonuç (mevzuat.php'nin döndürdüğü satır).
struct AramaKaydi: Identifiable {
    enum Kaynak { case eski, v5, sevk }

    let kaynak: Kaynak
    let id: String
    let fiil: String
    let mevzuat: String
    let madde: String
    let bent: String
    let aciklama: String
    let kapsam: String
    let kaynakMetni: String
    let etiket: String
    let dayanaklar: [String]
    let fiilNormal: String
    let fiilKelimeleri: [String]

    init(kaynak: Kaynak, id: String, fiil: String, mevzuat: String, madde: String = "", bent: String = "",
         aciklama: String = "", kapsam: String = "", kaynakMetni: String = "", etiket: String = "",
         dayanaklar: [String] = []) {
        self.kaynak = kaynak
        self.id = id
        self.fiil = fiil
        self.mevzuat = mevzuat
        self.madde = madde
        self.bent = bent
        self.aciklama = aciklama
        self.kapsam = kapsam
        self.kaynakMetni = kaynakMetni
        self.etiket = etiket
        self.dayanaklar = dayanaklar
        let n = TRMetin.normal(fiil)
        self.fiilNormal = n
        self.fiilKelimeleri = TRMetin.kelimeler(n)
    }

    var sevkMi: Bool { return kaynak == .sevk }
}

/// Eski kayıtlar: mevzuat_maddeleri ⟕ ihlal_mevzuat ⟕ ihlaller satırı.
struct EskiAday {
    let ihlalNormal: String?
    let baslikNormal: String?
    let kayit: AramaKaydi
}

/// mevzuat.php'deki arama motorunun telefondaki karşılığı.
struct MevzuatAramaMotoru {
    let eski: [EskiAday]
    let v5: [AramaKaydi]
    let sevk: [AramaKaydi]

    static let bos = MevzuatAramaMotoru(eski: [], v5: [], sevk: [])

    private static let yumusama: [Unicode.Scalar: Unicode.Scalar] = ["k": "ğ", "p": "b", "t": "d", "ç": "c"]

    /// $matchesQuery
    static func eslesir(kelimeler words: [String], sorgu q: String, parcalar tokens: [String]) -> Bool {
        if q.isEmpty || tokens.isEmpty || words.isEmpty { return false }

        if tokens.count == 1 && TRMetin.uzunluk(q) <= 3 {
            for w in words where w == q { return true }
            for w in words where TRMetin.basliyor(w, q) { return true }
            return false
        }

        for token in tokens {
            var bulundu = false
            let uzunluk = TRMetin.uzunluk(token)
            var yumusak: String? = nil
            if uzunluk >= 3, let son = token.unicodeScalars.last, let y = yumusama[son] {
                var govde = token.unicodeScalars
                govde.removeLast()
                govde.append(y)
                yumusak = String(govde)
            }
            for w in words {
                if w == token || TRMetin.basliyor(w, token) {
                    bulundu = true
                    break
                }
                if let y = yumusak, TRMetin.basliyor(w, y) {
                    bulundu = true
                    break
                }
                if uzunluk >= 4 && TRMetin.iceriyor(w, token) {
                    bulundu = true
                    break
                }
            }
            if !bulundu { return false }
        }
        return true
    }

    func ara(_ hamSorgu: String) -> [AramaKaydi] {
        let q = hamSorgu.trimmingCharacters(in: .whitespacesAndNewlines)
        if TRMetin.uzunluk(q) < 2 { return [] }
        let qNorm = TRMetin.normal(q)
        let tokens = qNorm.split(separator: " ").map(String.init)

        // 1) Eski kayıtlar: ihlal adı veya madde başlığında geçen (LIKE), en çok 150 satır
        var varyantlar = [qNorm]
        if let son = qNorm.unicodeScalars.last, let y = MevzuatAramaMotoru.yumusama[son] {
            var govde = qNorm.unicodeScalars
            govde.removeLast()
            govde.append(y)
            let v = String(govde)
            if !v.isEmpty && !varyantlar.contains(v) { varyantlar.append(v) }
        }
        var satirlar: [AramaKaydi] = []
        var eskiSayi = 0
        for aday in eski {
            if eskiSayi >= 150 { break }
            var uygun = false
            for v in varyantlar {
                if let i = aday.ihlalNormal, TRMetin.iceriyor(i, v) { uygun = true; break }
                if let b = aday.baslikNormal, TRMetin.iceriyor(b, v) { uygun = true; break }
            }
            if uygun {
                eskiSayi += 1
                if !aday.kayit.fiil.isEmpty { satirlar.append(aday.kayit) }
            }
        }

        // 2) V5 havuzu (hepsi aday), 2b) sevk kayıtları
        satirlar.append(contentsOf: v5)
        satirlar.append(contentsOf: sevk)

        // 3) Fiil eşleşme filtresi
        satirlar = satirlar.filter {
            !$0.fiil.isEmpty && MevzuatAramaMotoru.eslesir(kelimeler: $0.fiilKelimeleri, sorgu: qNorm, parcalar: tokens)
        }

        // 4) Tekrarları ayıkla
        var gorulen = Set<String>()
        var tekil: [AramaKaydi] = []
        for s in satirlar {
            let anahtar = TRMetin.normal(s.fiil + "|" + s.mevzuat + "|" + s.madde + "|" + s.bent)
            if anahtar == "|||" || gorulen.contains(anahtar) { continue }
            gorulen.insert(anahtar)
            tekil.append(s)
        }

        // 5) Sıralama
        let desen = "(^|[^\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: qNorm) + "([^\\p{L}\\p{N}]|$)"
        let kelimeRegex = try? NSRegularExpression(pattern: desen, options: [.caseInsensitive])
        func skor(_ s: AramaKaydi) -> Int {
            let f = s.fiilNormal
            if f == qNorm { return 0 }
            if let r = kelimeRegex,
               r.firstMatch(in: f, options: [], range: NSRange(f.startIndex..<f.endIndex, in: f)) != nil {
                return 1
            }
            if TRMetin.basliyor(f, qNorm) { return 2 }
            return 3
        }
        let puanli = tekil.map { (skor($0), $0) }
        let sirali = puanli.sorted { a, b in
            if a.0 != b.0 { return a.0 < b.0 }
            let ra = a.1.sevkMi ? 1 : 0
            let rb = b.1.sevkMi ? 1 : 0
            if ra != rb { return ra < rb }
            return TRMetin.strcasecmp(a.1.fiil, b.1.fiil) < 0
        }
        return Array(sirali.prefix(60).map { $0.1 })
    }
}

/// mevzuat.php filtre çipleri (Tümü / 6/1 / 6/2 / 1380).
enum AramaFiltresi: String, CaseIterable, Identifiable {
    case tumu = "all"
    case alti1 = "6/1"
    case alti2 = "6/2"
    case kanun1380 = "1380"

    var id: String { return rawValue }

    var baslik: String {
        switch self {
        case .tumu: return "Tümü"
        case .alti1: return "6/1 Tebliğ"
        case .alti2: return "6/2 Tebliğ"
        case .kanun1380: return "1380 Kanun"
        }
    }

    func uygun(_ k: AramaKaydi) -> Bool {
        if self == .tumu { return true }
        let metin = (k.mevzuat + " " + k.kaynakMetni + " " + k.madde + " " + k.etiket + " " + k.dayanaklar.joined(separator: " "))
            .lowercased(with: TRMetin.tr)
        return metin.contains(rawValue)
    }
}

enum AramaGosterim {
    /// lawShort
    static func kanunKisa(_ deger: String) -> String {
        let s = deger.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = s.lowercased(with: TRMetin.tr)
        if l.contains("6/1") { return "6/1 Tebliğ" }
        if l.contains("6/2") { return "6/2 Tebliğ" }
        if l.contains("1380") { return "1380 Kanun" }
        if s.count > 30 { return String(s.prefix(30)) + "…" }
        return s
    }

    /// maddeText: baştaki "Madde"/"md." sözcüğünü atar.
    static func maddeMetni(_ deger: String) -> String {
        let s = deger.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let r = try? NSRegularExpression(pattern: "^(madde|md\\.?)(?![a-zçğıöşü])\\s*", options: [.caseInsensitive]) else {
            return s
        }
        let aralik = NSRange(s.startIndex..<s.endIndex, in: s)
        return r.stringByReplacingMatches(in: s, options: [], range: aralik, withTemplate: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Resmî kaynaklar (assets/kaynaklar.js)

struct ResmiKaynak {
    let ad: String
    let url: URL
    let site: String
    let eslesti: Bool
}

struct KaynakListesi: Codable {
    struct Mevzuat: Codable {
        let anahtar: [String]
        let ad: String
        let url: String
    }

    struct Site: Codable {
        let ad: String
        let url: String
    }

    struct Aciklama: Codable {
        let title: String
        let explain: String
    }

    let mevzuat: [Mevzuat]
    let genel: Site
    let ek: [Site]
    let aciklama1380: [String: Aciklama]
    let genelAciklama: String

    /// Uygulamayla gelen kopya (sunucudan yenisi gelene kadar kullanılır).
    static let gomulu: KaynakListesi = {
        if let url = Bundle.main.url(forResource: "kaynaklar", withExtension: "json"),
           let veri = try? Data(contentsOf: url),
           let liste = try? JSONDecoder().decode(KaynakListesi.self, from: veri) {
            return liste
        }
        return KaynakListesi(mevzuat: [], genel: Site(ad: "Mevzuat Bilgi Sistemi", url: "https://www.mevzuat.gov.tr"),
                             ek: [], aciklama1380: [:], genelAciklama: "")
    }()

    var tumListe: [Site] {
        return mevzuat.map { Site(ad: $0.ad, url: $0.url) } + ek
    }

    /// kaynaklar.js lower()
    static func sade(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "İ", with: "i")
            .replacingOccurrences(of: "I", with: "i")
            .replacingOccurrences(of: "ı", with: "i")
            .lowercased()
        for (a, b) in [("ş", "s"), ("ğ", "g"), ("ü", "u"), ("ö", "o"), ("ç", "c")] {
            t = t.replacingOccurrences(of: a, with: b)
        }
        t = TRMetin.isaretleriSil(t)
        var cikti = String.UnicodeScalarView()
        var bosluk = false
        for u in t.unicodeScalars {
            let izinli = (u >= "a" && u <= "z") || (u >= "0" && u <= "9") || u == "/"
            if izinli {
                cikti.append(u)
                bosluk = false
            } else if !bosluk {
                cikti.append(" ")
                bosluk = true
            }
        }
        return String(cikti).trimmingCharacters(in: .whitespaces)
    }

    static func alanAdi(_ url: String) -> String {
        guard let h = URL(string: url)?.host else { return "" }
        return h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
    }

    private func ara(_ metin: String) -> Mevzuat? {
        if metin.isEmpty { return nil }
        for m in mevzuat {
            for a in m.anahtar where metin.contains(KaynakListesi.sade(a)) {
                return m
            }
        }
        return nil
    }

    private static func guvenliGovUrl(_ s: String) -> URL? {
        guard let u = URL(string: s), u.scheme?.lowercased() == "https",
              let h = u.host?.lowercased(), h.hasSuffix(".gov.tr") else { return nil }
        return u
    }

    /// kaynaklar.js bul(item)
    func bul(mevzuat mevzuatMetni: String, kaynak: String = "", madde: String = "") -> ResmiKaynak {
        let kaynakMetni = kaynak.trimmingCharacters(in: .whitespacesAndNewlines)
        var dogrudan: URL? = nil
        if kaynakMetni.lowercased().hasPrefix("https://") {
            let ilk = kaynakMetni.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
            dogrudan = KaynakListesi.guvenliGovUrl(ilk)
        }
        let bulunan = ara(KaynakListesi.sade(mevzuatMetni)) ?? ara(KaynakListesi.sade(kaynak + " " + madde))

        if let d = dogrudan {
            return ResmiKaynak(ad: bulunan?.ad ?? "Resmî kaynak", url: d, site: KaynakListesi.alanAdi(d.absoluteString), eslesti: true)
        }
        if let b = bulunan, let u = URL(string: b.url) {
            return ResmiKaynak(ad: b.ad, url: u, site: KaynakListesi.alanAdi(b.url), eslesti: true)
        }
        let g = URL(string: genel.url) ?? URL(string: "https://www.mevzuat.gov.tr")!
        return ResmiKaynak(ad: genel.ad, url: g, site: KaynakListesi.alanAdi(genel.url), eslesti: false)
    }

    /// 1380 sayılı Kanunun doğrulanmış maddelerinden biri mi? (mevzuat.php madde1380)
    /// Not: Yalnızca metinde 1380 / Su Ürünleri Kanunu geçiyorsa açıklama verilir.
    func dogrulanmis1380(_ metin: String) -> Aciklama? {
        let s = TRMetin.buyukHarf(metin)
        if !TRMetin.eslesirMi("1380|SU URUNLERI KANUNU", s) { return nil }
        if let ek = TRMetin.ilkGrup("EK\\s*[- ]?\\s*(3|4|5|6|7)\\s*\\.?\\s*MADDE", s) {
            return aciklama1380["EK " + ek]
        }
        if let m = TRMetin.ilkGrup("(?:^|\\s)(3|33|34|35|36)\\s*\\.?\\s*MADDE", s) {
            return aciklama1380[m]
        }
        return nil
    }
}
