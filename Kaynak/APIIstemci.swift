import Foundation

enum APIHatasi: Error {
    case yetkisiz(String)
    case sunucu(String)
    case baglanti
    case cozumleme

    var aciklama: String {
        switch self {
        case .yetkisiz(let m): return m
        case .sunucu(let m): return m
        case .baglanti: return "İnternet bağlantısı kurulamadı."
        case .cozumleme: return "Sunucudan beklenmeyen cevap geldi."
        }
    }
}

struct KullaniciOzet: Codable, Equatable {
    let id: Int
    let ad: String
    let kullaniciAdi: String
    let rol: String

    init(id: Int, ad: String, kullaniciAdi: String, rol: String) {
        self.id = id
        self.ad = ad
        self.kullaniciAdi = kullaniciAdi
        self.rol = rol
    }

    init?(_ o: [String: JSONDeger]?) {
        guard let o = o else { return nil }
        let kimlik = o.tamsayi("id")
        if kimlik <= 0 { return nil }
        id = kimlik
        kullaniciAdi = o.metin("kullanici_adi")
        let a = o.metin("ad")
        ad = a.isEmpty ? kullaniciAdi : a
        rol = o.metin("rol")
    }
}

/// hesabim.php'deki hesap durumu.
struct HesapBilgisi: Codable, Equatable {
    let sonGiris: String?
    let aktif: Bool
    let silmeTalebi: Bool
    let silmeKalan: String?

    init?(_ o: [String: JSONDeger]?) {
        guard let o = o else { return nil }
        sonGiris = o.secimli("son_giris")
        aktif = o["aktif"]?.mantik ?? true
        silmeTalebi = o["silme_talebi"]?.mantik ?? false
        silmeKalan = o.secimli("silme_kalan")
    }
}

struct HesapCevabi {
    let mesaj: String
    let token: String?
}

/// register.php'deki Kullanıcı Sözleşmesi.
struct Sozlesme {
    struct Bolum: Identifiable {
        let id = UUID()
        let baslik: String
        let metin: String
    }
    let bolumler: [Bolum]
    let tarih: String
}

struct IcerikCevabi {
    let degisti: Bool
    let h: String
    let veri: [String: [Satir]]?
}

/// Sunucudaki api/ klasörüyle konuşan katman.
enum APIIstemci {
    private static let oturum: URLSession = {
        let ayar = URLSessionConfiguration.default
        ayar.timeoutIntervalForRequest = 45
        ayar.timeoutIntervalForResource = 120
        ayar.requestCachePolicy = .reloadIgnoringLocalCacheData
        ayar.urlCache = nil
        return URLSession(configuration: ayar)
    }()

    private static func adres(_ yol: String, sorgu: [URLQueryItem] = []) -> URL {
        let temel = Ayarlar.apiAdresi.appendingPathComponent(yol)
        guard !sorgu.isEmpty, var parca = URLComponents(url: temel, resolvingAgainstBaseURL: false) else {
            return temel
        }
        parca.queryItems = sorgu
        return parca.url ?? temel
    }

    private static func gonder(_ istek: URLRequest) async throws -> [String: JSONDeger] {
        let sonuc: (Data, URLResponse)
        do {
            sonuc = try await oturum.data(for: istek)
        } catch {
            throw APIHatasi.baglanti
        }
        let veri = sonuc.0
        let cevap = sonuc.1
        let kod = (cevap as? HTTPURLResponse)?.statusCode ?? 0
        let json = try? JSONDecoder().decode([String: JSONDeger].self, from: veri)
        let mesaj = json?["hata"]?.metin
        if kod == 401 {
            throw APIHatasi.yetkisiz(mesaj ?? "Oturum geçersiz. Tekrar giriş yapın.")
        }
        guard (200..<300).contains(kod) else {
            throw APIHatasi.sunucu(mesaj ?? "Sunucu hatası (\(kod)).")
        }
        guard let j = json, j["ok"]?.mantik == true else {
            throw APIHatasi.cozumleme
        }
        return j
    }

    /// karsilama: login.php'deki gibi 1., 4., 7. ... girişte hoş geldin penceresi gösterilsin mi
    static func giris(kullanici: String, sifre: String) async throws -> (token: String, kullanici: KullaniciOzet, karsilama: Bool) {
        var istek = URLRequest(url: adres("giris.php"))
        istek.httpMethod = "POST"
        istek.setValue("application/json", forHTTPHeaderField: "Content-Type")
        istek.setValue("application/json", forHTTPHeaderField: "Accept")
        let govde: [String: String] = ["kullanici": kullanici, "sifre": sifre]
        istek.httpBody = try? JSONEncoder().encode(govde)
        let j = try await gonder(istek)
        guard let token = j["token"]?.metin, !token.isEmpty,
              let k = KullaniciOzet(j["kullanici"]?.nesne) else {
            throw APIHatasi.cozumleme
        }
        return (token, k, j["karsilama"]?.mantik ?? false)
    }

