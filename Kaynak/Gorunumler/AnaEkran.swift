import SwiftUI

struct AnaEkran: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu

    private let sutunlar = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ustKart

                    NavigationLink(destination: AramaEkrani()) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                            Text("Mevzuatta ara: boğaz, trol, gırgır…")
                            Spacer()
                        }
                        .foregroundColor(.secondary)
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    if !depo.veriVar {
                        indirmeDurumu
                    } else if let h = depo.hataMesaji {
                        UyariNotu(metin: h + " Telefondaki son veriler gösteriliyor.", sembol: "wifi.exclamationmark")
                    }

                    LazyVGrid(columns: sutunlar, spacing: 12) {
                        NavigationLink(destination: AramaEkrani()) {
                            Kutucuk(baslik: "Mevzuat Ara", alt: "\(depo.fiiller.count + depo.maddeler.count) kayıt",
                                    sembol: "text.magnifyingglass", renk: .blue)
                        }
                        NavigationLink(destination: SevkEkrani()) {
                            Kutucuk(baslik: "Sevk İşlemleri", alt: "\(depo.sevkler.count) kayıt",
                                    sembol: "arrow.triangle.branch", renk: .indigo)
                        }
                        NavigationLink(destination: YaptirimEkrani()) {
                            Kutucuk(baslik: "İdari Yaptırımlar", alt: "\(depo.yaptirimlar.count) kayıt",
                                    sembol: "turkishlirasign.circle", renk: .red)
                        }
                        NavigationLink(destination: TurlerEkrani()) {
                            Kutucuk(baslik: "Tür Kartları", alt: "\(depo.turler.count) tür",
                                    sembol: "fish", renk: .teal)
                        }
                        NavigationLink(destination: BolgeEkrani()) {
                            Kutucuk(baslik: "Bölge Yasakları", alt: "\(depo.bolgeler.count) bölge",
                                    sembol: "map", renk: .green)
                        }
                        NavigationLink(destination: YeniliklerEkrani()) {
                            Kutucuk(baslik: "Yenilikler", alt: "\(depo.yenilikler.count) duyuru",
                                    sembol: "megaphone", renk: .orange)
                        }
                    }
                    .buttonStyle(.plain)

                    Text(Notlar.resmiMetin)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Mevzuat Rehberi")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: HesapEkrani()) {
                        Image(systemName: "person.crop.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if depo.guncelleniyor {
                        ProgressView()
                    } else {
                        Button {
                            Task { await Eylemler.guncelle(oturum: oturum, depo: depo) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var ustKart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Merhaba, \(oturum.kullanici?.ad ?? "")")
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)
            Group {
                if depo.guncelleniyor {
                    Text("İçerik güncelleniyor…")
                } else if let s = depo.sonKontrol {
                    Text("Son kontrol: \(Tarih.anYaz(s))")
                } else {
                    Text("İçerik henüz indirilmedi")
                }
            }
            .font(.footnote)
            .foregroundColor(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.accentColor, Color.accentColor.opacity(0.75)]),
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(16)
    }

    @ViewBuilder
    private var indirmeDurumu: some View {
        if depo.guncelleniyor {
            HStack(spacing: 12) {
                ProgressView()
                Text("İçerik ilk kez indiriliyor. Bu işlem bir kez yapılır; sonra internetsiz de çalışır.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                UyariNotu(metin: depo.hataMesaji ?? "İçerik henüz indirilmedi.", sembol: "wifi.exclamationmark")
                Button("Tekrar dene") {
                    Task { await Eylemler.guncelle(oturum: oturum, depo: depo) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct Kutucuk: View {
    let baslik: String
    let alt: String
    let sembol: String
    let renk: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Sembol(ad: sembol, yedek: "doc.text")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(renk)
                .frame(width: 42, height: 42)
                .background(renk.opacity(0.12))
                .cornerRadius(12)
            VStack(alignment: .leading, spacing: 2) {
                Text(baslik)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(alt)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}
