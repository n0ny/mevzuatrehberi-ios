import SwiftUI
import UIKit

// Sitedeki renkler (mr-ui.css / gece-modu.php) ile aynı palet.

extension UIColor {
    convenience init(onaltilik: UInt32) {
        let r = CGFloat((onaltilik >> 16) & 0xFF) / 255
        let g = CGFloat((onaltilik >> 8) & 0xFF) / 255
        let b = CGFloat(onaltilik & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }

    static func dinamik(_ acik: UInt32, _ koyu: UInt32) -> UIColor {
        return UIColor { ozellik in
            ozellik.userInterfaceStyle == .dark ? UIColor(onaltilik: koyu) : UIColor(onaltilik: acik)
        }
    }
}

enum Renk {
    static let lacivert = Color(UIColor(onaltilik: 0x0B2E4A))
    static let mavi = Color(UIColor.dinamik(0x0B5CAD, 0x7FB4EA))
    static let tint = Color(UIColor.dinamik(0xE6F0FA, 0x16304A))
    static let zemin = Color(UIColor.dinamik(0xF2F5F8, 0x0B1520))
    static let kart = Color(UIColor.dinamik(0xFFFFFF, 0x132130))
    static let ikincil = Color(UIColor.dinamik(0xF6F9FC, 0x0F1B27))
    static let murekkep = Color(UIColor.dinamik(0x12263A, 0xE3EAF1))
    static let soluk = Color(UIColor.dinamik(0x566878, 0x9AAEC1))
    static let cizgi = Color(UIColor.dinamik(0xDCE4EC, 0x26384A))
    static let yesil = Color(UIColor.dinamik(0x17804A, 0x5FCF9A))
    static let yesilZemin = Color(UIColor.dinamik(0xE7F6EE, 0x11291F))
    static let kirmizi = Color(UIColor.dinamik(0xB42335, 0xF08D99))
    static let kirmiziZemin = Color(UIColor.dinamik(0xFCECEE, 0x2C151A))
    static let amber = Color(UIColor.dinamik(0x8A5A00, 0xF0C070))
    static let amberZemin = Color(UIColor.dinamik(0xFFF6E0, 0x2A2210))

    static let kahramanAcik = [UIColor(onaltilik: 0x08243A), UIColor(onaltilik: 0x0B2E4A), UIColor(onaltilik: 0x11456B)]
    static let kahramanKoyu = [UIColor(onaltilik: 0x050E17), UIColor(onaltilik: 0x08223A), UIColor(onaltilik: 0x0D3556)]

    /// Gezinme çubuğu: sitedeki lacivert üst alanla aynı.
    static func gezinmeCubugunuAyarla() {
        let gorunum = UINavigationBarAppearance()
        gorunum.configureWithOpaqueBackground()
        gorunum.backgroundColor = UIColor.dinamik(0x08243A, 0x050E17)
        gorunum.shadowColor = .clear
        gorunum.titleTextAttributes = [.foregroundColor: UIColor.white]
        gorunum.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        let cubuk = UINavigationBar.appearance()
        cubuk.standardAppearance = gorunum
        cubuk.scrollEdgeAppearance = gorunum
        cubuk.compactAppearance = gorunum
        cubuk.tintColor = .white
    }
}

/// Sitedeki "hero": lacivert geçişli üst alan, büyük başlık ve açıklama.
struct Kahraman<Icerik: View>: View {
    let baslik: String
    let aciklama: String?
    let icerik: Icerik
    @Environment(\.colorScheme) private var sema

    init(baslik: String, aciklama: String? = nil, @ViewBuilder icerik: () -> Icerik) {
        self.baslik = baslik
        self.aciklama = aciklama
        self.icerik = icerik()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(baslik)
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            if let a = aciklama {
                Text(a)
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            icerik
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(gradient: Gradient(colors: (sema == .dark ? Renk.kahramanKoyu : Renk.kahramanAcik).map { Color($0) }),
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea(edges: .top)
        )
    }
}

extension Kahraman where Icerik == EmptyView {
    init(baslik: String, aciklama: String? = nil) {
        self.init(baslik: baslik, aciklama: aciklama) { EmptyView() }
    }
}

/// Kahraman alanındaki beyaz arama kutusu.
struct AramaKutusu: View {
    let ipucu: String
    @Binding var metin: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Renk.soluk)
            TextField(ipucu, text: $metin)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .foregroundColor(Renk.murekkep)
            if !metin.isEmpty {
                Button {
                    metin = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Renk.soluk)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Renk.kart)
        .cornerRadius(14)
        .padding(.top, 6)
    }
}

