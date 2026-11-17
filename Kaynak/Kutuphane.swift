import Foundation

// Bilgi Kütüphanesi (sürüm 7): bayraklar, ses işaretleri, seyir fenerleri.
// İçerik sitedeki api/kutuphane.json dosyasından gelir (sitedeki bilgi-kutuphanesi.php ile aynı kaynak).
// İnternet yokken telefondaki son kopya, o da yoksa uygulamayla gelen kopya (Kaynak/kutuphane.json) gösterilir.

struct KutuphaneIcerik: Codable {
    struct Bolum: Codable {
        let anahtar: String
        let baslik: String
        let durum: String

        var hazir: Bool { return durum == "hazir" }
    }

    struct Bayrak: Codable {
        let harf: String
        let ad: String
        let anlam: String
        let ek: String?
        let ekBaslik: String?
    }

    struct OzelBayrak: Codable {
        let kod: String
        let harfler: [String]
        let baslik: String
        let alt: String?
        let anlam: String
        let ek: String?
        let dayanak: String?
    }

    struct Bayraklar: Codable {
        let baslik: String?
        let aciklama: String?
        let dayanak: String?
        let not: String?
        let liste: [Bayrak]
        let ozel: [OzelBayrak]?
    }

    /// Tanım satırı: {"desen": "k", "metin": "..."} ya da düz metin.
    struct TanimSatiri: Codable {
        let desen: String?
        let metin: String

        private enum CodingKeys: String, CodingKey {
            case desen, metin
        }

        init(from decoder: Decoder) throws {
            if let tek = try? decoder.singleValueContainer().decode(String.self) {
                desen = nil
                metin = tek
                return
            }
            let k = try decoder.container(keyedBy: CodingKeys.self)
            desen = try k.decodeIfPresent(String.self, forKey: .desen)
            metin = try k.decodeIfPresent(String.self, forKey: .metin) ?? ""
        }
    }

    struct Kart: Codable {
        let desen: String?
        let ad: String
        let anlam: String
        let ek: String?
        let dayanak: String?
        let tehlike: Bool?
    }

    struct Grup: Codable {
        let anahtar: String?
        let baslik: String
        let not: String?
        let kucukTekne: String?
        let ekNot: String?
        let liste: [Kart]
    }

    /// Ses işaretleri ve seyir fenerleri bölümleri (aynı yapı).
    struct KartliBolum: Codable {
        let baslik: String?
        let aciklama: String?
        let tanim: [TanimSatiri]?
        let tanimNot: String?
        let tanimDayanak: String?
        let dayanak: String?
        let not: String?
        let gruplar: [Grup]
    }

    let surum: String?
    let bolumler: [Bolum]
    let bayraklar: Bayraklar?
    let ses: KartliBolum?
    let fenerler: KartliBolum?

    static let bos = KutuphaneIcerik(surum: nil, bolumler: [], bayraklar: nil, ses: nil, fenerler: nil)

    static func coz(_ veri: Data) -> KutuphaneIcerik? {
        let c = JSONDecoder()
        c.keyDecodingStrategy = .convertFromSnakeCase
        guard let i = try? c.decode(KutuphaneIcerik.self, from: veri), !i.bolumler.isEmpty else { return nil }
        return i
    }

    /// Uygulamayla gelen kopya.
    static let gomulu: KutuphaneIcerik = {
        if let url = Bundle.main.url(forResource: "kutuphane", withExtension: "json"),
           let veri = try? Data(contentsOf: url),
           let i = coz(veri) {
            return i
        }
        return .bos
    }()

    /// Hazır ve bu sürümün gösterebildiği bölümler.
    var gosterilebilir: [Bolum] {
        return bolumler.filter { b in
            switch b.anahtar {
            case "bayraklar": return bayraklar != nil
            case "ses": return ses != nil
            case "fenerler": return fenerler != nil
            default: return false
            }
        }
    }
}

@MainActor
final class KutuphaneDeposu: ObservableObject {
    static let paylasilan = KutuphaneDeposu()

    @Published private(set) var icerik: KutuphaneIcerik
    @Published private(set) var yukleniyor = false

    private let dosya: URL

    private init() {
        let destek = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let klasor = destek.appendingPathComponent("Icerik", isDirectory: true)
        try? FileManager.default.createDirectory(at: klasor, withIntermediateDirectories: true)
        dosya = klasor.appendingPathComponent("kutuphane-site.json")
        if let d = try? Data(contentsOf: dosya), let i = KutuphaneIcerik.coz(d) {
            icerik = i
        } else {
            icerik = KutuphaneIcerik.gomulu
        }
    }

    /// Sitedeki api/kutuphane.json'u indirir; okunamazsa eldeki kopya kalır.
    func guncelle() async {
        if yukleniyor { return }
        yukleniyor = true
        defer { yukleniyor = false }
        var istek = URLRequest(url: Ayarlar.apiAdresi.appendingPathComponent("kutuphane.json"))
        istek.cachePolicy = .reloadIgnoringLocalCacheData
        istek.timeoutInterval = 30
        guard let sonuc = try? await URLSession.shared.data(for: istek) else { return }
        let veri = sonuc.0
        guard let kod = (sonuc.1 as? HTTPURLResponse)?.statusCode, (200..<300).contains(kod),
              let yeni = KutuphaneIcerik.coz(veri) else { return }
        icerik = yeni
        let hedef = dosya
        Task.detached(priority: .utility) {
            try? veri.write(to: hedef, options: [.atomic])
        }
    }
}

/// Kütüphane aramasında kullanılır (Türkçe harf duyarsız).
enum KutuphaneArama {
    static func eslesir(_ metinler: [String?], sorgu: String) -> Bool {
        let q = TRMetin.harfKatla(sorgu)
        if q.isEmpty { return true }
        let metin = TRMetin.harfKatla(metinler.compactMap { $0 }.joined(separator: " "))
        return metin.contains(q)
    }
}
