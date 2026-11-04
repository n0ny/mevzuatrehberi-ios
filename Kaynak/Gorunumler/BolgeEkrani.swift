import SwiftUI

struct BolgeEkrani: View {
    @EnvironmentObject var depo: VeriDeposu
    @State private var sorgu = ""
    @State private var deniz = "Tümü"

    private static let denizSirasi = ["Karadeniz", "Marmara", "Ege", "Akdeniz", "İç Sular"]

    private var denizler: [String] {
        let mevcut = Set(depo.bolgeler.map { $0.deniz })
        var sirali = BolgeEkrani.denizSirasi.filter { mevcut.contains($0) }
        sirali.append(contentsOf: mevcut.subtracting(sirali).sorted { Metin.once($0, $1) })
        return ["Tümü"] + sirali
    }

    var body: some View {
        let kelimeler = Metin.kelimeler(sorgu)
        let liste = depo.bolgeler
            .filter { deniz == "Tümü" || $0.deniz == deniz }
            .filter { kelimeler.isEmpty || Metin.eslesir($0.arama, kelimeler) }
        let iller = Dictionary(grouping: liste, by: { $0.il })
        let ilAdlari = iller.keys.sorted { Metin.once($0, $1) }
        List {
            Section {
                CipSatiri(secenekler: denizler, secili: $deniz)
            }
            if liste.isEmpty {
                BosDurum(metin: "Sonuç bulunamadı.", sembol: "magnifyingglass")
            } else {
                ForEach(ilAdlari, id: \.self) { il in
                    Section(header: Text("\(il) · \(iller[il]?.count ?? 0)")) {
                        ForEach(iller[il] ?? []) { b in
                            NavigationLink(destination: BolgeDetay(bolge: b)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(b.baslik)
                                        .font(.subheadline)
                                        .lineLimit(3)
                                    Text(Metin.birlestir([b.ilce, b.yasakTuru]))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $sorgu, placement: .navigationBarDrawer(displayMode: .always), prompt: "İl, ilçe veya bölge ara")
        .disableAutocorrection(true)
        .navigationTitle("Bölge Yasakları")
    }
}

struct BolgeDetay: View {
    let bolge: Bolge

    var body: some View {
        List {
            Section {
                Text(bolge.baslik)
                    .font(.headline)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                BilgiSatiri(baslik: "Yer", deger: bolge.deniz + " · " + bolge.yer)
                BilgiSatiri(baslik: "Yasak türü", deger: bolge.yasakTuru)
                BilgiSatiri(baslik: "İzin verilen av aracı", deger: bolge.izinliAvAraci)
                if bolge.baslangic != nil || bolge.bitis != nil {
                    BilgiSatiri(baslik: "Geçerlilik",
                                deger: Metin.birlestir([Tarih.gunYaz(bolge.baslangic), "–", Tarih.gunYaz(bolge.bitis)]))
                }
            }
            if bolge.aciklama != nil || bolge.kapsam != nil {
                Section(header: Text("Açıklama")) {
                    BilgiSatiri(baslik: "Açıklama", deger: bolge.aciklama)
                    if bolge.kapsam != bolge.aciklama {
                        BilgiSatiri(baslik: "Kapsam", deger: bolge.kapsam)
                    }
                }
            }
            Section(header: Text("Dayanak")) {
                BilgiSatiri(baslik: "Mevzuat", deger: bolge.mevzuatAdi)
                BilgiSatiri(baslik: "Madde", deger: bolge.mevzuatMadde)
                BilgiSatiri(baslik: "Harita", deger: bolge.haritaNo)
                BilgiSatiri(baslik: "Kaynak", deger: bolge.kaynak)
            }
            if let k = bolge.koordinatlar {
                Section(header: Text("Koordinatlar")) {
                    Text(k)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Section {
                UyariNotu(metin: "Kesin sınırlar için ilgili tebliğ ve haritası esas alınır. " + Notlar.resmiMetin)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Bölge")
        .navigationBarTitleDisplayMode(.inline)
    }
}
