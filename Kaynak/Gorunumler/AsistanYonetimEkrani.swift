import SwiftUI

// Yönetim > Balık Asistanı — sitedeki asistan-haklar.php ve asistan-rapor.php sayfalarının karşılığı.
// Sunucu: api/yonetim-asistan.php (yalnızca yönetici). Raporda kişiler baş harfleriyle gösterilir.

// MARK: - Veri

struct AsistanHakVerisi: Codable {
    let varsayilanMetin: Int
    let varsayilanFoto: Int
    let herkeseAcik: Bool
    let kisiler: [AsistanHakKisi]
}

struct AsistanHakKisi: Codable, Identifiable, Equatable {
    let id: Int
    let ad: String
    let kullaniciAdi: String
    let yonetici: Bool
    let ozel: Bool
    let sinirMetin: Int
    let sinirFoto: Int
    let kullanilanMetin: Int
    let kullanilanFoto: Int
}

struct AsistanRaporu: Codable {
    struct Kisi: Codable, Identifiable {
        let id: Int
        let etiket: String
        let soru: Int
        let foto: Int
        let usd: Double
        let son: String
    }

    struct Soru: Codable {
        let zaman: String
        let kisiId: Int
        let etiket: String
        let foto: Bool
        let maliyet: Double
        let soru: String
        let cevap: String
    }

    struct BildirimKaydi: Codable {
        let zaman: String
        let etiket: String
        let neden: String
        let aciklama: String
        let soru: String
        let cevap: String
        let kaynak: String
    }

    let aylar: [String]
    let ay: String
    let soru: Int
    let foto: Int
    let usd: Double
    let tavan: Double
    let kisiler: [Kisi]
    let secilen: Int
    let sorular: [Soru]
    let bildirimler: [BildirimKaydi]
}

enum AsistanYonetimKurallari {
    static func para(_ usd: Double) -> String {
        return String(format: usd < 1 ? "$%.4f" : "$%.2f", usd)
    }

    /// "2026-11-22 15:49:38" -> "22.11 15:49"
    static func kisaZaman(_ z: String) -> String {
        let p = z.split(separator: " ")
        guard p.count == 2 else { return z }
        let t = p[0].split(separator: "-")
        let s = p[1].prefix(5)
        return t.count == 3 ? "\(t[2]).\(t[1]) \(s)" : z
    }

    /// "2026-11" -> "Kasım 2026"
    static func ayAdi(_ ay: String) -> String {
        let adlar = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz",
                     "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
        let p = ay.split(separator: "-")
        guard p.count == 2, let n = Int(p[1]), n >= 1, n <= 12 else { return ay }
        return "\(adlar[n - 1]) \(p[0])"
    }

    static func ara(_ liste: [AsistanHakKisi], _ metin: String) -> [AsistanHakKisi] {
        let q = metin.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return liste }
        return liste.filter { k in
            (k.ad + " " + k.kullaniciAdi).range(of: q, options: [.caseInsensitive, .diacriticInsensitive],
                                                 locale: TRMetin.tr) != nil
        }
    }
}

// MARK: - Ekran

struct AsistanYonetimEkrani: View {
    @EnvironmentObject var oturum: Oturum

    @State private var bolum = 0
    @State private var haklar: AsistanHakVerisi?
    @State private var rapor: AsistanRaporu?
    @State private var hata: String?
    @State private var mesaj: String?
    @State private var arama = ""
    @State private var duzenlenen: AsistanHakKisi?
    @State private var secilenAy: String?
    @State private var secilenKisi = 0
    @State private var acikCevaplar: Set<String> = []

