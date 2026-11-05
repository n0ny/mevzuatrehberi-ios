import SwiftUI

// turler.php — Tür kartları sayfasının karşılığı.

struct TurlerEkrani: View {
    @EnvironmentObject var depo: VeriDeposu
    @State private var sorgu = ""
    @State private var grup = ""
    @State private var buyuk: Tur?

    var body: some View {
        let sirali = depo.turler.sorted { Metin.once($0.ad, $1.ad) }
        var gruplar: [String] = []
        for t in sirali where !gruplar.contains(t.grup) {
            gruplar.append(t.grup)
        }
        let q = sorgu.lowercased(with: TRMetin.tr).trimmingCharacters(in: .whitespacesAndNewlines)
        let liste = sirali.filter { t in
            (q.isEmpty || t.aramaSite.contains(q)) && (grup.isEmpty || t.grup == grup)
        }

        return YenilenebilirKaydirma {
            VStack(spacing: 0) {
                Kahraman(baslik: "Tür kartları", aciklama: "Asgari av boyu ve yasak dönemlerini tek ekranda gör.") {
                    if !sirali.isEmpty {
                        (Text("\(sirali.count)").bold() + Text(" tür"))
                            .font(.footnote)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.14))
                            .cornerRadius(999)
                    }
                }

                LazyVStack(alignment: .leading, spacing: 12) {
                    if sirali.isEmpty {
                        BosKutu(metin: "Henüz tür kartı eklenmedi.")
                    } else {
                        AramaKutusu(ipucu: "Tür adı ara (ör. hamsi, lüfer)", metin: $sorgu)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Renk.cizgi, lineWidth: 1).padding(.top, 6))
                        if gruplar.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    GrupCipi(baslik: "Tümü", secili: grup.isEmpty) { grup = "" }
                                    ForEach(gruplar, id: \.self) { g in
                                        GrupCipi(baslik: g, secili: grup == g) { grup = g }
                                    }
                                }
                            }
                        }
                        if liste.isEmpty {
                            BosKutu(metin: "Aramanla eşleşen tür bulunamadı.")
                        } else {
                            ForEach(liste) { t in
                                TurKarti(tur: t) { buyuk = t }
                            }
                        }
                    }

                    turUyarisi
                        .padding(.top, 4)
                }
                .padding(16)
            }
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle("Mevzuat Rehberi")
        .markaBasligi()
        .fullScreenCover(item: $buyuk) { t in
            BuyukFoto(url: t.fotoURL, ad: t.ad, kredi: t.fotoKredi)
        }
    }

    private var turUyarisi: some View {
        VStack(alignment: .leading, spacing: 8) {
            (Text("Kontrol gerekli: ").bold()
                + Text("Asgari boylar ve yasak dönemleri bölgeye, av aracına ve yıla göre değişebilir. İşlem yapmadan önce güncel tebliği kontrol edin:"))
                .font(.footnote)
                .foregroundColor(Renk.murekkep)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                if let u = URL(string: "https://resmigazete.gov.tr/eskiler/2024/08/20240811-3.htm") {
                    Link("6/1 Ticari Tebliğ", destination: u)
                }
                if let u = URL(string: "https://resmigazete.gov.tr/eskiler/2024/08/20240811-4.htm") {
                    Link("6/2 Amatör Tebliğ", destination: u)
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundColor(Renk.mavi)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Renk.amberZemin)
        .cornerRadius(12)
    }
}

struct GrupCipi: View {
    let baslik: String
    let secili: Bool
    let eylem: () -> Void

