import SwiftUI

/// tekne.php ve alt sayfaları — Tekne / Gemi Kontrolü.
/// Bütün sayfalar aynı ekranla çizilir; metinler sunucudaki tekne.json'dan gelir
/// (sitedeki sayfalarla birebir aynı).
struct TekneEkrani: View {
    @EnvironmentObject var depo: VeriDeposu
    /// Boşsa kök sayfa (tekne.php).
    var sayfaAdi: String? = nil

    var body: some View {
        let icerik = depo.tekne
        let ad = sayfaAdi ?? icerik?.kokSayfa ?? "tekne"
        let sayfa = icerik?.sayfalar[ad]

        return YenilenebilirKaydirma {
            VStack(spacing: 0) {
                if let s = sayfa {
                    Kahraman(baslik: s.baslik, aciklama: s.aciklama)
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(s.bloklar.enumerated()), id: \.offset) { _, b in
                            TekneBlokGorunumu(blok: b)
                        }
                    }
                    .padding(16)
                } else {
                    Kahraman(baslik: "Tekne / gemi kontrolü",
                             aciklama: "Denetlenecek araç sınıfını seçerek belge, donanım ve saha kontrollerini adım adım inceleyin.")
                    VStack(spacing: 12) {
                        if depo.guncelleniyor {
                            ProgressView()
                        }
                        UyariKutusu(tur: .bilgi, baslik: "İçerik henüz indirilmedi.",
                                    metin: "İnternete bağlıyken sayfayı aşağı çekip bırakarak güncelleyin.")
                    }
                    .padding(16)
                }
            }
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle(sayfa?.baslik ?? "Tekne / Gemi Kontrolü")
        .markaBasligi()
    }
}

/// Bir bölümün çizimi.
struct TekneBlokGorunumu: View {
    let blok: TekneBlok

    var body: some View {
        switch blok.tur {
        case "etiket":
            HStack {
                Text((blok.metin ?? "").uppercased(with: TRMetin.tr))
                    .font(.caption.weight(.bold))
                    .foregroundColor(Renk.soluk)
                    .tracking(0.6)
                Spacer()
                if let s = blok.sayi {
                    Hap(metin: s)
                }
            }
            .padding(.top, 4)
        case "kartlar":
            VStack(spacing: 10) {
                ForEach(Array((blok.kartlar ?? []).enumerated()), id: \.offset) { _, k in
                    TekneKartGorunumu(kart: k)
                }
            }
        case "liste":
            VStack(spacing: 8) {
                ForEach(Array((blok.maddeler ?? []).enumerated()), id: \.offset) { sira, m in
                    TekneMaddeSatiri(sira: sira + 1, madde: m)
                }
            }
        case "bilgi":
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Renk.mavi)
                (Text((blok.baslik ?? "") + "\n").bold() + Text(blok.metin ?? ""))
                    .font(.footnote)
                    .foregroundColor(Renk.murekkep)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Renk.tint)
            .cornerRadius(14)
        case "dayanak":
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(Renk.mavi)
                (Text((blok.baslik ?? "") + "\n").bold() + Text(blok.metin ?? ""))
                    .font(.footnote)
                    .foregroundColor(Renk.murekkep)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .kart()
        case "aciklama":
            Text(blok.metin ?? "")
                .font(.footnote)
                .foregroundColor(Renk.soluk)
                .fixedSize(horizontal: false, vertical: true)
        case "acilir":
            TekneAcilirKart(blok: blok)
        case "uyari":
            HStack(alignment: .top, spacing: 10) {
                (Text((blok.baslik ?? "") + " ").bold() + Text(blok.metin ?? ""))
                    .font(.footnote)
                    .foregroundColor(Renk.murekkep)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Renk.amberZemin)
            .cornerRadius(14)
        case "not":
            (Text((blok.baslik ?? "Not") + ": ").bold() + Text(blok.metin ?? ""))
                .font(.footnote)
                .foregroundColor(Renk.murekkep)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Renk.amberZemin)
                .cornerRadius(14)
        case "kaynak":
            TekneKaynakKarti(blok: blok)
        case "altnot":
            Text(blok.metin ?? "")
                .font(.caption)
                .foregroundColor(Renk.soluk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
        default:
            EmptyView()
        }
    }
}

/// Alt sayfaya giden kart (sitedeki .control-card / .quick-card).
struct TekneKartGorunumu: View {
    let kart: TekneKart

    var body: some View {
        if let h = kart.hedef, kart.yakinda == nil {
            NavigationLink(destination: TekneEkrani(sayfaAdi: h)) {
                icerik(etkin: true)
            }
            .buttonStyle(.plain)
        } else {
            icerik(etkin: false)
        }
    }

    private func icerik(etkin: Bool) -> some View {
        HStack(spacing: 14) {
            Sembol(ad: TekneSimge.kart(kart.hedef, baslik: kart.baslik), yedek: "checklist")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Renk.mavi)
                .frame(width: 46, height: 46)
                .background(Renk.tint)
                .cornerRadius(14)
            VStack(alignment: .leading, spacing: 4) {
                Text(kart.baslik)
                    .font(.headline)
                    .foregroundColor(Renk.murekkep)
                    .multilineTextAlignment(.leading)
                if let a = kart.aciklama, !a.isEmpty {
                    Text(a)
                        .font(.footnote)
                        .foregroundColor(Renk.soluk)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let y = kart.yakinda {
                    Label(y, systemImage: "clock")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Renk.amber)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            if etkin {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Renk.soluk)
            }
        }
        .padding(16)
        .kart()
        .opacity(etkin ? 1 : 0.6)
    }
}

