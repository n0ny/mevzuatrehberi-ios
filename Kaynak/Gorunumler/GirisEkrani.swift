import SwiftUI

/// index.php — Giriş sayfası (arka plan görseli, amblem, cam görünümlü kart).
struct GirisEkrani: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu

    @State private var kullanici = ""
    @State private var sifre = ""
    @State private var sifreGorunsun = false
    @State private var bekliyor = false
    @State private var hata: String?
    @State private var bilgi: String?
    @State private var kayitAcik = false
    @State private var sifreUnuttumAcik = false

    private enum Alan { case kullanici, sifre }
    @FocusState private var odak: Alan?

    var body: some View {
        ZStack {
            GirisArkaPlani()

            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 8) {
                        Image("Amblem")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 8)
                        (Text("MEVZUAT ") + Text("REHBERİ").foregroundColor(Color(UIColor(onaltilik: 0x7FC4FF))))
                            .font(.system(size: 30, weight: .heavy, design: .serif))
                            .foregroundColor(.white)
                        Text("Mevzuata Hızlı Erişim ve Bilgi Platformu")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.top, 44)

                    VStack(spacing: 14) {
                        if let b = bilgi {
                            CamMesaj(metin: b, hata: false)
                        }
                        if let h = hata {
                            CamMesaj(metin: h, hata: true)
                        }

                        CamAlan(simge: "person") {
                            TextField("", text: $kullanici, prompt: Text("Kullanıcı Adı").foregroundColor(.white.opacity(0.6)))
                                .textContentType(.username)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .submitLabel(.next)
                                .focused($odak, equals: .kullanici)
                                .onSubmit { odak = .sifre }
                        }

                        CamAlan(simge: "lock") {
                            HStack {
                                Group {
                                    if sifreGorunsun {
                                        TextField("", text: $sifre, prompt: Text("Şifre").foregroundColor(.white.opacity(0.6)))
                                            .textInputAutocapitalization(.never)
                                            .disableAutocorrection(true)
                                    } else {
                                        SecureField("", text: $sifre, prompt: Text("Şifre").foregroundColor(.white.opacity(0.6)))
                                    }
                                }
                                .textContentType(.password)
                                .submitLabel(.go)
                                .focused($odak, equals: .sifre)
                                .onSubmit { girisYap() }
                                GozDugmesi(acik: $sifreGorunsun)
                            }
                        }

                        HStack {
                            Spacer()
                            Button("Şifremi unuttum?") {
                                sifreUnuttumAcik = true
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.white.opacity(0.9))
                        }

                        CamAnaDugme(baslik: bekliyor ? "Giriş yapılıyor…" : "Giriş Yap",
                                    bekliyor: bekliyor,
                                    etkin: girisYapilabilir,
                                    eylem: girisYap)

                        HStack(spacing: 4) {
                            Text("Hesabın yok mu?")
                                .foregroundColor(.white.opacity(0.8))
                            Button("Kayıt ol") {
                                kayitAcik = true
                            }
                            .foregroundColor(.white)
                            .font(.footnote.weight(.bold))
                        }
                        .font(.footnote)
                    }
                    .camKart()

                    Text(Notlar.resmiDegil)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $kayitAcik) {
            KayitEkrani { mesaj in
                hata = nil
                bilgi = mesaj
            }
        }
        .sheet(isPresented: $sifreUnuttumAcik) {
            SifremiUnuttumEkrani()
        }
    }

    private var girisYapilabilir: Bool {
        return !kullanici.trimmingCharacters(in: .whitespaces).isEmpty && !sifre.isEmpty
    }

    private func girisYap() {
        guard girisYapilabilir, !bekliyor else { return }
        odak = nil
        hata = nil
        bilgi = nil
        bekliyor = true
        let k = kullanici.trimmingCharacters(in: .whitespaces)
        let s = sifre
        Task {
            do {
                try await oturum.girisYap(kullanici: k, sifre: s)
                sifre = ""
                _ = await oturum.kontrolEt()
                if let t = oturum.token {
                    _ = await depo.guncelle(token: t)
                }
            } catch let e as APIHatasi {
                hata = e.aciklama
            } catch {
                hata = APIHatasi.baglanti.aciklama
            }
            bekliyor = false
        }
    }
}

// MARK: - Giriş, kayıt ve şifre ekranlarının ortak parçaları

/// Arka plan görseli + koyu geçiş (sitedeki giriş sayfası).
struct GirisArkaPlani: View {
    var body: some View {
        GeometryReader { g in
            ZStack {
                Image("GirisArkaplan")
                    .resizable()
                    .scaledToFill()
                    .frame(width: g.size.width, height: g.size.height)
                    .clipped()
                LinearGradient(gradient: Gradient(colors: [Color(red: 2 / 255, green: 20 / 255, blue: 38 / 255).opacity(0.35),
                                                           Color(red: 2 / 255, green: 13 / 255, blue: 25 / 255).opacity(0.78)]),
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
    }
}

/// Cam görünümlü giriş alanı (simge + yazı alanı).
struct CamAlan<Icerik: View>: View {
    let simge: String
    @ViewBuilder let icerik: () -> Icerik

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: simge)
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 22)
            icerik()
                .foregroundColor(.white)
        }
        .padding(14)
        .background(Color.white.opacity(0.10))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.22), lineWidth: 1))
    }
}

struct GozDugmesi: View {
    @Binding var acik: Bool

    var body: some View {
        Button {
            acik.toggle()
        } label: {
            Image(systemName: acik ? "eye.slash" : "eye")
                .foregroundColor(.white.opacity(0.75))
        }
        .buttonStyle(.plain)
    }
}

/// Mavi geçişli büyük düğme.
struct CamAnaDugme: View {
    let baslik: String
    let bekliyor: Bool
    let etkin: Bool
    let eylem: () -> Void

    var body: some View {
        Button(action: eylem) {
            HStack {
                if bekliyor {
                    ProgressView().tint(.white)
                }
                Text(baslik)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(15)
            .foregroundColor(.white)
            .background(
                LinearGradient(gradient: Gradient(colors: [Color(UIColor(onaltilik: 0x1E88E5)),
                                                           Color(UIColor(onaltilik: 0x0B5CAD))]),
                               startPoint: .leading, endPoint: .trailing)
                    .opacity(etkin ? 1 : 0.5)
            )
            .cornerRadius(14)
        }
        .disabled(!etkin || bekliyor)
    }
}

/// Başarı / hata kutusu (cam kart içinde).
struct CamMesaj: View {
    let metin: String
    let hata: Bool

    var body: some View {
        Text(metin)
            .font(.callout)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor(onaltilik: hata ? 0xB42335 : 0x17804A)).opacity(0.85))
            .cornerRadius(12)
    }
}

struct CamKart: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .cornerRadius(22)
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
}

extension View {
    func camKart() -> some View {
        modifier(CamKart())
    }
}
