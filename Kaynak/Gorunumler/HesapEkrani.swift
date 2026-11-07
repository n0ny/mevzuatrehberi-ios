import SwiftUI
import UIKit

/// hesabim.php — Hesabım sayfasının karşılığı.
struct HesapEkrani: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu
    @EnvironmentObject var foto: ProfilFotografi
    @AppStorage("gorunum") private var gorunum = "otomatik"

    @State private var adSoyad = ""
    @State private var mevcutSifre = ""
    @State private var yeniSifre = ""
    @State private var yeniSifreTekrar = ""
    @State private var sifreAcik = false
    @State private var mesaj: String?
    @State private var hata: String?
    @State private var bekliyor = false
    @State private var silmeSorusu = false
    @State private var iptalSorusu = false
    @State private var cikisSorusu = false
    @State private var icSayfa: IcWebSayfasi?
    @State private var panelHatasi: String?
    @State private var panelAciliyor: String?
    @State private var fotoSecimi = false
    @State private var fotoSecici = false

    var body: some View {
        let k = oturum.kullanici
        let hesap = oturum.hesap
        let yonetici = oturum.yonetici
        let silmeBekliyor = !yonetici && (hesap?.silmeTalebi ?? false)

        return YenilenebilirKaydirma {
            VStack(spacing: 0) {
                ust(k: k, hesap: hesap, yonetici: yonetici)

                VStack(alignment: .leading, spacing: 14) {
                    if let m = mesaj {
                        Bildirim(metin: m, hata: false)
                    }
                    if let h = hata {
                        Bildirim(metin: h, hata: true)
                    }

                    if silmeBekliyor {
                        silmeBekliyorKarti(kalan: hesap?.silmeKalan)
                    }

                    if yonetici {
                        HStack(spacing: 10) {
                            NavigationLink(destination: DestekEkrani()) {
                                YoneticiEtiketi(sembol: "bubble.left.and.bubble.right", baslik: "Destek paneli")
                            }
                            .buttonStyle(.plain)
                            NavigationLink(destination: YonetimEkrani()) {
                                YoneticiEtiketi(sembol: "gearshape", baslik: "Yönetim paneli")
                            }
                            .buttonStyle(.plain)
                        }
                        if let h = panelHatasi {
                            UyariKutusu(tur: .dikkat, baslik: "Panel açılamadı.", metin: h)
                        }
                    }

                    hesapBilgileri(k: k)
                    gorunumKarti
                    sifreKarti
                    if !yonetici && !silmeBekliyor {
                        silmeKarti
                    }
                    icerikKarti
                    cikisKarti
                }
                .padding(16)
            }
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle("Hesabım")
        .markaBasligi()
        .onAppear {
            if adSoyad.isEmpty { adSoyad = k?.ad ?? "" }
            Task { _ = await oturum.kontrolEt() }
        }
        .fullScreenCover(item: $icSayfa) { s in
            IcWebEkrani(sayfa: s)
        }
        .sheet(isPresented: $fotoSecici) {
            FotoSecici { resim in
                foto.kaydet(resim)
            }
        }
        .confirmationDialog("Profil fotoğrafı", isPresented: $fotoSecimi, titleVisibility: .visible) {
            Button("Fotoğraf seç") { fotoSecici = true }
            if foto.resim != nil {
                Button("Fotoğrafı kaldır", role: .destructive) {
                    foto.sil()
                }
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Fotoğraf yalnızca bu telefonda saklanır.")
        }
        .alert("Hesabınızı silmek istediğinize emin misiniz?", isPresented: $silmeSorusu) {
            Button("Hesabımı sil", role: .destructive) { islem("silme-talebi") }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Talebiniz alınacak ve hesabınız 24 saat içinde kalıcı olarak silinecektir. Bu işlem geri alınamaz.")
        }
        .alert("Hesap silme talebinizi iptal etmek istediğinize emin misiniz?", isPresented: $iptalSorusu) {
            Button("Talebi iptal et") { islem("silme-iptal") }
            Button("Vazgeç", role: .cancel) {}
        }
        .alert("Çıkış yapılsın mı?", isPresented: $cikisSorusu) {
            Button("Çıkış yap", role: .destructive) {
                Eylemler.cikis(oturum: oturum, depo: depo)
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Telefona indirilen içerik silinir; profil fotoğrafınız bu telefonda kalır.")
        }
    }

    // MARK: Üst alan

    private func ust(k: KullaniciOzet?, hesap: HesapBilgisi?, yonetici: Bool) -> some View {
        let ilk = String((k?.kullaniciAdi ?? "?").prefix(1)).uppercased(with: TRMetin.tr)
        let aktif = hesap?.aktif ?? true
        return Kahraman(baslik: k?.ad ?? "") {
            VStack(alignment: .leading, spacing: 8) {
                Text("@" + (k?.kullaniciAdi ?? ""))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                HStack(spacing: 8) {
                    Text(yonetici ? "Yönetici" : "Personel")
                    Circle().fill(aktif ? Color.green : Color.gray).frame(width: 7, height: 7)
                    Text(aktif ? "Aktif" : "Pasif")
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.14))
                .cornerRadius(999)
                Text(hesap?.sonGiris.map { "Son giriş: " + $0 } ?? "Henüz giriş yapılmadı")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.75))
            }
        }
        .overlay(
            Button {
                fotoSecimi = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    ProfilResmi(resim: foto.resim, harf: ilk, boyut: 64)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Renk.mavi)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
            }
            .buttonStyle(.plain)
            .padding(18),
            alignment: .topTrailing)
    }

    // MARK: Kartlar

    private func silmeBekliyorKarti(kalan: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Hesap silme talebiniz alındı", systemImage: "clock")
                .font(.subheadline.weight(.bold))
                .foregroundColor(Renk.kirmizi)
            (Text("Hesabınız ") + Text("24 saat içinde").bold()
                + Text(" kalıcı olarak silinecektir. Bu süre içerisinde hesabınızı kullanmaya devam edebilirsiniz."))
                .font(.footnote)
                .foregroundColor(Renk.murekkep)
                .fixedSize(horizontal: false, vertical: true)
            if let k = kalan {
                Text("Kalan süre: \(k)")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Renk.kirmizi)
            }
            Button("Hesap silme talebini iptal et") { iptalSorusu = true }
                .font(.footnote.weight(.semibold))
                .foregroundColor(Renk.mavi)
                .disabled(bekliyor)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Renk.kirmiziZemin)
        .cornerRadius(16)
    }

    private func hesapBilgileri(k: KullaniciOzet?) -> some View {
        KartBolumu(sembol: "person", baslik: "Hesap bilgileri", aciklama: "Görünen kullanıcı bilgilerinizi güncelleyin.") {
            Giris(etiket: "Kullanıcı adı") {
                Text(k?.kullaniciAdi ?? "")
                    .foregroundColor(Renk.soluk)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Giris(etiket: "Ad soyad") {
                TextField("Ad Soyad", text: $adSoyad)
                    .textContentType(.name)
                    .foregroundColor(Renk.murekkep)
            }
            AnaDugme(baslik: "Bilgilerimi güncelle", bekliyor: bekliyor) {
                islem("profil", ["full_name": adSoyad])
            }
        }
    }

    private var gorunumKarti: some View {
        KartBolumu(sembol: "moon", baslik: "Görünüm", aciklama: "Uygulamanın açık veya koyu renkte görünmesini seçin.") {
            HStack(spacing: 8) {
                GorunumSecenegi(baslik: "Otomatik", sembol: "circle.lefthalf.filled", secili: gorunum == "otomatik") { gorunum = "otomatik" }
                GorunumSecenegi(baslik: "Gündüz", sembol: "sun.max", secili: gorunum == "acik") { gorunum = "acik" }
                GorunumSecenegi(baslik: "Gece", sembol: "moon", secili: gorunum == "koyu") { gorunum = "koyu" }
            }
            Text("Otomatik seçildiğinde telefonunuzun açık/koyu ayarı kullanılır. Seçiminiz bu cihazda hatırlanır.")
                .font(.caption)
                .foregroundColor(Renk.soluk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sifreKarti: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { sifreAcik.toggle() }
            } label: {
                HStack(spacing: 12) {
                    KartSimgesi(sembol: "key")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Şifreyi değiştir").font(.headline).foregroundColor(Renk.murekkep)
                        Text("Hesap güvenliğiniz için düzenli güncelleyin.").font(.caption).foregroundColor(Renk.soluk)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(sifreAcik ? 180 : 0))
                        .foregroundColor(Renk.soluk)
                }
            }
            .buttonStyle(.plain)
            if sifreAcik {
                SifreAlani(etiket: "Mevcut şifre", ipucu: "Mevcut şifreniz", metin: $mevcutSifre, yeni: false)
                SifreAlani(etiket: "Yeni şifre", ipucu: "Yeni şifreniz", metin: $yeniSifre, yeni: true)
                Text("En az 8 karakter olmalı; en az bir harf ve bir rakam içermeli.")
                    .font(.caption)
                    .foregroundColor(Renk.soluk)
                SifreAlani(etiket: "Yeni şifre tekrar", ipucu: "Yeni şifrenizi tekrar girin", metin: $yeniSifreTekrar, yeni: true)
                AnaDugme(baslik: "Şifremi değiştir", bekliyor: bekliyor) {
                    islem("sifre", ["mevcut": mevcutSifre, "yeni": yeniSifre, "yeni_tekrar": yeniSifreTekrar])
                }
            }
        }
        .padding(16)
        .kart()
    }

    private var silmeKarti: some View {
        KartBolumu(sembol: "trash", baslik: "Hesabı sil", aciklama: "Hesabınızı kalıcı olarak silmek için talep oluşturabilirsiniz.", tehlike: true) {
            Button {
                silmeSorusu = true
            } label: {
                Text("Hesabımı silmek istiyorum")
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

    private var icerikKarti: some View {
        KartBolumu(sembol: "arrow.down.circle", baslik: "Telefondaki içerik",
                   aciklama: "İçerik telefona kaydedilir; internet yokken son indirilen veriler gösterilir.") {
            HStack {
                Text("Son kontrol").foregroundColor(Renk.murekkep)
                Spacer()
                Text(depo.sonKontrol.map { Tarih.anYaz($0) } ?? "Yapılmadı").foregroundColor(Renk.soluk)
            }
            .font(.footnote)
            if let h = depo.hataMesaji {
                Text(h).font(.footnote).foregroundColor(Renk.kirmizi)
            }
            AnaDugme(baslik: depo.guncelleniyor ? "Güncelleniyor…" : "Şimdi güncelle", bekliyor: depo.guncelleniyor) {
                Task { await Eylemler.guncelle(oturum: oturum, depo: depo) }
            }
        }
    }

    private var cikisKarti: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                cikisSorusu = true
            } label: {
                Label("Çıkış yap", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Renk.kirmizi)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .kart()
            }
            .buttonStyle(.plain)
            Text(Notlar.resmiDegil)
                .font(.caption)
                .foregroundColor(Renk.soluk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }

    // MARK: İşlemler

    private func paneliAc(_ hedef: String, baslik: String) {
        guard panelAciliyor == nil else { return }
        panelHatasi = nil
        panelAciliyor = hedef
        PanelGecisi.ac(hedef, baslik: baslik, oturum: oturum) { s, h in
            panelAciliyor = nil
            icSayfa = s
            panelHatasi = h
        }
    }

    private func islem(_ ad: String, _ alanlar: [String: String] = [:]) {
        guard let t = oturum.token, !bekliyor else { return }
        mesaj = nil
        hata = nil
        bekliyor = true
        Task {
            do {
                let c = try await APIIstemci.hesap(islem: ad, alanlar: alanlar, token: t)
                if let yeni = c.token {
                    oturum.tokenGuncelle(yeni)
                }
                mesaj = c.mesaj
                if ad == "sifre" {
                    mevcutSifre = ""
                    yeniSifre = ""
                    yeniSifreTekrar = ""
                    sifreAcik = false
                }
                _ = await oturum.kontrolEt()
            } catch APIHatasi.yetkisiz(_) {
                Eylemler.cikis(oturum: oturum, depo: depo)
            } catch let e as APIHatasi {
                hata = e.aciklama
            } catch {
                hata = APIHatasi.baglanti.aciklama
            }
            bekliyor = false
        }
    }
}

// MARK: - Yardımcı görünümler

struct Bildirim: View {
    let metin: String
    let hata: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: hata ? "exclamationmark.circle" : "checkmark.circle")
            Text(metin).fixedSize(horizontal: false, vertical: true)
        }
        .font(.footnote.weight(.semibold))
        .foregroundColor(hata ? Renk.kirmizi : Renk.yesil)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(hata ? Renk.kirmiziZemin : Renk.yesilZemin)
        .cornerRadius(12)
    }
}

