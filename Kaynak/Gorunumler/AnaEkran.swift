import SwiftUI
import SafariServices

/// Uygulamanın alt sekmeleri.
struct AnaSekmeler: View {
    @EnvironmentObject var depo: VeriDeposu
    @State private var secili = 0
    @State private var yeniSayisi = 0

    var body: some View {
        TabView(selection: $secili) {
            NavigationView { AnaEkran() }
                .navigationViewStyle(.stack)
                .tabItem { Label("Ana sayfa", systemImage: "house") }
                .tag(0)
            NavigationView { AramaEkrani() }
                .navigationViewStyle(.stack)
                .tabItem { Label("Mevzuat", systemImage: "magnifyingglass") }
                .tag(1)
            NavigationView { TurlerEkrani() }
                .navigationViewStyle(.stack)
                .tabItem {
                    Label {
                        Text("Türler")
                    } icon: {
                        Image(systemName: UIImage(systemName: "fish") != nil ? "fish" : "leaf")
                    }
                }
                .tag(2)
            NavigationView { YeniliklerEkrani() }
                .navigationViewStyle(.stack)
                .tabItem { Label("Yenilikler", systemImage: "text.bubble") }
                .badge(yeniSayisi)
                .tag(3)
            NavigationView { HesapEkrani() }
                .navigationViewStyle(.stack)
                .tabItem { Label("Hesabım", systemImage: "person.crop.circle") }
                .tag(4)
        }
        .onAppear { rozetiGuncelle() }
        .onChange(of: depo.yenilikler.count) { _ in rozetiGuncelle() }
        .onChange(of: secili) { yeni in
            if yeni == 3 {
                yeniSayisi = 0
            } else {
                rozetiGuncelle()
            }
        }
    }

    private func rozetiGuncelle() {
        yeniSayisi = secili == 3 ? 0 : YenilikTakibi.yeniSayisi(depo.yenilikler)
    }
}

/// dashboard.php — Ana sayfa.
struct AnaEkran: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu
    @Environment(\.colorScheme) private var sema
    @AppStorage("gorunum") private var gorunum = "otomatik"
    @State private var yeniSayisi = 0
    @State private var webSayfasi: WebSayfasi?
    @State private var panelHatasi: String?

    var body: some View {
        YenilenebilirKaydirma {
            VStack(spacing: 0) {
                Kahraman(baslik: "Hoş geldin, \(oturum.kullanici?.ad ?? "") 👋",
                         aciklama: "Aradığın mevzuata hızlıca ulaş.")

                VStack(alignment: .leading, spacing: 12) {
                    durumSatiri

                    if oturum.yonetici {
                        HStack(spacing: 10) {
                            YoneticiDugmesi(sembol: "bubble.left.and.bubble.right", baslik: "Destek paneli") {
                                PanelGecisi.ac("destek", oturum: oturum) { s, h in webSayfasi = s; panelHatasi = h }
                            }
                            YoneticiDugmesi(sembol: "gearshape", baslik: "Yönetim paneli") {
                                PanelGecisi.ac("admin", oturum: oturum) { s, h in webSayfasi = s; panelHatasi = h }
                            }
                        }
                        if let h = panelHatasi {
                            UyariKutusu(tur: .dikkat, baslik: "Panel açılamadı.", metin: h)
                        }
                    }

                    NavigationLink(destination: AramaEkrani()) {
                        AnaKart(sembol: "magnifyingglass", baslik: "Mevzuat arama",
                                aciklama: "Kanun, yönetmelik, genelge ve diğer düzenlemelerde hızlı arama yap",
                                ana: true)
                    }
                    NavigationLink(destination: TurlerEkrani()) {
                        AnaKart(sembol: "fish", baslik: "Tür kartları",
                                aciklama: "Asgari av boyu ve yasak dönemleri")
                    }
                    NavigationLink(destination: YeniliklerEkrani()) {
                        AnaKart(sembol: "text.bubble", baslik: "Yenilikler",
                                aciklama: "Eklenen mevzuat ve duyurular",
                                rozet: yeniSayisi > 0 ? "\(yeniSayisi) yeni" : nil)
                    }

                    VStack(alignment: .center, spacing: 8) {
                        Text("Bu uygulama resmî kurum uygulaması değildir. İçerikler mevzuata erişim ve referans amacıyla sunulmaktadır; güncel mevzuat metinleri ve yetkili kaynaklar esas alınmalıdır.")
                            .font(.caption)
                            .foregroundColor(Renk.soluk)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            webSayfasi = WebSayfasi(baslik: "KVKK aydınlatma metni", yol: "kvkk.php")
                        } label: {
                            Text("KVKK aydınlatma metni")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Renk.mavi)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                }
                .buttonStyle(.plain)
                .padding(16)
            }
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle("Mevzuat Rehberi")
        .markaBasligi()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        // Sitedeki ay simgesi: koyudaysa gündüze, açıktaysa geceye geçer.
                        gorunum = sema == .dark ? "acik" : "koyu"
                    } label: {
                        Image(systemName: sema == .dark ? "sun.max" : "moon")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(item: $webSayfasi) { s in
            SafariGorunumu(url: s.url)
                .ignoresSafeArea()
        }
        .onAppear { yeniSayisi = YenilikTakibi.yeniSayisi(depo.yenilikler) }
        .onChange(of: depo.yenilikler.count) { _ in yeniSayisi = YenilikTakibi.yeniSayisi(depo.yenilikler) }
    }

    @ViewBuilder
    private var durumSatiri: some View {
        if !depo.veriVar {
            if depo.guncelleniyor {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("İçerik ilk kez indiriliyor. Bu işlem bir kez yapılır; sonra internetsiz de çalışır.")
                        .font(.footnote)
                        .foregroundColor(Renk.murekkep)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .kart()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    UyariKutusu(tur: .bilgi, baslik: "İçerik indirilemedi.",
                                metin: depo.hataMesaji ?? "İnternet bağlantınızı kontrol edin.")
                    Button("Tekrar dene") {
                        Task { await Eylemler.guncelle(oturum: oturum, depo: depo) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Renk.lacivert)
                }
            }
        } else if let h = depo.hataMesaji {
            UyariKutusu(tur: .bilgi, baslik: "Güncelleme yapılamadı.", metin: h + " Telefondaki son veriler gösteriliyor.")
        } else if let s = depo.sonKontrol {
            Text("İçerik son kontrol: \(Tarih.anYaz(s))")
                .font(.caption)
                .foregroundColor(Renk.soluk)
        }
    }
}