/// Çek listesi satırı. Alt hususları varsa dokununca açılır.
struct TekneMaddeSatiri: View {
    let sira: Int
    let madde: TekneMadde
    @State private var acik = false

    private var altVar: Bool { !(madde.alt ?? []).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if altVar {
                    withAnimation(.easeInOut(duration: 0.2)) { acik.toggle() }
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Text("\(sira)")
                        .font(.footnote.weight(.bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Renk.lacivert)
                        .clipShape(Circle())
                    if let s = madde.simge {
                        Sembol(ad: TekneSimge.madde(s), yedek: "doc.text")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Renk.mavi)
                            .frame(width: 28, height: 28)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(madde.baslik)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Renk.murekkep)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if let n = madde.not, !n.isEmpty {
                            Text(n)
                                .font(.caption)
                                .foregroundColor(Renk.soluk)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                    if altVar {
                        Image(systemName: "chevron.down")
                            .font(.footnote.weight(.semibold))
                            .rotationEffect(.degrees(acik ? 180 : 0))
                            .foregroundColor(Renk.soluk)
                            .padding(.top, 5)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if acik, let alt = madde.alt {
                VStack(alignment: .leading, spacing: 6) {
                    if let e = madde.etiket, !e.isEmpty {
                        Text(e)
                            .font(.caption.weight(.bold))
                            .foregroundColor(Renk.mavi)
                    }
                    ForEach(Array(alt.enumerated()), id: \.offset) { _, a in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Renk.mavi)
                                .frame(width: 5, height: 5)
                                .padding(.top, 7)
                            Text(a)
                                .font(.footnote)
                                .foregroundColor(Renk.murekkep)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Renk.ikincil)
                .cornerRadius(12)
                .padding(.top, 10)
            }
        }
        .padding(14)
        .kart()
    }
}

/// Av aracı kartı (amator_balikci_av_araci.php): dokununca açıklama ve mevzuat açılır.
struct TekneAcilirKart: View {
    let blok: TekneBlok
    @State private var acik = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { acik.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Text(blok.simge ?? "")
                        .font(.system(size: 22))
                        .frame(width: 44, height: 44)
                        .background(Renk.tint)
                        .cornerRadius(12)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(blok.baslik ?? "")
                            .font(.headline)
                            .foregroundColor(Renk.murekkep)
                            .multilineTextAlignment(.leading)
                        if let o = blok.ozet {
                            Text(o)
                                .font(.caption)
                                .foregroundColor(Renk.soluk)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .rotationEffect(.degrees(acik ? 90 : 0))
                        .foregroundColor(Renk.soluk)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if acik {
                VStack(alignment: .leading, spacing: 10) {
                    if let a = blok.aciklama {
                        Text(a)
                            .font(.callout)
                            .foregroundColor(Renk.murekkep)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let m = blok.mevzuat {
                        (Text("Mevzuat: ").bold() + Text(m))
                            .font(.footnote)
                            .foregroundColor(Renk.murekkep)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Renk.tint)
                            .cornerRadius(12)
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding(14)
        .kart()
    }
}

/// "Resmî kaynak" kutusu.
struct TekneKaynakKarti: View {
    let blok: TekneBlok

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(blok.baslik ?? "Resmî kaynak")
                .font(.headline)
                .foregroundColor(Renk.murekkep)
            if let s = blok.url, let u = URL(string: s), u.scheme == "https" {
                Link(destination: u) {
                    HStack(alignment: .top, spacing: 6) {
                        Text(blok.ad ?? s)
                            .font(.footnote.weight(.semibold))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "arrow.up.right.square")
                            .font(.footnote)
                    }
                    .foregroundColor(Renk.mavi)
                }
            } else if let a = blok.ad {
                Text(a)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Renk.murekkep)
            }
            if let site = blok.site, !site.isEmpty {
                Text(site)
                    .font(.caption2)
                    .foregroundColor(Renk.soluk)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .kart()
    }
}

/// Sitedeki çizgi simgelerin iOS karşılıkları.
enum TekneSimge {
    static func kart(_ hedef: String?, baslik: String) -> String {
        switch hedef ?? "" {
        case "balikci": return "fish"
        case "ozel_tekne": return "sailboat"
        case "ticari-kontrol-liste": return "ferry"
        case "ticari_balikcilik": return "briefcase"
        case "amator_balikcilik": return "figure.fishing"
        case "amator_balikci_av_araci": return "wrench.and.screwdriver"
        case "ozel_tekne_cek_listesi_buyuk": return "arrow.up.left.and.arrow.down.right"
        case "ozel_tekne_cek_listesi_kucuk": return "arrow.down.right.and.arrow.up.left"
        case "": return baslik.contains("Boy") ? "ruler" : "checklist"
        default: return "checklist"
        }
    }

    static func madde(_ ad: String) -> String {
        switch ad {
        case "book": return "book"
        case "eye": return "binoculars"
        case "file": return "doc.text"
        case "fire": return "flame"
        case "lifebuoy": return "lifepreserver"
        case "map-pin": return "mappin.and.ellipse"
        case "plus": return "cross.case"
        case "radio": return "antenna.radiowaves.left.and.right"
        case "shield": return "shield"
        case "user-card": return "person.text.rectangle"
        case "volume": return "speaker.wave.2"
        case "zap": return "flashlight.on.fill"
        case "users": return "person.2"
        case "compass": return "safari"
        case "trash": return "trash"
        default: return "doc.text"
        }
    }
}
