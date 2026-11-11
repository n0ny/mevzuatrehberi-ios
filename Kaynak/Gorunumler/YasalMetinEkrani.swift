import SwiftUI

// MARK: - Veri (api/yasal-metin.php — sitedeki gizlilik-politikasi.php / kvkk.php'den okunur)

struct YasalMetin: Codable {
    let sayfa: String
    let baslik: String
    let aciklama: String
    let tarih: String
    let bloklar: [Blok]

    /// tur: baslik / altbaslik / paragraf / liste / tablo / kutu / baglanti
    struct Blok: Codable {
        let tur: String
        var metin: String?
        var maddeler: [String]?
        var basliklar: [String]?
        var satirlar: [[String]]?
        /// Kutu türü: bilgi / uyari / olumlu / iletisim
        var kutu: String?
        var adres: String?
        var baglanti: Baglanti?
    }

    struct Baglanti: Codable {
        let metin: String
        let adres: String
    }
}

// MARK: - Ekran

/// Gizlilik Politikası ve KVKK Aydınlatma Metni — uygulamanın kendi ekranı.
/// Metin sitedeki sayfadan gelir; site güncellenince burası da güncellenir.
struct YasalMetinEkrani: View {
    /// "gizlilik" veya "kvkk"
    let sayfa: String
    @State private var veri: YasalMetin?
    @State private var hata: String?

    private var yedekBaslik: String { sayfa == "kvkk" ? "KVKK Aydınlatma Metni" : "Gizlilik Politikası" }

    var body: some View {
        YenilenebilirKaydirma(eylem: { await yukle() }) {
            VStack(spacing: 0) {
                Kahraman(baslik: veri.map { $0.baslik.isEmpty ? yedekBaslik : $0.baslik } ?? yedekBaslik,
                         aciklama: veri.flatMap { $0.aciklama.isEmpty ? nil : $0.aciklama }) {
                    if let t = veri?.tarih, !t.isEmpty {
                        Text("Son güncelleme: \(t)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Capsule())
                    }
                }
                VStack(alignment: .leading, spacing: 14) {
                    if let v = veri {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(v.bloklar.enumerated()), id: \.offset) { _, b in
                                YasalBlok(blok: b)
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .kart()
                    } else if let h = hata {
                        UyariKutusu(tur: .bilgi, baslik: "Metin yüklenemedi.", metin: h)
                    } else {
                        HStack { Spacer(); ProgressView(); Spacer() }.padding(.top, 20)
                    }
                }
                .padding(16)
            }
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle(yedekBaslik)
        .markaBasligi()
        .task { if veri == nil { await yukle() } }
    }

    private func yukle() async {
        do {
            veri = try await APIIstemci.yasalMetin(sayfa: sayfa)
            hata = nil
        } catch {
            if veri == nil { hata = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
        }
    }
}

private struct YasalBlok: View {
    let blok: YasalMetin.Blok
    @Environment(\.openURL) private var ac

    var body: some View {
        switch blok.tur {
        case "baslik":
            VStack(alignment: .leading, spacing: 6) {
                Text(blok.metin ?? "")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(Renk.murekkep)
                    .fixedSize(horizontal: false, vertical: true)
                Rectangle().fill(Renk.cizgi).frame(height: 1)
            }
            .padding(.top, 10)
        case "altbaslik":
            Text(blok.metin ?? "")
                .font(.headline)
                .foregroundColor(Renk.murekkep)
                .padding(.top, 4)
        case "paragraf":
            Text(blok.metin ?? "")
                .font(.subheadline)
                .foregroundColor(Renk.murekkep)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        case "baglanti":
            Button {
                if let a = blok.adres, let u = URL(string: a) { ac(u) }
            } label: {
                Text(blok.metin ?? "")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Renk.mavi)
            }
            .buttonStyle(.plain)
        case "liste":
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array((blok.maddeler ?? []).enumerated()), id: \.offset) { _, m in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(Renk.mavi).frame(width: 6, height: 6).padding(.top, 7)
                        Text(m)
                            .font(.subheadline)
                            .foregroundColor(Renk.murekkep)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case "tablo":
            tablo
        case "kutu":
            kutu
        default:
            EmptyView()
        }
    }

    /// Telefona sığsın diye her satır ayrı bir bölüm: ilk sütun başlık, diğerleri altında.
    private var tablo: some View {
        let basliklar = blok.basliklar ?? []
        let satirlar = blok.satirlar ?? []
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(satirlar.enumerated()), id: \.offset) { i, satir in
                if i > 0 { Rectangle().fill(Renk.cizgi).frame(height: 1) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(satir.first ?? "")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Renk.murekkep)
                    ForEach(Array(satir.dropFirst().enumerated()), id: \.offset) { k, hucre in
                        if basliklar.count > 2, k + 1 < basliklar.count {
                            Text(basliklar[k + 1])
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(Renk.soluk)
                        }
                        Text(hucre)
                            .font(.footnote)
                            .foregroundColor(Renk.murekkep)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Renk.cizgi, lineWidth: 1))
    }

    private var kutu: some View {
        let yazi: Color
        let zemin: Color
        switch blok.kutu {
        case "uyari": yazi = Renk.amber; zemin = Renk.amberZemin
        case "olumlu": yazi = Renk.yesil; zemin = Renk.yesilZemin
        default: yazi = Renk.murekkep; zemin = Renk.tint
        }
        let satirlar = (blok.metin ?? "").components(separatedBy: "\n")
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(satirlar.enumerated()), id: \.offset) { _, s in
                if let b = blok.baglanti, s == b.metin {
                    Button {
                        if let u = URL(string: b.adres) { ac(u) }
                    } label: {
                        Text(s).font(.subheadline.weight(.bold)).foregroundColor(Renk.mavi)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(s)
                        .font(.footnote)
                        .foregroundColor(yazi)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(zemin)
        .cornerRadius(12)
    }
}
