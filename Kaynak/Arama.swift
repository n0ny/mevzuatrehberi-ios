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

    /// mevzuat.php $katla: normalize + Türkçe harfler sadeleşir, harf/rakam dışı her şey atılır.
    static func katla(_ s: String) -> String {
        let n = TRMetin.normal(s)
        let degisim: [Character: Character] = ["ı": "i", "ş": "s", "ğ": "g", "ü": "u", "ö": "o", "ç": "c",
                                               "â": "a", "î": "i", "û": "u"]
        var sonuc = ""
        for c in n {
            let h = degisim[c] ?? c
            if let a = h.asciiValue, (a >= 97 && a <= 122) || (a >= 48 && a <= 57) {
                sonuc.append(h)
            }
        }
        return sonuc
    }

    /// mevzuat.php $yaziPuani: Türkçe karakteri doğru yazılmış, tamamı büyük harf fiil tercih edilir.
    static func yaziPuani(_ fiil: String) -> Int {
        var puan = 0
        var kucukVar = false
        for u in fiil.unicodeScalars {
            if "çğıöşüÇĞİÖŞÜ".unicodeScalars.contains(u) { puan += 1 }
            if u.properties.generalCategory == .lowercaseLetter { kucukVar = true }
        }
        return kucukVar ? puan - 100 : puan
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

        // 4) Tekrarları ayıkla: aynı fiil + aynı dayanak tek kart (Türkçe karakter, büyük-küçük harf,
        //    boşluk ve noktalama farkı yok sayılır). Birleşen sevk kayıtlarının dayanakları tekrarsız toplanır.
        var gorulen: [String: Int] = [:]
        var tekil: [AramaKaydi] = []
        for s in satirlar {
            let anahtar = MevzuatAramaMotoru.katla(s.fiil) + "|" + MevzuatAramaMotoru.katla(s.mevzuat) + "|"
                + MevzuatAramaMotoru.katla(s.madde) + "|" + MevzuatAramaMotoru.katla(s.bent)
            if anahtar == "|||" { continue }
            if let i = gorulen[anahtar] {
                if tekil[i].sevkMi && s.sevkMi {
                    var liste = tekil[i].dayanaklar
                    var var_ = Set(liste.map { TRMetin.normal($0) })
                    for d in s.dayanaklar {
                        let n = TRMetin.normal(d)
                        if n.isEmpty || var_.contains(n) { continue }
                        var_.insert(n)
                        liste.append(d)
                    }
                    let fiil = MevzuatAramaMotoru.yaziPuani(s.fiil) > MevzuatAramaMotoru.yaziPuani(tekil[i].fiil)
                        ? s.fiil : tekil[i].fiil
                    let e = tekil[i]
                    tekil[i] = AramaKaydi(kaynak: e.kaynak, id: e.id, fiil: fiil, mevzuat: e.mevzuat, madde: e.madde,
                                          bent: e.bent, aciklama: e.aciklama, kapsam: e.kapsam,
                                          kaynakMetni: e.kaynakMetni, etiket: e.etiket, dayanaklar: liste)
                }
                continue
            }
            gorulen[anahtar] = tekil.count
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
    /// 36. maddenin bentleri → hangi maddenin yaptırımı (sunucuda yoksa uygulamadaki kopya).
    let bent36: [String: String]?
    let genelAciklama: String
    let yaptirim: YaptirimAyari?

    /// Uygulamayla gelen kopya (sunucudan yenisi gelene kadar kullanılır).
    static let gomulu: KaynakListesi = {
        if let url = Bundle.main.url(forResource: "kaynaklar", withExtension: "json"),
           let veri = try? Data(contentsOf: url),
           let liste = try? JSONDecoder().decode(KaynakListesi.self, from: veri) {
            return liste
        }
        return KaynakListesi(mevzuat: [], genel: Site(ad: "Mevzuat Bilgi Sistemi", url: "https://www.mevzuat.gov.tr"),
                             ek: [], aciklama1380: [:], bent36: nil, genelAciklama: "", yaptirim: nil)
    }()

    /// İdari yaptırım sayfasının ayarları (sunucudan gelmediyse uygulamadaki kopya).
    var yaptirimAyari: YaptirimAyari {
        return yaptirim ?? KaynakListesi.gomulu.yaptirim ?? YaptirimAyari.bos
    }

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

    // MARK: 1380 madde açıklamaları (mevzuat.php / sevk_islemleri.php ile birebir)

    static let kanun1380 = "1380 sayılı Su Ürünleri Kanunu"

    /// Dayanaktan çözülen 1380 maddesi (madde: "23", "EK 5"; fıkra: "2"; bent: "b").
    struct Madde1380: Equatable {
        let madde: String
        let fikra: String
        let bent: String

        /// etiket1380: "Madde 23/1-b", "Madde 3/2", "Ek Madde 5"
        var etiket: String {
            if madde.hasPrefix("EK ") { return "Ek Madde " + String(madde.dropFirst(3)) }
            var t = "Madde " + madde
            if !fikra.isEmpty || !bent.isEmpty { t += "/" + (fikra.isEmpty ? "1" : fikra) }
            if !bent.isEmpty { t += "-" + bent }
            return t
        }
    }

    /// Kartta gösterilecek tek dayanak bloğu.
    struct DayanakGosterimi {
        let baslik: String
        let aciklama: String
        let kaynakMetni: String
    }

    private static func gruplar(_ desen: String, _ metin: String, buyukKucukDuyarsiz: Bool = false) -> [String]? {
        guard let r = try? NSRegularExpression(pattern: desen, options: buyukKucukDuyarsiz ? [.caseInsensitive] : []) else {
            return nil
        }
        let aralik = NSRange(metin.startIndex..<metin.endIndex, in: metin)
        guard let m = r.firstMatch(in: metin, options: [], range: aralik) else { return nil }
        var sonuc: [String] = []
        for i in 0..<m.numberOfRanges {
            if let g = Range(m.range(at: i), in: metin) { sonuc.append(String(metin[g])) } else { sonuc.append("") }
        }
        return sonuc
    }

    /// yasal1380Coz: "1380 Su Ürünleri Kanunu-01 Ocak 2020 23.MADDE - 1 FIKRASI - b BENDİ" gibi yazımlar.
    static func yasal1380Coz(_ metin: String) -> Madde1380? {
        let s = TRMetin.buyukHarf(metin)
        if !TRMetin.eslesirMi("1380|SU URUNLERI KANUNU", s) { return nil }
        if let ek = TRMetin.ilkGrup("EK\\s*[- ]?\\s*(\\d+)\\s*\\.?\\s*MADDE", s) {
            return Madde1380(madde: "EK " + ek, fikra: "", bent: "")
        }
        guard let r = gruplar("(?:^|[^\\d])(\\d{1,2})\\s*\\.\\s*MADDE(?:\\s*-\\s*\\(?([0-9A-Z])\\)?\\s*FIKRASI)?(?:\\s*-\\s*\\(?([0-9A-Z])\\)?\\s*BENDI)?", s),
              r.count >= 4 else { return nil }
        var fikra = r[2]
        var bent = r[3]
        if TRMetin.eslesirMi("[A-Z]", fikra) { bent = fikra; fikra = "" }   // "a FIKRASI" aslında bent
        if TRMetin.eslesirMi("\\d", bent) { bent = "" }                     // 36/a içindeki paragraf numarası
        return Madde1380(madde: r[1], fikra: fikra, bent: bent.lowercased())
    }

    /// zengin1380Coz: "1380 m.23/1-a-b + … → 36/1-k", "1380 Ek m.5 + 6/1 m.46 …"
    /// Yalnızca "1380" geçen parçalar okunur; 6/1, 6/2 ve 36 (ceza) parçaları atlanır.
    static func zengin1380Coz(_ metin: String) -> [Madde1380] {
        var sonuc: [Madde1380] = []
        var bolunmus = metin
        if let r = try? NSRegularExpression(pattern: "[+;→,]|\\bveya\\b", options: []) {
            let aralik = NSRange(metin.startIndex..<metin.endIndex, in: metin)
            bolunmus = r.stringByReplacingMatches(in: metin, options: [], range: aralik, withTemplate: "\u{1}")
        }
        for parca in bolunmus.components(separatedBy: "\u{1}") {
            if !parca.contains("1380") { continue }
            if let ek = gruplar("1380\\s+Ek\\s*m\\.?\\s*(\\d+)", parca, buyukKucukDuyarsiz: true), ek.count >= 2 {
                sonuc.append(Madde1380(madde: "EK " + ek[1], fikra: "", bent: ""))
                continue
            }
            guard let r = gruplar("1380\\s+m\\.?\\s*(\\d+)(?:/(\\d+))?(?:-([a-z](?:-[a-z])*))?", parca, buyukKucukDuyarsiz: true),
                  r.count >= 4, r[1] != "36" else { continue }
            let bentler = r[3].split(separator: "-").map(String.init).filter { !$0.isEmpty }
            sonuc.append(Madde1380(madde: r[1], fikra: r[2], bent: bentler.count == 1 ? bentler[0].lowercased() : ""))
        }
        return sonuc
    }

    private func metin1380(_ anahtar: String) -> String? {
        if let a = aciklama1380[anahtar]?.explain, !a.isEmpty { return a }
        if let a = KaynakListesi.gomulu.aciklama1380[anahtar]?.explain, !a.isEmpty { return a }
        return nil
    }

    /// aciklama1380
    func aciklama(_ k: Madde1380) -> String {
        if k.madde == "36", !k.bent.isEmpty,
           let b = bent36?[k.bent] ?? KaynakListesi.gomulu.bent36?[k.bent] {
            return "36. maddenin (" + k.bent + ") bendi, " + b + " aykırılığın idari yaptırımını düzenler. Ceza tutarları İdari yaptırım bölümündedir."
        }
        if !k.bent.isEmpty, let a = metin1380(k.madde + "/" + k.bent) { return a }
        if !k.fikra.isEmpty, let a = metin1380(k.madde + "/" + k.fikra) { return a }
        return metin1380(k.madde) ?? ""
    }

    /// sevkDayanakHtml / legalBasisBlock: dayanak listesinden gösterilecek bloklar.
    /// 1380 maddeleri kendi açıklamasıyla; aynı madde bir kez; madde içermeyen notlar gösterilmez.
    func dayanakGosterimleri(_ liste: [String]) -> [DayanakGosterimi] {
        var bloklar: [DayanakGosterimi] = []
        var gorulen = Set<String>()
        for ham in liste {
            let d = ham.trimmingCharacters(in: .whitespacesAndNewlines)
            if d.isEmpty { continue }
            var anahtarlar: [Madde1380] = []
            if let y = KaynakListesi.yasal1380Coz(d) {
                anahtarlar = [y]
            } else if d.contains("1380") {
                anahtarlar = KaynakListesi.zengin1380Coz(d)
            }
            if !anahtarlar.isEmpty {
                for k in anahtarlar where !gorulen.contains("m:" + k.madde) {
                    gorulen.insert("m:" + k.madde)
                    let a = aciklama(k)
                    bloklar.append(DayanakGosterimi(baslik: KaynakListesi.kanun1380 + " – " + k.etiket,
                                                    aciklama: a.isEmpty ? genelAciklama : a,
                                                    kaynakMetni: KaynakListesi.kanun1380))
                }
                continue
            }
            if !TRMetin.eslesirMi("\\d", d) { continue }
            if gorulen.contains("d:" + d) { continue }
            gorulen.insert("d:" + d)
            bloklar.append(DayanakGosterimi(baslik: d, aciklama: genelAciklama, kaynakMetni: d))
        }
        return bloklar
    }
}


/// idari_yaptirim.php'deki sayfaya özel ayarlar (kaynaklar.json → "yaptirim").
struct YaptirimAyari: Codable {
    struct Kaynak: Codable {
        let ad: String
        let url: String
    }

    struct Ipucu: Codable {
        let etiket: String
        let sorgu: String
    }

    struct Tablo: Codable {
        let satirlar: [String]
        let not: String
    }

    let yil: Int
    let resmiKaynaklar: [String: Kaynak]
    let kaynakSirasi: [String]
    let genelKaynaklar: [Kaynak]
    let ipuclari: [Ipucu]
    let genelTrol: Tablo
    let ruhsat36_1_t: Tablo
    let kisaAciklamalar: [String: String]

    static let bos = YaptirimAyari(yil: 2026, resmiKaynaklar: [:], kaynakSirasi: [], genelKaynaklar: [], ipuclari: [],
                                   genelTrol: Tablo(satirlar: [], not: ""), ruhsat36_1_t: Tablo(satirlar: [], not: ""),
                                   kisaAciklamalar: [:])
}
