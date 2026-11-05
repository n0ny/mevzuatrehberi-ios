import SwiftUI

// MARK: - Veri (api/yonetim-bilgi.php — sitedeki admin/bilgi.php ile aynı)

struct SoruSetListesi: Codable {
    struct SetOzeti: Codable, Identifiable {
        let id: Int
        let baslik: String
        let tarih: String
        let soruSayisi: Int
        let katilimci: Int
        let durum: String
        let durumTuru: String
    }
    struct GenelSatir: Codable {
        let ad: String
        let kullaniciAdi: String
        let dogru: Int
        let cevap: Int
        let son: String
    }
    struct Varsayilan: Codable {
        let baslik: String
        let baslangic: String
        let bitis: String
    }
    let personelSayisi: Int
    let setler: [SetOzeti]
    let genel: [GenelSatir]
    let varsayilan: Varsayilan
}

struct SoruSetiAyrintisi: Codable {
    struct SetBilgisi: Codable {
        let id: Int
        let baslik: String
        let baslangic: String
        let bitis: String
        let tarih: String
        let aktif: Bool
        let durum: String
        let durumTuru: String
        let duyuruldu: String?
    }
    struct Dagilim: Codable {
        let a: Int
        let b: Int
        let c: Int
        let d: Int
    }
    struct YonetimSorusu: Codable, Identifiable {
        let id: Int
        let no: Int
        let sira: Int
        let soru: String
        let sikA: String
        let sikB: String
        let sikC: String
        let sikD: String
        let dogru: String
        let aciklama: String
        let kaynak: String
        let cevapSayisi: Int
        let dagilim: Dagilim
        let dagilimToplam: Int
        let dogruOrani: Int

        struct SikSatiri: Identifiable {
            let k: String
            let harf: String
            let metin: String
            let sayi: Int
            var id: String { k }
        }

        /// Dolu şıklar (harf, metin, kaç kişi seçti)
        var siklar: [SikSatiri] {
            let tum = [SikSatiri(k: "a", harf: "A", metin: sikA, sayi: dagilim.a),
                       SikSatiri(k: "b", harf: "B", metin: sikB, sayi: dagilim.b),
                       SikSatiri(k: "c", harf: "C", metin: sikC, sayi: dagilim.c),
                       SikSatiri(k: "d", harf: "D", metin: sikD, sayi: dagilim.d)]
            return tum.filter { !$0.metin.trimmingCharacters(in: .whitespaces).isEmpty }
        }
    }
    struct Hucre: Codable {
        let secilen: String
        let dogruMu: Bool
    }
    struct Kisi: Codable {
        let ad: String
        let kullaniciAdi: String
        let admin: Bool
        let dogru: Int
        let son: String
        let cevaplar: [Hucre?]
    }
    struct Katilmayan: Codable {
        let ad: String
        let kullaniciAdi: String
        let sonGiris: String?
    }
    let personelSayisi: Int
    let set: SetBilgisi
    let sorular: [YonetimSorusu]
    let katilimci: Int
    let kisiler: [Kisi]
    let katilmayanlar: [Katilmayan]

    var yayinda: Bool { return self.set.durumTuru == "yayinda" }
}

enum GunBicimi {
    static let bicimci: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func tarih(_ s: String) -> Date { bicimci.date(from: s) ?? Date() }
    static func metin(_ d: Date) -> String { bicimci.string(from: d) }
}

/// Set durum rozeti (admin/bilgi.php set_durum).
struct SetDurumHapi: View {
    let durum: String
    let tur: String

    var body: some View {
        switch tur {
        case "yayinda": Hap(metin: durum, renk: Renk.yesil, zemin: Renk.yesilZemin)
        case "planlandi": Hap(metin: durum, renk: Renk.amber, zemin: Renk.amberZemin)
        default: Hap(metin: durum, renk: Renk.soluk, zemin: Renk.ikincil)
        }
    }
}

// MARK: - Set listesi