    var body: some View {
        Button(action: eylem) {
            Text(baslik)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundColor(secili ? .white : Renk.murekkep)
                .background(secili ? Renk.lacivert : Renk.kart)
                .cornerRadius(999)
                .overlay(RoundedRectangle(cornerRadius: 999).stroke(secili ? Color.clear : Renk.cizgi, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct BosKutu: View {
    let metin: String

    var body: some View {
        Text(metin)
            .font(.subheadline)
            .foregroundColor(Renk.soluk)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .kart()
    }
}

/// Tür kartı (turler.php article.sp).
struct TurKarti: View {
    let tur: Tur
    let fotoyuAc: () -> Void

    var body: some View {
        let tekBoy = (tur.boyTicari == nil) != (tur.boyAmator == nil)
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if tur.fotoURL != nil {
                    Button(action: fotoyuAc) {
                        UzakFoto(url: tur.fotoURL)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                            .overlay(
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 30, height: 30)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(9)
                                    .padding(8),
                                alignment: .bottomLeading)
                    }
                    .buttonStyle(.plain)
                } else {
                    ZStack {
                        Renk.ikincil
                        VStack(spacing: 6) {
                            Image(systemName: "photo")
                            Text("Fotoğraf eklenmedi").font(.caption)
                        }
                        .foregroundColor(Renk.soluk)
                    }
                    .frame(height: 140)
                }
                Text(tur.grup)
                    .font(.caption.weight(.bold))
                    .foregroundColor(Renk.lacivert)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.92))
                    .cornerRadius(999)
                    .padding(10)
            }
            .overlay(fotoKredisi, alignment: .bottomTrailing)

            VStack(alignment: .leading, spacing: 8) {
                Text(tur.ad)
                    .font(.title3.weight(.bold))
                    .foregroundColor(Renk.murekkep)
                if let b = tur.bilimselAd {
                    Text(b).italic().font(.footnote).foregroundColor(Renk.soluk)
                }
                if let d = tur.digerAdlar {
                    Text("Diğer adları: \(d)").font(.footnote).foregroundColor(Renk.soluk)
                }
                if tur.boyTicari != nil || tur.boyAmator != nil || tur.yasakDonemi != nil {
                    VStack(spacing: 8) {
                        if tekBoy {
                            if let t = tur.boyTicari { Bilgi(etiket: "Asgari boy · Ticari", deger: t) }
                            if let a = tur.boyAmator { Bilgi(etiket: "Asgari boy · Amatör", deger: a) }
                        } else if let t = tur.boyTicari, let a = tur.boyAmator {
                            HStack(alignment: .top, spacing: 8) {
                                Bilgi(etiket: "Asgari boy · Ticari", deger: t)
                                Bilgi(etiket: "Asgari boy · Amatör", deger: a)
                            }
                        }
                        if let y = tur.yasakDonemi {
                            Bilgi(etiket: "Yasak dönemi / bölgesi", deger: y, yasak: true)
                        }
                    }
                }
                if let n = tur.notlar {
                    Text(n)
                        .font(.footnote)
                        .foregroundColor(Renk.murekkep)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    if let k = tur.kaynak {
                        Text("Dayanak: \(k)")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let u = tur.kaynakURL {
                        Link("Resmî metni aç", destination: u)
                            .foregroundColor(Renk.mavi)
                    }
                    if let g = Tarih.gunYaz(tur.guncelleme) {
                        Text("Güncelleme: \(g)")
                    }
                }
                .font(.caption)
                .foregroundColor(Renk.soluk)
            }
            .padding(14)
        }
        .kart()
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var fotoKredisi: some View {
        if tur.fotoURL != nil, let k = tur.fotoKredi {
            Group {
                if let u = tur.fotoKaynakURL {
                    Link(destination: u) { Text("Fotoğraf: \(k)") }
                } else {
                    Text("Fotoğraf: \(k)")
                }
            }
            .font(.caption2)
            .lineLimit(1)
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.5))
            .cornerRadius(6)
            .padding(8)
            .frame(maxWidth: 260, alignment: .trailing)
        }
    }

    struct Bilgi: View {
        let etiket: String
        let deger: String
        var yasak = false

        var body: some View {
            VStack(alignment: .leading, spacing: 3) {
                Text(etiket)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(yasak ? Renk.kirmizi : Renk.soluk)
                Text(deger)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(yasak ? Renk.kirmizi : Renk.murekkep)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(yasak ? Renk.kirmiziZemin : Renk.ikincil)
            .cornerRadius(10)
        }
    }
}

/// Fotoğrafın tam ekran, kırpılmadan gösterimi. Dokununca 2,5 kat yakınlaşır; iki parmakla da yakınlaştırılır.
struct BuyukFoto: View {
    let url: URL?
    let ad: String
    let kredi: String?
    @Environment(\.dismiss) private var kapat
    @State private var olcek: CGFloat = 1
    @State private var sonOlcek: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            VStack(spacing: 10) {
                Spacer()
                UzakFoto(url: url, dolgu: false)
                    .scaleEffect(olcek)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { d in olcek = max(1, min(4, sonOlcek * d)) }
                            .onEnded { _ in sonOlcek = olcek }
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            olcek = olcek > 1 ? 1 : 2.5
                            sonOlcek = olcek
                        }
                    }
                Spacer()
                VStack(spacing: 4) {
                    Text(ad).font(.headline).foregroundColor(.white)
                    if let k = kredi {
                        Text(k).font(.caption).foregroundColor(.white.opacity(0.7))
                    }
                    Text("Yakınlaştırmak için fotoğrafa dokunun")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.bottom, 16)
            }
            Button {
                kapat()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(16)
            }
        }
    }
}
