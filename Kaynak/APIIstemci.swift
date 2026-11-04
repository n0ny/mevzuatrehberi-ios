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

    static func giris(kullanici: String, sifre: String) async throws -> (token: String, kullanici: KullaniciOzet) {
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
        return (token, k)
    }

    static func ben(token: String) async throws -> KullaniciOzet {
        var istek = URLRequest(url: adres("ben.php"))
        istek.setValue(token, forHTTPHeaderField: "X-MR-Token")
        istek.setValue("application/json", forHTTPHeaderField: "Accept")
        let j = try await gonder(istek)
        guard let k = KullaniciOzet(j["kullanici"]?.nesne) else {
            throw APIHatasi.cozumleme
        }
        return k
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
