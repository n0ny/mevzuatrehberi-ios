import SwiftUI

struct TurlerEkrani: View {
    @EnvironmentObject var depo: VeriDeposu
    @State private var sorgu = ""
    @State private var grup = "Tümü"

    private static let grupSirasi = ["Balık", "Kabuklu", "Yumuşakça", "İçsu", "Diğer"]

    private var gruplar: [String] {
        let mevcut = Set(depo.turler.map { $0.grup })
        var sirali = TurlerEkrani.grupSirasi.filter { mevcut.contains($0) }
        let digerleri = mevcut.subtracting(sirali).sorted { Metin.once($0, $1) }
        sirali.append(contentsOf: digerleri)
        return ["Tümü"] + sirali
    }

    var body: some View {
        let kelimeler = Metin.kelimeler(sorgu)
        let liste = depo.turler
            .filter { grup == "Tümü" || $0.grup == grup }
            .filter { kelimeler.isEmpty || Metin.eslesir($0.arama, kelimeler) }
        List {
            Section {
                CipSatiri(secenekler: gruplar, secili: $grup)
            }
            if liste.isEmpty {
                BosDurum(metin: "Sonuç bulunamadı.", sembol: "magnifyingglass")
            } else {
                Section(header: Text("\(liste.count) tür")) {
                    ForEach(liste) { t in
                        NavigationLink(destination: TurDetay(tur: t)) {
                            TurSatiri(tur: t)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $sorgu, placement: .navigationBarDrawer(displayMode: .always), prompt: "Tür adı ara")
        .disableAutocorrection(true)
        .navigationTitle("Tür Kartları")
    }
}

struct TurSatiri: View {
    let tur: Tur

    var body: some View {
        HStack(spacing: 12) {
            UzakFoto(url: tur.fotoURL)
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(tur.ad)
                    .font(.headline)
                if let b = tur.bilimselAd {
                    Text(b)
                        .font(.caption)
                        .italic()
                        .foregroundColor(.secondary)
                }
                Text(tur.ozet)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

struct TurDetay: View {
    let tur: Tur
    @State private var buyukFoto = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        if tur.fotoURL != nil { buyukFoto = true }
                    } label: {
                        UzakFoto(url: tur.fotoURL)
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipped()
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    if let k = tur.fotoKredi {
                        HStack(spacing: 4) {
                            Text("Fotoğraf: \(k)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            if let u = tur.fotoKaynakURL {
                                Link("(kaynak)", destination: u)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(tur.ad)
                        .font(.title2.weight(.bold))
                    if let b = tur.bilimselAd {
                        Text(b).italic().foregroundColor(.secondary)
                    }
                    if let d = tur.digerAdlar {
                        Text("Diğer adları: \(d)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Text(tur.grup)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.accentColor)
                        .padding(.top, 2)
                }
            }

            if tur.boyTicari != nil || tur.boyAmator != nil {
                Section(header: Text("Asgari avlanabilir boy")) {
                    BilgiSatiri(baslik: "Ticari avcılık", deger: tur.boyTicari)
                    BilgiSatiri(baslik: "Amatör avcılık", deger: tur.boyAmator)
                }
            }
            if let y = tur.yasakDonemi {
                Section(header: Text("Yasak dönemi")) {
                    Text(y)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let n = tur.notlar {
                Section(header: Text("Notlar")) {
                    Text(n)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if tur.kaynak != nil || tur.kaynakURL != nil {
                Section(header: Text("Kaynak")) {
                    BilgiSatiri(baslik: "Dayanak", deger: tur.kaynak)
                    if let u = tur.kaynakURL {
                        KaynakBaglantisi(baslik: "Resmî metni aç", url: u)
                    }
                }
            }
            Section {
                UyariNotu(metin: Notlar.resmiMetin)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .listStyle(.insetGrouped)
        .navigationTitle(tur.ad)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $buyukFoto) {
            BuyukFoto(url: tur.fotoURL, kredi: tur.fotoKredi)
        }
    }
}

/// Fotoğrafın tam ekran, kırpılmadan gösterimi. İki parmakla yakınlaştırılabilir.
struct BuyukFoto: View {
    let url: URL?
    let kredi: String?
    @Environment(\.dismiss) private var kapat
    @State private var olcek: CGFloat = 1
    @State private var sonOlcek: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            VStack {
                Spacer()
                UzakFoto(url: url, dolgu: false)
                    .scaleEffect(olcek)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { d in olcek = max(1, min(4, sonOlcek * d)) }
                            .onEnded { _ in sonOlcek = olcek }
                    )
                    .onTapGesture(count: 2) {
                        olcek = olcek > 1 ? 1 : 2.5
                        sonOlcek = olcek
                    }
                Spacer()
                if let k = kredi {
                    Text(k)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 16)
                }
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