    var body: some View {
        YenilenebilirKaydirma(eylem: { await yukle() }) {
            VStack(spacing: 0) {
                Kahraman(baslik: "Balık Asistanı",
                         aciklama: "Soru hakları, kullanım raporu ve bildirilen cevaplar.")
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Bölüm", selection: $bolum) {
                        Text("Soru hakları").tag(0)
                        Text("Kullanım raporu").tag(1)
                    }
                    .pickerStyle(.segmented)

                    if let m = mesaj {
                        Bildirim(metin: m, hata: false)
                    }
                    if let h = hata {
                        UyariKutusu(tur: .bilgi, baslik: "Yüklenemedi.", metin: h)
                    }

                    if bolum == 0 {
                        hakBolumu
                    } else {
                        raporBolumu
                    }
                }
                .padding(16)
            }
        }
        .background(DenizZemini().ignoresSafeArea())
        .navigationTitle("Balık Asistanı")
        .markaBasligi()
        .task { await yukle() }
        .onChange(of: bolum) { _ in
            hata = nil
            Task { await yukle() }
        }
        .sheet(item: $duzenlenen) { k in
            HakDuzenlePenceresi(kisi: k, varsayilanMetin: haklar?.varsayilanMetin ?? 10,
                                varsayilanFoto: haklar?.varsayilanFoto ?? 10) { m in
                mesaj = m
                Task { await yukle() }
            }
            .environmentObject(oturum)
        }
    }

    // MARK: Soru hakları

    @ViewBuilder
    private var hakBolumu: some View {
        if let v = haklar {
            VStack(alignment: .leading, spacing: 6) {
                (Text("Herkesin aylık hakkı: ").bold()
                    + Text("\(v.varsayilanMetin) yazılı soru + \(v.varsayilanFoto) fotoğraf. Haklar her ayın 1'inde yenilenir. Bir kişiye dokunup ona özel hak verebilirsin."))
                    .font(.footnote)
                    .foregroundColor(Renk.murekkep)
                    .fixedSize(horizontal: false, vertical: true)
                if !v.herkeseAcik {
                    Text("Asistan şu an yalnızca yöneticilere açık; haklar herkese açıldığında geçerli olur.")
                        .font(.footnote)
                        .foregroundColor(Renk.amber)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Renk.tint)
            .cornerRadius(12)

            AramaKutusu(ipucu: "Ad veya kullanıcı adı ara", metin: $arama)

            let liste = AsistanYonetimKurallari.ara(v.kisiler, arama)
            if liste.isEmpty {
                BosKutu(metin: "Aramayla eşleşen kullanıcı yok.")
            }
            ForEach(liste) { k in
                Button {
                    if !k.yonetici { duzenlenen = k }
                } label: {
                    hakSatiri(k)
                }
                .buttonStyle(.plain)
            }
        } else if hata == nil {
            HStack { Spacer(); ProgressView(); Spacer() }.padding(.top, 20)
        }
    }

    private func hakSatiri(_ k: AsistanHakKisi) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(k.ad)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Renk.murekkep)
                if k.yonetici {
                    Text("Bu ay \(k.kullanilanMetin) soru · \(k.kullanilanFoto) fotoğraf")
                        .font(.caption)
                        .foregroundColor(Renk.soluk)
                } else {
                    (Text("\(k.kullanilanMetin) / \(k.sinirMetin) soru")
                        .foregroundColor(k.kullanilanMetin >= k.sinirMetin ? Renk.kirmizi : Renk.soluk)
                        + Text(" · ").foregroundColor(Renk.soluk)
                        + Text("\(k.kullanilanFoto) / \(k.sinirFoto) fotoğraf")
                        .foregroundColor(k.kullanilanFoto >= k.sinirFoto ? Renk.kirmizi : Renk.soluk))
                        .font(.caption)
                }
            }
            Spacer(minLength: 0)
            Text(k.yonetici ? "Yönetici" : (k.ozel ? "Özel hak" : "Varsayılan"))
                .font(.caption2.weight(.semibold))
                .foregroundColor(k.yonetici ? Renk.mavi : (k.ozel ? Renk.amber : Renk.soluk))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(k.yonetici ? Renk.tint : (k.ozel ? Renk.amberZemin : Renk.ikincil)))
            if !k.yonetici {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Renk.soluk)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .kart()
    }

    // MARK: Kullanım raporu

    @ViewBuilder
    private var raporBolumu: some View {
        if let r = rapor {
            HStack(spacing: 8) {
                if r.aylar.count > 1 {
                    Menu {
                        ForEach(r.aylar, id: \.self) { a in
                            Button(AsistanYonetimKurallari.ayAdi(a)) {
                                secilenAy = a
                                secilenKisi = 0
                                Task { await yukle() }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(AsistanYonetimKurallari.ayAdi(r.ay))
                            Image(systemName: "chevron.down")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Renk.mavi)
                    }
                } else {
                    Text(AsistanYonetimKurallari.ayAdi(r.ay))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Renk.murekkep)
                }
                Spacer()
            }
            Text("\(r.soru) soru · \(r.foto) fotoğraf · \(AsistanYonetimKurallari.para(r.usd)) / \(Int(r.tavan)) $")
                .font(.footnote.weight(.semibold))
                .foregroundColor(r.usd >= r.tavan * 0.8 ? Renk.kirmizi : Renk.murekkep)

            if !r.bildirimler.isEmpty {
                Label("Bildirilen cevaplar (\(r.bildirimler.count))", systemImage: "flag.fill")
                    .font(.headline)
                    .foregroundColor(Renk.kirmizi)
                ForEach(Array(r.bildirimler.enumerated()), id: \.offset) { i, b in
                    bildirimKarti(b, anahtar: "b\(i)")
                }
            }

            if r.kisiler.isEmpty {
                BosKutu(metin: "Bu ay için kayıt yok.")
            } else {
                Text("Kişiler")
                    .font(.headline)
                    .foregroundColor(Renk.murekkep)
                VStack(spacing: 0) {
                    ForEach(r.kisiler) { k in
                        Button {
                            secilenKisi = secilenKisi == k.id ? 0 : k.id
                            Task { await yukle() }
                        } label: {
                            HStack {
                                Text(k.etiket)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(secilenKisi == k.id ? Renk.mavi : Renk.murekkep)
                                Spacer()
                                Text("\(k.soru) soru · \(k.foto) foto · \(AsistanYonetimKurallari.para(k.usd))")
                                    .font(.caption)
                                    .foregroundColor(Renk.soluk)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(secilenKisi == k.id ? Renk.tint : Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if k.id != r.kisiler.last?.id {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .kart()

                HStack {
                    Text(secilenKisi > 0
                         ? "\(r.kisiler.first(where: { $0.id == secilenKisi })?.etiket ?? "") · soruları"
                         : "Son \(r.sorular.count) soru")
                        .font(.headline)
                        .foregroundColor(Renk.murekkep)
                    Spacer()
                    if secilenKisi > 0 {
                        Button("Tümünü göster") {
                            secilenKisi = 0
                            Task { await yukle() }
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Renk.mavi)
                    }
                }
                ForEach(Array(r.sorular.enumerated()), id: \.offset) { i, s in
                    soruKarti(s, anahtar: "s\(i)-\(s.zaman)")
                }
            }
        } else if hata == nil {
            HStack { Spacer(); ProgressView(); Spacer() }.padding(.top, 20)
        }
    }

    private func soruKarti(_ s: AsistanRaporu.Soru, anahtar: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(AsistanYonetimKurallari.kisaZaman(s.zaman))
                if secilenKisi == 0 {
                    Text(s.etiket).bold()
                }
                if s.foto {
                    Text("Fotoğraf")
                        .foregroundColor(Renk.mavi)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Renk.tint))
                }
                Text(AsistanYonetimKurallari.para(s.maliyet))
            }
            .font(.caption)
            .foregroundColor(Renk.soluk)
            Text(s.soru.isEmpty ? "(yalnızca fotoğraf)" : s.soru)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Renk.murekkep)
                .fixedSize(horizontal: false, vertical: true)
            cevapMetni(s.cevap, anahtar: anahtar)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .kart()
    }

    private func bildirimKarti(_ b: AsistanRaporu.BildirimKaydi, anahtar: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(AsistanYonetimKurallari.kisaZaman(b.zaman))
                Text(b.etiket).bold()
                Text(b.neden)
                    .foregroundColor(Renk.kirmizi)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Renk.kirmiziZemin))
                Text(b.kaynak == "uygulama" ? "Uygulama" : "Site")
            }
            .font(.caption)
            .foregroundColor(Renk.soluk)
            if !b.aciklama.isEmpty {
                Text("“\(b.aciklama)”")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Renk.murekkep)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Soru: \(b.soru)")
                .font(.footnote)
                .foregroundColor(Renk.soluk)
                .fixedSize(horizontal: false, vertical: true)
            cevapMetni(b.cevap, anahtar: anahtar)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .kart()
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Renk.kirmizi.opacity(0.25), lineWidth: 1))
    }

    private func cevapMetni(_ cevap: String, anahtar: String) -> some View {
        let acik = acikCevaplar.contains(anahtar)
        return VStack(alignment: .leading, spacing: 4) {
            AsistanKurallari.bicimli(cevap)
                .font(.footnote)
                .foregroundColor(Renk.murekkep)
                .lineLimit(acik ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 10)
                .overlay(Rectangle().fill(Renk.cizgi).frame(width: 3), alignment: .leading)
            Button(acik ? "Kısalt" : "Cevabın tamamı") {
                if acik { acikCevaplar.remove(anahtar) } else { acikCevaplar.insert(anahtar) }
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(Renk.mavi)
        }
    }

    // MARK: Yükleme

    private func yukle() async {
        guard let t = oturum.token else { return }
        do {
            if bolum == 0 {
                haklar = try await APIIstemci.asistanHaklari(token: t)
            } else {
                rapor = try await APIIstemci.asistanRaporu(ay: secilenAy, kisi: secilenKisi, token: t)
                acikCevaplar = []
            }
            hata = nil
        } catch let h as APIHatasi {
            hata = h.aciklama
        } catch {
            hata = "Bir hata oluştu."
        }
    }
}

