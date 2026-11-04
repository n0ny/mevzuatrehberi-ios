import SwiftUI

struct SevkEkrani: View {
    @EnvironmentObject var depo: VeriDeposu
    @State private var sorgu = ""

    var body: some View {
        let kelimeler = Metin.kelimeler(sorgu)
        List {
            if kelimeler.isEmpty {
                Section(header: Text("Kategoriler")) {
                    ForEach(kategoriler) { k in
                        NavigationLink(destination: SevkKategoriEkrani(kategori: k.ad)) {
                            HStack {
                                Text(k.ad)
                                Spacer()
                                Text("\(k.sayi)")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } else {
                let bulunan = depo.sevkler.filter { Metin.eslesir($0.arama, kelimeler) }
                if bulunan.isEmpty {
                    BosDurum(metin: "Sonuç bulunamadı. Soru yerine anahtar kelime yazın.", sembol: "magnifyingglass")
                } else {
                    Section(header: Text("\(bulunan.count) kayıt")) {
                        ForEach(bulunan.prefix(150)) { s in
                            NavigationLink(destination: SevkDetay(kayit: s)) {
                                SevkSatiri(kayit: s)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $sorgu, placement: .navigationBarDrawer(displayMode: .always), prompt: "Fiil veya kanun ara")
        .disableAutocorrection(true)
        .navigationTitle("Sevk İşlemleri")
    }

    private var kategoriler: [KategoriSayisi] {
        var sayac: [String: Int] = [:]
        for s in depo.sevkler {
            sayac[s.kategori, default: 0] += 1
        }
        return sayac.keys
            .sorted { Metin.once($0, $1) }
            .map { KategoriSayisi(ad: $0, sayi: sayac[$0] ?? 0) }
    }
}

struct KategoriSayisi: Identifiable {
    let ad: String
    let sayi: Int
    var id: String { ad }
}

struct SevkKategoriEkrani: View {
    @EnvironmentObject var depo: VeriDeposu
    let kategori: String
    @State private var sorgu = ""

    var body: some View {
        let kelimeler = Metin.kelimeler(sorgu)
        let liste = depo.sevkler.filter {
            $0.kategori == kategori && (kelimeler.isEmpty || Metin.eslesir($0.arama, kelimeler))
        }
        List {
            if liste.isEmpty {
                BosDurum(metin: "Sonuç bulunamadı.", sembol: "magnifyingglass")
            } else {
                Section(header: Text("\(liste.count) kayıt")) {
                    ForEach(liste) { s in
                        NavigationLink(destination: SevkDetay(kayit: s)) {
                            SevkSatiri(kayit: s)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $sorgu, prompt: "Bu kategoride ara")
        .disableAutocorrection(true)
        .navigationTitle(kategori)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SevkSatiri: View {
    let kayit: SevkKaydi

    var renk: Color {
        switch kayit.dogrulamaDurumu {
        case "green": return .green
        case "red": return .red
        default: return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(kayit.gerekce)
                .font(.subheadline)
                .lineLimit(3)
            HStack(spacing: 6) {
                Circle().fill(renk).frame(width: 8, height: 8)
                Text(kayit.yasalMadde)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }
}

struct SevkDetay: View {
    let kayit: SevkKaydi

    var body: some View {
        List {
            Section {
                Text(kayit.gerekce)
                    .font(.headline)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                DurumRozeti(durum: kayit.dogrulamaDurumu, metin: kayit.kontrolDurumu)
                if let n = kayit.kontrolNotu {
                    Text(n)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section(header: Text("Yasal işlem")) {
                BilgiSatiri(baslik: "Kategori", deger: kayit.kategori)
                BilgiSatiri(baslik: "Yasal işlem maddesi", deger: kayit.yasalMadde)
                BilgiSatiri(baslik: "Sevk makamı", deger: kayit.sevkMakami ?? "Belirtilmemiş")
                BilgiSatiri(baslik: "Yaptırım durumu", deger: kayit.yaptirimDogrulama)
            }

            liste("Mevzuat dayanakları", kayit.dayanaklar)
            liste("Yaptırımlar", kayit.yaptirimlar)
            liste("İşlemler", kayit.islemler)
            liste("Kaynaklar", kayit.kaynaklar)
            liste("Notlar", kayit.notlar)
            liste("Önceki sevk makamları", kayit.eskiSevkler)

            if kayit.dogrulamaNotu != nil || kayit.dogrulamaTarihi != nil || kayit.resmiKaynakURL != nil {
                Section(header: Text("Doğrulama")) {
                    BilgiSatiri(baslik: "Tarih", deger: Tarih.gunYaz(kayit.dogrulamaTarihi))
                    BilgiSatiri(baslik: "Not", deger: kayit.dogrulamaNotu)
                    if let u = kayit.resmiKaynakURL {
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
        .navigationTitle("Sevk Kaydı")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func liste(_ baslik: String, _ maddeler: [String]) -> some View {
        if !maddeler.isEmpty {
            Section(header: Text(baslik)) {
                MaddeListesi(maddeler: maddeler)
            }
        }
    }
}