    static func ben(token: String) async throws -> (kullanici: KullaniciOzet, hesap: HesapBilgisi?) {
        var istek = URLRequest(url: adres("ben.php"))
        istek.setValue(token, forHTTPHeaderField: "X-MR-Token")
        istek.setValue("application/json", forHTTPHeaderField: "Accept")
        let j = try await gonder(istek)
        guard let k = KullaniciOzet(j["kullanici"]?.nesne) else {
            throw APIHatasi.cozumleme
        }
        return (k, HesapBilgisi(j["hesap"]?.nesne))
    }

    /// web-oturum.php: siteye şifresiz geçiş için tek kullanımlık bağlantı (admin, destek, kvkk)
    static func webOturum(hedef: String, token: String) async throws -> URL {
        var istek = URLRequest(url: adres("web-oturum.php"))
        istek.httpMethod = "POST"
        istek.setValue(token, forHTTPHeaderField: "X-MR-Token")
        istek.setValue("application/json", forHTTPHeaderField: "Content-Type")
        istek.setValue("application/json", forHTTPHeaderField: "Accept")
        istek.httpBody = try? JSONEncoder().encode(["hedef": hedef])
        let j = try await gonder(istek)
        guard let s = j["url"]?.metin, let u = URL(string: s), u.scheme == "https" else {
            throw APIHatasi.cozumleme
        }
        return u
    }

    /// hesap.php: profil, sifre, silme-talebi, silme-iptal
    static func hesap(islem: String, alanlar: [String: String], token: String) async throws -> HesapCevabi {
        var istek = URLRequest(url: adres("hesap.php"))
        istek.httpMethod = "POST"
        istek.setValue(token, forHTTPHeaderField: "X-MR-Token")
        istek.setValue("application/json", forHTTPHeaderField: "Content-Type")
        istek.setValue("application/json", forHTTPHeaderField: "Accept")
        var govde = alanlar
        govde["islem"] = islem
        istek.httpBody = try? JSONEncoder().encode(govde)
        let j = try await gonder(istek)
        return HesapCevabi(mesaj: j["mesaj"]?.metin ?? "İşlem tamamlandı.", token: j["token"]?.metin)
    }

    private static func jsonPost(_ yol: String, _ govde: [String: String]) async throws -> [String: JSONDeger] {
        var istek = URLRequest(url: adres(yol))
        istek.httpMethod = "POST"
        istek.setValue("application/json", forHTTPHeaderField: "Content-Type")
        istek.setValue("application/json", forHTTPHeaderField: "Accept")
        istek.httpBody = try? JSONEncoder().encode(govde)
        return try await gonder(istek)
    }

    /// kayit.php (sitedeki register.php ile aynı kurallar). Başarı mesajını döndürür.
    static func kayit(_ alanlar: [String: String]) async throws -> String {
        let j = try await jsonPost("kayit.php", alanlar)
        return j["mesaj"]?.metin ?? "Kayıt başarılı. Hesabınız yönetici onayı bekliyor."
    }

    /// kayit.php GET: Kullanıcı Sözleşmesi metni.
    static func sozlesme() async throws -> Sozlesme {
        var istek = URLRequest(url: adres("kayit.php"))
        istek.setValue("application/json", forHTTPHeaderField: "Accept")
        let j = try await gonder(istek)
        let o = j["sozlesme"]?.nesne
        let bolumler: [Sozlesme.Bolum] = (o?["bolumler"]?.dizi ?? []).compactMap { d in
            guard let b = d.nesne else { return nil }
            return Sozlesme.Bolum(baslik: b.metin("baslik"), metin: b.metin("metin"))
        }
        return Sozlesme(bolumler: bolumler, tarih: o?.metin("tarih") ?? "")
    }

    /// sifre-unuttum.php (sitedeki forgot_password.php ile aynı). Mesajı döndürür.
    static func sifreUnuttum(eposta: String) async throws -> String {
        let j = try await jsonPost("sifre-unuttum.php", ["email": eposta])
        return j["mesaj"]?.metin ?? "Şifre yenileme bağlantısı gönderildi."
    }

    private static func tokenliIstek(_ yol: String, sorgu: [URLQueryItem] = [], token: String,
                                     govde: [String: String]? = nil) -> URLRequest {
        var istek = URLRequest(url: adres(yol, sorgu: sorgu))
        istek.setValue(token, forHTTPHeaderField: "X-MR-Token")
        istek.setValue("application/json", forHTTPHeaderField: "Accept")
        if let g = govde {
            istek.httpMethod = "POST"
            istek.setValue("application/json", forHTTPHeaderField: "Content-Type")
            istek.httpBody = try? JSONEncoder().encode(g)
        }
        return istek
    }