// MARK: - Hak düzenleme

struct HakDuzenlePenceresi: View {
    let kisi: AsistanHakKisi
    let varsayilanMetin: Int
    let varsayilanFoto: Int
    let tamam: (String) -> Void
    @EnvironmentObject var oturum: Oturum
    @Environment(\.dismiss) private var kapat
    @State private var metin = ""
    @State private var foto = ""
    @State private var bekliyor = false
    @State private var hata: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kisi.ad)
                            .font(.headline)
                            .foregroundColor(Renk.murekkep)
                        Text("Bu ay \(kisi.kullanilanMetin) soru, \(kisi.kullanilanFoto) fotoğraf kullandı.")
                            .font(.footnote)
                            .foregroundColor(Renk.soluk)
                    }
                    if let h = hata {
                        Bildirim(metin: h, hata: true)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        sayiAlani("Aylık yazılı soru hakkı", $metin)
                        sayiAlani("Aylık fotoğraf hakkı", $foto)
                        Text("Varsayılan: \(varsayilanMetin) soru + \(varsayilanFoto) fotoğraf. Özel hak, varsayılana dönene kadar her ay geçerlidir.")
                            .font(.caption)
                            .foregroundColor(Renk.soluk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .kart()

                    AnaDugme(baslik: "Kaydet", bekliyor: bekliyor) {
                        Task { await islem("kaydet") }
                    }
                    .disabled(bekliyor || Int(metin) == nil || Int(foto) == nil)
                    if kisi.ozel {
                        Button("Varsayılana dön") {
                            Task { await islem("sifirla") }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Renk.mavi)
                        .frame(maxWidth: .infinity)
                        .disabled(bekliyor)
                    }
                }
                .padding(16)
            }
            .background(DenizZemini().ignoresSafeArea())
            .navigationTitle("Soru hakkı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Vazgeç") { kapat() }
                }
            }
        }
        .onAppear {
            metin = String(kisi.sinirMetin)
            foto = String(kisi.sinirFoto)
        }
    }

    private func sayiAlani(_ etiket: String, _ deger: Binding<String>) -> some View {
        HStack {
            Text(etiket)
                .font(.subheadline)
                .foregroundColor(Renk.murekkep)
            Spacer()
            TextField("0", text: deger)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func islem(_ ad: String) async {
        guard let t = oturum.token else { return }
        let m = Int(metin.trimmingCharacters(in: .whitespaces)) ?? -1
        let f = Int(foto.trimmingCharacters(in: .whitespaces)) ?? -1
        if ad == "kaydet" && (m < 0 || m > 1000 || f < 0 || f > 1000) {
            hata = "Hak sayıları 0 ile 1000 arasında olmalı."
            return
        }
        bekliyor = true
        hata = nil
        do {
            let sonuc = try await APIIstemci.asistanHakIslem(ad, uid: kisi.id, metin: m, foto: f, token: t)
            tamam(sonuc)
            kapat()
        } catch let h as APIHatasi {
            hata = h.aciklama
        } catch {
            hata = "Kaydedilemedi."
        }
        bekliyor = false
    }
}
