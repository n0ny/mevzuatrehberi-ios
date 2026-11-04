import SwiftUI

struct YaptirimEkrani: View {
    @EnvironmentObject var depo: VeriDeposu
    @State private var sorgu = ""

    var body: some View {
        let kelimeler = Metin.kelimeler(sorgu)
        let liste = depo.yaptirimlar.filter { kelimeler.isEmpty || Metin.eslesir($0.arama, kelimeler) }
        let yil = depo.yaptirimlar.map { $0.yil }.max()
        List {
            if liste.isEmpty {
                BosDurum(metin: "Sonuç bulunamadı.", sembol: "magnifyingglass")
            } else {
                Section(header: Text(yil.map { "\($0) tutarları · \(liste.count) kayıt" } ?? "\(liste.count) kayıt"),
                        footer: Text(Notlar.resmiMetin)) {
                    ForEach(liste) { y in
                        NavigationLink(destination: YaptirimDetay(yaptirim: y)) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(y.nitelik)
                                    .font(.subheadline)
                                    .lineLimit(3)
                                HStack(spacing: 8) {
                                    if let c = y.cezaMaddesi {
                                        Text(c)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if let t = y.tutarMetni {
                                        Text(t)
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $sorgu, placement: .navigationBarDrawer(displayMode: .always), prompt: "Fiil veya madde ara")
        .disableAutocorrection(true)
        .navigationTitle("İdari Yaptırımlar")
    }
}

struct YaptirimDetay: View {
    let yaptirim: Yaptirim

    var body: some View {
        List {
            Section {
                Text(yaptirim.nitelik)
                    .font(.headline)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if let t = yaptirim.tutarMetni {
                    HStack {
                        Text("\(yaptirim.yil) idari para cezası")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(t)
                            .font(.title3.weight(.bold))
                            .foregroundColor(.red)
                    }
                }
                BilgiSatiri(baslik: "Hesaplama", deger: yaptirim.hesaplamaTipi)
            }
            Section(header: Text("Dayanak")) {
                BilgiSatiri(baslik: "Olay türü", deger: yaptirim.olayTuru)
                BilgiSatiri(baslik: "Kanun maddesi", deger: yaptirim.kanunMaddesi)
                BilgiSatiri(baslik: "Yönetmelik maddesi", deger: yaptirim.yonetmelikMaddesi)
                BilgiSatiri(baslik: "Tebliğ", deger: yaptirim.tebligMaddesi)
                BilgiSatiri(baslik: "Ceza maddesi", deger: yaptirim.cezaMaddesi)
                BilgiSatiri(baslik: "Kaynak", deger: yaptirim.kaynakMetni)
            }
            if yaptirim.suUrunuElKoyma != nil || yaptirim.vasitaElKoyma != nil {
                Section(header: Text("El koyma")) {
                    BilgiSatiri(baslik: "Su ürünlerine", deger: yaptirim.suUrunuElKoyma)
                    BilgiSatiri(baslik: "İstihsal vasıtasına", deger: yaptirim.vasitaElKoyma)
                }
            }
            if let n = yaptirim.notlar {
                Section(header: Text("Not")) {
                    Text(n)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Section {
                UyariNotu(metin: Notlar.resmiMetin)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .listStyle(.insetGrouped)
        .navigationTitle("İdari Yaptırım")
        .navigationBarTitleDisplayMode(.inline)
    }
}