/// Ana sayfa kartı (dashboard.php .q).
struct AnaKart: View {
    let sembol: String
    let baslik: String
    let aciklama: String
    var ana = false
    var rozet: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            Sembol(ad: sembol, yedek: "doc.text")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ana ? .white : Renk.mavi)
                .frame(width: 46, height: 46)
                .background(ana ? Renk.lacivert : Renk.tint)
                .cornerRadius(14)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(baslik)
                        .font(.headline)
                        .foregroundColor(Renk.murekkep)
                    if let r = rozet {
                        Text(r)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Renk.mavi)
                            .cornerRadius(999)
                    }
                }
                Text(aciklama)
                    .font(.footnote)
                    .foregroundColor(Renk.soluk)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundColor(Renk.soluk)
        }
        .padding(16)
        .kart(vurgulu: ana)
        .shadow(color: ana ? Color.black.opacity(0.06) : .clear, radius: 10, x: 0, y: 4)
    }
}

/// Site sayfası — uygulama içinde Safari ile açılır.
struct WebSayfasi: Identifiable {
    let id = UUID()
    let url: URL

    init(url: URL) {
        self.url = url
    }

    init(baslik: String, yol: String) {
        self.url = Ayarlar.siteAdresi.appendingPathComponent(yol)
    }
}

/// Yönetim ve destek paneline şifresiz geçiş: uygulamadaki giriş tek kullanımlık kodla siteye taşınır.
@MainActor
enum PanelGecisi {
    static func ac(_ hedef: String, oturum: Oturum, sonuc: @escaping (WebSayfasi?, String?) -> Void) {
        guard let t = oturum.token else { return }
        Task {
            do {
                let u = try await APIIstemci.webOturum(hedef: hedef, token: t)
                sonuc(WebSayfasi(url: u), nil)
            } catch let e as APIHatasi {
                sonuc(nil, e.aciklama)
            } catch {
                sonuc(nil, APIHatasi.baglanti.aciklama)
            }
        }
    }
}

struct SafariGorunumu: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let v = SFSafariViewController(url: url)
        v.preferredControlTintColor = UIColor(onaltilik: 0x0B2E4A)
        v.dismissButtonStyle = .close
        return v
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct YoneticiDugmesi: View {
    let sembol: String
    let baslik: String
    let eylem: () -> Void

    var body: some View {
        Button(action: eylem) {
            HStack(spacing: 8) {
                Image(systemName: sembol)
                Text(baslik)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .foregroundColor(Renk.lacivert)
            .background(Renk.tint)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
