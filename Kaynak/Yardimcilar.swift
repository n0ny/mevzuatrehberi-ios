import Foundation

enum Ayarlar {
    static let siteAdresi = URL(string: "https://sg.barisguresci.com.tr/")!
    static let apiAdresi = URL(string: "https://sg.barisguresci.com.tr/api/")!
    /// İndirme sırası: küçük bölümler önce gelir, büyük sevk bölümü en son.
    static let bolumler = ["kaynaklar", "yenilikler", "turler", "yaptirim", "bolge", "fiil", "mevzuat", "sevk", "tekne", "yakinda"]
    /// Sunucuda henüz yoksa güncellemeyi durdurmayan bölümler (yeni eklenenler).
    static let istegeBagliBolumler: Set<String> = ["tekne", "yakinda"]
    /// Uygulama öne geldiğinde en az bu kadar süre geçtiyse içerik kontrol edilir.
    static let kontrolAraligi: TimeInterval = 10 * 60
}

enum Metin {
    static let tr = Locale(identifier: "tr_TR")

    /// Aramada kullanılır: küçük harf, Türkçe karakterler sadeleşir (ğ→g, ş→s, ı→i ...).
    static func katla(_ s: String) -> String {
        let kucuk = s.lowercased(with: tr)
        let sade = kucuk.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: tr)
        return sade.replacingOccurrences(of: "ı", with: "i")
    }

    static func kelimeler(_ s: String) -> [String] {
        return katla(s)
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { !$0.isEmpty }
    }

    /// Bütün kelimeler metinde geçiyorsa doğru.
    static func eslesir(_ katlanmis: String, _ kelimeler: [String]) -> Bool {
        if kelimeler.isEmpty { return false }
        for k in kelimeler where !katlanmis.contains(k) {
            return false
        }
        return true
    }

    static func birlestir(_ parcalar: [String?]) -> String {
        return parcalar.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Türkçe alfabeye göre sıralama karşılaştırması.
    static func once(_ a: String, _ b: String) -> Bool {
        return a.compare(b, options: [.caseInsensitive], range: nil, locale: tr) == .orderedAscending
    }

    /// Açıklama metnini satırlara böler ("- " ile başlayan satırlar madde olur).
    static func satirlar(_ s: String) -> [String] {
        return s.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

enum Para {
    static let bicim: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    static func sayi(_ d: Double) -> String {
        return bicim.string(from: NSNumber(value: d)) ?? String(d)
    }

    static func yaz(_ d: Double) -> String {
        return sayi(d) + " TL"
    }

    static func aralik(_ en_az: Double, _ en_cok: Double) -> String {
        return sayi(en_az) + " – " + sayi(en_cok) + " TL"
    }
}

enum Tarih {
    private static let okuyucu: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Istanbul")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let gun: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.timeZone = TimeZone(identifier: "Europe/Istanbul")
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    private static let gunSaat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMMM yyyy, HH:mm"
        return f
    }()

    /// "2026-10-23" → "23 Ekim 2026". Okunamazsa olduğu gibi döner.
    static func gunYaz(_ s: String?) -> String? {
        guard let s = s, !s.isEmpty else { return nil }
        let ilk10 = String(s.prefix(10))
        if let d = okuyucu.date(from: ilk10) {
            return gun.string(from: d)
        }
        return s
    }

    static func tarihOku(_ s: String?) -> Date? {
        guard let s = s, !s.isEmpty else { return nil }
        return okuyucu.date(from: String(s.prefix(10)))
    }

    static func anYaz(_ d: Date) -> String {
        return gunSaat.string(from: d)
    }
}

enum Baglanti {
    /// Yalnızca http/https adreslerini kabul eder.
    static func url(_ s: String?) -> URL? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
              let u = URL(string: s), let sema = u.scheme?.lowercased(),
              sema == "https" || sema == "http" else { return nil }
        return u
    }
}
