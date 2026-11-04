import SwiftUI

struct AramaEkrani: View {
    @EnvironmentObject var depo: VeriDeposu
    @State private var sorgu = ""

    private let ornekler = ["boğaz", "trol", "gırgır", "mesafe", "ruhsat", "dalış", "seyir", "algarna"]

    var body: some View {
        let sonuc = depo.ara(sorgu)
        List {
            if sorgu.trimmingCharacters(in: .whitespaces).isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Soru yerine anahtar kelime yazın.")
                            .font(.headline)
                        Text("Örneğin \"boğazda avcılık yasak mı\" yerine sadece \"boğaz\" yazın. Birden çok kelime yazarsanız hepsinin geçtiği kayıtlar gelir.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        OrnekKelimeler(kelimeler: ornekler) { sorgu = $0 }
                    }
                    .padding(.vertical, 6)
                }
            } else if sonuc.sonuclar.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        BosDurum(metin: "Sonuç bulunamadı.", sembol: "magnifyingglass")
                        Text("Soru yerine anahtar kelime yazın. Örnek kelimeler:")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        OrnekKelimeler(kelimeler: ornekler) { sorgu = $0 }
                    }
                }
            } else {
                Section(header: Text("\(sonuc.sonuclar.count) sonuç"),
                        footer: Text(sonuc.kesildi ? "Daha fazla sonuç var. Aramayı daraltmak için kelime ekleyin." : Notlar.resmiMetin)) {
                    ForEach(sonuc.sonuclar) { s in
                        AramaSatiri(sonuc: s)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $sorgu, placement: .navigationBarDrawer(displayMode: .always), prompt: "Anahtar kelime")
        .disableAutocorrection(true)
        .navigationTitle("Mevzuat Ara")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct OrnekKelimeler: View {
    let kelimeler: [String]
    let sec: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(kelimeler, id: \.self) { k in
                    Cip(baslik: k, secili: false) { sec(k) }
                }
            }
        }
    }
}

struct AramaSatiri: View {
    let sonuc: AramaSonucu

    var body: some View {
        switch sonuc {
        case .fiil(let f):
            NavigationLink(destination: FiilDetay(fiil: f)) {
                SonucSatiri(tur: "Fiil", renk: .blue, baslik: f.fiil, alt: f.dayanak)
            }
        case .madde(let m):
            NavigationLink(destination: MaddeDetay(madde: m)) {
                SonucSatiri(tur: "Madde", renk: .purple, baslik: m.gorunenBaslik,
                            alt: Metin.birlestir([m.mevzuatAdi, m.no]))
            }
        case .ihlal(let i):
            NavigationLink(destination: IhlalDetay(ihlal: i)) {
                SonucSatiri(tur: "İhlal", renk: .orange, baslik: i.ad, alt: i.kategori ?? "")
            }
        case .sevk(let s):
            NavigationLink(destination: SevkDetay(kayit: s)) {
                SonucSatiri(tur: "Sevk", renk: .indigo, baslik: s.gerekce, alt: s.kategori)
            }
        }
    }
}

struct SonucSatiri: View {
    let tur: String
    let renk: Color
    let baslik: String
    let alt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(tur)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(renk)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(renk.opacity(0.12))
                    .cornerRadius(6)
                if !alt.isEmpty {
                    Text(alt)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Text(baslik)
                .font(.subheadline)
                .lineLimit(3)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Detaylar

struct FiilDetay: View {
    let fiil: Fiil

    var body: some View {
        List {
            Section {
                Text(fiil.fiil)
                    .font(.headline)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if let d = fiil.dogrulama {
                    DurumRozeti(durum: d.uppercased(with: Metin.tr).contains("DOĞRULANDI") ? "green" : "yellow", metin: d)
                }
            }
            Section(header: Text("Dayanak")) {
                BilgiSatiri(baslik: "Mevzuat", deger: fiil.mevzuat)
                BilgiSatiri(baslik: "Madde", deger: fiil.madde)
                BilgiSatiri(baslik: "Fıkra / bent", deger: fiil.bent)
                BilgiSatiri(baslik: "Kaynak", deger: fiil.kaynak)
            }
            if fiil.aciklama != nil || fiil.kapsam != nil || fiil.notlar != nil {
                Section(header: Text("Ne anlatıyor?")) {
                    BilgiSatiri(baslik: "Açıklama", deger: fiil.aciklama)
                    BilgiSatiri(baslik: "Kapsam", deger: fiil.kapsam)
                    BilgiSatiri(baslik: "Not", deger: fiil.notlar)
                }
            }
            Section {
                UyariNotu(metin: Notlar.resmiMetin)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Fiil")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MaddeDetay: View {
    let madde: Madde

    var body: some View {
        List {
            Section(header: Text(madde.no)) {
                if let b = madde.baslik {
                    Text(b)
                        .font(.headline)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(madde.metin)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section(header: Text("Mevzuat")) {
                BilgiSatiri(baslik: "Adı", deger: madde.mevzuatAdi)
                if let u = madde.kaynakURL {
                    KaynakBaglantisi(baslik: "Kaynağı aç", url: u)
                }
            }
            Section {
                UyariNotu(metin: Notlar.resmiMetin)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Madde")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct IhlalDetay: View {
    @EnvironmentObject var depo: VeriDeposu
    let ihlal: Ihlal

    var body: some View {
        let ilgili = depo.ilgiliMaddeler(ihlal: ihlal)
        List {
            Section {
                Text(ihlal.ad)
                    .font(.headline)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                BilgiSatiri(baslik: "Kategori", deger: ihlal.kategori)
                BilgiSatiri(baslik: "Açıklama", deger: ihlal.aciklama)
            }
            if !ilgili.isEmpty {
                Section(header: Text("İlgili maddeler")) {
                    ForEach(ilgili) { m in
                        NavigationLink(destination: MaddeDetay(madde: m)) {
                            SonucSatiri(tur: m.no, renk: .purple, baslik: m.gorunenBaslik, alt: m.mevzuatAdi ?? "")
                        }
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
        .navigationTitle("İhlal")
        .navigationBarTitleDisplayMode(.inline)
    }
}
