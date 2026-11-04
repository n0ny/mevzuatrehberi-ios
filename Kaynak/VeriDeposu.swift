import Foundation

/// Telefona kaydedilen bir bölüm (ör. turler): sunucudaki özeti (h) ve satırları.
struct KayitliBolum: Codable {
    var h: String
    var alinma: Date
    var veri: [String: [Satir]]
}

enum GuncellemeSonucu {
    case tamam
    case yetkisiz
    case hata(String)
}

/// Bütün içeriği tutar. İçerik telefonda saklanır; internet yokken son indirilen veri gösterilir.
@MainActor
final class VeriDeposu: ObservableObject {
    @Published private(set) var mevzuatlar: [Int: Mevzuat] = [:]
    @Published private(set) var maddeler: [Madde] = []
    @Published private(set) var ihlaller: [Ihlal] = []
    @Published private(set) var fiiller: [Fiil] = []
    @Published private(set) var sevkler: [SevkKaydi] = []
    @Published private(set) var yaptirimlar: [Yaptirim] = []
    @Published private(set) var turler: [Tur] = []
    @Published private(set) var bolgeler: [Bolge] = []
    @Published private(set) var yenilikler: [Yenilik] = []

    @Published private(set) var sonKontrol: Date?
    @Published private(set) var guncelleniyor = false
    @Published private(set) var diskOkundu = false
    @Published var hataMesaji: String?

    private var ihlalMaddeIdleri: [Int: [Int]] = [:]
    private var hashler: [String: String] = [:]
    private let klasor: URL
    private static let sonKontrolAnahtari = "depo.sonKontrol"

    init() {
        let destek = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        klasor = destek.appendingPathComponent("Icerik", isDirectory: true)
        try? FileManager.default.createDirectory(at: klasor, withIntermediateDirectories: true)
        sonKontrol = UserDefaults.standard.object(forKey: VeriDeposu.sonKontrolAnahtari) as? Date
    }

    var veriVar: Bool {
        return !turler.isEmpty || !sevkler.isEmpty || !fiiller.isEmpty || !maddeler.isEmpty
    }

    /// Kontrol zamanı geldiyse true.
    var kontrolGerekli: Bool {
        guard let s = sonKontrol else { return true }
        return Date().timeIntervalSince(s) > Ayarlar.kontrolAraligi
    }

    // MARK: - Disk

    func diskOku() async {
        if diskOkundu { return }
        let klasor = self.klasor
        let okunan = await Task.detached(priority: .userInitiated) { () -> [String: KayitliBolum] in
            var sonuc: [String: KayitliBolum] = [:]
            for b in Ayarlar.bolumler {
                let url = klasor.appendingPathComponent(b + ".json")
                if let d = try? Data(contentsOf: url),
                   let k = try? JSONDecoder().decode(KayitliBolum.self, from: d) {
                    sonuc[b] = k
                }
            }
            return sonuc
        }.value
        for b in Ayarlar.bolumler {
            if let k = okunan[b] {
                uygula(b, k)
            }
        }
        diskOkundu = true
    }

    private func diskeYaz(_ bolum: String, _ kayit: KayitliBolum) {
        let url = klasor.appendingPathComponent(bolum + ".json")
        Task.detached(priority: .utility) {
            if let d = try? JSONEncoder().encode(kayit) {
                try? d.write(to: url, options: [.atomic])
            }
        }
    }

    /// Çıkışta telefondaki bütün içerik silinir.
    func temizle() {
        for b in Ayarlar.bolumler {
            try? FileManager.default.removeItem(at: klasor.appendingPathComponent(b + ".json"))
        }
        mevzuatlar = [:]
        maddeler = []
        ihlaller = []
        fiiller = []
        sevkler = []
        yaptirimlar = []
        turler = []
        bolgeler = []
        yenilikler = []
        ihlalMaddeIdleri = [:]
        hashler = [:]
        sonKontrol = nil
        hataMesaji = nil
        UserDefaults.standard.removeObject(forKey: VeriDeposu.sonKontrolAnahtari)
    }

    // MARK: - Sunucudan güncelleme

