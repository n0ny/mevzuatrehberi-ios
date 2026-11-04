import SwiftUI

/// dashboard.php — Ana sayfa.
struct AnaEkran: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu
    @State private var yeniSayisi = 0

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    Kahraman(baslik: "Hoş geldin, \(oturum.kullanici?.ad ?? "") 👋",
                             aciklama: "Aradığın mevzuata hızlıca ulaş.")

                    VStack(alignment: .leading, spacing: 12) {
                        durumSatiri

                        NavigationLink(destination: AramaEkrani()) {
                            AnaKart(sembol: "magnifyingglass", baslik: "Mevzuat arama",
                                    aciklama: "Kanun, yönetmelik, genelge ve diğer düzenlemelerde hızlı arama yap",
                                    ana: true)
                        }
                        NavigationLink(destination: TurlerEkrani()) {
                            AnaKart(sembol: "fish", baslik: "Tür kartları",
                                    aciklama: "Asgari av boyu ve yasak dönemleri")
                        }
                        NavigationLink(destination: YeniliklerEkrani()) {
                            AnaKart(sembol: "text.bubble", baslik: "Yenilikler",
                                    aciklama: "Eklenen mevzuat ve duyurular",
                                    rozet: yeniSayisi > 0 ? "\(yeniSayisi) yeni" : nil)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Bu uygulama resmî kurum uygulaması değildir. İçerikler mevzuata erişim ve referans amacıyla sunulmaktadır; güncel mevzuat metinleri ve yetkili kaynaklar esas alınmalıdır.")
                                .font(.caption)
                                .foregroundColor(Renk.soluk)
                                .fixedSize(horizontal: false, vertical: true)
                            if let u = URL(string: "https://sg.barisguresci.com.tr/kvkk.php") {
                                Link("KVKK aydınlatma metni", destination: u)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(Renk.mavi)
                            }
                        }
                        .padding(.top, 10)
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                }
            }
            .background(Renk.zemin.ignoresSafeArea())
            .navigationTitle("Mevzuat Rehberi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        if depo.guncelleniyor {
                            ProgressView().tint(.white)
                        } else {
                            Button {
                                Task { await Eylemler.guncelle(oturum: oturum, depo: depo) }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        NavigationLink(destination: HesapEkrani()) {
                            Image(systemName: "person.crop.circle")
                        }
                    }
                }
            }
            .onAppear { yeniSayisi = YenilikTakibi.yeniSayisi(depo.yenilikler) }
            .onChange(of: depo.yenilikler.count) { _ in yeniSayisi = YenilikTakibi.yeniSayisi(depo.yenilikler) }
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder
    private var durumSatiri: some View {
        if !depo.veriVar {
            if depo.guncelleniyor {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("İçerik ilk kez indiriliyor. Bu işlem bir kez yapılır; sonra internetsiz de çalışır.")
                        .font(.footnote)
                        .foregroundColor(Renk.murekkep)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .kart()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    UyariKutusu(tur: .bilgi, baslik: "İçerik indirilemedi.",
                                metin: depo.hataMesaji ?? "İnternet bağlantınızı kontrol edin.")
                    Button("Tekrar dene") {
                        Task { await Eylemler.guncelle(oturum: oturum, depo: depo) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Renk.lacivert)
                }
            }
        } else if let h = depo.hataMesaji {
            UyariKutusu(tur: .bilgi, baslik: "Güncelleme yapılamadı.", metin: h + " Telefondaki son veriler gösteriliyor.")
        } else if let s = depo.sonKontrol {
            Text("İçerik son kontrol: \(Tarih.anYaz(s))")
                .font(.caption)
                .foregroundColor(Renk.soluk)
        }
    }
}

/// Ana sayfa kartı (dashboard.php .q).
struct AnaKart: View {
    let sembol: String
    let baslik: String
    let aciklama: String
    var ana = false
    var rozet: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            Sembol(ad: sembol, yedek: "doc.text")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ana ? .white : Renk.mavi)
                .frame(width: 46, height: 46)
                .background(ana ? Renk.lacivert : Renk.tint)
                .cornerRadius(14)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(baslik)
                        .font(.headline)
                        .foregroundColor(Renk.murekkep)
                    if let r = rozet {
                        Text(r)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Renk.mavi)
                            .cornerRadius(999)
                    }
                }
                Text(aciklama)
                    .font(.footnote)
                    .foregroundColor(Renk.soluk)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundColor(Renk.soluk)
        }
        .padding(16)
        .kart(vurgulu: ana)
        .shadow(color: ana ? Color.black.opacity(0.06) : .clear, radius: 10, x: 0, y: 4)
    }
}
