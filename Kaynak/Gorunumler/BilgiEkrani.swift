import SwiftUI

// MARK: - Veri (api/bilgi.php — sitedeki bilgi.php ile aynı kurallar)

struct BilgiVerisi: Codable {
    struct BilgiSeti: Codable {
        let id: Int
        let baslik: String
        let tarih: String
        let bitis: String
        let acik: Bool
        let arsiv: Bool
    }

    struct Sik: Codable, Identifiable {
        let k: String
        let harf: String
        let metin: String
        var id: String { k }
    }

    struct Cevap: Codable {
        let secilen: String
        let dogruMu: Bool
    }

    struct Soru: Codable, Identifiable {
        let id: Int
        let no: Int
        let soru: String
        let siklar: [Sik]
        let kilitli: Bool
        let cevap: Cevap?
        let dogru: String?
        let dogruHarf: String?
        let aciklama: String?
        let kaynak: String?
    }

    struct Ozet: Codable {
        let toplam: Int
        let cevap: Int
        let dogru: Int
        let puan: Int
        let tamPuan: Int
        let tamamlandi: Bool
        let siram: Int
    }

    struct SiraSatiri: Codable, Identifiable {
        let sira: Int
        let ad: String
        let puan: Int
        let ben: Bool
        var id: Int { sira }
    }

    struct Siralama: Codable {
        let liste: [SiraSatiri]
        let siram: Int
        let katilimci: Int
    }

    struct Siralamalar: Codable {
        let hafta: Siralama?
        let genel: Siralama
    }

    struct GecmisSet: Codable, Identifiable {
        let id: Int
        let baslik: String
        let tarih: String
        let katildi: Bool
        let puan: Int
    }

    let soruPuani: Int
    let yonetici: Bool
    let bekleyen: Int
    let set: BilgiSeti?
    let sorular: [Soru]
    let ozet: Ozet
    let siralama: Siralamalar
    let gecmis: [GecmisSet]
}

// MARK: - Ekran