struct KartSimgesi: View {
    let sembol: String
    var tehlike = false

    var body: some View {
        Image(systemName: sembol)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(tehlike ? Renk.kirmizi : Renk.mavi)
            .frame(width: 38, height: 38)
            .background(tehlike ? Renk.kirmiziZemin : Renk.tint)
            .cornerRadius(11)
    }
}

struct KartBolumu<Icerik: View>: View {
    let sembol: String
    let baslik: String
    let aciklama: String
    var tehlike = false
    @ViewBuilder let icerik: () -> Icerik

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                KartSimgesi(sembol: sembol, tehlike: tehlike)
                VStack(alignment: .leading, spacing: 2) {
                    Text(baslik).font(.headline).foregroundColor(tehlike ? Renk.kirmizi : Renk.murekkep)
                    Text(aciklama).font(.caption).foregroundColor(Renk.soluk).fixedSize(horizontal: false, vertical: true)
                }
            }
            icerik()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .kart()
    }
}

struct Giris<Icerik: View>: View {
    let etiket: String
    @ViewBuilder let icerik: () -> Icerik

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(etiket).font(.caption.weight(.semibold)).foregroundColor(Renk.soluk)
            icerik()
                .padding(12)
                .background(Renk.ikincil)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Renk.cizgi, lineWidth: 1))
        }
    }
}

