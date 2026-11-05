import SwiftUI

// idari_yaptirim.php — 1380 idari yaptırım rehberinin karşılığı.

/// Sayfadaki arama ve gösterim kuralları (sitedeki JS fonksiyonlarının birebir karşılığı).
enum YaptirimKurallari {
    /// AJAX arama: en az 2 karakter; her kelime alanlardan birinde geçmeli; yalnızca ayarlanan yıl; id sırası; en çok 50.
    static func ara(_ liste: [Yaptirim], sorgu: String, yil: Int) -> [Yaptirim] {
        let q = sorgu.trimmingCharacters(in: .whitespacesAndNewlines)
        if TRMetin.uzunluk(q) < 2 { return [] }
        var kelimeler: [String] = []
        for k in q.lowercased(with: TRMetin.tr).split(whereSeparator: { $0.isWhitespace }).map(String.init)
        where !kelimeler.contains(k) {
            kelimeler.append(k)
        }
        if kelimeler.isEmpty { return [] }
        let uygun = liste.filter { y in
            y.yil == yil && kelimeler.allSatisfy { y.aramaSite.contains($0) }
        }
        return Array(uygun.sorted { $0.id < $1.id }.prefix(50))
    }

    static func ihlal(_ y: Yaptirim) -> String {
        if !y.nitelik.isEmpty { return y.nitelik }
        if !y.olayTuru.isEmpty { return y.olayTuru }
        return "İhlal bilgisi belirtilmemiş."
    }

