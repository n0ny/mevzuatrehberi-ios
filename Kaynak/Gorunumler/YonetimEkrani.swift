import SwiftUI

// MARK: - Veri (api/yonetim.php)

struct YonetimVerisi: Codable {
    let toplam: Int
    let bekleyen: Int
    let kullanicilar: [YonetimKullanici]
    /// Sunucu "Kime gönderilsin" ve "yalnız bana" seçeneklerini destekliyor mu (güncel api/yonetim.php).
    var bildirimSecenekleri: Bool?
}

struct YonetimKullanici: Codable, Identifiable, Equatable {
    let id: Int
    let kullaniciAdi: String
    let ad: String
    let eposta: String
    let rol: String
    let aktif: Bool
    let durum: String
    let yeni: Bool
    let sonGiris: String?
    let sonGirisTs: Int
    let girisSayisi: Int
    let ben: Bool

    var yonetici: Bool { rol == "admin" }

    var basHarf: String {
        guard let h = kullaniciAdi.first else { return "?" }
        return String(h).uppercased(with: TRMetin.tr)
    }

    /// admin/index.php sıralaması: önce onay bekleyenler, sonra onaylılar, sonra reddedilenler.
    var durumSirasi: Int {
        switch durum {
        case "pending": return 0
        case "approved": return 1
        case "rejected": return 2
        default: return 3
        }
    }
}

struct BildirimSonucu: Codable {
    struct Sayilar: Codable {
        let gonderilen: Int
        let basarisiz: Int
        let silinen: Int
    }
    let gonderildi: Bool
    let mesaj: String
    let sayilar: Sayilar?
}

enum YonetimKurallari {
    /// "yeni": en yeni kayıt, "giris": son giriş, "ad": kullanıcı adı A-Z (admin/index.php ile aynı)
    static func sirala(_ liste: [YonetimKullanici], _ tur: String) -> [YonetimKullanici] {
        return liste.sorted { a, b in
            if a.durumSirasi != b.durumSirasi { return a.durumSirasi < b.durumSirasi }
            switch tur {
            case "giris":
                let aYok = a.sonGirisTs == 0
                let bYok = b.sonGirisTs == 0
                if aYok != bYok { return !aYok }
                if a.sonGirisTs != b.sonGirisTs { return a.sonGirisTs > b.sonGirisTs }
                return a.id > b.id
            case "ad":
                return a.kullaniciAdi < b.kullaniciAdi
            default:
                return a.id > b.id
            }
        }
    }

    static func ara(_ liste: [YonetimKullanici], _ metin: String) -> [YonetimKullanici] {
        let q = metin.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return liste }
        return liste.filter { k in
            let alan = k.kullaniciAdi + " " + k.ad + " " + k.eposta
            return alan.range(of: q, options: [.caseInsensitive, .diacriticInsensitive], locale: TRMetin.tr) != nil
        }
    }
}

// MARK: - Ekran