/// bilgi.php — Haftanın soruları.
struct BilgiEkrani: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu
    /// Geçmiş bir set açılıyorsa kimliği (bilgi.php?set=…).
    var setId: Int? = nil

    @State private var veri: BilgiVerisi?
    @State private var hata: String?
    @State private var yukleniyor = false
    @State private var bildirim: String?
    @State private var siralamaGenel = false
    @State private var cevaplarAcik = false
    @State private var gecmisAcik = false

    var body: some View {
        YenilenebilirKaydirma(eylem: { await yukle() }) {
            VStack(spacing: 0) {
                Kahraman(baslik: "Haftanın soruları",
                         aciklama: "Kısa sorularla bilgini tazele. Her doğru cevap \(veri?.soruPuani ?? 20) puan.") {
                    istatistikler
                }
                VStack(alignment: .leading, spacing: 14) {
                    if let b = bildirim {
                        Bildirim(metin: b, hata: true)
                    }
                    if let v = veri {
                        icerik(v)
                    } else if let h = hata {
                        UyariKutusu(tur: .bilgi, baslik: "Sorular yüklenemedi.", metin: h)
                        Button("Tekrar dene") { Task { await yukle() } }
                            .buttonStyle(.borderedProminent)
                            .tint(Renk.lacivert)
                    } else {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.top, 30)
                    }
                }
                .padding(16)
            }
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle("Haftanın soruları")
        .markaBasligi()
        .task { if veri == nil { await yukle() } }
    }

    // MARK: Üst alan istatistikleri (mr_header stats)

    @ViewBuilder
    private var istatistikler: some View {
        if let v = veri, v.set != nil, v.ozet.toplam > 0, !(v.set?.arsiv ?? false) {
            HStack(spacing: 8) {
                if v.ozet.tamamlandi {
                    istatistik("\(v.ozet.puan)", "puan")
                } else {
                    istatistik("\(v.ozet.cevap)/\(v.ozet.toplam)", "cevaplandı", vurgu: true)
                    if v.ozet.cevap > 0 {
                        istatistik("\(v.ozet.puan)", "puan")
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private func istatistik(_ deger: String, _ etiket: String, vurgu: Bool = false) -> some View {
        (Text(deger).bold() + Text(" " + etiket))
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(vurgu ? 0.22 : 0.14))
            .cornerRadius(999)
    }

    // MARK: Gövde

    @ViewBuilder
    private func icerik(_ v: BilgiVerisi) -> some View {
        let arsiv = v.set?.arsiv ?? false
        if v.set == nil || v.ozet.toplam == 0 {
            Text("Bu hafta için henüz soru yayınlanmadı. Yeni sorular eklendiğinde burada görünecek.")
                .font(.callout)
                .foregroundColor(Renk.soluk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(20)
                .frame(maxWidth: .infinity)
                .kart()
        } else if v.ozet.tamamlandi && !arsiv, let set = v.set {
            SonucKarti(veri: v, set: set)
            AcilirBolum(sembol: "list.bullet.rectangle", baslik: "Cevapları ve açıklamaları incele") {
                ForEach(v.sorular) { q in
                    SoruKarti(soru: q, toplam: v.ozet.toplam, puan: v.soruPuani, setAcik: set.acik, arsiv: arsiv) { s in
                        await cevapla(q, s)
                    }
                }
            }
            .padding(14)
            .kart()
        } else if let set = v.set {
            setKarti(v, set: set)
            ForEach(v.sorular) { q in
                SoruKarti(soru: q, toplam: v.ozet.toplam, puan: v.soruPuani, setAcik: set.acik, arsiv: arsiv) { s in
                    await cevapla(q, s)
                }
            }
        }

        siralamaKarti(v)

        if !v.gecmis.isEmpty && setId == nil {
            AcilirBolum(sembol: "clock.arrow.circlepath", baslik: "Geçmiş setler") {
                ForEach(v.gecmis) { g in
                    NavigationLink(destination: BilgiEkrani(setId: g.id)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(g.baslik)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Renk.murekkep)
                                Text(g.tarih)
                                    .font(.caption)
                                    .foregroundColor(Renk.soluk)
                            }
                            Spacer()
                            if g.katildi {
                                Hap(metin: "\(g.puan) puan", renk: Renk.yesil, zemin: Renk.yesilZemin)
                            } else {
                                Hap(metin: "Katılmadın", renk: Renk.soluk, zemin: Renk.ikincil)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Renk.soluk)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .kart()
        }

        Text("Cevapların ve puanın yönetici tarafından görülebilir. Sıralamada adın kısaltılmış olarak (ör. A. Yılmaz) görünür. Yöneticilerin cevapları sıralamaya dahil edilmez.")
            .font(.caption)
            .foregroundColor(Renk.soluk)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    private func setKarti(_ v: BilgiVerisi, set: BilgiVerisi.BilgiSeti) -> some View {
        let kapali = set.arsiv || !set.acik
        let oran = v.ozet.toplam > 0 ? Double(v.ozet.cevap) / Double(v.ozet.toplam) : 0
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                KartSimgesi(sembol: "questionmark.circle")
                Text(set.baslik)
                    .font(.headline)
                    .foregroundColor(Renk.murekkep)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if kapali {
                    Hap(metin: "Kapandı", renk: Renk.soluk, zemin: Renk.ikincil)
                } else {
                    Hap(metin: "Yayında", renk: Renk.yesil, zemin: Renk.yesilZemin)
                }
            }
            Text("\(set.tarih) · \(v.ozet.toplam) soru")
                .font(.footnote)
                .foregroundColor(Renk.soluk)
            ProgressView(value: oran)
                .tint(Renk.mavi)
            if !kapali {
                Text("\(v.ozet.toplam - v.ozet.cevap) soru cevabını bekliyor.")
                    .font(.footnote)
                    .foregroundColor(Renk.soluk)
            } else {
                kapandiMetni(v.ozet)
                    .font(.footnote)
                    .foregroundColor(Renk.soluk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .kart()
    }

    private func kapandiMetni(_ o: BilgiVerisi.Ozet) -> Text {
        let son = Text("Doğru cevapları ve açıklamaları inceleyebilirsin.")
        if o.cevap > 0 {
            let puan = Text("Puanın: ") + Text("\(o.puan)").bold() + Text(". ")
            return Text("Bu set kapandı. ") + puan + son
        }
        return Text("Bu set kapandı. ") + son
    }

    private func siralamaKarti(_ v: BilgiVerisi) -> some View {
        let haftaVar = v.siralama.hafta != nil
        let genel = siralamaGenel || !haftaVar
        let s = genel ? v.siralama.genel : (v.siralama.hafta ?? v.siralama.genel)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                KartSimgesi(sembol: "rosette")
                Text("Puan sıralaması")
                    .font(.headline)
                    .foregroundColor(Renk.murekkep)
            }
            HStack(spacing: 8) {
                if haftaVar {
                    SecimCipi(baslik: "Bu set", secili: !genel) { siralamaGenel = false }
                }
                SecimCipi(baslik: "Genel", secili: genel) { siralamaGenel = true }
            }
            if s.liste.isEmpty {
                Text("Henüz sıralamaya girecek cevap yok. İlk sen ol.")
                    .font(.footnote)
                    .foregroundColor(Renk.soluk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 6) {
                    ForEach(s.liste) { r in
                        HStack(spacing: 10) {
                            Text("\(r.sira)")
                                .font(.footnote.weight(.bold))
                                .foregroundColor(r.sira <= 3 ? .white : Renk.murekkep)
                                .frame(width: 26, height: 26)
                                .background(r.sira <= 3 ? Renk.lacivert : Renk.ikincil)
                                .clipShape(Circle())
                            Text(r.ad + (r.ben ? " (sen)" : ""))
                                .font(.subheadline.weight(r.ben ? .bold : .regular))
                                .foregroundColor(Renk.murekkep)
                            Spacer()
                            (Text("\(r.puan) ").bold() + Text("puan").font(.caption))
                                .font(.subheadline)
                                .foregroundColor(Renk.murekkep)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(r.ben ? Renk.tint : Color.clear)
                        .cornerRadius(10)
                    }
                }
                if s.siram > 10 {
                    (Text("Sen ") + Text("\(s.siram).").bold() + Text(" sıradasın."))
                        .font(.footnote)
                        .foregroundColor(Renk.soluk)
                }
            }
        }
        .padding(16)
        .kart()
    }

    // MARK: İşlemler

    private func yukle() async {
        guard let t = oturum.token else { return }
        if yukleniyor { return }
        yukleniyor = true
        defer { yukleniyor = false }
        do {
            veri = try await APIIstemci.bilgi(setId: setId, token: t)
            hata = nil
        } catch APIHatasi.yetkisiz(_) {
            Eylemler.cikis(oturum: oturum, depo: depo)
        } catch let e as APIHatasi {
            hata = e.aciklama
        } catch {
            hata = APIHatasi.baglanti.aciklama
        }
    }

    private func cevapla(_ q: BilgiVerisi.Soru, _ secim: String) async {
        guard let t = oturum.token else { return }
        bildirim = nil
        do {
            try await APIIstemci.bilgiCevapla(soruId: q.id, secim: secim, token: t)
        } catch APIHatasi.yetkisiz(_) {
            Eylemler.cikis(oturum: oturum, depo: depo)
            return
        } catch let e as APIHatasi {
            bildirim = e.aciklama
        } catch {
            bildirim = APIHatasi.baglanti.aciklama
        }
        await yukle()
    }
}

/// Soru kartı: açıksa şık seçilip gönderilir; kilitliyse doğru cevap ve açıklama görünür.
struct SoruKarti: View {
    let soru: BilgiVerisi.Soru
    let toplam: Int
    let puan: Int
    let setAcik: Bool
    let arsiv: Bool
    let gonder: (String) async -> Void

    @State private var secim: String?
    @State private var gonderiliyor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Soru \(soru.no) / \(toplam)")
                .font(.caption.weight(.bold))
                .foregroundColor(Renk.mavi)
            Text(soru.soru)
                .font(.callout.weight(.semibold))
                .foregroundColor(Renk.murekkep)
                .fixedSize(horizontal: false, vertical: true)

            if !soru.kilitli {
                Text("Bir şık seç:")
                    .font(.caption)
                    .foregroundColor(Renk.soluk)
                ForEach(soru.siklar) { s in
                    Button {
                        secim = s.k
                    } label: {
                        sikSatiri(s, secili: secim == s.k, durum: nil)
                    }
                    .buttonStyle(.plain)
                    .disabled(gonderiliyor)
                }
                Button {
                    guard let s = secim, !gonderiliyor else { return }
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
                    .background(Renk.lacivert.opacity(secim == nil ? 0.45 : 1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(secim == nil || gonderiliyor)
            } else {
                ForEach(soru.siklar) { s in
                    sikSatiri(s, secili: false, durum: kilitliDurum(s))
                }
                sonucSatiri
                if soru.aciklama != nil || soru.kaynak != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Açıklama")
                            .font(.footnote.weight(.bold))
                            .foregroundColor(Renk.murekkep)
                        if let a = soru.aciklama {
                            Text(a)
                                .font(.footnote)
                                .foregroundColor(Renk.murekkep)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let k = soru.kaynak {
                            Text("Dayanak: " + k)
                                .font(.caption)
                                .foregroundColor(Renk.soluk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Renk.tint)
                    .cornerRadius(12)
                }
            }
        }
        .padding(16)
        .kart()
    }

    private enum SikDurumu { case dogru, yanlis, benimDogru, notr }

    private func kilitliDurum(_ s: BilgiVerisi.Sik) -> (SikDurumu, String?) {
        let dogruMu = s.k == soru.dogru
        let benim = soru.cevap?.secilen == s.k
        if benim && dogruMu { return (.benimDogru, "Senin cevabın · Doğru") }
        if benim { return (.yanlis, "Senin cevabın") }
        if dogruMu { return (.dogru, "Doğru cevap") }
        return (.notr, nil)
    }

    private func sikSatiri(_ s: BilgiVerisi.Sik, secili: Bool, durum: (SikDurumu, String?)?) -> some View {
        let d = durum?.0 ?? .notr
        let yesil = d == .dogru || d == .benimDogru
        let kirmizi = d == .yanlis
        let zemin: Color = yesil ? Renk.yesilZemin : (kirmizi ? Renk.kirmiziZemin : (secili ? Renk.tint : Renk.ikincil))
        let cerceve: Color = yesil ? Renk.yesil : (kirmizi ? Renk.kirmizi : (secili ? Renk.mavi : Renk.cizgi))
        return HStack(alignment: .top, spacing: 10) {
            Text(s.harf)
                .font(.footnote.weight(.bold))
                .foregroundColor(secili || yesil || kirmizi ? .white : Renk.murekkep)
                .frame(width: 26, height: 26)
                .background(yesil ? Renk.yesil : (kirmizi ? Renk.kirmizi : (secili ? Renk.mavi : Renk.kart)))
                .clipShape(Circle())
                .overlay(Circle().stroke(Renk.cizgi, lineWidth: secili || yesil || kirmizi ? 0 : 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(s.metin)
                    .font(.subheadline)
                    .foregroundColor(Renk.murekkep)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let m = durum?.1 {
                    Text(m)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(yesil ? Renk.yesil : Renk.kirmizi)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(zemin)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(cerceve, lineWidth: secili || yesil || kirmizi ? 1.5 : 1))
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var sonucSatiri: some View {
        if let c = soru.cevap {
            if c.dogruMu {
                Label("Doğru bildin! +\(puan) puan", systemImage: "checkmark.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Renk.yesil)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Renk.yesilZemin)
                    .cornerRadius(10)
            } else {
                Label("Bu sefer olmadı. Doğru cevap: \(soru.dogruHarf ?? "?")", systemImage: "xmark.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Renk.kirmizi)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Renk.kirmiziZemin)
                    .cornerRadius(10)
            }
        } else if !setAcik || arsiv {
            Text("Bu soruyu süresi içinde cevaplamadın.")
                .font(.footnote.weight(.semibold))
                .foregroundColor(Renk.soluk)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Renk.ikincil)
                .cornerRadius(10)
        }
    }
}

/// Set tamamlanınca gösterilen sonuç kartı (bilgi.php "score-card").
struct SonucKarti: View {
    let veri: BilgiVerisi
    let set: BilgiVerisi.BilgiSeti

    var body: some View {
        let o = veri.ozet
        let oran = o.toplam > 0 ? Double(o.dogru) / Double(o.toplam) : 0
        let mesaj: (String, String) = oran >= 1
            ? ("Mükemmel!", "Tüm soruları doğru bildin.")
            : (oran >= 0.6
                ? ("Çok iyi!", "Yanlış yaptıklarının açıklamalarına göz atabilirsin.")
                : ("Seti tamamladın", "Açıklamaları inceleyip gelecek hafta daha iyisini yapabilirsin."))
        let katilimci = veri.siralama.hafta?.katilimci ?? 0

        return VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Renk.ikincil, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: CGFloat(oran))
                    .stroke(Renk.mavi, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(o.puan)")
                        .font(.system(size: 30, weight: .bold, design: .serif))
                        .foregroundColor(Renk.murekkep)
                    Text("/ \(o.tamPuan) puan")
                        .font(.caption)
                        .foregroundColor(Renk.soluk)
                }
            }
            .frame(width: 124, height: 124)

            Text(mesaj.0)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(Renk.murekkep)
            Text("\(o.dogru)/\(o.toplam) doğru · \(mesaj.1)")
                .font(.footnote)
                .foregroundColor(Renk.soluk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                ForEach(veri.sorular) { q in
                    let ok = q.cevap?.dogruMu ?? false
                    Text("S\(q.no) \(ok ? "✓" : "✗")")
                        .font(.caption.weight(.bold))
                        .foregroundColor(ok ? Renk.yesil : Renk.kirmizi)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ok ? Renk.yesilZemin : Renk.kirmiziZemin)
                        .cornerRadius(999)
                }
            }

            HStack(spacing: 0) {
                if o.siram > 0 {
                    meta("\(o.siram).", "bu setteki sıran")
                }
                meta("\(katilimci)", "katılımcı")
                meta(set.bitis, "set kapanışı")
            }
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .kart()
    }

    private func meta(_ deger: String, _ etiket: String) -> some View {
        VStack(spacing: 2) {
            Text(deger)
                .font(.subheadline.weight(.bold))
                .foregroundColor(Renk.murekkep)
                .multilineTextAlignment(.center)
            Text(etiket)
                .font(.caption2)
                .foregroundColor(Renk.soluk)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Sekme benzeri seçim çipi.
struct SecimCipi: View {
    let baslik: String
    let secili: Bool
    let eylem: () -> Void

    var body: some View {
        Button(action: eylem) {
            Text(baslik)
                .font(.footnote.weight(.semibold))
                .foregroundColor(secili ? .white : Renk.murekkep)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(secili ? Renk.lacivert : Renk.ikincil)
                .cornerRadius(999)
        }
        .buttonStyle(.plain)
    }
}