    static func cezaKodu(_ y: Yaptirim) -> String {
        return (y.cezaMaddesi ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// formatArticleValue
    static func maddeDegeri(_ s: String?) -> String {
        let t = (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "" }
        guard let r = try? NSRegularExpression(pattern: "^madde\\s*", options: [.caseInsensitive]) else { return t }
        return r.stringByReplacingMatches(in: t, options: [], range: NSRange(t.startIndex..<t.endIndex, in: t), withTemplate: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// tebligKey
    static func tebligAnahtari(_ s: String?) -> String {
        let t = (s ?? "").components(separatedBy: .whitespacesAndNewlines).joined()
        if TRMetin.eslesirMi("(^|[^\\d])6/1(?!\\d)", t) { return "teblig61" }
        if TRMetin.eslesirMi("(^|[^\\d])6/2(?!\\d)", t) { return "teblig62" }
        return ""
    }

    /// normalizeActionValue
    static func elKoymaDegeri(_ s: String?) -> String {
        let t = (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "" }
        let l = t.lowercased(with: TRMetin.tr)
        if l == "evet" || l == "yes" || l == "1" { return "Evet" }
        if ["hayır", "hayir", "hayır.", "hayir.", "no", "0"].contains(l) { return "Hayır" }
        return t
    }

    /// formatTL (Intl tr-TR, TRY, kuruşsuz)
    static func tl(_ d: Double) -> String {
        return "₺" + Para.sayi(d.rounded())
    }

    enum Ceza {
        case tutar(String)
        case kosullar([String], not: String?)
        case bosKosul
        case olayBazli
        case trolAltTuru
    }

    /// buildPenaltyAmountHtml
    static func ceza(_ y: Yaptirim, ayar: YaptirimAyari) -> Ceza {
        let sabit = y.miktar
        let enAz = y.enAz
        let enCok = y.enCok
        let tip = (y.hesaplamaTipi ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased(with: TRMetin.tr)
        let kod = cezaKodu(y)
        let notlar = (y.notlar ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let fiil = (!y.nitelik.isEmpty ? y.nitelik : y.olayTuru).trimmingCharacters(in: .whitespacesAndNewlines)

        if kod == "36/1-l" {
            if tip.contains("DIP TROLU") || tip.contains("DİP TROLÜ") {
                if let a = enAz, let c = enCok {
                    let orta = ((a + c) / 2).rounded(.toNearestOrAwayFromZero)
                    return .kosullar([
                        "12 metreden küçük gemi: **\(tl(a))**",
                        "12 metre dahil, 22 metreden küçük gemi: **\(tl(orta))**",
                        "22 metre ve üzeri gemi: **\(tl(c))**",
                    ], not: "Geminin tam boyu kontrol edilmelidir.")
                }
            }
            if tip.contains("GENEL TROL") {
                return .kosullar(ayar.genelTrol.satirlar, not: ayar.genelTrol.not)
            }
            if tip.contains("MUHURSUZ TROL") || tip.contains("MÜHÜRSÜZ TROL") {
                if let m = sabit ?? enAz ?? enCok {
                    return .tutar(tl(m))
                }
            }
            if tip.contains("OLAY_BAZLI")
                || TRMetin.eslesirMi("12\\s*m(?:etre)?den\\s*küçük", fiil, buyukKucukDuyarsiz: true)
                || TRMetin.eslesirMi("12\\s*metreden\\s*küçük", notlar, buyukKucukDuyarsiz: true) {
                return .olayBazli
            }
            if tip.contains("AYRISTIRILMALI_TROL_ALT_TIPI") {
                return .trolAltTuru
            }
        }

        if kod == "36/1-t" {
            return .kosullar(ayar.ruhsat36_1_t.satirlar, not: ayar.ruhsat36_1_t.not)
        }

        if tip.contains("KOŞULLU") {
            let satirlar = kosulListesi(notlar: notlar, kaynakMetni: y.kaynakMetni ?? "", yil: ayar.yil)
            return satirlar.isEmpty ? .bosKosul : .kosullar(satirlar, not: nil)
        }

        if let s = sabit { return .tutar(tl(s)) }
        if let a = enAz, let c = enCok { return .tutar(tl(a) + " – " + tl(c)) }
        return .tutar("Tutar belirtilmemiş")
    }

    /// buildPenaltyConditionListHtml
    static func kosulListesi(notlar: String, kaynakMetni: String, yil: Int) -> [String] {
        var metin = notlar.trimmingCharacters(in: .whitespacesAndNewlines)
        let isaret = "\(yil) CEZA:"
        if let r = metin.range(of: isaret) {
            metin = String(metin[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            metin = kaynakMetni.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        metin = degistir("\\s*Somut kayıt.*$", metin)
        metin = degistir("\\s*Somut alt tür.*$", metin).trimmingCharacters(in: .whitespacesAndNewlines)
        if metin.isEmpty { return [] }

        var parcalar: [String] = []
        for parca in metin.components(separatedBy: ";") {
            let p = parca.trimmingCharacters(in: .whitespacesAndNewlines)
            if p.isEmpty { continue }
            for cumle in bol("(?<=\\.)\\s+", p) {
                var c = cumle.trimmingCharacters(in: .whitespacesAndNewlines)
                if c.isEmpty { continue }
                c = degistir("^\\s*\\d+/\\d+-[a-z]\\.?\\s*", c).trimmingCharacters(in: .whitespacesAndNewlines)
                if !c.isEmpty { parcalar.append(c) }
            }
        }
        return parcalar
    }

    /// getSanctionExplanation
    static func kisaca(_ y: Yaptirim, ayar: YaptirimAyari) -> String {
        let kod = cezaKodu(y)
        let tip = (y.hesaplamaTipi ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased(with: TRMetin.tr)
        let fiil = ihlal(y)
        if let k = ayar.kisaAciklamalar[kod] { return k }
        if !kod.isEmpty {
            if tip == "SABİT" {
                return "Bu ceza, ilgili fiil için uygulanır. Uygulanacak tutar yukarıda gösterilmiştir."
            }
            if !fiil.isEmpty {
                return "“\(fiil)” fiili için uygulanır. Tutar, yukarıdaki koşullara göre belirlenir."
            }
            return "Bu ceza, ilgili fiil için uygulanır. Tutar, yukarıdaki koşullara göre belirlenir."
        }
        return fiil.isEmpty
            ? "İdarî para cezası, ilgili fiilin koşullarına göre uygulanır."
            : "“\(fiil)” fiili için idarî para cezası uygulanır."
    }

    private static func degistir(_ desen: String, _ metin: String) -> String {
        guard let r = try? NSRegularExpression(pattern: desen, options: [.caseInsensitive]) else { return metin }
        return r.stringByReplacingMatches(in: metin, options: [], range: NSRange(metin.startIndex..<metin.endIndex, in: metin),
                                          withTemplate: "")
    }

    private static func bol(_ desen: String, _ metin: String) -> [String] {
        guard let r = try? NSRegularExpression(pattern: desen, options: []) else { return [metin] }
        let ns = metin as NSString
        var sonuc: [String] = []
        var bas = 0
        for m in r.matches(in: metin, options: [], range: NSRange(location: 0, length: ns.length)) {
            sonuc.append(ns.substring(with: NSRange(location: bas, length: m.range.location - bas)))
            bas = m.range.location + m.range.length
        }
        sonuc.append(ns.substring(from: bas))
        return sonuc
    }
}

struct YaptirimEkrani: View {
    @EnvironmentObject var depo: VeriDeposu
    @State private var sorgu = ""

    var body: some View {
        let ayar = depo.kaynakListesi.yaptirimAyari
        let q = sorgu.trimmingCharacters(in: .whitespacesAndNewlines)
        let sonuc = YaptirimKurallari.ara(depo.yaptirimlar, sorgu: sorgu, yil: ayar.yil)
        let kayitSayisi = depo.yaptirimlar.filter { $0.yil == ayar.yil }.count
        ScrollView {
            VStack(spacing: 0) {
                Kahraman(baslik: "1380 idari yaptırım rehberi",
                         aciklama: "Tespit ettiğin ihlali ara, uygulanacak ceza ve işlemleri hızlıca gör. Hukuki dayanağı gerektiğinde açarak inceleyebilirsin.") {
                    AramaKutusu(ipucu: "Ruhsat, küçük balık, ağ, yetiştiricilik...", metin: $sorgu)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ayar.ipuclari, id: \.sorgu) { i in
                                Button {
                                    sorgu = i.sorgu
                                } label: {
                                    Text(i.etiket)
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 13)
                                        .padding(.vertical, 7)
                                        .foregroundColor(.white)
                                        .background(Color.white.opacity(0.14))
                                        .cornerRadius(999)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 4)
                    }
                }

                LazyVStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "calendar")
                            .foregroundColor(Renk.mavi)
                        (Text("\(String(ayar.yil)) yılı ").bold()
                            + Text("Bu bölüm yalnızca \(String(ayar.yil)) yılı idari yaptırım bilgilerini içerir."))
                            .font(.footnote)
                            .foregroundColor(Renk.murekkep)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Renk.tint)
                    .cornerRadius(12)

                    if TRMetin.uzunluk(q) >= 2 {
                        if sonuc.isEmpty {
                            Text("Bu arama için \(String(ayar.yil)) tablosunda eşleşen yaptırım bulunamadı.")
                                .font(.subheadline)
                                .foregroundColor(Renk.murekkep)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .kart()
                        } else {
                            Text("\(sonuc.count) yaptırım kaydı bulundu.")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(Renk.soluk)
                            ForEach(sonuc) { y in
                                YaptirimKarti(yaptirim: y, ayar: ayar)
                            }
                        }
                    }

                    YaptirimKaynaklari(ayar: ayar)
                        .padding(.top, 6)

                    Text("\(String(ayar.yil)) yılı tablosundaki \(kayitSayisi) aktif yaptırım kaydı üzerinden arama yapılmaktadır.")
                        .font(.caption)
                        .foregroundColor(Renk.soluk)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(16)
            }
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle("Mevzuat Rehberi")
        .markaBasligi()
    }
}

struct YaptirimKarti: View {
    let yaptirim: Yaptirim
    let ayar: YaptirimAyari
    @State private var acik = false

    var body: some View {
        let kod = YaptirimKurallari.cezaKodu(yaptirim)
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { acik.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "scalemass")
                        .foregroundColor(Renk.mavi)
                        .frame(width: 34, height: 34)
                        .background(Renk.tint)
                        .cornerRadius(10)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(YaptirimKurallari.ihlal(yaptirim))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Renk.murekkep)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        VStack(alignment: .leading, spacing: 5) {
                            Hap(metin: yaptirim.olayTuru.isEmpty ? "İDARİ YAPTIRIM" : yaptirim.olayTuru)
                            if !kod.isEmpty {
                                Hap(metin: "Yaptırım: " + kod, renk: Renk.kirmizi, zemin: Renk.kirmiziZemin)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(acik ? 180 : 0))
                        .foregroundColor(Renk.soluk)
                        .padding(.top, 8)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if acik {
                VStack(alignment: .leading, spacing: 12) {
                    neYapacagim
                    AcilirBolum(sembol: "book", baslik: "Mevzuat dayanağını göster",
                                altBaslik: "Kanun, madde ve ilgili mevzuatı görüntüle") {
                        dayanak
                    }
                    AcilirBolum(sembol: "turkishlirasign.circle", baslik: "İdari para cezasını göster",
                                altBaslik: "Uygulanacak ceza maddesi ve tutarı") {
                        cezaBolumu(kod: kod)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .kart(vurgulu: acik)
    }

    // MARK: Ne yapacağım?

    @ViewBuilder
    private var neYapacagim: some View {
        let su = YaptirimKurallari.elKoymaDegeri(yaptirim.suUrunuElKoyma)
        let vasita = YaptirimKurallari.elKoymaDegeri(yaptirim.vasitaElKoyma)
        if !su.isEmpty || !vasita.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Ne yapacağım?")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Renk.mavi)
                VStack(spacing: 8) {
                    if !su.isEmpty {
                        ElKoymaSatiri(sembol: "fish", baslik: "Su ürünlerine el koy", deger: su)
                    }
                    if !vasita.isEmpty {
                        ElKoymaSatiri(sembol: "wrench.and.screwdriver", baslik: "İstihsal vasıtasına el koy", deger: vasita)
                    }
                }
                .padding(10)
                .background(Renk.tint.opacity(0.6))
                .cornerRadius(12)
            }
        }
    }

    // MARK: Mevzuat dayanağı

    @ViewBuilder
    private var dayanak: some View {
        let y = yaptirim
        Text("Bu kayıt hangi mevzuata dayandırılmış?")
            .font(.footnote.weight(.semibold))
            .foregroundColor(Renk.soluk)
        if y.kanunMaddesi == nil && y.yonetmelikMaddesi == nil && y.tebligMaddesi == nil && y.kaynakMetni == nil {
            Text("Bu kayıt için mevzuat dayanağı bulunmamaktadır.")
                .font(.footnote)
                .foregroundColor(Renk.murekkep)
        }
        if let k = y.kanunMaddesi {
            DayanakSatiri(etiket: "1380 SAYILI SU ÜRÜNLERİ KANUNU",
                          baslik: "1380 sayılı Su Ürünleri Kanunu",
                          deger: "Madde " + YaptirimKurallari.maddeDegeri(k),
                          kaynak: ayar.resmiKaynaklar["kanun"])
        }
        if let m = y.yonetmelikMaddesi {
            DayanakSatiri(etiket: "SU ÜRÜNLERİ YÖNETMELİĞİ", baslik: nil,
                          deger: YaptirimKurallari.maddeDegeri(m), kaynak: ayar.resmiKaynaklar["yonetmelik"])
        }
        if let t = y.tebligMaddesi {
            DayanakSatiri(etiket: "İLGİLİ TEBLİĞ", baslik: nil, deger: YaptirimKurallari.maddeDegeri(t),
                          kaynak: ayar.resmiKaynaklar[YaptirimKurallari.tebligAnahtari(t)])
        }
        if let d = y.kaynakMetni {
            DayanakSatiri(etiket: "İDARİ YAPTIRIMIN DAYANAĞI", baslik: nil, deger: d, kaynak: nil)
        }
        AciklamaBlogu(baslik: "Ne anlatıyor?",
                      metin: y.kanunMaddesi.map {
                          "Bu kayıt, 1380 sayılı Su Ürünleri Kanunu'nun \(YaptirimKurallari.maddeDegeri($0)) dayanağıyla ilişkilendirilmiştir. İhlalin konusu ve uygulanacak yaptırım aşağıdaki kartta ayrıca gösterilmiştir."
                      } ?? "Bu kayıt için veritabanında kanun maddesi belirtilmemiştir.")
        UyariKutusu(tur: .bilgi, baslik: "Kontrol gerekli:",
                    metin: "Bu kayıt kaynak bilgisine dayanmaktadır. Güncel mevzuat, madde/fiil eşleştirmesi, yetki ve sevk makamı işlem tesis edilmeden önce ayrıca doğrulanmalıdır.")
    }

    // MARK: İdari para cezası

    @ViewBuilder
    private func cezaBolumu(kod: String) -> some View {
        Text("Uygulanacak idarî yaptırım")
            .font(.footnote.weight(.semibold))
            .foregroundColor(Renk.soluk)
        HStack(spacing: 6) {
            Hap(metin: kod.isEmpty ? "—" : kod, renk: Renk.kirmizi, zemin: Renk.kirmiziZemin)
            if !kod.isEmpty {
                Hap(metin: "İdarî para cezası", renk: Renk.mavi, zemin: Renk.tint)
            }
        }
        CezaTutari(ceza: YaptirimKurallari.ceza(yaptirim, ayar: ayar), yil: ayar.yil)
        AciklamaBlogu(baslik: "Kısaca", metin: YaptirimKurallari.kisaca(yaptirim, ayar: ayar))
        UyariKutusu(tur: .bilgi, baslik: "Kontrol gerekli:",
                    metin: "Bu kayıt kaynak bilgisine dayanmaktadır. Güncel mevzuat, madde/fiil eşleştirmesi, yetki ve sevk makamı işlem tesis edilmeden önce ayrıca doğrulanmalıdır.")
    }
}

struct ElKoymaSatiri: View {
    let sembol: String
    let baslik: String
    let deger: String

    var body: some View {
        let l = deger.lowercased(with: TRMetin.tr)
        let evet = l == "evet"
        let hayir = l == "hayır" || l == "hayir"
        HStack(spacing: 10) {
            Sembol(ad: sembol, yedek: "circle")
                .foregroundColor(Renk.mavi)
                .frame(width: 22)
            Text(baslik)
                .font(.footnote.weight(.semibold))
                .foregroundColor(Renk.murekkep)
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(Renk.soluk)
            Text(evet ? "EVET" : (hayir ? "HAYIR" : deger))
                .font(.footnote.weight(.bold))
                .foregroundColor(evet ? Renk.yesil : (hayir ? Renk.kirmizi : Renk.murekkep))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(evet ? Renk.yesilZemin : (hayir ? Renk.kirmiziZemin : Renk.kart))
                .cornerRadius(8)
        }
    }
}

struct DayanakSatiri: View {
    let etiket: String
    let baslik: String?
    let deger: String
    let kaynak: YaptirimAyari.Kaynak?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(etiket)
                .font(.caption2.weight(.bold))
                .foregroundColor(Renk.mavi)
            if let b = baslik {
                Text(b)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Renk.murekkep)
            }
            Text(deger)
                .font(.footnote)
                .foregroundColor(Renk.murekkep)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if let k = kaynak, let u = URL(string: k.url) {
                Link(destination: u) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Resmî metni aç")
                            .fontWeight(.semibold)
                        Text(KaynakListesi.alanAdi(k.url))
                            .foregroundColor(Renk.soluk)
                    }
                    .font(.caption)
                    .foregroundColor(Renk.mavi)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Renk.ikincil)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Renk.cizgi, lineWidth: 1))
        .cornerRadius(10)
    }
}

struct CezaTutari: View {
    let ceza: YaptirimKurallari.Ceza
    let yil: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(String(yil)) İDARİ PARA CEZASI")
                .font(.caption2.weight(.bold))
                .foregroundColor(Renk.kirmizi)
            switch ceza {
            case .tutar(let t):
                Text(t)
                    .font(.title3.weight(.bold))
                    .foregroundColor(Renk.kirmizi)
            case .kosullar(let satirlar, let not):
                ForEach(Array(satirlar.enumerated()), id: \.offset) { _, s in
                    KosulSatiri(metin: s)
                }
                if let n = not, !n.isEmpty {
                    Rozet(metin: n)
                }
            case .bosKosul:
                Text("Tutar, ilgili fiilin uygulama koşullarına göre belirlenir.")
                    .font(.footnote)
                    .foregroundColor(Renk.kirmizi)
            case .olayBazli:
                ElleDegerlendirme(
                    baslik: "Olay bazlı değerlendirme",
                    metin: "12 metreden küçük olması tek başına kesin ceza tutarını belirlemez.",
                    satirlar: [
                        ("Avcılık alanı:", "Bölge ve saha yasağı kontrol edilmelidir."),
                        ("Tarih / yasak dönemi:", "İlgili dönemsel yasaklar kontrol edilmelidir."),
                        ("Trol türü:", "Dip trolü veya orta su trolü olduğu belirlenmelidir."),
                        ("Kişi / gemi:", "Uygulanacak kişi ve varsa gemi sahibi/donatan yönünden değerlendirme yapılmalıdır."),
                        ("Sonuç:", "Somut olay belirlendikten sonra uygun 36/1-l alt bendi ve \(String(yil)) tutarı seçilmelidir."),
                    ],
                    rozet: "OLAY BAZLI — OTOMATİK TUTAR SEÇİLMEZ")
            case .trolAltTuru:
                ElleDegerlendirme(
                    baslik: "Trol alt türü doğrulanmalı",
                    metin: "Bu kayıt için yalnızca \"trol\" ifadesi yeterli değildir. Fiilin dip trolü, genel trol veya başka bir alt tür olup olmadığı belirlenmelidir.",
                    satirlar: [],
                    rozet: "SOMUT FİİL / ALT TÜR KONTROLÜ GEREKLİ")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Renk.kirmiziZemin)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Renk.kirmizi.opacity(0.25), lineWidth: 1))
        .cornerRadius(12)
    }
}

