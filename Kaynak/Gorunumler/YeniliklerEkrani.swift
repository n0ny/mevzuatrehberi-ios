import SwiftUI

struct YeniliklerEkrani: View {
    @EnvironmentObject var depo: VeriDeposu

    var body: some View {
        List {
            if depo.yenilikler.isEmpty {
                BosDurum(metin: "Henüz duyuru yok.", sembol: "megaphone")
            } else {
                ForEach(depo.yenilikler) { y in
                    YenilikKarti(yenilik: y)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Yenilikler")
    }
}

struct YenilikKarti: View {
    let yenilik: Yenilik
    @State private var acik = false

    private var renk: Color {
        switch yenilik.kategori {
        case "Mevzuat": return .purple
        case "Yeni özellik": return .green
        case "Uyarı": return .red
        default: return .blue
        }
    }

    private var uzun: Bool {
        return Metin.satirlar(yenilik.aciklama).count > 2 || yenilik.aciklama.count > 160
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(yenilik.kategori)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(renk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(renk.opacity(0.12))
                    .cornerRadius(6)
                Spacer()
                if let t = Tarih.gunYaz(yenilik.tarih) {
                    Text(t)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Text(yenilik.baslik)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            if acik || !uzun {
                AciklamaMetni(metin: yenilik.aciklama)
                    .font(.callout)
            } else {
                Text(Metin.satirlar(yenilik.aciklama).first ?? "")
                    .font(.callout)
                    .lineLimit(2)
            }
            if uzun {
                Button(acik ? "Daha az göster" : "Devamını oku") {
                    withAnimation { acik.toggle() }
                }
                .font(.callout.weight(.semibold))
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 6)
    }
}
