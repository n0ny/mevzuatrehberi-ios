import SwiftUI

struct HesapEkrani: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu
    @State private var cikisSorusu = false

    private var surum: String {
        let s = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(s) (\(b))"
    }

    var body: some View {
        List {
            Section(header: Text("Hesap")) {
                BilgiSatiri(baslik: "Ad", deger: oturum.kullanici?.ad)
                BilgiSatiri(baslik: "Kullanıcı adı", deger: oturum.kullanici?.kullaniciAdi)
            }

            Section(header: Text("İçerik"),
                    footer: Text("İçerik telefona kaydedilir; internet yokken son indirilen veriler gösterilir. Uygulama açıldığında güncellemeler kendiliğinden kontrol edilir.")) {
                HStack {
                    Text("Son kontrol")
                    Spacer()
                    Text(depo.sonKontrol.map { Tarih.anYaz($0) } ?? "Yapılmadı")
                        .foregroundColor(.secondary)
                }
                sayiSatiri("Mevzuat maddesi", depo.maddeler.count)
                sayiSatiri("Fiil", depo.fiiller.count)
                sayiSatiri("Sevk kaydı", depo.sevkler.count)
                sayiSatiri("İdari yaptırım", depo.yaptirimlar.count)
                sayiSatiri("Tür kartı", depo.turler.count)
                sayiSatiri("Bölge yasağı", depo.bolgeler.count)
                if let h = depo.hataMesaji {
                    Text(h)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
                Button {
                    Task { await Eylemler.guncelle(oturum: oturum, depo: depo) }
                } label: {
                    HStack {
                        Text(depo.guncelleniyor ? "Güncelleniyor…" : "Şimdi güncelle")
                        Spacer()
                        if depo.guncelleniyor {
                            ProgressView()
                        }
                    }
                }
                .disabled(depo.guncelleniyor)
            }

            Section {
                Button(role: .destructive) {
                    cikisSorusu = true
                } label: {
                    Text("Çıkış yap")
                }
            }

            Section(header: Text("Hakkında")) {
                Text(Notlar.resmiDegil)
                    .font(.footnote)
                Text(Notlar.resmiMetin)
                    .font(.footnote)
                Link("sg.barisguresci.com.tr", destination: Ayarlar.siteAdresi)
                HStack {
                    Text("Sürüm")
                    Spacer()
                    Text(surum).foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Hesabım")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Çıkış yapılsın mı?", isPresented: $cikisSorusu) {
            Button("Çıkış yap", role: .destructive) {
                Eylemler.cikis(oturum: oturum, depo: depo)
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Telefona indirilen içerik de silinir.")
        }
    }

    private func sayiSatiri(_ baslik: String, _ sayi: Int) -> some View {
        HStack {
            Text(baslik)
            Spacer()
            Text("\(sayi)").foregroundColor(.secondary)
        }
    }
}
