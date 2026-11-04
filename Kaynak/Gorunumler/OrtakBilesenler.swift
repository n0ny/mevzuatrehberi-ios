import SwiftUI
import UIKit

/// SF Symbol; telefonun iOS sürümünde yoksa yedek simgeyi gösterir.
struct Sembol: View {
    let ad: String
    var yedek: String = "doc.text"

    var body: some View {
        Image(systemName: UIImage(systemName: ad) != nil ? ad : yedek)
    }
}

/// Başlık + değer satırı (detay ekranlarında).
struct BilgiSatiri: View {
    let baslik: String
    let deger: String?

    var body: some View {
        if let d = deger, !d.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text(baslik)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(d)
                    .font(.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
        }
    }
}

/// Madde işaretli liste.
struct MaddeListesi: View {
    let maddeler: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(maddeler.enumerated()), id: \.offset) { _, m in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•").foregroundColor(.accentColor)
                    Text(m)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// "- " ile başlayan satırları madde, diğerlerini paragraf olarak gösterir.
struct AciklamaMetni: View {
    let metin: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(Metin.satirlar(metin).enumerated()), id: \.offset) { _, satir in
                if satir.hasPrefix("- ") || satir.hasPrefix("• ") {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundColor(.accentColor)
                        Text(String(satir.dropFirst(2)))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(satir)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// Sarı bilgi kutusu.
struct UyariNotu: View {
    let metin: String
    var sembol: String = "info.circle"

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: sembol)
                .foregroundColor(.orange)
            Text(metin)
                .font(.footnote)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(12)
    }
}

/// Kayıt doğrulama durumu (green / yellow / red).
struct DurumRozeti: View {
    let durum: String
    let metin: String?

    var renk: Color {
        switch durum {
        case "green": return .green
        case "red": return .red
        default: return .orange
        }
    }

    var varsayilan: String {
        switch durum {
        case "green": return "Doğrulandı"
        case "red": return "Güncelleme gerekli"
        default: return "Kontrol gerekli"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(renk).frame(width: 9, height: 9)
            Text(metin ?? varsayilan)
                .font(.caption.weight(.semibold))
                .foregroundColor(renk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(renk.opacity(0.12))
        .cornerRadius(8)
    }
}

/// Filtre çipi.
struct Cip: View {
    let baslik: String
    let secili: Bool
    let eylem: () -> Void

    var body: some View {
        Button(action: eylem) {
            Text(baslik)
                .font(.subheadline.weight(secili ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundColor(secili ? .white : .primary)
                .background(secili ? Color.accentColor : Color(.secondarySystemBackground))
                .cornerRadius(18)
        }
        .buttonStyle(.borderless)
    }
}

struct CipSatiri: View {
    let secenekler: [String]
    @Binding var secili: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(secenekler, id: \.self) { s in
                    Cip(baslik: s, secili: s == secili) { secili = s }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

/// Boş liste uyarısı.
struct BosDurum: View {
    let metin: String
    var sembol: String = "tray"

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: sembol)
                .font(.system(size: 34))
                .foregroundColor(.secondary)
            Text(metin)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

/// Resmî kaynak bağlantısı.
struct KaynakBaglantisi: View {
    let baslik: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack {
                Image(systemName: "arrow.up.right.square")
                Text(baslik)
                Spacer()
            }
        }
    }
}

/// Uygulama genelindeki sorumluluk notu.
enum Notlar {
    static let resmiMetin = "Bu bilgiler resmî kaynaklara dayanır. İşlem yapmadan önce ilgili mevzuatın resmî metni esas alınmalıdır."
    static let resmiDegil = "Mevzuat Rehberi resmî bir uygulama değildir; herhangi bir kurumla bağlantısı yoktur."
}

/// İnternetten fotoğraf (önbellekli).
struct UzakFoto: View {
    let url: URL?
    var dolgu: Bool = true

    var body: some View {
        if let url = url {
            AsyncImage(url: url) { faz in
                switch faz {
                case .success(let resim):
                    if dolgu {
                        resim.resizable().scaledToFill()
                    } else {
                        resim.resizable().scaledToFit()
                    }
                case .failure:
                    yerTutucu
                case .empty:
                    ZStack {
                        Color(.secondarySystemBackground)
                        ProgressView()
                    }
                @unknown default:
                    yerTutucu
                }
            }
        } else {
            yerTutucu
        }
    }

    private var yerTutucu: some View {
        ZStack {
            Color(.secondarySystemBackground)
            Image(systemName: "photo")
                .foregroundColor(.secondary)
        }
    }
}