/// admin/bilgi.php — Haftanın soruları yönetimi (set listesi).
struct SoruSetleriEkrani: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu

    @State private var veri: SoruSetListesi?
    @State private var hata: String?
    @State private var mesaj: (metin: String, hata: Bool)?
    @State private var bekliyor = false
    @State private var yeniAcik = false
    @State private var baslik = ""
    @State private var baslangic = Date()
    @State private var bitis = Date()
    @State private var aktif = true
    @State private var acilacakSet: Int?

    var body: some View {
        YenilenebilirKaydirma(eylem: { await yukle() }) {
            VStack(spacing: 0) {
                Kahraman(baslik: "Haftanın soruları",
                         aciklama: "Haftalık soru setlerini hazırla, personelin cevaplarını takip et.")
                VStack(alignment: .leading, spacing: 14) {
                    if let m = mesaj {
                        Bildirim(metin: m.metin, hata: m.hata)
                    }
                    if let v = veri {
                        yeniSetKarti(v)
                        setlerKarti(v)
                        genelKarti(v)
                    } else if let h = hata {
                        UyariKutusu(tur: .bilgi, baslik: "Liste yüklenemedi.", metin: h)
                    } else {
                        HStack { Spacer(); ProgressView(); Spacer() }.padding(.top, 20)
                    }
                }
                .padding(16)
                if let id = acilacakSet {
                    NavigationLink(destination: SoruSetiEkrani(setId: id),
                                   isActive: Binding(get: { acilacakSet != nil },
                                                     set: { if !$0 { acilacakSet = nil } })) {
                        EmptyView()
                    }
                    .hidden()
                }
            }
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle("Haftanın soruları")
        .markaBasligi()
        .onAppear { Task { await yukle() } }
    }

    private func yeniSetKarti(_ v: SoruSetListesi) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { yeniAcik.toggle() }
            } label: {
                HStack(spacing: 12) {
                    KartSimgesi(sembol: "plus.circle")
                    Text("Yeni haftalık set oluştur")
                        .font(.headline)
                        .foregroundColor(Renk.murekkep)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(yeniAcik ? 180 : 0))
                        .foregroundColor(Renk.soluk)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if yeniAcik {
                Giris(etiket: "Set başlığı") {
                    TextField("Set başlığı", text: $baslik)
                        .foregroundColor(Renk.murekkep)
                }
                DatePicker("Başlangıç", selection: $baslangic, displayedComponents: .date)
                    .font(.subheadline)
                DatePicker("Bitiş", selection: $bitis, displayedComponents: .date)
                    .font(.subheadline)
                Toggle("Aktif (tarih aralığı gelince personele görünsün)", isOn: $aktif)
                    .font(.footnote)
                    .tint(Renk.mavi)
                AnaDugme(baslik: "Seti oluştur", bekliyor: bekliyor) {
                    Task {
                        let alanlar = ["set_id": "0", "baslik": baslik,
                                       "baslangic": GunBicimi.metin(baslangic), "bitis": GunBicimi.metin(bitis),
                                       "aktif": aktif ? "1" : "0"]
                        if let id = await islem("set_kaydet", alanlar) {
                            yeniAcik = false
                            acilacakSet = id
                        }
                    }
                }
            }
        }
        .padding(16)
        .kart()
    }

    private func setlerKarti(_ v: SoruSetListesi) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                KartSimgesi(sembol: "list.bullet.rectangle")
                Text("Setler").font(.headline).foregroundColor(Renk.murekkep)
                Spacer()
                Hap(metin: "\(v.setler.count)")
            }
            if v.setler.isEmpty {
                Text("Henüz set yok. Yukarıdan ilk haftalık seti oluştur.")
                    .font(.footnote).foregroundColor(Renk.soluk)
                    .padding(.vertical, 8)
            }
            ForEach(v.setler) { s in
                NavigationLink(destination: SoruSetiEkrani(setId: s.id)) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(s.baslik)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Renk.murekkep)
                                .multilineTextAlignment(.leading)
                            Text("\(s.tarih) · \(s.soruSayisi) soru · \(s.katilimci)/\(v.personelSayisi) katılım")
                                .font(.caption)
                                .foregroundColor(Renk.soluk)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 6)
                        SetDurumHapi(durum: s.durum, tur: s.durumTuru)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Renk.soluk)
                            .padding(.top, 4)
                    }
                    .padding(12)
                    .background(Renk.ikincil)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .kart()
    }

    private func genelKarti(_ v: SoruSetListesi) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                KartSimgesi(sembol: "rosette")
                Text("Genel sıralama (tam isimler)").font(.headline).foregroundColor(Renk.murekkep)
            }
            Text("Personel bu listeyi kısaltılmış isimlerle görür. Yöneticiler dahil edilmez.")
                .font(.caption).foregroundColor(Renk.soluk)
                .fixedSize(horizontal: false, vertical: true)
            if v.genel.isEmpty {
                Text("Henüz cevap yok.").font(.footnote).foregroundColor(Renk.soluk)
            }
            ForEach(Array(v.genel.enumerated()), id: \.offset) { i, g in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)")
                        .font(.footnote.weight(.bold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Renk.lacivert)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(g.ad).font(.subheadline.weight(.semibold)).foregroundColor(Renk.murekkep)
                        Text("\(g.kullaniciAdi) · Son cevap: \(g.son)")
                            .font(.caption).foregroundColor(Renk.soluk)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(g.dogru) doğru").font(.footnote.weight(.bold)).foregroundColor(Renk.murekkep)
                        Text("\(g.cevap) cevap").font(.caption).foregroundColor(Renk.soluk)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .kart()
    }

    private func yukle() async {
        guard let t = oturum.token else { return }
        do {
            let v = try await APIIstemci.soruSetleri(token: t)
            if veri == nil {
                baslik = v.varsayilan.baslik
                baslangic = GunBicimi.tarih(v.varsayilan.baslangic)
                bitis = GunBicimi.tarih(v.varsayilan.bitis)
                yeniAcik = v.setler.isEmpty
            }
            veri = v
            hata = nil
        } catch APIHatasi.yetkisiz(_) {
            Eylemler.cikis(oturum: oturum, depo: depo)
        } catch let e as APIHatasi {
            hata = e.aciklama
        } catch {
            hata = APIHatasi.baglanti.aciklama
        }
    }

    /// Başarılıysa (yeni) set kimliğini döner.
    private func islem(_ ad: String, _ alanlar: [String: String]) async -> Int? {
        guard let t = oturum.token, !bekliyor else { return nil }
        bekliyor = true
        defer { bekliyor = false }
        mesaj = nil
        do {
            let s = try await APIIstemci.soruSetiIslem(ad, alanlar: alanlar, token: t)
            mesaj = (s.mesaj, false)
            await yukle()
            return s.setId ?? 0
        } catch APIHatasi.yetkisiz(_) {
            Eylemler.cikis(oturum: oturum, depo: depo)
        } catch let e as APIHatasi {
            mesaj = (e.aciklama, true)
        } catch {
            mesaj = (APIHatasi.baglanti.aciklama, true)
        }
        return nil
    }
}