/// Sitedeki beyaz kart görünümü.
struct KartStili: ViewModifier {
    var vurgulu = false

    func body(content: Content) -> some View {
        content
            .background(Renk.kart)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(vurgulu ? Renk.mavi.opacity(0.45) : Renk.cizgi, lineWidth: 1)
            )
    }
}

extension View {
    func kart(vurgulu: Bool = false) -> some View {
        modifier(KartStili(vurgulu: vurgulu))
    }
}

/// Uyarı kutuları (Kontrol gerekli / Dikkat).
struct UyariKutusu: View {
    enum Tur { case bilgi, dikkat }
    let tur: Tur
    let baslik: String
    let metin: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: tur == .dikkat ? "exclamationmark.triangle" : "info.circle")
                .foregroundColor(tur == .dikkat ? Renk.kirmizi : Renk.amber)
            (Text(baslik + " ").bold() + Text(metin))
                .font(.footnote)
                .foregroundColor(Renk.murekkep)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tur == .dikkat ? Renk.kirmiziZemin : Renk.amberZemin)
        .cornerRadius(12)
    }
}

/// Hap biçimli etiket.
struct Hap: View {
    let metin: String
    var renk: Color = Renk.mavi
    var zemin: Color = Renk.tint

    var body: some View {
        Text(metin)
            .font(.caption.weight(.semibold))
            .foregroundColor(renk)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(zemin)
            .cornerRadius(999)
    }
}

/// Açılır/kapanır bölüm başlığı (ör. "Mevzuat dayanağını göster").
struct AcilirBolum<Icerik: View>: View {
    let sembol: String
    let baslik: String
    var altBaslik: String? = nil
    @ViewBuilder let icerik: () -> Icerik
    @State private var acik = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { acik.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: sembol)
                        .foregroundColor(Renk.mavi)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(baslik)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Renk.murekkep)
                        if let a = altBaslik {
                            Text(a)
                                .font(.caption)
                                .foregroundColor(Renk.soluk)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(acik ? 180 : 0))
                        .foregroundColor(Renk.soluk)
                }
                .padding(12)
                .background(Renk.ikincil)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            if acik {
                VStack(alignment: .leading, spacing: 12) {
                    icerik()
                }
                .padding(.top, 12)
            }
        }
    }
}

/// Resmî kaynak satırı (kaynaklar.js'deki official-source bloğu).
struct ResmiKaynakSatiri: View {
    let kaynak: ResmiKaynak

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Resmî kaynak")
                .font(.caption2.weight(.semibold))
                .foregroundColor(Renk.soluk)
            Link(destination: kaynak.url) {
                HStack(alignment: .top, spacing: 6) {
                    Text(kaynak.ad)
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "arrow.up.right.square")
                        .font(.footnote)
                }
                .foregroundColor(Renk.mavi)
            }
            Text(kaynak.site)
                .font(.caption2)
                .foregroundColor(Renk.soluk)
            if !kaynak.eslesti {
                Text("Bu kayıt için ilgili mevzuatı Mevzuat Bilgi Sistemi’nde arayınız.")
                    .font(.caption2)
                    .foregroundColor(Renk.soluk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Renk.tint.opacity(0.6))
        .cornerRadius(10)
    }
}

/// "Resmî kaynaklar" listesi (mevzuat, sevk sayfalarının altı).
struct ResmiKaynakListesi: View {
    let liste: KaynakListesi

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Resmî kaynaklar")
                .font(.headline)
                .foregroundColor(Renk.murekkep)
            VStack(spacing: 0) {
                ForEach(Array(liste.tumListe.enumerated()), id: \.offset) { sira, k in
                    if let u = URL(string: k.url) {
                        Link(destination: u) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(k.ad)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundColor(Renk.murekkep)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(KaynakListesi.alanAdi(k.url))
                                        .font(.caption2)
                                        .foregroundColor(Renk.soluk)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(Renk.mavi)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                        }
                        if sira < liste.tumListe.count - 1 {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
            }
            .kart()
            Text("Mevzuat Rehberi resmî bir kurum uygulaması değildir ve hiçbir kamu kurumunu temsil etmez. İçerikler bilgilendirme amaçlıdır; resmî işlemlerde yukarıdaki kaynaklardaki güncel metinler esas alınmalıdır.")
                .font(.caption)
                .foregroundColor(Renk.soluk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