/// admin/index.php — Yönetim paneli (kullanıcılar, onay bekleyenler, bildirim).
struct YonetimEkrani: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu

    @State private var veri: YonetimVerisi?
    @State private var yukleniyor = false
    @State private var hata: String?
    @State private var mesaj: (metin: String, hata: Bool)?
    @State private var bekliyor = false

    @State private var arama = ""
    @State private var siralama = "yeni"
    @State private var acikKullanici: Int?

    @State private var soru: Soru?

    struct Soru: Identifiable {
        let id = UUID()
        let baslik: String
        let dugme: String
        let yikici: Bool
        let islem: String
        let alanlar: [String: String]
    }

    var body: some View {
        YenilenebilirKaydirma(eylem: { await yukle() }) {
            VStack(spacing: 0) {
                Kahraman(baslik: "Yönetim paneli",
                         aciklama: "Kullanıcı hesaplarını ve erişim yetkilerini yönetin.") {
                    if let v = veri {
                        HStack(spacing: 8) {
                            ozetCipi("\(v.toplam)", "kullanıcı", uyari: false)
                            if v.bekleyen > 0 {
                                ozetCipi("\(v.bekleyen)", "onay bekliyor", uyari: true)
                            }
                        }
                        .padding(.top, 4)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    if let m = mesaj {
                        Bildirim(metin: m.metin, hata: m.hata)
                    }

                    BildirimGonderKarti(seceneklerVar: veri?.bildirimSecenekleri == true)

                    icerikYonetimi

                    if let v = veri {
                        let bekleyenler = v.kullanicilar.filter { $0.durum == "pending" }
                        if !bekleyenler.isEmpty {
                            onayBekleyenler(bekleyenler)
                        }
                        YeniKullaniciKarti(bekliyor: bekliyor) { alanlar in
                            await islemYap("create", alanlar)
                        }
                        kullanicilarKarti(v)
                    } else if let h = hata {
                        UyariKutusu(tur: .bilgi, baslik: "Liste yüklenemedi.", metin: h)
                        Button("Tekrar dene") { Task { await yukle() } }
                            .buttonStyle(.borderedProminent)
                            .tint(Renk.lacivert)
                    } else {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.top, 20)
                    }
                }
                .padding(16)
            }
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle("Yönetim paneli")
        .markaBasligi()
        .task { if veri == nil { await yukle() } }
        .alert(item: $soru) { s in
            Alert(title: Text(s.baslik),
                  primaryButton: s.yikici
                    ? .destructive(Text(s.dugme)) { Task { await islemYap(s.islem, s.alanlar) } }
                    : .default(Text(s.dugme)) { Task { await islemYap(s.islem, s.alanlar) } },
                  secondaryButton: .cancel(Text("Vazgeç")))
        }
    }

    private func ozetCipi(_ deger: String, _ etiket: String, uyari: Bool) -> some View {
        (Text(deger).bold() + Text(" " + etiket))
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(uyari ? Color.orange.opacity(0.45) : Color.white.opacity(0.14))
            .cornerRadius(999)
    }

    // MARK: İçerik yönetimi

    private var icerikYonetimi: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                KartSimgesi(sembol: "square.grid.2x2")
                Text("İçerik yönetimi")
                    .font(.headline)
                    .foregroundColor(Renk.murekkep)
            }
            NavigationLink(destination: SoruSetleriEkrani()) {
                icerikEtiketi("questionmark.circle", "Haftanın soruları", "Soru setleri, kim ne cevapladı, sıralama")
            }
            .buttonStyle(.plain)
            NavigationLink(destination: YenilikYonetimiEkrani()) {
                icerikEtiketi("text.bubble", "Yenilikler", "Eklenen mevzuatı duyur, bildirim gönder")
            }
            .buttonStyle(.plain)
            NavigationLink(destination: TurYonetimiEkrani()) {
                icerikEtiketi("fish", "Tür kartları", "Fotoğraf, asgari boy ve yasak dönemi gir")
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .kart()
    }

    private func icerikEtiketi(_ sembol: String, _ baslik: String, _ aciklama: String) -> some View {
            HStack(spacing: 12) {
                Sembol(ad: sembol, yedek: "doc.text")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Renk.mavi)
                    .frame(width: 36, height: 36)
                    .background(Renk.tint)
                    .cornerRadius(10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(baslik)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Renk.murekkep)
                    Text(aciklama)
                        .font(.caption)
                        .foregroundColor(Renk.soluk)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Renk.soluk)
            }
            .padding(10)
            .background(Renk.ikincil)
            .cornerRadius(12)
    }

    // MARK: Onay bekleyenler

    private func onayBekleyenler(_ liste: [YonetimKullanici]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                KartSimgesi(sembol: "person.crop.circle.badge.exclamationmark")
                Text("Onay bekleyenler")
                    .font(.headline)
                    .foregroundColor(Renk.murekkep)
                Spacer()
                Hap(metin: "\(liste.count)", renk: Renk.amber, zemin: Renk.amberZemin)
            }
            ForEach(liste) { k in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        BasHarf(harf: k.basHarf)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(k.kullaniciAdi)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Renk.murekkep)
                            Text([k.ad, k.eposta].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundColor(Renk.soluk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    HStack(spacing: 10) {
                        Button {
                            Task { await islemYap("approve", ["id": String(k.id)]) }
                        } label: {
                            Text("Onayla")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundColor(.white)
                                .background(Renk.yesil)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        Button {
                            soru = Soru(baslik: "Bu kullanıcı reddedilsin mi?", dugme: "Reddet", yikici: true,
                                        islem: "reject", alanlar: ["id": String(k.id)])
                        } label: {
                            Text("Reddet")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundColor(Renk.kirmizi)
                                .background(Renk.kirmiziZemin)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                    .disabled(bekliyor)
                }
                .padding(12)
                .background(Renk.amberZemin.opacity(0.6))
                .cornerRadius(12)
            }
        }
        .padding(16)
        .kart()
    }

    // MARK: Kullanıcılar

    private func kullanicilarKarti(_ v: YonetimVerisi) -> some View {
        let liste = YonetimKurallari.sirala(YonetimKurallari.ara(v.kullanicilar, arama), siralama)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                KartSimgesi(sembol: "person.2")
                Text("Kullanıcılar")
                    .font(.headline)
                    .foregroundColor(Renk.murekkep)
                Spacer()
                Hap(metin: "\(v.toplam)")
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Renk.soluk)
                TextField("Ad, kullanıcı adı veya e-posta ara", text: $arama)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .foregroundColor(Renk.murekkep)
            }
            .padding(11)
            .background(Renk.ikincil)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Renk.cizgi, lineWidth: 1))

            HStack(spacing: 8) {
                Text("Sırala:")
                    .font(.caption)
                    .foregroundColor(Renk.soluk)
                SecimCipi(baslik: "En yeni", secili: siralama == "yeni") { siralama = "yeni" }
                SecimCipi(baslik: "Son giriş", secili: siralama == "giris") { siralama = "giris" }
                SecimCipi(baslik: "A-Z", secili: siralama == "ad") { siralama = "ad" }
            }

            if liste.isEmpty {
                Text("Aramanızla eşleşen kullanıcı bulunamadı.")
                    .font(.footnote)
                    .foregroundColor(Renk.soluk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(liste) { k in
                        KullaniciSatiri(kullanici: k,
                                        acik: acikKullanici == k.id,
                                        bekliyor: bekliyor,
                                        ac: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                acikKullanici = acikKullanici == k.id ? nil : k.id
                                            }
                                        },
                                        rolDegistir: { rol in
                                            soru = Soru(baslik: "\(k.kullaniciAdi) için yetki \(rol == "admin" ? "Admin" : "Personel") yapılsın mı?",
                                                        dugme: "Değiştir", yikici: false,
                                                        islem: "role", alanlar: ["id": String(k.id), "role": rol])
                                        },
                                        durumDegistir: {
                                            Task { await islemYap("toggle", ["id": String(k.id)]) }
                                        },
                                        sil: {
                                            soru = Soru(baslik: "Bu kullanıcı silinsin mi?", dugme: "Sil", yikici: true,
                                                        islem: "delete", alanlar: ["id": String(k.id)])
                                        },
                                        sifreDegistir: { yeni in
                                            await islemYap("password", ["id": String(k.id), "password": yeni])
                                        })
                    }
                }
            }
        }
        .padding(16)
        .kart()
    }

    // MARK: İşlemler

    private func yukle() async {
        guard let t = oturum.token, !yukleniyor else { return }
        yukleniyor = true
        defer { yukleniyor = false }
        do {
            veri = try await APIIstemci.yonetimListesi(token: t)
            hata = nil
        } catch APIHatasi.yetkisiz(_) {
            Eylemler.cikis(oturum: oturum, depo: depo)
        } catch let e as APIHatasi {
            hata = e.aciklama
        } catch {
            hata = APIHatasi.baglanti.aciklama
        }
    }

    /// Başarılıysa true döner.
    @discardableResult
    private func islemYap(_ islem: String, _ alanlar: [String: String]) async -> Bool {
        guard let t = oturum.token, !bekliyor else { return false }
        bekliyor = true
        mesaj = nil
        var basarili = false
        do {
            let m = try await APIIstemci.yonetimIslem(islem, alanlar: alanlar, token: t)
            mesaj = (m, false)
            basarili = true
            if islem == "delete" { acikKullanici = nil }
        } catch APIHatasi.yetkisiz(_) {
            Eylemler.cikis(oturum: oturum, depo: depo)
        } catch let e as APIHatasi {
            mesaj = (e.aciklama, true)
        } catch {
            mesaj = (APIHatasi.baglanti.aciklama, true)
        }
        bekliyor = false
        await yukle()
        return basarili
    }
}