struct KosulSatiri: View {
    let metin: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Renk.kirmizi)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            Text(KosulSatiri.bicimli(metin))
                .font(.footnote)
                .foregroundColor(Renk.murekkep)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Renk.kart)
        .cornerRadius(8)
    }

    /// "**...**" kısımlarını kalın gösterir.
    static func bicimli(_ s: String) -> AttributedString {
        if let a = try? AttributedString(markdown: s) {
            return a
        }
        return AttributedString(s)
    }
}

struct Rozet: View {
    let metin: String

    var body: some View {
        Text(metin)
            .font(.caption.weight(.semibold))
            .foregroundColor(Renk.amber)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Renk.amberZemin)
            .cornerRadius(8)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct ElleDegerlendirme: View {
    let baslik: String
    let metin: String
    let satirlar: [(String, String)]
    let rozet: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(baslik)
                .font(.subheadline.weight(.bold))
                .foregroundColor(Renk.murekkep)
            Text(metin)
                .font(.footnote)
                .foregroundColor(Renk.murekkep)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(satirlar.enumerated()), id: \.offset) { _, s in
                (Text(s.0 + " ").bold() + Text(s.1))
                    .font(.footnote)
                    .foregroundColor(Renk.murekkep)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Renk.ikincil)
                    .cornerRadius(8)
            }
            Rozet(metin: rozet)
        }
        .padding(10)
        .background(Renk.kart)
        .cornerRadius(10)
    }
}

