import SwiftUI

/// register.php — Kayıt ol. İşlemi sunucuda sitenin kendi kayıt sayfası yapar
/// (aynı kurallar, aynı kayıt kodu, hesap yönetici onayı bekler).
struct KayitEkrani: View {
    /// Kayıt başarılıysa mesajla çağrılır (giriş ekranında gösterilir).
    let tamamlandi: (String) -> Void
    @Environment(\.dismiss) private var kapat

    @State private var adSoyad = ""
    @State private var kullaniciAdi = ""
    @State private var eposta = ""
    @State private var sifre = ""
    @State private var sifreTekrar = ""
    @State private var kayitKodu = ""
    @State private var sozlesmeKabul = false
    @State private var sifreGorunsun = false
    @State private var bekliyor = false
    @State private var hata: String?
    @State private var basari: String?
    @State private var sozlesmeAcik = false

    private enum Alan: Hashable { case ad, kullanici, eposta, sifre, tekrar, kod }
    @FocusState private var odak: Alan?

    var body: some View {
        ZStack {
            GirisArkaPlani()

            ScrollView {
                VStack(spacing: 18) {
                    DonusDugmesi { kapat() }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Hesap Oluştur")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("Mevzuat Rehberi'ne erişim sağlamak için kullanıcı hesabınızı oluşturun.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)

                        if let b = basari {
                            CamMesaj(metin: b, hata: false)
                            CamAnaDugme(baslik: "Giriş sayfasına dön", bekliyor: false, etkin: true) {
                                tamamlandi(b)
                                kapat()
                            }
                        } else {
                            form
                        }
                    }
                    .camKart()
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $sozlesmeAcik) {
            SozlesmeEkrani()
        }
    }

    @ViewBuilder
    private var form: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield")
            Text("Kayıt kodu yalnızca uygulamayı kullanmaya yetkili kişilerle paylaşılmalıdır.")
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.footnote)
        .foregroundColor(.white.opacity(0.9))
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor(onaltilik: 0x1E88E5)).opacity(0.18))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(UIColor(onaltilik: 0x4AA8ED)).opacity(0.45), lineWidth: 1))

        if let h = hata {
            CamMesaj(metin: h, hata: true)
        }

        Group {
        CamAlan(simge: "person.text.rectangle") {
            TextField("", text: $adSoyad, prompt: ipucu("Ad Soyad"))
                .textContentType(.name)
                .submitLabel(.next)
                .focused($odak, equals: .ad)
                .onSubmit { odak = .kullanici }
        }
        CamAlan(simge: "person") {
            TextField("", text: $kullaniciAdi, prompt: ipucu("Kullanıcı Adı"))
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.next)
                .focused($odak, equals: .kullanici)
                .onSubmit { odak = .eposta }
        }
        CamAlan(simge: "envelope") {
            TextField("", text: $eposta, prompt: ipucu("E-posta Adresi"))
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.next)
                .focused($odak, equals: .eposta)
                .onSubmit { odak = .sifre }
        }
        CamAlan(simge: "lock") {
            HStack {
                sifreAlani($sifre, yazi: "Şifre (en az 6 karakter)", alan: .sifre) { odak = .tekrar }
                GozDugmesi(acik: $sifreGorunsun)
            }
        }
        CamAlan(simge: "lock.rotation") {
            sifreAlani($sifreTekrar, yazi: "Şifre Tekrarı", alan: .tekrar) { odak = .kod }
        }
        CamAlan(simge: "number") {
            TextField("", text: $kayitKodu, prompt: ipucu("Kayıt Kodu"))
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.done)
                .focused($odak, equals: .kod)
                .onSubmit { odak = nil }
        }
        }

        HStack(alignment: .center, spacing: 10) {
            Button {
                sozlesmeKabul.toggle()
            } label: {
                Image(systemName: sozlesmeKabul ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundColor(sozlesmeKabul ? Color(UIColor(onaltilik: 0x4AA8ED)) : .white.opacity(0.75))
            }
            .buttonStyle(.plain)
            (Text("Kullanıcı Sözleşmesini ")
                + Text("okudum").bold().underline().foregroundColor(GirisRenk.baglanti)
                + Text(" ve kabul ediyorum."))
                .font(.footnote)
                .foregroundColor(.white.opacity(0.9))
                .onTapGesture { sozlesmeAcik = true }
        }

        CamAnaDugme(baslik: bekliyor ? "Kaydediliyor…" : "Kayıt Ol",
                    bekliyor: bekliyor,
                    etkin: sozlesmeKabul,
                    eylem: kayitOl)

        HStack(spacing: 4) {
            Spacer()
            Text("Zaten hesabın var mı?")
                .foregroundColor(.white.opacity(0.8))
            Button("Giriş Yap") { kapat() }
                .foregroundColor(GirisRenk.baglanti)
                .font(.footnote.weight(.bold))
            Spacer()
        }
        .font(.footnote)
    }

    private func ipucu(_ m: String) -> Text {
        return Text(m).foregroundColor(.white.opacity(0.6))
    }

    @ViewBuilder
    private func sifreAlani(_ metin: Binding<String>, yazi: String, alan: Alan, sonraki: @escaping () -> Void) -> some View {
        Group {
            if sifreGorunsun {
                TextField("", text: metin, prompt: ipucu(yazi))
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } else {
                SecureField("", text: metin, prompt: ipucu(yazi))
            }
        }
        .textContentType(.newPassword)
        .submitLabel(.next)
        .focused($odak, equals: alan)
        .onSubmit(sonraki)
    }

    private func kayitOl() {
        guard sozlesmeKabul, !bekliyor else { return }
        odak = nil
        hata = nil
        bekliyor = true
        let alanlar: [String: String] = [
            "full_name": adSoyad,
            "username": kullaniciAdi,
            "email": eposta,
            "password": sifre,
            "password2": sifreTekrar,
            "register_code": kayitKodu,
            "terms_accepted": "1",
        ]
        Task {
            do {
                let m = try await APIIstemci.kayit(alanlar)
                sifre = ""
                sifreTekrar = ""
                basari = m
            } catch let e as APIHatasi {
                hata = e.aciklama
            } catch {
                hata = APIHatasi.baglanti.aciklama
            }
            bekliyor = false
        }
    }
}

