import SwiftUI

/// bilgi-kutuphanesi.php — Bilgi Kütüphanesi (bayraklar, ses işaretleri, seyir fenerleri).
/// Kartlara dokununca anlamı açılır, tekrar dokununca kapanır; aynı anda tek kart açık kalır.
struct KutuphaneEkrani: View {
    @EnvironmentObject var kutuphane: KutuphaneDeposu
    @State private var secili = "bayraklar"
    @State private var sorgu = ""
    @State private var acik: String?
    /// Ana sayfadaki "Yeni" etiketi bir kez açılınca kalkar.
    @AppStorage("kutuphaneGoruldu") private var kutuphaneGoruldu = false

    var body: some View {
        let ic = kutuphane.icerik
        let bolumler = ic.gosterilebilir
        let aktif = bolumler.contains(where: { $0.anahtar == secili }) ? secili : (bolumler.first?.anahtar ?? "")

        return YenilenebilirKaydirma(eylem: { await kutuphane.guncelle() }) {
            VStack(spacing: 0) {
                Kahraman(baslik: "Bilgi Kütüphanesi",
                         aciklama: "Denizcilikte temel bilgiler, kaynağıyla birlikte.") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ic.bolumler, id: \.anahtar) { b in
                                if bolumler.contains(where: { $0.anahtar == b.anahtar }) {
                                    // Lacivert üst alanda: seçili beyaz, diğerleri yarı saydam (Mevzuat arama süzgeçleri gibi).
                                    Button {
                                        secili = b.anahtar
                                        sorgu = ""
                                        acik = nil
                                    } label: {
                                        Text(b.baslik)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(aktif == b.anahtar ? Renk.lacivert : .white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .background(Capsule().fill(aktif == b.anahtar ? Color.white : Color.white.opacity(0.14)))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(aktif == b.anahtar ? .isSelected : [])
                                } else {
                                    (Text(b.baslik) + Text("  yakında").font(.caption2))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.white.opacity(0.55))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(Capsule().fill(Color.white.opacity(0.07)))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    AramaKutusu(ipucu: aramaIpucu(aktif), metin: $sorgu)
                }

                VStack(alignment: .leading, spacing: 10) {
                    switch aktif {
                    case "bayraklar":
                        if let b = ic.bayraklar { bayrakBolumu(b) }
                    case "ses":
                        if let s = ic.ses { kartliBolum(s, anahtar: "ses") }
                    case "fenerler":
                        if let f = ic.fenerler { kartliBolum(f, anahtar: "fenerler") }
                    default:
                        BosKutu(metin: "İçerik şu anda yüklenemedi. Sayfayı aşağı çekip yenileyin.")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(DenizZemini().ignoresSafeArea())
        .navigationTitle("Bilgi Kütüphanesi")
        .markaBasligi()
        .onAppear { kutuphaneGoruldu = true }
        .task { await kutuphane.guncelle() }
        .onChange(of: sorgu) { _ in acik = nil }
    }

    private func aramaIpucu(_ bolum: String) -> String {
        switch bolum {
        case "ses": return "Ara (ör. sis, demirli, sancak, kılavuz)"
        case "fenerler": return "Ara (ör. trol, demirli, kırmızı, daire)"
        default: return "Harf, ad veya anlam ara (ör. kılavuz, yardım, M)"
        }
    }

    // MARK: Bayraklar

    @ViewBuilder
    private func bayrakBolumu(_ b: KutuphaneIcerik.Bayraklar) -> some View {
        let q = sorgu.trimmingCharacters(in: .whitespacesAndNewlines)
        let tekHarf = q.count == 1 ? TRMetin.harfKatla(q) : nil
        let liste = b.liste.filter { k in
            if let h = tekHarf { return TRMetin.harfKatla(k.harf) == h }
            return KutuphaneArama.eslesir([k.harf, k.ad, k.anlam, k.ek, k.ekBaslik], sorgu: q)
        }
        let ozel = (b.ozel ?? []).filter { o in
            if let h = tekHarf { return TRMetin.harfKatla(o.kod) == h }
            return KutuphaneArama.eslesir([o.kod, o.baslik, o.alt, o.anlam, o.ek], sorgu: q)
        }

        if let a = b.aciklama, q.isEmpty {
            Text(a + " Tekrar dokununca kapanır.")
                .font(.footnote)
                .foregroundColor(Renk.soluk)
                .padding(.horizontal, 4)
        }
        ForEach(liste, id: \.harf) { k in
            AcilirBilgiKarti(kimlik: "b-" + k.harf, acik: $acik,
                             baslik: k.ad, alt: "Uluslararası İşaret Kodu",
                             anlam: k.anlam, ek: k.ek, ekBaslik: k.ekBaslik,
                             dayanak: (b.dayanak ?? "") + " — " + k.harf) {
                HStack(spacing: 12) {
                    BayrakCizimi(harf: k.harf)
                    Text(k.harf)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(Renk.murekkep)
                        .frame(minWidth: 24)
                }
            }
        }
        if !ozel.isEmpty {
            GrupBasligi(metin: "Tehlike işareti")
            ForEach(ozel, id: \.kod) { o in
                AcilirBilgiKarti(kimlik: "o-" + o.kod, acik: $acik, tehlike: true,
                                 baslik: o.baslik, alt: o.alt,
                                 anlam: o.anlam, ek: o.ek, ekBaslik: nil, dayanak: o.dayanak) {
                    HStack(spacing: 12) {
                        VStack(spacing: 3) {
                            ForEach(o.harfler, id: \.self) { h in BayrakCizimi(harf: h, genislik: 48) }
                        }
                        Text(o.kod)
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(Renk.murekkep)
                    }
                }
            }
        }
        if liste.isEmpty && ozel.isEmpty {
            BosKutu(metin: "Aramanla eşleşen bayrak bulunamadı.")
        }
        KaynakNotu(dayanak: b.dayanak, not: b.not)
    }

    // MARK: Ses işaretleri ve seyir fenerleri

    @ViewBuilder
    private func kartliBolum(_ b: KutuphaneIcerik.KartliBolum, anahtar: String) -> some View {
        let q = sorgu.trimmingCharacters(in: .whitespacesAndNewlines)
        let gruplar = b.gruplar.map { g in
            (g, g.liste.enumerated().filter { _, k in
                KutuphaneArama.eslesir([k.ad, k.anlam, k.ek, k.dayanak], sorgu: q)
            })
        }.filter { !$0.1.isEmpty }

        if let a = b.aciklama, q.isEmpty {
            Text(a + " Tekrar dokununca kapanır.")
                .font(.footnote)
                .foregroundColor(Renk.soluk)
                .padding(.horizontal, 4)
        }
        if q.isEmpty, let tanim = b.tanim, !tanim.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                if anahtar == "fenerler" {
                    HStack(spacing: 14) {
                        ForEach(Array(tanim.enumerated()), id: \.offset) { _, t in
                            HStack(spacing: 6) {
                                if let d = t.desen { FenerDeseni(desen: d) }
                                Text(t.metin).font(.footnote).foregroundColor(Renk.murekkep)
                            }
                        }
                    }
                } else {
                    ForEach(Array(tanim.enumerated()), id: \.offset) { _, t in
                        HStack(spacing: 10) {
                            if let d = t.desen {
                                SesDeseni(desen: d).frame(width: 44)
                            }
                            Text(t.metin).font(.footnote).foregroundColor(Renk.murekkep)
                        }
                    }
                }
                if let n = b.tanimNot {
                    Text(n).font(.caption).foregroundColor(Renk.soluk).fixedSize(horizontal: false, vertical: true)
                }
                if let d = b.tanimDayanak {
                    Text("Dayanak: " + d).font(.caption).foregroundColor(Renk.soluk)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Renk.tint.opacity(0.7)))
        }

        ForEach(Array(gruplar.enumerated()), id: \.offset) { _, eleman in
            let g = eleman.0
            GrupBasligi(metin: g.baslik)
            if let n = g.not, q.isEmpty {
                Text(n)
                    .font(.footnote)
                    .foregroundColor(Renk.soluk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
            ForEach(eleman.1, id: \.offset) { sira, k in
                AcilirBilgiKarti(kimlik: "\(anahtar)-\(g.anahtar ?? g.baslik)-\(sira)", acik: $acik,
                                 tehlike: k.tehlike ?? false,
                                 baslik: k.ad, alt: KutuphaneMetin.kuralKisa(k.dayanak),
                                 anlam: k.anlam, ek: k.ek, ekBaslik: nil, dayanak: k.dayanak) {
                    Group {
                        if anahtar == "fenerler" {
                            FenerDeseni(desen: k.desen ?? "")
                        } else {
                            SesDeseni(desen: k.desen ?? "")
                        }
                    }
                    .frame(width: 118)
                }
            }
            if q.isEmpty {
                if let n = g.kucukTekne { NotKutusu(metin: n) }
                if let n = g.ekNot { NotKutusu(metin: n) }
            }
        }
        if gruplar.isEmpty {
            BosKutu(metin: "Aramanla eşleşen kart bulunamadı.")
        }
        KaynakNotu(dayanak: b.dayanak, not: b.not)
    }
}

enum KutuphaneMetin {
    /// "COLREG 1972 Kural 34(a)(i)" → "Kural 34(a)(i)" (kart başlığında kısa gösterim).
    static func kuralKisa(_ s: String?) -> String? {
        guard let s = s, !s.isEmpty else { return nil }
        if let r = s.range(of: "Kural") { return String(s[r.lowerBound...]) }
        return s
    }
}

private struct GrupBasligi: View {
    let metin: String

    var body: some View {
        Text(metin.uppercased(with: TRMetin.tr))
            .font(.caption.weight(.bold))
            .kerning(0.8)
            .foregroundColor(Renk.soluk)
            .padding(.horizontal, 4)
            .padding(.top, 12)
    }
}

private struct NotKutusu: View {
    let metin: String

    var body: some View {
        Text(metin)
            .font(.footnote)
            .foregroundColor(Renk.soluk)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Renk.cizgi, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }
}

private struct KaynakNotu: View {
    let dayanak: String?
    let not: String?

    var body: some View {
        let metin = [dayanak.map { "Kaynak: " + $0 + "." }, not].compactMap { $0 }.joined(separator: " ")
        if !metin.isEmpty {
            Text(metin)
                .font(.caption)
                .foregroundColor(Renk.soluk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
                .padding(.top, 14)
        }
    }
}

/// Dokununca açılıp kapanan bilgi kartı.
struct AcilirBilgiKarti<Sol: View>: View {
    let kimlik: String
    @Binding var acik: String?
    var tehlike = false
    let baslik: String
    let alt: String?
    let anlam: String
    let ek: String?
    let ekBaslik: String?
    let dayanak: String?
    @ViewBuilder let sol: () -> Sol

    var body: some View {
        let acikMi = acik == kimlik
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    acik = acikMi ? nil : kimlik
                }
            } label: {
                HStack(spacing: 14) {
                    sol()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(baslik)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(Renk.murekkep)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if let a = alt, !a.isEmpty {
                            Text(a)
                                .font(.caption)
                                .foregroundColor(Renk.soluk)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Renk.soluk)
                        .rotationEffect(.degrees(acikMi ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(acikMi ? "Kapatmak için dokunun" : "Anlamını görmek için dokunun")

            if acikMi {
                Divider().padding(.horizontal, 14)
                VStack(alignment: .leading, spacing: 8) {
                    Text(anlam)
                        .font(.body.weight(.semibold))
                        .foregroundColor(Renk.murekkep)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    if let e = ek, !e.isEmpty {
                        (ekBaslik.map { Text($0 + ": ").bold().foregroundColor(Renk.murekkep) } ?? Text("")) + Text(e)
                    }
                    if let d = dayanak, !d.isEmpty {
                        HStack(spacing: 8) {
                            Rectangle().fill(Renk.altin).frame(width: 3)
                            Text("Dayanak: " + d)
                                .font(.caption)
                                .foregroundColor(Renk.soluk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .font(.footnote)
                .foregroundColor(Renk.soluk)
                .padding(14)
            }
        }
        .kart()
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tehlike ? Renk.kirmizi.opacity(0.45) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Çizimler

/// Uluslararası İşaret Kodu bayrağı (sitedeki kt_bayrak ile aynı desenler, 60×40 ölçek).
struct BayrakCizimi: View {
    let harf: String
    var genislik: CGFloat = 56

    private static let sari = Color(UIColor(onaltilik: 0xF4C430))
    private static let mavi = Color(UIColor(onaltilik: 0x1F4FA3))
    private static let kirmizi = Color(UIColor(onaltilik: 0xD42027))
    private static let beyaz = Color.white
    private static let siyah = Color(UIColor(onaltilik: 0x111111))
    private static let cerceve = Color(UIColor(onaltilik: 0xC9D3DF))

    var body: some View {
        Canvas { ctx, boyut in
            let o = boyut.width / 60
            func d(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: Color) {
                ctx.fill(Path(CGRect(x: x * o, y: y * o, width: w * o, height: h * o)), with: .color(c))
            }
            func y(_ n: [(CGFloat, CGFloat)], _ c: Color) {
                var p = Path()
                p.move(to: CGPoint(x: n[0].0 * o, y: n[0].1 * o))
                for k in n.dropFirst() { p.addLine(to: CGPoint(x: k.0 * o, y: k.1 * o)) }
                p.closeSubpath()
                ctx.fill(p, with: .color(c))
            }
            func capraz(_ c: Color) {
                var p = Path()
                p.move(to: .zero)
                p.addLine(to: CGPoint(x: 60 * o, y: 40 * o))
                p.move(to: CGPoint(x: 60 * o, y: 0))
                p.addLine(to: CGPoint(x: 0, y: 40 * o))
                ctx.stroke(p, with: .color(c), lineWidth: 8 * o)
            }
            let kirlangic: [(CGFloat, CGFloat)] = [(0, 0), (60, 0), (45, 20), (60, 40), (0, 40)]
            let S = BayrakCizimi.self

            switch harf.uppercased() {
            case "A":
                y(kirlangic, S.mavi)
                d(0, 0, 30, 40, S.beyaz)
            case "B":
                y(kirlangic, S.kirmizi)
            case "C":
                d(0, 0, 60, 8, S.mavi); d(0, 8, 60, 8, S.beyaz); d(0, 16, 60, 8, S.kirmizi)
                d(0, 24, 60, 8, S.beyaz); d(0, 32, 60, 8, S.mavi)
            case "D":
                d(0, 0, 60, 40, S.sari); d(0, 10, 60, 20, S.mavi)
            case "E":
                d(0, 0, 60, 20, S.mavi); d(0, 20, 60, 20, S.kirmizi)
            case "F":
                d(0, 0, 60, 40, S.beyaz); y([(30, 0), (60, 20), (30, 40), (0, 20)], S.kirmizi)
            case "G":
                for i in 0..<6 { d(CGFloat(i) * 10, 0, 10, 40, i % 2 == 1 ? S.mavi : S.sari) }
            case "H":
                d(0, 0, 30, 40, S.beyaz); d(30, 0, 30, 40, S.kirmizi)
            case "I":
                d(0, 0, 60, 40, S.sari)
                ctx.fill(Path(ellipseIn: CGRect(x: 19 * o, y: 9 * o, width: 22 * o, height: 22 * o)), with: .color(S.siyah))
            case "J":
                d(0, 0, 60, 40, S.mavi); d(0, 13.3, 60, 13.4, S.beyaz)
            case "K":
                d(0, 0, 30, 40, S.sari); d(30, 0, 30, 40, S.mavi)
            case "L":
                d(0, 0, 30, 20, S.sari); d(30, 0, 30, 20, S.siyah); d(0, 20, 30, 20, S.siyah); d(30, 20, 30, 20, S.sari)
            case "M":
                d(0, 0, 60, 40, S.mavi); capraz(S.beyaz)
            case "N":
                for r in 0..<4 {
                    for c in 0..<4 {
                        d(CGFloat(c) * 15, CGFloat(r) * 10, 15, 10, (r + c) % 2 == 1 ? S.beyaz : S.mavi)
                    }
                }
            case "O":
                y([(0, 0), (60, 0), (60, 40)], S.kirmizi); y([(0, 0), (0, 40), (60, 40)], S.sari)
            case "P":
                d(0, 0, 60, 40, S.mavi); d(20, 13, 20, 14, S.beyaz)
            case "Q":
                d(0, 0, 60, 40, S.sari)
            case "R":
                d(0, 0, 60, 40, S.kirmizi); d(25, 0, 10, 40, S.sari); d(0, 15, 60, 10, S.sari)
            case "S":
                d(0, 0, 60, 40, S.beyaz); d(20, 13, 20, 14, S.mavi)
            case "T":
                d(0, 0, 20, 40, S.kirmizi); d(20, 0, 20, 40, S.beyaz); d(40, 0, 20, 40, S.mavi)
            case "U":
                d(0, 0, 30, 20, S.kirmizi); d(30, 0, 30, 20, S.beyaz); d(0, 20, 30, 20, S.beyaz); d(30, 20, 30, 20, S.kirmizi)
            case "V":
                d(0, 0, 60, 40, S.beyaz); capraz(S.kirmizi)
            case "W":
                d(0, 0, 60, 40, S.mavi); d(12, 8, 36, 24, S.beyaz); d(20, 13, 20, 14, S.kirmizi)
            case "X":
                d(0, 0, 60, 40, S.beyaz); d(25, 0, 10, 40, S.mavi); d(0, 15, 60, 10, S.mavi)
            case "Y":
                d(0, 0, 60, 40, S.sari)
                var i = -6
                while i < 12 {
                    let a = CGFloat(i * 6)
                    y([(a, 40), (a + 40, 0), (a + 46, 0), (a + 6, 40)], S.kirmizi)
                    i += 2
                }
            case "Z":
                y([(0, 0), (60, 0), (30, 20)], S.sari); y([(0, 0), (0, 40), (30, 20)], S.siyah)
                y([(0, 40), (60, 40), (30, 20)], S.kirmizi); y([(60, 0), (60, 40), (30, 20)], S.mavi)
            default:
                break
            }

            // Çerçeve
            var cerceve = Path()
            if harf.uppercased() == "A" || harf.uppercased() == "B" {
                cerceve.move(to: CGPoint(x: kirlangic[0].0 * o, y: kirlangic[0].1 * o))
                for k in kirlangic.dropFirst() { cerceve.addLine(to: CGPoint(x: k.0 * o, y: k.1 * o)) }
                cerceve.closeSubpath()
            } else {
                cerceve.addRect(CGRect(origin: .zero, size: boyut))
            }
            ctx.stroke(cerceve, with: .color(S.cerceve), lineWidth: 1)
        }
        .frame(width: genislik, height: genislik * 2 / 3)
        .shadow(color: Color.black.opacity(0.15), radius: 1.5, x: 0, y: 1)
        .accessibilityHidden(true)
    }
}

/// Ses işareti deseni. k: kısa düdük, u: uzun düdük, B: kampana (~5 sn), v: kampanaya tek vuruş,
/// S: sürekli ses, P: patlama, D: dikkat çekme (sitedeki kt_ses ile aynı harfler).
struct SesDeseni: View {
    let desen: String
    var tehlikeRengi = false

    var body: some View {
        let harfler = Array(desen)
        HStack(spacing: 0) {
            ForEach(Array(harfler.enumerated()), id: \.offset) { i, h in
                if i > 0 {
                    let ince = h == "v" || harfler[i - 1] == "v"
                    Spacer().frame(width: ince ? 4 : 6)
                }
                parca(h)
            }
        }
        .foregroundColor(desen == "S" || desen == "P" ? Renk.kirmizi : Color(UIColor.dinamik(0x0B2E4A, 0x9CC3EA)))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func parca(_ h: Character) -> some View {
        switch h {
        case "k": Capsule().frame(width: 10, height: 10)
        case "u": Capsule().frame(width: 40, height: 10)
        case "v": RoundedRectangle(cornerRadius: 1.5).frame(width: 3, height: 14)
        case "S": Capsule().frame(width: 104, height: 10)
        case "B": Image(systemName: "bell").font(.system(size: 18, weight: .semibold))
        case "P": Image(systemName: "burst").font(.system(size: 18, weight: .semibold))
        case "D": Image(systemName: "speaker.wave.2").font(.system(size: 18, weight: .semibold))
        default: EmptyView()
        }
    }
}

/// Fener / gündüz şekli deseni. Satırlar "/" ile ayrılır (üstten alta), satırdaki harfler yan yana, "." boş.
/// Fenerler: K kırmızı, Y yeşil, B beyaz, S sarı (lacivert zemin üzerinde).
/// Şekiller: o daire, d elmas, A sivri ucu yukarı koni, V sivri ucu aşağı koni, C silindir.
struct FenerDeseni: View {
    let desen: String

    private var satirlar: [[Character]] {
        return desen.split(separator: "/", omittingEmptySubsequences: false).map { Array($0) }
    }

    private var fenerMi: Bool {
        return desen.contains(where: { "KYBS".contains($0) })
    }

    var body: some View {
        let s = satirlar
        let sutun = s.map { $0.count }.max() ?? 0
        Group {
            if sutun == 0 {
                EmptyView()
            } else if fenerMi {
                VStack(spacing: 4) {
                    ForEach(Array(s.enumerated()), id: \.offset) { _, satir in
                        HStack(spacing: 4) {
                            ForEach(0..<sutun, id: \.self) { c in
                                let h: Character = c < satir.count ? satir[c] : "."
                                Circle()
                                    .fill(FenerDeseni.renk(h))
                                    .frame(width: 12, height: 12)
                                    .opacity(h == "." ? 0 : 1)
                            }
                        }
                    }
                }
                .padding(5)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(UIColor.dinamik(0x0B2E4A, 0x06182A))))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(s.enumerated()), id: \.offset) { _, satir in
                        HStack(spacing: 0) {
                            ForEach(0..<sutun, id: \.self) { c in
                                sekil(c < satir.count ? satir[c] : ".")
                                    .frame(width: 20, height: 20)
                            }
                        }
                    }
                }
                .foregroundColor(Color(UIColor.dinamik(0x111111, 0xE8EEF5)))
            }
        }
        .accessibilityHidden(true)
    }

    static func renk(_ h: Character) -> Color {
        switch h {
        case "K": return Color(UIColor(onaltilik: 0xFF5A5F))
        case "Y": return Color(UIColor(onaltilik: 0x34D27F))
        case "B": return Color.white
        case "S": return Color(UIColor(onaltilik: 0xFFC940))
        default: return Color.clear
        }
    }

    @ViewBuilder
    private func sekil(_ h: Character) -> some View {
        switch h {
        case "o": Circle().padding(2)
        case "d": Rectangle().rotationEffect(.degrees(45)).padding(4)
        case "A": UcgenSekli(yukari: true).padding(1)
        case "V": UcgenSekli(yukari: false).padding(1)
        case "C": RoundedRectangle(cornerRadius: 1.5).padding(.horizontal, 4).padding(.vertical, 1)
        default: Color.clear
        }
    }
}

/// Koni (üçgen) şekli; iki koni uç uca gelecek şekilde hücreyi tam doldurur.
struct UcgenSekli: Shape {
    let yukari: Bool

    func path(in r: CGRect) -> Path {
        var p = Path()
        if yukari {
            p.move(to: CGPoint(x: r.midX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        } else {
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        }
        p.closeSubpath()
        return p
    }
}
