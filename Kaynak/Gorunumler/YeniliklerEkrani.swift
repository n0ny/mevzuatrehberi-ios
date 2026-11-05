import SwiftUI
import UIKit

// yenilikler.php — Yenilikler (zaman çizelgesi) sayfasının karşılığı.

enum YenilikKurallari {
    static let kategoriler = ["Mevzuat", "Yeni özellik", "Düzeltme", "Duyuru"]
    static let aylar = ["", "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
    static let aylarKisa = ["", "Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"]

    static func renk(_ kategori: String) -> (Color, Color, String) {
        switch kategori {
        case "Mevzuat":
            return (Color(UIColor.dinamik(0x0B5CAD, 0x7FB4EA)), Color(UIColor.dinamik(0xE6F0FA, 0x16304A)), "book.closed")
        case "Yeni özellik":
            return (Color(UIColor.dinamik(0x14684C, 0x6FD8A6)), Color(UIColor.dinamik(0xE4F4EC, 0x11291F)), "sparkles")
        case "Düzeltme":
            return (Color(UIColor.dinamik(0x8A5200, 0xF0C070)), Color(UIColor.dinamik(0xFDEBC8, 0x2A2210)), "wrench")
        default:
            return (Color(UIColor.dinamik(0x5B3FA8, 0xB9A6F2)), Color(UIColor.dinamik(0xEFEAFB, 0x221A3A)), "megaphone")
        }
    }

    /// "2026-11-05" → (yıl, ay, gün)
    static func parcala(_ s: String?) -> (Int, Int, Int)? {
        guard let s = s, s.count >= 10 else { return nil }
        let p = s.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, p[1] >= 1, p[1] <= 12 else { return nil }
        return (p[0], p[1], p[2])
    }

    static func ayBasligi(_ s: String?) -> String {
        guard let t = parcala(s) else { return "" }
        return aylar[t.1] + " " + String(t.0)
    }

    static func kisaTarih(_ s: String?) -> String {
        guard let t = parcala(s) else { return "" }
        return "\(t.2) " + aylarKisa[t.1]
    }

    private static let sunucuSaati: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Istanbul")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    private static let gun: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Istanbul")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func bugun() -> String {
        return gun.string(from: Date())
    }

    /// Sitedeki liste: aktif, tarihi bugün veya öncesi, en yeni önce, en çok 100.
    static func gorunen(_ liste: [Yenilik]) -> [Yenilik] {
        let b = bugun()
        return Array(liste.filter { String(($0.tarih ?? "").prefix(10)) <= b && $0.tarih != nil }
            .sorted { a, c in
                let ta = a.tarih ?? ""
                let tc = c.tarih ?? ""
                if ta != tc { return ta > tc }
                return a.id > c.id
            }
            .prefix(100))
    }

    /// mr_yenilik_yeni_mi: hiç açılmadıysa son 14 gün; açıldıysa son açılıştan sonra eklenenler.
    static func yeniMi(_ y: Yenilik, sonGorme: Date?) -> Bool {
        if let son = sonGorme {
            guard let o = y.olusturma, let d = sunucuSaati.date(from: String(o.prefix(19))) else { return false }
            return d > son
        }
        let sinir = gun.string(from: Date().addingTimeInterval(-14 * 86400))
        return String((y.tarih ?? "").prefix(10)) >= sinir
    }

    /// "- " / "• " / "* " satırları madde, boş satırlar paragraf ayırır.
    enum Parca {
        case paragraf([String])
        case liste([String])
    }

    static func govde(_ metin: String) -> [Parca] {
        var sonuc: [Parca] = []
        var liste: [String] = []
        var paragraf: [String] = []
        func bosalt() {
            if !paragraf.isEmpty { sonuc.append(.paragraf(paragraf)); paragraf = [] }
            if !liste.isEmpty { sonuc.append(.liste(liste)); liste = [] }
        }
        let satirlar = metin.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
        for ham in satirlar {
            let s = ham.trimmingCharacters(in: .whitespaces)
            if s.isEmpty {
                bosalt()
                continue
            }
            if let m = TRMetin.ilkGrup("^[-•*]\\s+(.+)$", s) {
                if !paragraf.isEmpty { sonuc.append(.paragraf(paragraf)); paragraf = [] }
                liste.append(m)
            } else {
                if !liste.isEmpty { bosalt() }
                paragraf.append(s)
            }
        }
        bosalt()
        return sonuc
    }
}

/// "Yeni" işareti telefonda kişiye özel tutulur (sitedeki yenilik_gorme mantığı).
enum YenilikTakibi {
    private static let anahtar = "yenilik.sonGorme"

    static func sonGorme() -> Date? {
        return UserDefaults.standard.object(forKey: anahtar) as? Date
    }

    static func yeniSayisi(_ liste: [Yenilik]) -> Int {
        let son = sonGorme()
        return YenilikKurallari.gorunen(liste).filter { YenilikKurallari.yeniMi($0, sonGorme: son) }.count
    }

    static func goruldu() {
        UserDefaults.standard.set(Date(), forKey: anahtar)
    }
}

struct YeniliklerEkrani: View {
    @EnvironmentObject var depo: VeriDeposu
    @State private var secili = ""
    @State private var oncekiGorme: Date?
    @State private var hazir = false

