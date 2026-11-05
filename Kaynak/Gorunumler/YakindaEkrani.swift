import SwiftUI

/// dashboard.php "Yakında eklenecek özellikler" penceresi.
/// Liste sitedeki pencereden okunur; site güncellenince burası da güncellenir.
struct YakindaEkrani: View {
    @EnvironmentObject var depo: VeriDeposu
    @Environment(\.dismiss) private var kapat
    @State private var oneriAcik = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let y = depo.yakinda {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 46, height: 46)
                                .background(Renk.lacivert)
                                .cornerRadius(14)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(y.baslik)
                                    .font(.system(size: 22, weight: .bold, design: .serif))
                                    .foregroundColor(Renk.murekkep)
                                Text(y.aciklama)
                                    .font(.footnote)
                                    .foregroundColor(Renk.soluk)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if !y.etiket.isEmpty {
                            Text(y.etiket.uppercased(with: TRMetin.tr))
                                .font(.caption.weight(.bold))
                                .foregroundColor(Renk.soluk)
                                .padding(.top, 4)
                        }
                        let liste = y.uygulamaMaddeleri
                        if liste.isEmpty {
                            Text("Şu anda planlanan yeni bir özellik bulunmuyor.")
                                .font(.footnote)
                                .foregroundColor(Renk.soluk)
                        }
                        ForEach(Array(liste.enumerated()), id: \.offset) { _, m in
                            YakindaSatiri(madde: m)
                        }
                        if !y.not.isEmpty {
                            Text(y.not)
                                .font(.caption)
                                .foregroundColor(Renk.soluk)
                                .padding(.top, 2)
                        }
                        HStack(spacing: 10) {
                            Button {
                                oneriAcik = true
                            } label: {
                                Text("Öneri gönder")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .foregroundColor(Renk.mavi)
                                    .background(Renk.tint)
                                    .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            Button {
                                kapat()
                            } label: {
                                Text("Kapat")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .foregroundColor(.white)
                                    .background(Renk.lacivert)
                                    .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 6)
                    } else {
                        UyariKutusu(tur: .bilgi, baslik: "Liste henüz indirilmedi.",
                                    metin: "İnternete bağlıyken ana sayfayı aşağı çekip bırakarak güncelleyin.")
                    }
                }
                .padding(18)
                NavigationLink(destination: OneriEkrani(), isActive: $oneriAcik) { EmptyView() }
                    .hidden()
            }
            .background(Renk.zemin.ignoresSafeArea(edges: .bottom))
            .background(Color(UIColor.dinamik(0x08243A, 0x050E17)).ignoresSafeArea())
            .navigationTitle("Yakında eklenecekler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { kapat() }
                        .foregroundColor(.white)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct YakindaSatiri: View {
    let madde: YakindaIcerik.Madde

    private var renk: (on: Color, arka: Color) {
        switch madde.renk {
        case "green": return (Renk.yesil, Renk.yesilZemin)
        case "orange": return (Renk.amber, Renk.amberZemin)
        case "navy": return (.white, Renk.lacivert)
        default: return (Renk.mavi, Renk.tint)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: madde.durumTuru == "done" ? "checkmark" : "clock")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(renk.on)
                .frame(width: 38, height: 38)
                .background(renk.arka)
                .cornerRadius(11)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top) {
                    Text(madde.baslik)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Renk.murekkep)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 6)
                    if !madde.durum.isEmpty {
                        if madde.durumTuru == "done" {
                            Hap(metin: "✓ " + madde.durum, renk: Renk.yesil, zemin: Renk.yesilZemin)
                        } else {
                            Hap(metin: "● " + madde.durum)
                        }
                    }
                }
                Text(madde.metin)
                    .font(.footnote)
                    .foregroundColor(Renk.soluk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .kart()
    }
}