/// Kullanıcı satırı; dokununca yetki, durum, silme ve şifre işlemleri açılır.
struct KullaniciSatiri: View {
    let kullanici: YonetimKullanici
    let acik: Bool
    let bekliyor: Bool
    let ac: () -> Void
    let rolDegistir: (String) -> Void
    let durumDegistir: () -> Void
    let sil: () -> Void
    let sifreDegistir: (String) async -> Bool

    @State private var yeniSifre = ""

    var body: some View {
        let k = kullanici
        VStack(alignment: .leading, spacing: 0) {
            Button(action: ac) {
                HStack(alignment: .top, spacing: 10) {
                    BasHarf(harf: k.basHarf)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(k.kullaniciAdi)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Renk.murekkep)
                            if k.yeni {
                                Hap(metin: "YENİ", renk: .white, zemin: Renk.mavi)
                            }
                        }
                        if !k.ad.isEmpty {
                            Text(k.ad).font(.caption).foregroundColor(Renk.soluk)
                        }
                        if !k.eposta.isEmpty {
                            Text(k.eposta).font(.caption).foregroundColor(Renk.soluk)
                        }
                        Text(k.sonGiris.map { "Son giriş: " + $0 } ?? "Henüz giriş yapılmadı")
                            .font(.caption)
                            .foregroundColor(Renk.soluk)
                        Text("Giriş sayısı: \(k.girisSayisi)")
                            .font(.caption)
                            .foregroundColor(Renk.soluk)
                        HStack(spacing: 6) {
                            if k.yonetici {
                                Hap(metin: "Admin", renk: Renk.mavi, zemin: Renk.tint)
                            } else {
                                Hap(metin: "Personel", renk: Renk.soluk, zemin: Renk.ikincil)
                            }
                            durumHapi
                        }
                        .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(acik ? 180 : 0))
                        .foregroundColor(Renk.soluk)
                        .padding(.top, 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if acik {
                kontroller
                    .padding(.top, 12)
            }
        }
        .padding(12)
        .background(Renk.ikincil.opacity(0.6))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(k.yeni ? Renk.mavi.opacity(0.5) : Renk.cizgi, lineWidth: 1))
    }

    @ViewBuilder
    private var durumHapi: some View {
        switch kullanici.durum {
        case "pending":
            Hap(metin: "Onay bekliyor", renk: Renk.amber, zemin: Renk.amberZemin)
        case "rejected":
            Hap(metin: "Reddedildi", renk: Renk.kirmizi, zemin: Renk.kirmiziZemin)
        default:
            if kullanici.aktif {
                Hap(metin: "● Aktif", renk: Renk.yesil, zemin: Renk.yesilZemin)
            } else {
                Hap(metin: "● Pasif", renk: Renk.soluk, zemin: Renk.ikincil)
            }
        }
    }

    private var kontroller: some View {
        let k = kullanici
        return VStack(alignment: .leading, spacing: 10) {
            if k.ben {
                Text("Kendi hesabınızın yetkisini ve durumunu bu ekrandan değiştiremezsiniz.")
                    .font(.caption)
                    .foregroundColor(Renk.soluk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Menu {
                    Button("Personel") { if k.yonetici { rolDegistir("personel") } }
                    Button("Admin") { if !k.yonetici { rolDegistir("admin") } }
                } label: {
                    kontrolEtiketi(k.yonetici ? "Rol: Admin" : "Rol: Personel", sembol: "key", renk: Renk.murekkep)
                }
                .disabled(k.ben || bekliyor)

                Button(action: durumDegistir) {
                    kontrolEtiketi(k.aktif ? "Pasifleştir" : "Aktifleştir",
                                   sembol: k.aktif ? "pause.circle" : "play.circle", renk: Renk.murekkep)
                }
                .buttonStyle(.plain)
                .disabled(k.ben || bekliyor)
            }
            .opacity(k.ben ? 0.5 : 1)

            if !k.ben {
                Button(action: sil) {
                    kontrolEtiketi("Sil", sembol: "trash", renk: Renk.kirmizi)
                }
                .buttonStyle(.plain)
                .disabled(bekliyor)
            }

            HStack(spacing: 8) {
                SecureField("Yeni şifre (en az 8 karakter)", text: $yeniSifre)
                    .textContentType(.newPassword)
                    .padding(10)
                    .background(Renk.kart)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Renk.cizgi, lineWidth: 1))
                Button {
                    let s = yeniSifre
                    Task {
                        if await sifreDegistir(s) { yeniSifre = "" }
                    }
                } label: {
                    Text("Şifreyi değiştir")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(Renk.lacivert.opacity(yeniSifre.isEmpty ? 0.45 : 1))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(yeniSifre.isEmpty || bekliyor)
            }
        }
    }

    private func kontrolEtiketi(_ metin: String, sembol: String, renk: Color) -> some View {
        Label(metin, systemImage: sembol)
            .font(.footnote.weight(.semibold))
            .foregroundColor(renk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Renk.kart)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Renk.cizgi, lineWidth: 1))
    }
}