    var body: some View {
        let tumu = YenilikKurallari.gorunen(depo.yenilikler)
        let liste = secili.isEmpty ? tumu : tumu.filter { $0.kategori == secili }
        let yeniSayisi = hazir ? tumu.filter { YenilikKurallari.yeniMi($0, sonGorme: oncekiGorme) }.count : 0

        return YenilenebilirKaydirma {
            VStack(spacing: 0) {
                Kahraman(baslik: "Yenilikler", aciklama: "Uygulamaya eklenen mevzuat, özellik ve duyurular.") {
                    if yeniSayisi > 0 {
                        (Text("\(yeniSayisi)").bold() + Text(" yeni"))
                            .font(.footnote)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Renk.mavi)
                            .cornerRadius(999)
                    }
                }

                LazyVStack(alignment: .leading, spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            GrupCipi(baslik: "Tümü", secili: secili.isEmpty) { secili = "" }
                            ForEach(YenilikKurallari.kategoriler, id: \.self) { k in
                                GrupCipi(baslik: k, secili: secili == k) { secili = k }
                            }
                        }
                    }

                    if liste.isEmpty {
                        BosKutu(metin: secili.isEmpty ? "Henüz yenilik eklenmedi." : "Bu kategoride henüz kayıt yok.")
                    } else {
                        ForEach(Array(liste.enumerated()), id: \.element.id) { sira, y in
                            let ay = YenilikKurallari.ayBasligi(y.tarih)
                            if sira == 0 || YenilikKurallari.ayBasligi(liste[sira - 1].tarih) != ay {
                                Text(ay)
                                    .font(.headline)
                                    .foregroundColor(Renk.murekkep)
                                    .padding(.top, sira == 0 ? 4 : 12)
                            }
                            YenilikKarti(yenilik: y, yeni: hazir && YenilikKurallari.yeniMi(y, sonGorme: oncekiGorme))
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle("Mevzuat Rehberi")
        .markaBasligi()
        .onAppear {
            if !hazir {
                // Önce eski "son görme" alınır (yeni işaretleri buna göre), sonra şimdiye çekilir.
                oncekiGorme = YenilikTakibi.sonGorme()
                hazir = true
                YenilikTakibi.goruldu()
            }
        }
    }
}

struct YenilikKarti: View {
    let yenilik: Yenilik
    let yeni: Bool
    @State private var acik = false

    private var uzun: Bool {
        let satirSayisi = YenilikKurallari.govde(yenilik.aciklama).reduce(0) { toplam, p in
            switch p {
            case .paragraf(let s): return toplam + s.count
            case .liste(let s): return toplam + s.count
            }
        }
        return satirSayisi > 3 || yenilik.aciklama.count > 200
    }

    var body: some View {
        let r = YenilikKurallari.renk(yenilik.kategori)
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Image(systemName: r.2)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(r.0)
                    .frame(width: 28, height: 28)
                    .background(r.1)
                    .clipShape(Circle())
                Rectangle()
                    .fill(Renk.cizgi)
                    .frame(width: 2)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(yenilik.kategori)
                        .font(.caption.weight(.bold))
                        .foregroundColor(r.0)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(r.1)
                        .cornerRadius(999)
                    if yeni {
                        Text("Yeni")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Renk.mavi)
                            .cornerRadius(999)
                    }
                    Spacer()
                    Text(YenilikKurallari.kisaTarih(yenilik.tarih))
                        .font(.caption)
                        .foregroundColor(Renk.soluk)
                }
                Text(yenilik.baslik)
                    .font(.headline)
                    .foregroundColor(Renk.murekkep)
                    .fixedSize(horizontal: false, vertical: true)
                YenilikGovdesi(parcalar: YenilikKurallari.govde(yenilik.aciklama))
                    .frame(maxHeight: (uzun && !acik) ? 66 : nil, alignment: .top)
                    .clipped()
                HStack(spacing: 14) {
                    if uzun {
                        Button(acik ? "Daha az göster" : "Devamını oku") {
                            withAnimation(.easeInOut(duration: 0.2)) { acik.toggle() }
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Renk.mavi)
                        .buttonStyle(.plain)
                    }
                    baglanti
                }
            }
            .padding(14)
            .kart(vurgulu: yeni)
            .padding(.bottom, 6)
        }
    }

    @ViewBuilder
    private var baglanti: some View {
        if let l = yenilik.link {
            if l.lowercased().hasPrefix("http://") || l.lowercased().hasPrefix("https://") {
                if let u = Baglanti.url(l) {
                    Link("Kaynağı aç", destination: u)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Renk.mavi)
                }
            } else if let hedef = SayfaHedefi.gorunum(l) {
                NavigationLink(destination: hedef) {
                    Text("Sayfaya git")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Renk.mavi)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct YenilikGovdesi: View {
    let parcalar: [YenilikKurallari.Parca]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parcalar.enumerated()), id: \.offset) { _, p in
                switch p {
                case .paragraf(let satirlar):
                    Text(satirlar.joined(separator: "\n"))
                        .font(.subheadline)
                        .foregroundColor(Renk.murekkep)
                        .fixedSize(horizontal: false, vertical: true)
                case .liste(let maddeler):
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(maddeler.enumerated()), id: \.offset) { _, m in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("•").foregroundColor(Renk.mavi)
                                Text(m)
                                    .font(.subheadline)
                                    .foregroundColor(Renk.murekkep)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Sitedeki sayfa bağlantılarının (ör. "turler.php") uygulamadaki karşılığı.
enum SayfaHedefi {
    static func gorunum(_ link: String) -> AnyView? {
        let sayfa = link.split(separator: "?").first.map(String.init)?.lowercased() ?? ""
        switch sayfa {
        case "mevzuat.php": return AnyView(AramaEkrani())
        case "idari_yaptirim.php": return AnyView(YaptirimEkrani())
        case "sevk_islemleri.php": return AnyView(SevkEkrani())
        case "bolge_yasaklari.php": return AnyView(BolgeEkrani())
        case "turler.php": return AnyView(TurlerEkrani())
        case "yenilikler.php": return AnyView(YeniliklerEkrani())
        case "hesabim.php": return AnyView(HesapEkrani())
        default: return nil
        }
    }
}