// MARK: - Set ayrıntısı

/// admin/bilgi.php?set=… — Sorular ve Sonuçlar sekmeleri.
struct SoruSetiEkrani: View {
    let setId: Int
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu
    @Environment(\.dismiss) private var geri

    @State private var veri: SoruSetiAyrintisi?
    @State private var hata: String?
    @State private var mesaj: (metin: String, hata: Bool)?
    @State private var bekliyor = false
    @State private var sonuclar = false
    @State private var duzenlenen: Int?
    @State private var formSurumu = 0
    @State private var soru: YonetimEkrani.Soru?

    @State private var ayarAcik = false
    @State private var setBaslik = ""
    @State private var setBaslangic = Date()
    @State private var setBitis = Date()
    @State private var setAktif = true

    var body: some View {
        ScrollViewReader { kaydirici in
            YenilenebilirKaydirma(eylem: { await yukle() }) {
                VStack(spacing: 0) {
                    Kahraman(baslik: veri?.set.baslik ?? "Soru seti",
                             aciklama: veri.map { "\($0.set.tarih) · \($0.set.durum)" })
                    VStack(alignment: .leading, spacing: 14) {
                        if let m = mesaj {
                            Bildirim(metin: m.metin, hata: m.hata).id("ust")
                        }
                        if let v = veri {
                            HStack(spacing: 8) {
                                SecimCipi(baslik: "Sorular (\(v.sorular.count))", secili: !sonuclar) { sonuclar = false }
                                SecimCipi(baslik: "Sonuçlar (\(v.katilimci)/\(v.personelSayisi))", secili: sonuclar) { sonuclar = true }
                            }
                            if sonuclar {
                                SoruSonuclari(veri: v)
                            } else {
                                duyurKarti(v)
                                sorularKarti(v, kaydirici: kaydirici)
                                SoruFormu(setId: setId,
                                          soru: v.sorular.first { $0.id == duzenlenen },
                                          soruSayisi: v.sorular.count,
                                          bekliyor: bekliyor,
                                          kaydet: { alanlar in await islem("soru_kaydet", alanlar) },
                                          vazgec: { duzenlenen = nil; formSurumu += 1 })
                                    .id("form-\(duzenlenen ?? 0)-\(formSurumu)")
                                ayarlarKarti(v)
                            }
                        } else if let h = hata {
                            UyariKutusu(tur: .bilgi, baslik: "Set yüklenemedi.", metin: h)
                        } else {
                            HStack { Spacer(); ProgressView(); Spacer() }.padding(.top, 20)
                        }
                    }
                    .padding(16)
                }
            }
            .onChange(of: mesaj?.metin) { _ in
                withAnimation { kaydirici.scrollTo("ust", anchor: .top) }
            }
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle("Soru seti")
        .markaBasligi()
        .task { if veri == nil { await yukle() } }
        .alert(item: $soru) { s in
            Alert(title: Text(s.baslik),
                  primaryButton: s.yikici
                    ? .destructive(Text(s.dugme)) { Task { await onayliIslem(s) } }
                    : .default(Text(s.dugme)) { Task { await onayliIslem(s) } },
                  secondaryButton: .cancel(Text("Vazgeç")))
        }
    }

    // MARK: Personele duyur

    private func duyurKarti(_ v: SoruSetiAyrintisi) -> some View {
        let olur = v.yayinda && !v.sorular.isEmpty
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                KartSimgesi(sembol: "megaphone")
                Text("Personele duyur").font(.headline).foregroundColor(Renk.murekkep)
                Spacer()
                SetDurumHapi(durum: v.set.durum, tur: v.set.durumTuru)
            }
            (Text("Kayıtlı cihazlara \"Haftanın soruları yayında\" bildirimi gönderir.")
                + (v.set.duyuruldu.map { Text(" Son duyuru: ") + Text($0).bold() + Text(".") } ?? Text("")))
                .font(.footnote)
                .foregroundColor(Renk.soluk)
                .fixedSize(horizontal: false, vertical: true)
            AnaDugme(baslik: "Bildirim gönder", bekliyor: bekliyor) {
                soru = YonetimEkrani.Soru(baslik: "Bu set için tüm personele bildirim gönderilsin mi?",
                                          dugme: "Gönder", yikici: false,
                                          islem: "duyur", alanlar: ["set_id": String(setId)])
            }
            .disabled(!olur)
            .opacity(olur ? 1 : 0.5)
            if !olur {
                Text("Set yayında olduğunda ve en az bir soru eklendiğinde duyurabilirsin.")
                    .font(.caption).foregroundColor(Renk.soluk)
            }
            Text("Şimdilik yalnızca Android telefonlara ulaşır.")
                .font(.caption).foregroundColor(Renk.amber)
        }
        .padding(16)
        .kart()
    }

    // MARK: Sorular

    private func sorularKarti(_ v: SoruSetiAyrintisi, kaydirici: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                KartSimgesi(sembol: "questionmark.circle")
                Text("Sorular").font(.headline).foregroundColor(Renk.murekkep)
                Spacer()
                Hap(metin: "\(v.sorular.count)/5")
            }
            if v.sorular.isEmpty {
                Text("Bu sette henüz soru yok. Aşağıdan ekleyebilirsin.")
                    .font(.footnote).foregroundColor(Renk.soluk)
            }
            ForEach(v.sorular) { q in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("S\(q.no)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Renk.lacivert)
                            .cornerRadius(6)
                        Text(q.soru)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Renk.murekkep)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(q.siklar) { s in
                        Text("\(s.harf)) \(s.metin)")
                            .font(.caption.weight(s.k == q.dogru ? .bold : .regular))
                            .foregroundColor(s.k == q.dogru ? Renk.yesil : Renk.soluk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !q.kaynak.isEmpty {
                        Text("Dayanak: " + q.kaynak).font(.caption).foregroundColor(Renk.soluk)
                    }
                    Text("\(q.cevapSayisi) kişi cevapladı").font(.caption).foregroundColor(Renk.soluk)
                    HStack(spacing: 8) {
                        Button {
                            duzenlenen = q.id
                            let hedef = "form-\(q.id)-\(formSurumu)"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation { kaydirici.scrollTo(hedef, anchor: .top) }
                            }
                        } label: {
                            Text("Düzenle")
                                .font(.footnote.weight(.semibold))
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .foregroundColor(Renk.mavi)
                                .background(Renk.tint)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        Button {
                            soru = YonetimEkrani.Soru(baslik: "Soru ve verilen \(q.cevapSayisi) cevap silinsin mi?",
                                                      dugme: "Sil", yikici: true, islem: "soru_sil",
                                                      alanlar: ["set_id": String(setId), "soru_id": String(q.id)])
                        } label: {
                            Text("Sil")
                                .font(.footnote.weight(.semibold))
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .foregroundColor(Renk.kirmizi)
                                .background(Renk.kirmiziZemin)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(duzenlenen == q.id ? Renk.tint : Renk.ikincil)
                .cornerRadius(12)
            }
        }
        .padding(16)
        .kart()
    }

    // MARK: Set ayarları

    private func ayarlarKarti(_ v: SoruSetiAyrintisi) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { ayarAcik.toggle() }
            } label: {
                HStack(spacing: 12) {
                    KartSimgesi(sembol: "gearshape")
                    Text("Set ayarları").font(.headline).foregroundColor(Renk.murekkep)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(ayarAcik ? 180 : 0))
                        .foregroundColor(Renk.soluk)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if ayarAcik {
                Giris(etiket: "Set başlığı") {
                    TextField("Set başlığı", text: $setBaslik).foregroundColor(Renk.murekkep)
                }
                DatePicker("Başlangıç", selection: $setBaslangic, displayedComponents: .date).font(.subheadline)
                DatePicker("Bitiş", selection: $setBitis, displayedComponents: .date).font(.subheadline)
                Toggle("Aktif (kapalıysa personel bu seti hiç görmez)", isOn: $setAktif)
                    .font(.footnote)
                    .tint(Renk.mavi)
                AnaDugme(baslik: "Kaydet", bekliyor: bekliyor) {
                    Task {
                        _ = await islem("set_kaydet", ["set_id": String(setId), "baslik": setBaslik,
                                                       "baslangic": GunBicimi.metin(setBaslangic),
                                                       "bitis": GunBicimi.metin(setBitis),
                                                       "aktif": setAktif ? "1" : "0"])
                    }
                }
                Button {
                    soru = YonetimEkrani.Soru(baslik: "Set, tüm soruları ve verilen tüm cevaplarla birlikte kalıcı olarak silinsin mi?",
                                              dugme: "Seti sil", yikici: true, islem: "set_sil",
                                              alanlar: ["set_id": String(setId)])
                } label: {
                    Text("Seti sil")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(.white)
                        .background(Renk.kirmizi)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(bekliyor)
            }
        }
        .padding(16)
        .kart()
    }

    // MARK: İşlemler

    private func yukle() async {
        guard let t = oturum.token else { return }
        do {
            let v = try await APIIstemci.soruSeti(id: setId, token: t)
            veri = v
            hata = nil
            setBaslik = v.set.baslik
            setBaslangic = GunBicimi.tarih(v.set.baslangic)
            setBitis = GunBicimi.tarih(v.set.bitis)
            setAktif = v.set.aktif
        } catch APIHatasi.yetkisiz(_) {
            Eylemler.cikis(oturum: oturum, depo: depo)
        } catch let e as APIHatasi {
            hata = e.aciklama
        } catch {
            hata = APIHatasi.baglanti.aciklama
        }
    }

    private func onayliIslem(_ s: YonetimEkrani.Soru) async {
        let tamam = await islem(s.islem, s.alanlar)
        if tamam && s.islem == "set_sil" {
            geri()
        }
    }

    /// Başarılıysa true döner.
    @discardableResult
    private func islem(_ ad: String, _ alanlar: [String: String]) async -> Bool {
        guard let t = oturum.token, !bekliyor else { return false }
        bekliyor = true
        defer { bekliyor = false }
        mesaj = nil
        do {
            let s = try await APIIstemci.soruSetiIslem(ad, alanlar: alanlar, token: t)
            mesaj = (s.mesaj, false)
            if ad == "soru_kaydet" || ad == "soru_sil" {
                duzenlenen = nil
                formSurumu += 1
            }
            if ad != "set_sil" {
                await yukle()
            }
            return true
        } catch APIHatasi.yetkisiz(_) {
            Eylemler.cikis(oturum: oturum, depo: depo)
        } catch let e as APIHatasi {
            mesaj = (e.aciklama, true)
        } catch {
            mesaj = (APIHatasi.baglanti.aciklama, true)
        }
        return false
    }
}

