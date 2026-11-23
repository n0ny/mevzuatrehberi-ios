import SwiftUI

// MARK: - Haftanın soruları — süreli tur
//
// Sitedeki bilgi.php ve Android'deki SureliTur.kt ile aynı tasarım:
//  - İlk soruda lacivert "Hazır mısın?" kartı (altın halka, kurallar, "Başla").
//  - Açık soruda geri sayım halkası (altın → son 10 sn turuncu → son 5 sn kırmızı) ve durum çizgisi.
//  - Cevaptan sonra "Sıradaki soru hazır · Aç" şeridi.
// Süreyi sunucu tutar (bilgi-sure.php); telefondaki sayaç yalnızca gösterir.

enum SureliKurallari {
    /// Sayaç 0'a inince sunucunun zayıf internet payını (5 sn) bekleyip yenile.
    static let yenilemeBeklemesi: UInt64 = 6_500_000_000

    /// Halka rengi aşaması: 0 normal (altın), 1 uyarı (turuncu, ≤10 sn), 2 kritik (kırmızı, ≤5 sn).
    static func asama(_ kalanSn: Int) -> Int {
        if (1...5).contains(kalanSn) { return 2 }
        if (6...10).contains(kalanSn) { return 1 }
        return 0
    }

    /// Ekranda sıralama: önce açık / sıradaki soru, altında cevaplananlar (en yenisi üstte). Bekleyenler gösterilmez.
    static func siralama(_ sorular: [BilgiVerisi.Soru]) -> [BilgiVerisi.Soru] {
        let simdiki = sorular.filter { $0.durum == "acik" || $0.durum == "sirada" }.prefix(1)
        let biten = sorular.filter { $0.durum == "cevap" || $0.durum == "doldu" }.reversed()
        return Array(simdiki) + Array(biten)
    }
}

private enum SureliRenk {
    static let altin = Color(UIColor(onaltilik: 0xDDBF7E))
    static let turuncu = Color(UIColor(onaltilik: 0xE8912D))
    static let lacivert = Color(UIColor(onaltilik: 0x0B2E4A))
    static let acikYazi = Color(UIColor(onaltilik: 0xB9CFE3))
    static let zemin = LinearGradient(
        colors: [Color(UIColor(onaltilik: 0x08243A)), Color(UIColor(onaltilik: 0x0B2E4A)), Color(UIColor(onaltilik: 0x11456B))],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// Soruların durum çizgisi: yeşil doğru, kırmızı yanlış, gri cevapsız, altın şu anki.
struct DurumCizgisi: View {
    let sorular: [BilgiVerisi.Soru]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(sorular) { q in
                Capsule()
                    .fill(renk(q))
                    .frame(height: 6)
            }
        }
    }

    private func renk(_ q: BilgiVerisi.Soru) -> Color {
        switch q.durum {
        case "cevap": return q.cevap?.dogruMu == true ? Renk.yesil : Renk.kirmizi
        case "doldu": return Renk.soluk
        case "acik": return SureliRenk.altin
        default: return Renk.cizgi
        }
    }
}

struct SureliBaslaKarti: View {
    let veri: BilgiVerisi
    let ac: () async -> Void
    @State private var aciliyor = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                    Text("SÜRELİ TUR").kerning(1.4)
                }
                    .font(.caption2.weight(.bold))
                    .foregroundColor(SureliRenk.altin)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 4)
                    .overlay(Capsule().stroke(SureliRenk.altin.opacity(0.55), lineWidth: 1))
                Spacer()
                Text("\(veri.ozet.toplam) soru · \(veri.ozet.tamPuan) puan")
                    .font(.caption)
                    .foregroundColor(SureliRenk.acikYazi)
            }
            ZStack {
                Circle().fill(SureliRenk.altin.opacity(0.10)).frame(width: 110, height: 110)
                Circle().stroke(SureliRenk.altin, lineWidth: 6).frame(width: 92, height: 92)
                VStack(spacing: 2) {
                    Text("\(veri.sure ?? 30)").font(.system(size: 30, weight: .bold)).foregroundColor(.white)
                    Text("saniye").font(.caption2).foregroundColor(SureliRenk.acikYazi)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 10)
            Text("Hazır mısın?")
                .font(.system(size: 25, weight: .medium, design: .serif))
                .foregroundColor(.white)
            Text("Her soru için \(veri.sure ?? 30) saniyen var. Doğru cevap \(veri.soruPuani) puan.")
                .font(.footnote)
                .foregroundColor(SureliRenk.acikYazi)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .padding(.bottom, 14)
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    kural("play.fill", "Süre \"Başla\"ya basınca işler")
                    kural("arrow.right", "Sorular tek tek gelir, geri dönülmez")
                }
                HStack(spacing: 8) {
                    kural("hourglass", "Süre dolarsa soru cevapsız sayılır")
                    kural("lock.fill", "Uygulamayı kapatsan da süre işler")
                }
            }
            Button {
                guard !aciliyor else { return }
                aciliyor = true
                Task { await ac(); aciliyor = false }
            } label: {
                HStack(spacing: 8) {
                    if aciliyor { ProgressView().tint(SureliRenk.lacivert) } else { Image(systemName: "play.fill") }
                    Text(aciliyor ? "Açılıyor…" : "Başla").font(.body.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundColor(SureliRenk.lacivert)
                .background(SureliRenk.altin)
                .cornerRadius(14)
            }
            .buttonStyle(.plain)
            .disabled(aciliyor)
            .padding(.top, 16)
            Text("Bol şans!")
                .font(.caption)
                .foregroundColor(Color(UIColor(onaltilik: 0x8FA6B8)))
                .padding(.top, 8)
        }
        .padding(18)
        .background(SureliRenk.zemin)
        .cornerRadius(22)
    }

    private func kural(_ simge: String, _ yazi: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: simge)
                .font(.caption)
                .foregroundColor(SureliRenk.altin)
                .frame(width: 16)
            Text(yazi)
                .font(.caption)
                .foregroundColor(Color(UIColor(onaltilik: 0xE6EDF3)))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .cornerRadius(14)
    }
}