    /// oneri.php GET: hesabın e-postası ve konu listesi.
    static func oneriBilgisi(token: String) async throws -> (eposta: String, konular: [String]) {
        let j = try await gonder(tokenliIstek("oneri.php", token: token))
        let konular = (j["konular"]?.dizi ?? []).compactMap { $0.metin }
        return (j["eposta"]?.metin ?? "", konular)
    }

    /// oneri.php POST (sitedeki oneri.php ile aynı kurallar). Başarı mesajını döndürür.
    static func oneriGonder(konu: String, mesaj: String, eposta: String, token: String) async throws -> String {
        let j = try await gonder(tokenliIstek("oneri.php", token: token,
                                              govde: ["konu": konu, "mesaj": mesaj, "email": eposta]))
        return j["mesaj"]?.metin ?? "Öneriniz başarıyla iletildi."
    }

    /// bilgi.php GET: haftanın soruları (setId verilirse geçmiş set).
    static func bilgi(setId: Int?, token: String) async throws -> BilgiVerisi {
        var sorgu: [URLQueryItem] = []
        if let s = setId {
            sorgu.append(URLQueryItem(name: "set", value: String(s)))
        }
        let j = try await gonder(tokenliIstek("bilgi.php", sorgu: sorgu, token: token))
        do {
            let veri = try JSONEncoder().encode(j)
            let cozucu = JSONDecoder()
            cozucu.keyDecodingStrategy = .convertFromSnakeCase
            return try cozucu.decode(BilgiVerisi.self, from: veri)
        } catch {
            throw APIHatasi.cozumleme
        }
    }

    /// bilgi.php POST: cevap gönder.
    static func bilgiCevapla(soruId: Int, secim: String, token: String) async throws {
        _ = try await gonder(tokenliIstek("bilgi.php", token: token,
                                          govde: ["soru_id": String(soruId), "secim": secim]))
    }

    // MARK: Yönetim (yalnızca yönetici) — api/yonetim.php

    private static func snakeCoz<T: Decodable>(_ j: [String: JSONDeger], _ tur: T.Type) throws -> T {
        do {
            let veri = try JSONEncoder().encode(j)
            let cozucu = JSONDecoder()
            cozucu.keyDecodingStrategy = .convertFromSnakeCase
            return try cozucu.decode(tur, from: veri)
        } catch {
            throw APIHatasi.cozumleme
        }
    }

    static func yonetimListesi(token: String) async throws -> YonetimVerisi {
        let j = try await gonder(tokenliIstek("yonetim.php", token: token))
        return try snakeCoz(j, YonetimVerisi.self)
    }

    /// Kullanıcı işlemleri (admin/index.php ile aynı). Başarı mesajını döndürür.
    static func yonetimIslem(_ islem: String, alanlar: [String: String], token: String) async throws -> String {
        var govde = alanlar
        govde["islem"] = islem
        let j = try await gonder(tokenliIstek("yonetim.php", token: token, govde: govde))
        return j["mesaj"]?.metin ?? "İşlem tamamlandı."
    }

    /// Bildirim gönder (admin/send_notification.php ile aynı).
    static func yonetimBildirim(baslik: String, metin: String, token: String) async throws -> BildirimSonucu {
        let j = try await gonder(tokenliIstek("yonetim.php", token: token,
                                              govde: ["islem": "bildirim", "title": baslik, "body": metin]))
        return try snakeCoz(j, BildirimSonucu.self)
    }

    static func icerik(bolum: String, h: String?, token: String) async throws -> IcerikCevabi {
        var sorgu = [URLQueryItem(name: "bolum", value: bolum)]
        if let h = h, !h.isEmpty {
            sorgu.append(URLQueryItem(name: "h", value: h))
        }
        var istek = URLRequest(url: adres("icerik.php", sorgu: sorgu))
        istek.setValue(token, forHTTPHeaderField: "X-MR-Token")
        istek.setValue("application/json", forHTTPHeaderField: "Accept")
        istek.timeoutInterval = 90
        let j = try await gonder(istek)
        let yeniH = j["h"]?.metin ?? ""
        let degisti = j["degisti"]?.mantik ?? true
        if !degisti {
            return IcerikCevabi(degisti: false, h: yeniH, veri: nil)
        }
        guard let ham = j["veri"]?.nesne else {
            throw APIHatasi.cozumleme
        }
        var veri: [String: [Satir]] = [:]
        for (anahtar, deger) in ham {
            veri[anahtar] = (deger.dizi ?? []).compactMap { $0.nesne }
        }
        return IcerikCevabi(degisti: true, h: yeniH, veri: veri)
    }
}