/// Soru ekle / düzenle formu (admin/bilgi.php).
struct SoruFormu: View {
    let setId: Int
    let soru: SoruSetiAyrintisi.YonetimSorusu?
    let soruSayisi: Int
    let bekliyor: Bool
    let kaydet: ([String: String]) async -> Bool
    let vazgec: () -> Void

    @State private var metin = ""
    @State private var sikA = ""
    @State private var sikB = ""
    @State private var sikC = ""
    @State private var sikD = ""
    @State private var dogru = ""
    @State private var aciklama = ""
    @State private var kaynak = ""
    @State private var hazir = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                KartSimgesi(sembol: soru == nil ? "plus.circle" : "pencil")
                Text(soru == nil ? "Soru ekle" : "Soruyu düzenle")
                    .font(.headline).foregroundColor(Renk.murekkep)
            }
            if let q = soru, q.cevapSayisi > 0 {
                UyariKutusu(tur: .bilgi, baslik: "Dikkat:",
                            metin: "Bu soruyu \(q.cevapSayisi) kişi cevapladı. Doğru şıkkı değiştirirsen verilen cevapların puanları yeniden hesaplanır.")
            } else if soru == nil && soruSayisi >= 5 {
                UyariKutusu(tur: .bilgi, baslik: "Bilgi:",
                            metin: "Bu sette zaten \(soruSayisi) soru var. Haftalık set için 5 soru önerilir.")
            }
            metinKutusu("Soru", $metin, ipucu: "Ör. Geminin bulunduğu yerden ayrılmasına ne denir?", enFazla: 1000)
            Group {
                sik("A şıkkı", $sikA)
                sik("B şıkkı", $sikB)
                sik("C şıkkı (isteğe bağlı)", $sikC)
                sik("D şıkkı (isteğe bağlı)", $sikD)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("Doğru cevap").font(.caption.weight(.semibold)).foregroundColor(Renk.soluk)
                Picker("Doğru cevap", selection: $dogru) {
                    Text("A").tag("a")
                    Text("B").tag("b")
                    Text("C").tag("c")
                    Text("D").tag("d")
                }
                .pickerStyle(.segmented)
                Text("Kaydetmeden önce kontrol et: personel bu şıkkı doğru cevap olarak görecek.")
                    .font(.caption).foregroundColor(Renk.soluk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            metinKutusu("Açıklama (cevaptan sonra gösterilir)", $aciklama,
                        ipucu: "Doğru cevabın neden doğru olduğunu kısaca açıkla.", enFazla: 2000)
            VStack(alignment: .leading, spacing: 5) {
                Giris(etiket: "Dayanak / kaynak") {
                    TextField("Ör. 1380 sayılı Kanun md. 23", text: $kaynak)
                        .foregroundColor(Renk.murekkep)
                        .onChange(of: kaynak) { y in if y.count > 255 { kaynak = String(y.prefix(255)) } }
                }
                Text("Personel cevabı verdikten sonra açıklamanın altında görür.")
                    .font(.caption).foregroundColor(Renk.soluk)
            }
            AnaDugme(baslik: soru == nil ? "Soruyu ekle" : "Değişiklikleri kaydet", bekliyor: bekliyor) {
                let alanlar: [String: String] = [
                    "set_id": String(setId),
                    "soru_id": String(soru?.id ?? 0),
                    "sira": String(soru?.sira ?? 0),
                    "soru": metin, "sik_a": sikA, "sik_b": sikB, "sik_c": sikC, "sik_d": sikD,
                    "dogru": dogru, "aciklama": aciklama, "kaynak": kaynak,
                ]
                Task { _ = await kaydet(alanlar) }
            }
            if soru != nil {
                Button("Vazgeç", action: vazgec)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(Renk.mavi)
                    .background(Renk.tint)
                    .cornerRadius(12)
            }
        }
        .padding(16)
        .kart()
        .onAppear {
            guard !hazir else { return }
            hazir = true
            if let q = soru {
                metin = q.soru
                sikA = q.sikA
                sikB = q.sikB
                sikC = q.sikC
                sikD = q.sikD
                dogru = q.dogru
                aciklama = q.aciklama
                kaynak = q.kaynak
            }
        }
    }

    private func sik(_ etiket: String, _ deger: Binding<String>) -> some View {
        Giris(etiket: etiket) {
            TextField(etiket, text: deger)
                .foregroundColor(Renk.murekkep)
                .onChange(of: deger.wrappedValue) { y in if y.count > 255 { deger.wrappedValue = String(y.prefix(255)) } }
        }
    }

    private func metinKutusu(_ etiket: String, _ deger: Binding<String>, ipucu: String, enFazla: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(etiket).font(.caption.weight(.semibold)).foregroundColor(Renk.soluk)
            ZStack(alignment: .topLeading) {
                if deger.wrappedValue.isEmpty {
                    Text(ipucu)
                        .foregroundColor(Renk.soluk.opacity(0.8))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: deger)
                    .saydamMetinKutusu()
                    .frame(minHeight: 90)
                    .foregroundColor(Renk.murekkep)
                    .onChange(of: deger.wrappedValue) { y in
                        if y.count > enFazla { deger.wrappedValue = String(y.prefix(enFazla)) }
                    }
            }
            .padding(7)
            .background(Renk.ikincil)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Renk.cizgi, lineWidth: 1))
        }
    }
}

