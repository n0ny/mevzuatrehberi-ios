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
    @Published private(set) var kaynakListesi: KaynakListesi = .gomulu
    /// Tekne / Gemi Kontrolü sayfaları (tekne.php ve alt sayfaları).
    @Published private(set) var tekne: TekneIcerik?
    @Published private(set) var motor: MevzuatAramaMotoru = .bos

    @Published private(set) var sonKontrol: Date?
    @Published private(set) var guncelleniyor = false
    @Published private(set) var diskOkundu = false
    @Published var hataMesaji: String?

    private var ihlalBaglari: [(ihlalId: Int, maddeId: Int)] = []
    private var motorEskidi = false
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
        motoruKurGerekirse()
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
        ihlalBaglari = []
        kaynakListesi = .gomulu
        tekne = nil
        motor = .bos
        hashler = [:]
        sonKontrol = nil
        hataMesaji = nil
        UserDefaults.standard.removeObject(forKey: VeriDeposu.sonKontrolAnahtari)
    }

    // MARK: - Sunucudan güncelleme

    func guncelle(token: String) async -> GuncellemeSonucu {
        if guncelleniyor { return .tamam }
        guncelleniyor = true
        defer {
            motoruKurGerekirse()
            guncelleniyor = false
        }

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
            } catch is APIHatasi where Ayarlar.istegeBagliBolumler.contains(b) {
                // Sunucu dosyası henüz yüklenmemişse diğer bölümler yine güncellenir.
                continue
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
            maddeler = (v["maddeler"] ?? []).map { Madde($0, mevzuatlar: m) }.filter { m[$0.mevzuatId] != nil }
            ihlaller = (v["ihlaller"] ?? []).map { Ihlal($0) }
            ihlalBaglari = (v["ihlal_mevzuat"] ?? []).map { (ihlalId: $0.tamsayi("ihlal_id"), maddeId: $0.tamsayi("mevzuat_madde_id")) }
            motorEskidi = true
        case "fiil":
            fiiller = (v["fiiller"] ?? []).map { Fiil($0) }
            motorEskidi = true
        case "sevk":
            sevkler = (v["kayitlar"] ?? []).map { SevkKaydi($0) }
            motorEskidi = true
        case "yaptirim":
            yaptirimlar = (v["yaptirimlar"] ?? []).map { Yaptirim($0) }
        case "turler":
            turler = (v["turler"] ?? []).map { Tur($0) }
        case "bolge":
            bolgeler = (v["bolgeler"] ?? []).map { Bolge($0) }
        case "yenilikler":
            yenilikler = (v["yenilikler"] ?? []).map { Yenilik($0) }
        case "kaynaklar":
            if let satir = v["kaynaklar"]?.first,
               let veri = try? JSONEncoder().encode(satir),
               let liste = try? JSONDecoder().decode(KaynakListesi.self, from: veri) {
                kaynakListesi = liste
            }
        case "tekne":
            if let satir = v["tekne"]?.first,
               let veri = try? JSONEncoder().encode(satir),
               let icerik = try? JSONDecoder().decode(TekneIcerik.self, from: veri) {
                tekne = icerik
            }
        default:
            break
        }
        hashler[bolum] = kayit.h
    }

    /// Mevzuat arama motorunu (mevzuat.php'deki üç kaynak) yeniden kurar.
    private func motoruKurGerekirse() {
        if !motorEskidi { return }
        motorEskidi = false

        var ihlalSozluk: [Int: Ihlal] = [:]
        for i in ihlaller { ihlalSozluk[i.id] = i }
        var maddeBaglari: [Int: [Int]] = [:]
        for b in ihlalBaglari { maddeBaglari[b.maddeId, default: []].append(b.ihlalId) }

        var eski: [EskiAday] = []
        for m in maddeler.sorted(by: { $0.id < $1.id }) {
            let baglar = maddeBaglari[m.id] ?? []
            let ihlalListesi: [Ihlal?] = baglar.isEmpty ? [nil] : baglar.map { ihlalSozluk[$0] }
            for (sira, ihlal) in ihlalListesi.enumerated() {
                var fiil = ihlal?.ad ?? ""
                if fiil.isEmpty { fiil = m.baslik ?? "" }
                let aciklama = ihlal?.aciklama ?? m.metin
                let kayit = AramaKaydi(kaynak: .eski, id: "e\(m.id)-\(sira)", fiil: fiil,
                                       mevzuat: m.mevzuatAdi ?? "", madde: m.no, aciklama: aciklama)
                eski.append(EskiAday(ihlalNormal: ihlal.map { TRMetin.normal($0.ad) },
                                     baslikNormal: m.baslik.map { TRMetin.normal($0) },
                                     kayit: kayit))
            }
        }

        let v5 = fiiller.filter { !$0.fiil.isEmpty }.map { f in
            AramaKaydi(kaynak: .v5, id: "v\(f.id)", fiil: f.fiil, mevzuat: f.mevzuat, madde: f.madde ?? "",
                       bent: f.bent ?? "", aciklama: f.aciklama ?? "", kapsam: f.kapsam ?? "",
                       kaynakMetni: f.kaynak ?? "")
        }
        let sevk = sevkler.filter { !$0.gerekce.isEmpty }.map { $0.aramaKaydi }
        motor = MevzuatAramaMotoru(eski: eski, v5: v5, sevk: sevk)
    }
}