struct SiradakiSerit: View {
    let soru: BilgiVerisi.Soru
    let toplam: Int
    let sure: Int
    let ac: () async -> Void
    @State private var aciliyor = false

    var body: some View {
        HStack(spacing: 12) {
            Text("\(soru.no)")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(SureliRenk.altin, lineWidth: 4))
            VStack(alignment: .leading, spacing: 2) {
                Text("Sıradaki soru hazır")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text("Açınca \(sure) saniyen başlar · \(soru.no)/\(toplam)")
                    .font(.caption)
                    .foregroundColor(SureliRenk.acikYazi)
            }
            Spacer(minLength: 0)
            Button {
                guard !aciliyor else { return }
                aciliyor = true
                Task { await ac(); aciliyor = false }
            } label: {
                HStack(spacing: 4) {
                    Text(aciliyor ? "…" : "Aç").font(.subheadline.weight(.bold))
                    if !aciliyor { Image(systemName: "arrow.right").font(.caption.weight(.bold)) }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .foregroundColor(SureliRenk.lacivert)
                .background(SureliRenk.altin)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(aciliyor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(SureliRenk.zemin)
        .cornerRadius(18)
    }
}

/// Açık soru: geri sayım halkası + şıklar. Sayaç bitince şıklar kilitlenir,
/// sunucunun payı beklenip `bitti` çağrılır (ekran yenilenir, soru "süre doldu" olur).
struct SureliSoruKarti: View {
    let soru: BilgiVerisi.Soru
    let veri: BilgiVerisi
    let gonder: (String) async -> Void
    let bitti: () async -> Void

    @State private var bitis = Date()
    @State private var simdi = Date()
    @State private var basladi = false
    @State private var secim: String?
    @State private var gonderiliyor = false

    private var sure: Int { veri.sure ?? 30 }
    private var kalanSn: Int { basladi ? max(0, Int(ceil(bitis.timeIntervalSince(simdi)))) : (soru.kalan ?? 0) }
    private var bitmis: Bool { basladi && simdi >= bitis }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Soru \(soru.no) / \(veri.ozet.toplam) · Puanın \(veri.ozet.puan)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Renk.soluk)
                    DurumCizgisi(sorular: veri.sorular)
                }
                sayac
            }
            Text(soru.soru)
                .font(.body.weight(.semibold))
                .foregroundColor(Renk.murekkep)
                .fixedSize(horizontal: false, vertical: true)
            if bitmis {
                Text("Süre doldu…")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Renk.kirmizi)
            }
            ForEach(soru.siklar) { s in
                Button {
                    secim = s.k
                } label: {
                    sikSatiri(s, secili: secim == s.k)
                }
                .buttonStyle(.plain)
                .disabled(gonderiliyor || bitmis)
            }
            Button {
                guard let s = secim, !gonderiliyor, !bitmis else { return }
                gonderiliyor = true
                Task {
                    await gonder(s)
                    gonderiliyor = false
                }
            } label: {
                HStack {
                    if gonderiliyor { ProgressView().tint(.white) }
                    Text(gonderiliyor ? "Gönderiliyor…" : "Cevabı gönder").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.white)
                .background(Renk.lacivert.opacity(secim == nil || bitmis ? 0.45 : 1))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(secim == nil || gonderiliyor || bitmis)
        }
        .padding(16)
        .kart()
        .task {
            bitis = Date().addingTimeInterval(Double(soru.kalan ?? 0))
            simdi = Date()
            basladi = true
            while !Task.isCancelled {
                simdi = Date()
                if simdi >= bitis { break }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            try? await Task.sleep(nanoseconds: SureliKurallari.yenilemeBeklemesi)
            if !Task.isCancelled && !gonderiliyor {
                await bitti()
            }
        }
    }

    private var sayac: some View {
        let asama = SureliKurallari.asama(kalanSn)
        let renk: Color = bitmis ? Renk.soluk : (asama == 2 ? Renk.kirmizi : (asama == 1 ? SureliRenk.turuncu : SureliRenk.altin))
        let oran = sure > 0 ? max(0, min(1, basladi ? bitis.timeIntervalSince(simdi) / Double(sure) : Double(soru.kalan ?? 0) / Double(sure))) : 0
        return ZStack {
            Circle().stroke(Renk.ikincil, lineWidth: 6)
            Circle()
                .trim(from: 0, to: oran)
                .stroke(renk, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.2), value: oran)
            Text("\(kalanSn)")
                .font(.system(size: 19, weight: .heavy))
                .foregroundColor(asama == 0 || bitmis ? Renk.murekkep : renk)
        }
        .frame(width: 64, height: 64)
    }

    private func sikSatiri(_ s: BilgiVerisi.Sik, secili: Bool) -> some View {
        HStack(spacing: 10) {
            Text(s.harf)
                .font(.caption.weight(.bold))
                .foregroundColor(secili ? .white : Renk.mavi)
                .frame(width: 26, height: 26)
                .background(secili ? Renk.mavi : Renk.kart)
                .cornerRadius(9)
            Text(s.metin)
                .font(.subheadline)
                .foregroundColor(Renk.murekkep)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(secili ? Renk.tint : Renk.ikincil)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(secili ? Renk.mavi : Renk.cizgi, lineWidth: 1.5))
        .cornerRadius(14)
    }
}