/// Bildirim gönder kartı (admin/index.php "Bildirim gönder").
struct BildirimGonderKarti: View {
    @EnvironmentObject var oturum: Oturum
    /// Eski sunucu kime/yalnız bana seçimini bilmez ve herkese gönderir; o durumda seçimle gönderilmez.
    var seceneklerVar = false
    /// "" hepsi, "android", "ios"
    @State private var platform = ""
    @State private var yalnizBen = false
    @State private var baslik = ""
    @State private var metin = ""
    @State private var soruAcik = false
    @State private var gonderiliyor = false
    @State private var sonuc: BildirimSonucu?
    @State private var gonderilenBaslik = ""
    @State private var hata: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                KartSimgesi(sembol: "bell")
                Text("Bildirim gönder")
                    .font(.headline)
                    .foregroundColor(Renk.murekkep)
            }
            if let s = sonuc {
                sonucKutusu(s)
            }
            if let h = hata {
                Bildirim(metin: h, hata: true)
            }
            Text("Mevzuat Rehberi uygulamasına kayıtlı cihazlara duyuru gönderin.")
                .font(.footnote)
                .foregroundColor(Renk.soluk)
            Text("iPhone'lara bildirim henüz ulaşmıyor; bunun için Apple Developer hesabı gerekiyor. Şimdilik bildirimler Android telefonlara gider.")
                .font(.caption)
                .foregroundColor(Renk.amber)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                Text("Kime gönderilsin?").font(.caption.weight(.semibold)).foregroundColor(Renk.soluk)
                Picker("Kime gönderilsin?", selection: $platform) {
                    Text("Hepsi").tag("")
                    Text("Yalnız Android").tag("android")
                    Text("Yalnız iPhone").tag("ios")
                }
                .pickerStyle(.segmented)
            }
            Toggle(isOn: $yalnizBen) {
                Text("Deneme: yalnız bana gönder (diğer kullanıcılara gitmez)")
                    .font(.footnote)
                    .foregroundColor(Renk.murekkep)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .tint(Renk.mavi)
            Giris(etiket: "Bildirim başlığı") {
                TextField("Örn. Yeni özellik eklendi", text: $baslik)
                    .foregroundColor(Renk.murekkep)
                    .onChange(of: baslik) { y in if y.count > 100 { baslik = String(y.prefix(100)) } }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("Bildirim mesajı").font(.caption.weight(.semibold)).foregroundColor(Renk.soluk)
                ZStack(alignment: .topLeading) {
                    if metin.isEmpty {
                        Text("Kullanıcılara gönderilecek mesajı yazın.")
                            .foregroundColor(Renk.soluk.opacity(0.8))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $metin)
                        .saydamMetinKutusu()
                        .frame(minHeight: 100)
                        .foregroundColor(Renk.murekkep)
                        .onChange(of: metin) { y in if y.count > 1000 { metin = String(y.prefix(1000)) } }
                }
                .padding(7)
                .background(Renk.ikincil)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Renk.cizgi, lineWidth: 1))
            }
            AnaDugme(baslik: gonderiliyor ? "Gönderiliyor…" : "Bildirimi gönder", bekliyor: gonderiliyor) {
                hata = nil
                if !seceneklerVar && (yalnizBen || !platform.isEmpty) {
                    hata = "Sunucu henüz \"Kime gönderilsin\" ve \"yalnız bana\" seçeneklerini desteklemiyor; bildirim herkese giderdi, gönderilmedi."
                    return
                }
                soruAcik = true
            }
        }
        .padding(16)
        .kart()
        .alert(yalnizBen ? "Deneme bildirimi yalnızca sizin cihazlarınıza gönderilecek. Devam edilsin mi?"
                         : "Bu bildirimi kayıtlı cihazlara göndermek istiyor musunuz?", isPresented: $soruAcik) {
            Button("Gönder") { gonder() }
            Button("Vazgeç", role: .cancel) {}
        }
    }

    private func sonucKutusu(_ s: BildirimSonucu) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(s.gonderildi ? "Bildirim gönderildi" : "Bildirim gönderilemedi",
                  systemImage: s.gonderildi ? "checkmark.circle" : "exclamationmark.circle")
                .font(.subheadline.weight(.bold))
                .foregroundColor(s.gonderildi ? Renk.yesil : Renk.kirmizi)
            if let say = s.sayilar {
                if !gonderilenBaslik.isEmpty {
                    Text("“\(gonderilenBaslik)”").font(.footnote).foregroundColor(Renk.murekkep)
                }
                HStack(spacing: 6) {
                    Hap(metin: "\(say.gonderilen) cihaza gönderildi", renk: Renk.yesil, zemin: Renk.yesilZemin)
                    if say.basarisiz > 0 {
                        Hap(metin: "\(say.basarisiz) cihaza gönderilemedi", renk: Renk.kirmizi, zemin: Renk.kirmiziZemin)
                    }
                }
                if say.silinen > 0 {
                    Text("Ulaşılamayan \(say.silinen) cihaz kaydı listeden çıkarıldı (uygulama silinmiş veya cihaz yenilenmiş olabilir).")
                        .font(.caption).foregroundColor(Renk.soluk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if s.gonderildi {
                    Text("Kapalı veya internete bağlı olmayan telefonlara bildirim, bağlandıklarında ulaşır.")
                        .font(.caption).foregroundColor(Renk.soluk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !s.mesaj.isEmpty {
                Text(s.mesaj).font(.caption).foregroundColor(Renk.soluk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(s.gonderildi ? Renk.yesilZemin : Renk.kirmiziZemin)
        .cornerRadius(12)
    }

    private func gonder() {
        guard let t = oturum.token, !gonderiliyor else { return }
        gonderiliyor = true
        hata = nil
        sonuc = nil
        let b = baslik
        let m = metin
        let pl = platform
        let ben = yalnizBen
        Task {
            do {
                let s = try await APIIstemci.yonetimBildirim(baslik: b, metin: m, platform: pl, yalnizBen: ben, token: t)
                sonuc = s
                gonderilenBaslik = b
                if s.gonderildi {
                    baslik = ""
                    metin = ""
                }
            } catch let e as APIHatasi {
                hata = e.aciklama
            } catch {
                hata = APIHatasi.baglanti.aciklama
            }
            gonderiliyor = false
        }
    }
}

/// Yeni kullanıcı ekle (admin/index.php "Yeni kullanıcı ekle").
struct YeniKullaniciKarti: View {
    let bekliyor: Bool
    let olustur: ([String: String]) async -> Bool

    @State private var acik = false
    @State private var adSoyad = ""
    @State private var eposta = ""
    @State private var kullaniciAdi = ""
    @State private var sifre = ""
    @State private var rol = "personel"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { acik.toggle() }
            } label: {
                HStack(spacing: 12) {
                    KartSimgesi(sembol: "person.badge.plus")
                    Text("Yeni kullanıcı ekle")
                        .font(.headline)
                        .foregroundColor(Renk.murekkep)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(acik ? 180 : 0))
                        .foregroundColor(Renk.soluk)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if acik {
                Giris(etiket: "Ad soyad") {
                    TextField("Örn. Ahmet Yılmaz", text: $adSoyad)
                        .foregroundColor(Renk.murekkep)
                }
                Giris(etiket: "E-posta") {
                    TextField("ornek@mail.com", text: $eposta)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .foregroundColor(Renk.murekkep)
                }
                Giris(etiket: "Kullanıcı adı") {
                    TextField("kullaniciadi", text: $kullaniciAdi)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .foregroundColor(Renk.murekkep)
                }
                Giris(etiket: "Şifre") {
                    SecureField("En az 8 karakter", text: $sifre)
                        .textContentType(.newPassword)
                        .foregroundColor(Renk.murekkep)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Rol").font(.caption.weight(.semibold)).foregroundColor(Renk.soluk)
                    Picker("Rol", selection: $rol) {
                        Text("Personel").tag("personel")
                        Text("Admin").tag("admin")
                    }
                    .pickerStyle(.segmented)
                }
                AnaDugme(baslik: "Kullanıcı oluştur", bekliyor: bekliyor) {
                    let alanlar = ["full_name": adSoyad, "email": eposta, "username": kullaniciAdi,
                                   "password": sifre, "role": rol]
                    Task {
                        if await olustur(alanlar) {
                            adSoyad = ""
                            eposta = ""
                            kullaniciAdi = ""
                            sifre = ""
                            rol = "personel"
                            acik = false
                        }
                    }
                }
            }
        }
        .padding(16)
        .kart()
    }
}

/// Yuvarlak baş harf (admin/index.php avatar).
struct BasHarf: View {
    let harf: String

    var body: some View {
        Text(harf)
            .font(.subheadline.weight(.bold))
            .foregroundColor(.white)
            .frame(width: 38, height: 38)
            .background(Renk.lacivert)
            .clipShape(Circle())
    }
}