/// forgot_password.php — Şifremi unuttum. Bağlantıyı sitenin kendi sayfası e-postayla gönderir.
struct SifremiUnuttumEkrani: View {
    @Environment(\.dismiss) private var kapat
    @State private var eposta = ""
    @State private var bekliyor = false
    @State private var hata: String?
    @State private var basari: String?

    var body: some View {
        ZStack {
            GirisArkaPlani()

            ScrollView {
                VStack(spacing: 18) {
                    DonusDugmesi { kapat() }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Şifremi Unuttum")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("Hesabınızın kayıtlı olduğu e-posta adresini girin. Şifre yenileme bağlantısını e-posta adresinize göndereceğiz.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)

                        (Text(Image(systemName: "lock")) + Text(" Şifre yenileme bağlantısı güvenlik amacıyla ") + Text("30 dakika").bold() + Text(" geçerlidir."))
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor(onaltilik: 0x1E88E5)).opacity(0.18))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(UIColor(onaltilik: 0x4AA8ED)).opacity(0.45), lineWidth: 1))

                        if let b = basari {
                            CamMesaj(metin: b, hata: false)
                            CamAnaDugme(baslik: "Giriş sayfasına dön", bekliyor: false, etkin: true) { kapat() }
                        } else {
                            if let h = hata {
                                CamMesaj(metin: h, hata: true)
                            }
                            CamAlan(simge: "envelope") {
                                TextField("", text: $eposta, prompt: Text("E-posta Adresi").foregroundColor(.white.opacity(0.6)))
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                    .submitLabel(.send)
                                    .onSubmit(gonder)
                            }
                            CamAnaDugme(baslik: bekliyor ? "Gönderiliyor…" : "Şifre Yenileme Bağlantısı Gönder",
                                        bekliyor: bekliyor,
                                        etkin: !eposta.trimmingCharacters(in: .whitespaces).isEmpty,
                                        eylem: gonder)
                            HStack {
                                Spacer()
                                Button("Giriş sayfasına dön") { kapat() }
                                    .font(.footnote.weight(.bold))
                                    .foregroundColor(GirisRenk.baglanti)
                                Spacer()
                            }
                        }
                    }
                    .camKart()

                    Text("Bağlantıya tıkladığınızda yeni şifre belirleme sayfası tarayıcıda açılır. Yeni şifrenizle uygulamaya giriş yapabilirsiniz.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
        }
    }

    private func gonder() {
        let e = eposta.trimmingCharacters(in: .whitespaces)
        guard !e.isEmpty, !bekliyor else { return }
        hata = nil
        bekliyor = true
        Task {
            do {
                basari = try await APIIstemci.sifreUnuttum(eposta: e)
            } catch let h as APIHatasi {
                hata = h.aciklama
            } catch {
                hata = APIHatasi.baglanti.aciklama
            }
            bekliyor = false
        }
    }
}

/// register.php'deki Kullanıcı Sözleşmesi penceresi.
struct SozlesmeEkrani: View {
    @Environment(\.dismiss) private var kapat
    @State private var sozlesme: Sozlesme?
    @State private var hata: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Lütfen aşağıdaki bilgileri dikkatlice okuyunuz.")
                        .font(.subheadline)
                        .foregroundColor(Renk.soluk)
                    if let s = sozlesme {
                        ForEach(s.bolumler) { b in
                            VStack(alignment: .leading, spacing: 6) {
                                if !b.baslik.isEmpty {
                                    Text(b.baslik)
                                        .font(.headline)
                                        .foregroundColor(Renk.murekkep)
                                }
                                Text(b.metin)
                                    .font(.callout)
                                    .foregroundColor(Renk.murekkep)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if !s.tarih.isEmpty {
                            Text(s.tarih)
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(Renk.soluk)
                        }
                        Button {
                            kapat()
                        } label: {
                            Text("Anladım, Devam Et  →")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .foregroundColor(.white)
                                .background(Renk.lacivert)
                                .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 6)
                    } else if let h = hata {
                        UyariKutusu(tur: .bilgi, baslik: "Sözleşme yüklenemedi.", metin: h)
                        Button("Tekrar dene") { Task { await yukle() } }
                    } else {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.top, 30)
                    }
                }
                .padding(18)
            }
            .background(Renk.zemin.ignoresSafeArea(edges: .bottom))
            .background(Color(UIColor.dinamik(0x08243A, 0x050E17)).ignoresSafeArea())
            .navigationTitle("Kullanıcı Sözleşmesi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { kapat() }
                        .foregroundColor(.white)
                }
            }
        }
        .navigationViewStyle(.stack)
        .task { await yukle() }
    }

    private func yukle() async {
        hata = nil
        do {
            sozlesme = try await APIIstemci.sozlesme()
        } catch let e as APIHatasi {
            hata = e.aciklama
        } catch {
            hata = APIHatasi.baglanti.aciklama
        }
    }
}

/// "← Giriş Sayfasına Dön"
struct DonusDugmesi: View {
    let eylem: () -> Void

    var body: some View {
        HStack {
            Button(action: eylem) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left")
                    Text("Giriş Sayfasına Dön")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.12))
                .cornerRadius(999)
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }
}