/// Sonuçlar sekmesi: kim ne cevapladı, soru bazında dağılım, katılmayanlar.
struct SoruSonuclari: View {
    let veri: SoruSetiAyrintisi

    var body: some View {
        if veri.sorular.isEmpty {
            Text("Bu sette henüz soru yok.")
                .font(.footnote).foregroundColor(Renk.soluk)
                .frame(maxWidth: .infinity).padding(20).kart()
        } else {
            kimKarti
            dagilimKarti
            AcilirBolum(sembol: "person.crop.circle.badge.xmark",
                        baslik: "Katılmayan personel (\(veri.katilmayanlar.count))") {
                if veri.katilmayanlar.isEmpty {
                    Text("Tüm aktif personel katıldı.").font(.footnote).foregroundColor(Renk.soluk)
                }
                ForEach(Array(veri.katilmayanlar.enumerated()), id: \.offset) { _, k in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(k.ad).font(.subheadline.weight(.semibold)).foregroundColor(Renk.murekkep)
                        Text("\(k.kullaniciAdi) · " + (k.sonGiris.map { "Son giriş: " + $0 } ?? "Henüz giriş yapmadı"))
                            .font(.caption).foregroundColor(Renk.soluk)
                    }
                    .padding(.vertical, 3)
                }
            }
            .padding(14)
            .kart()
        }
    }

    private var kimKarti: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                KartSimgesi(sembol: "person.2")
                Text("Kim ne cevapladı?").font(.headline).foregroundColor(Renk.murekkep)
                Spacer()
                Hap(metin: "\(veri.kisiler.count) kişi")
            }
            if veri.kisiler.isEmpty {
                Text("Bu sete henüz kimse cevap vermedi.").font(.footnote).foregroundColor(Renk.soluk)
            }
            ForEach(Array(veri.kisiler.enumerated()), id: \.offset) { _, k in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(k.ad).font(.subheadline.weight(.semibold)).foregroundColor(Renk.murekkep)
                                if k.admin {
                                    Hap(metin: "admin", renk: Renk.soluk, zemin: Renk.ikincil)
                                }
                            }
                            Text(k.kullaniciAdi).font(.caption).foregroundColor(Renk.soluk)
                        }
                        Spacer()
                        Text("\(k.dogru)/\(veri.sorular.count)")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(Renk.murekkep)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(k.cevaplar.enumerated()), id: \.offset) { i, h in
                                hucre(no: i + 1, h)
                            }
                        }
                    }
                    Text("Son cevap: " + k.son).font(.caption2).foregroundColor(Renk.soluk)
                }
                .padding(12)
                .background(Renk.ikincil)
                .cornerRadius(12)
            }
        }
        .padding(16)
        .kart()
    }

    private func hucre(no: Int, _ h: SoruSetiAyrintisi.Hucre?) -> some View {
        let metin: String
        let renk: Color
        let zemin: Color
        if let c = h {
            metin = "S\(no) \(c.secilen) \(c.dogruMu ? "✓" : "✗")"
            renk = c.dogruMu ? Renk.yesil : Renk.kirmizi
            zemin = c.dogruMu ? Renk.yesilZemin : Renk.kirmiziZemin
        } else {
            metin = "S\(no) –"
            renk = Renk.soluk
            zemin = Renk.kart
        }
        return Text(metin)
            .font(.caption.weight(.bold))
            .foregroundColor(renk)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(zemin)
            .cornerRadius(999)
    }

    private var dagilimKarti: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                KartSimgesi(sembol: "chart.bar")
                Text("Soru bazında dağılım").font(.headline).foregroundColor(Renk.murekkep)
            }
            ForEach(veri.sorular) { q in
                VStack(alignment: .leading, spacing: 6) {
                    Text("S\(q.no). \(q.soru)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Renk.murekkep)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(q.dagilimToplam) cevap · doğru oranı %\(q.dogruOrani)")
                        .font(.caption).foregroundColor(Renk.soluk)
                    ForEach(q.siklar) { s in
                        let oran = q.dagilimToplam > 0 ? Double(s.sayi) / Double(q.dagilimToplam) : 0
                        HStack(spacing: 8) {
                            Text(s.harf)
                                .font(.caption.weight(.bold))
                                .foregroundColor(s.k == q.dogru ? Renk.yesil : Renk.murekkep)
                                .frame(width: 16)
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Renk.ikincil)
                                    Capsule()
                                        .fill(s.k == q.dogru ? Renk.yesil : Renk.mavi.opacity(0.6))
                                        .frame(width: max(0, g.size.width * CGFloat(oran)))
                                }
                            }
                            .frame(height: 10)
                            Text("\(s.sayi) kişi")
                                .font(.caption)
                                .foregroundColor(Renk.soluk)
                                .frame(width: 52, alignment: .trailing)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(16)
        .kart()
    }
}