struct SifreAlani: View {
    let etiket: String
    let ipucu: String
    @Binding var metin: String
    let yeni: Bool
    @State private var gorunsun = false

    var body: some View {
        Giris(etiket: etiket) {
            HStack {
                Group {
                    if gorunsun {
                        TextField(ipucu, text: $metin)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    } else {
                        SecureField(ipucu, text: $metin)
                    }
                }
                .textContentType(yeni ? UITextContentType.newPassword : UITextContentType.password)
                .foregroundColor(Renk.murekkep)
                Button {
                    gorunsun.toggle()
                } label: {
                    Image(systemName: gorunsun ? "eye.slash" : "eye").foregroundColor(Renk.soluk)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct AnaDugme: View {
    let baslik: String
    let bekliyor: Bool
    let eylem: () -> Void

    var body: some View {
        Button(action: eylem) {
            HStack {
                if bekliyor { ProgressView().tint(.white) }
                Text(baslik).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundColor(.white)
            .background(Renk.lacivert)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(bekliyor)
    }
}

struct GorunumSecenegi: View {
    let baslik: String
    let sembol: String
    let secili: Bool
    let eylem: () -> Void

    var body: some View {
        Button(action: eylem) {
            VStack(spacing: 6) {
                Image(systemName: sembol).font(.system(size: 18))
                Text(baslik).font(.footnote.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundColor(secili ? .white : Renk.murekkep)
            .background(secili ? Renk.lacivert : Renk.ikincil)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(secili ? Color.clear : Renk.cizgi, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