    func guncelle(token: String) async -> GuncellemeSonucu {
        if guncelleniyor { return .tamam }
        guncelleniyor = true
        defer { guncelleniyor = false }

        for b in Ayarlar.bolumler {
            do {
                let cevap = try await APIIstemci.icerik(bolum: b, h: hashler[b], token: token)
                if cevap.degisti, let veri = cevap.veri {
                    let kayit = KayitliBolum(h: cevap.h, alinma: Date(), veri: veri)
                    uygula(b, kayit)
                    diskeYaz(b, kayit)
                }
            } catch APIHatasi.yetkisiz(_) {
                return .yetkisiz
            } catch let hata as APIHatasi {
                hataMesaji = hata.aciklama
                return .hata(hata.aciklama)
            } catch {
                hataMesaji = APIHatasi.baglanti.aciklama
                return .hata(APIHatasi.baglanti.aciklama)
            }
        }

        let simdi = Date()
        sonKontrol = simdi
        hataMesaji = nil
        UserDefaults.standard.set(simdi, forKey: VeriDeposu.sonKontrolAnahtari)
        return .tamam
    }

    private func uygula(_ bolum: String, _ kayit: KayitliBolum) {
        let v = kayit.veri
        switch bolum {
        case "mevzuat":
            var m: [Int: Mevzuat] = [:]
            for s in v["mevzuatlar"] ?? [] {
                let x = Mevzuat(s)
                m[x.id] = x
            }
            mevzuatlar = m
            maddeler = (v["maddeler"] ?? []).map { Madde($0, mevzuatlar: m) }
            ihlaller = (v["ihlaller"] ?? []).map { Ihlal($0) }
            var baglar: [Int: [Int]] = [:]
            for s in v["ihlal_mevzuat"] ?? [] {
                baglar[s.tamsayi("ihlal_id"), default: []].append(s.tamsayi("mevzuat_madde_id"))
            }
            ihlalMaddeIdleri = baglar
        case "fiil":
            fiiller = (v["fiiller"] ?? []).map { Fiil($0) }
        case "sevk":
            sevkler = (v["kayitlar"] ?? []).map { SevkKaydi($0) }
        case "yaptirim":
            yaptirimlar = (v["yaptirimlar"] ?? []).map { Yaptirim($0) }
        case "turler":
            turler = (v["turler"] ?? []).map { Tur($0) }
        case "bolge":
            bolgeler = (v["bolgeler"] ?? []).map { Bolge($0) }
        case "yenilikler":
            yenilikler = (v["yenilikler"] ?? []).map { Yenilik($0) }
        default:
            break
        }
        hashler[bolum] = kayit.h
    }

    // MARK: - Sorgular

    func ilgiliMaddeler(ihlal: Ihlal) -> [Madde] {
        let idler = Set(ihlalMaddeIdleri[ihlal.id] ?? [])
        return maddeler.filter { idler.contains($0.id) }
    }

    /// Mevzuat araması: bütün kelimeler geçen kayıtlar. Her türden sınırlı sayıda sonuç döner.
    func ara(_ sorgu: String) -> (sonuclar: [AramaSonucu], kesildi: Bool) {
        let k = Metin.kelimeler(sorgu)
        if k.isEmpty { return ([], false) }
        var sonuc: [AramaSonucu] = []
        var kesildi = false

        func ekle<T>(_ liste: [T], sinir: Int, arama: (T) -> String, donustur: (T) -> AramaSonucu) {
            var sayac = 0
            for x in liste where Metin.eslesir(arama(x), k) {
                if sayac >= sinir {
                    kesildi = true
                    return
                }
                sonuc.append(donustur(x))
                sayac += 1
            }
        }

        ekle(fiiller, sinir: 25, arama: { $0.arama }, donustur: { AramaSonucu.fiil($0) })
        ekle(maddeler, sinir: 15, arama: { $0.arama }, donustur: { AramaSonucu.madde($0) })
        ekle(ihlaller, sinir: 10, arama: { $0.arama }, donustur: { AramaSonucu.ihlal($0) })
        ekle(sevkler, sinir: 25, arama: { $0.arama }, donustur: { AramaSonucu.sevk($0) })
        return (sonuc, kesildi)
    }
}
