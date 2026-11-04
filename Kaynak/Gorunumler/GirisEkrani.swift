import SwiftUI

struct GirisEkrani: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu

    @State private var kullanici = ""
    @State private var sifre = ""
    @State private var bekliyor = false
    @State private var hata: String?

    private enum Alan { case kullanici, sifre }
    @FocusState private var odak: Alan?

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 46))
                        .foregroundColor(.white)
                        .frame(width: 88, height: 88)
                        .background(Color.accentColor)
                        .cornerRadius(24)
                    Text("Mevzuat Rehberi")
                        .font(.largeTitle.bold())
                    Text("Hesabınızla giriş yapın")
                        .foregroundColor(.secondary)
                }
                .padding(.top, 50)

                VStack(spacing: 12) {
                    TextField("Kullanıcı adı veya e-posta", text: $kullanici)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .submitLabel(.next)
                        .focused($odak, equals: .kullanici)
                        .onSubmit { odak = .sifre }
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)

                    SecureField("Şifre", text: $sifre)
                        .textContentType(.password)
                        .submitLabel(.go)
                        .focused($odak, equals: .sifre)
                        .onSubmit { girisYap() }
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                }

                if let h = hata {
                    Text(h)
                        .font(.callout)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button(action: girisYap) {
                    HStack {
                        if bekliyor {
                            ProgressView().tint(.white)
                        }
                        Text(bekliyor ? "Giriş yapılıyor…" : "Giriş yap")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(15)
                    .foregroundColor(.white)
                    .background(girisYapilabilir ? Color.accentColor : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!girisYapilabilir || bekliyor)

                VStack(spacing: 6) {
                    Text("Hesap oluşturma ve şifre yenileme işlemleri sitemizden yapılır.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Link("sg.barisguresci.com.tr", destination: Ayarlar.siteAdresi)
                        .font(.footnote.weight(.semibold))
                }
                .padding(.top, 6)

                Text(Notlar.resmiDegil)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
    }

    private var girisYapilabilir: Bool {
        return !kullanici.trimmingCharacters(in: .whitespaces).isEmpty && !sifre.isEmpty
    }

    private func girisYap() {
        guard girisYapilabilir, !bekliyor else { return }
        odak = nil
        hata = nil
        bekliyor = true
        let k = kullanici.trimmingCharacters(in: .whitespaces)
        let s = sifre
        Task {
            do {
                try await oturum.girisYap(kullanici: k, sifre: s)
                sifre = ""
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