struct YaptirimKaynaklari: View {
    let ayar: YaptirimAyari

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Resmî kaynaklar")
                .font(.headline)
                .foregroundColor(Renk.murekkep)
            Text("Bu bölümdeki bilgiler aşağıdaki mevzuata dayanır. İşlem yapmadan önce güncel metni resmî kaynaktan kontrol edin.")
                .font(.footnote)
                .foregroundColor(Renk.soluk)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                ForEach(ayar.kaynakSirasi, id: \.self) { anahtar in
                    if let k = ayar.resmiKaynaklar[anahtar] {
                        KaynakSatiri(kaynak: k)
                        Divider().padding(.leading, 14)
                    }
                }
                Text("GENEL RESMÎ SİTELER")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(Renk.soluk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                ForEach(Array(ayar.genelKaynaklar.enumerated()), id: \.offset) { _, k in
                    KaynakSatiri(kaynak: k)
                }
            }
            .kart()
        }
    }
}

struct KaynakSatiri: View {
    let kaynak: YaptirimAyari.Kaynak

    var body: some View {
        if let u = URL(string: kaynak.url) {
            Link(destination: u) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kaynak.ad)
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Renk.mavi)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(KaynakListesi.alanAdi(kaynak.url))
                            .font(.caption2)
                            .foregroundColor(Renk.soluk)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(Renk.mavi)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
            }
        }
    }
}
