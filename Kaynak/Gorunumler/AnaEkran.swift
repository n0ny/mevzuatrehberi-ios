import SwiftUI

/// Uygulamanın alt sekmeleri. Sistemin sekme çubuğu gizlidir (Renk.sekmeCubugunuAyarla);
/// altta yüzen sekme çubuğu (YuzenSekmeCubugu) çizilir. Sekmeler ve içerikleri aynıdır.
struct AnaSekmeler: View {
    @EnvironmentObject var depo: VeriDeposu
    @EnvironmentObject var foto: ProfilFotografi
    @State private var secili = 0
    @State private var yeniSayisi = 0
    @State private var klavyeAcik = false
    /// Seçili sekmeye yeniden dokununca o sekme ilk sayfasına döner (sistem sekme çubuğundaki gibi).
    @State private var sekmeKimligi: [Int: UUID] = Dictionary(uniqueKeysWithValues: (0...4).map { ($0, UUID()) })

    var body: some View {
        TabView(selection: $secili) {
            sekme(0) { AnaEkran() }
                .tabItem { Label("Ana sayfa", systemImage: "house") }
                .tag(0)
            sekme(1) { AramaEkrani() }
                .tabItem { Label("Mevzuat", systemImage: "magnifyingglass") }
                .tag(1)
            sekme(2) { TurlerEkrani() }
                .tabItem { Label("Türler", systemImage: "leaf") }
                .tag(2)
            sekme(3) { YeniliklerEkrani() }
                .tabItem { Label("Yenilikler", systemImage: "text.bubble") }
                .tag(3)
            sekme(4) { HesapEkrani() }
                .tabItem { Label("Hesabım", systemImage: "person.crop.circle") }
                .tag(4)
        }
        .overlay(alignment: .bottom) {
            if !klavyeAcik {
                YuzenSekmeCubugu(secili: secili, yeniSayisi: yeniSayisi, hesapResmi: foto.resim) { sec($0) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            klavyeAcik = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            klavyeAcik = false
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

    /// Bir sekmenin gezinme yığını; alttaki yüzen çubuğun altında içerik kalmasın diye alttan boşluk bırakılır.
    private func sekme<Icerik: View>(_ no: Int, @ViewBuilder _ icerik: () -> Icerik) -> some View {
        NavigationView { icerik() }
            .navigationViewStyle(.stack)
            .id(sekmeKimligi[no] ?? AnaSekmeler.sabitKimlik)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: klavyeAcik ? 0 : YuzenSekmeCubugu.kaplama)
            }
    }

    private static let sabitKimlik = UUID()

    private func sec(_ no: Int) {
        if no == secili {
            sekmeKimligi[no] = UUID()
        } else {
            secili = no
        }
    }

    private func rozetiGuncelle() {
        yeniSayisi = secili == 3 ? 0 : YenilikTakibi.yeniSayisi(depo.yenilikler)
    }
}

/// Ekranın altına oturan sekme çubuğu (üst köşeleri yuvarlak, zemini ekranın en altına kadar iner).
/// Seçili sekme lacivert bir daire içinde yukarı kalkar.
struct YuzenSekmeCubugu: View {
    let secili: Int
    let yeniSayisi: Int
    let hesapResmi: UIImage?
    let sec: (Int) -> Void

    /// Sayfaların altında bırakılan boşluk: çubuk (64) + yukarı kalkan seçili daire (~15) + nefes payı.
    /// Listenin sonuna gelince en alttaki yazı menünün üstünde kalır.
    static let kaplama: CGFloat = 104

    private struct Oge {
        let no: Int
        let baslik: String
        let sembol: String
        let yedek: String
    }

    // Ana sayfa ortada.
    private let ogeler = [
        Oge(no: 1, baslik: "Mevzuat", sembol: "magnifyingglass", yedek: "magnifyingglass"),
        Oge(no: 2, baslik: "Türler", sembol: "fish", yedek: "leaf"),
        Oge(no: 0, baslik: "Ana sayfa", sembol: "house.fill", yedek: "house"),
        Oge(no: 3, baslik: "Yenilikler", sembol: "text.bubble", yedek: "text.bubble"),
        Oge(no: 4, baslik: "Hesabım", sembol: "person.crop.circle", yedek: "person.crop.circle"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ogeler, id: \.no) { o in
                Button {
                    sec(o.no)
                } label: {
                    ogeGorunumu(o)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(o.no == 3 && yeniSayisi > 0 ? "\(o.baslik), \(yeniSayisi) yeni" : o.baslik)
                .accessibilityAddTraits(secili == o.no ? .isSelected : [])
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 64)
        // Zemin ekranın en altına kadar iner (alt boşluk kalmaz). İnce çerçeve zeminin parçası:
        // seçili sekmenin yukarı kalkan dairesinin üstünden çizgi geçmesin.
        .background(
            UstKoseYuvarlak(yaricap: 26)
                .fill(Renk.kart)
                .overlay(UstKoseYuvarlak(yaricap: 26).stroke(Renk.cizgi.opacity(0.6), lineWidth: 0.5))
                .shadow(color: Renk.golge, radius: 12, x: 0, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder
    private func ogeGorunumu(_ o: Oge) -> some View {
        let aktif = secili == o.no
        VStack(spacing: 3) {
            ZStack {
                if aktif {
                    simge(o, boyut: 22)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Renk.dugme))
                        .overlay(Circle().stroke(Renk.kart, lineWidth: 4))
                        .shadow(color: Renk.golge, radius: 8, x: 0, y: 4)
                        .offset(y: -14)
                } else {
                    simge(o, boyut: 20)
                        .foregroundColor(Renk.soluk)
                }
                if o.no == 3 && yeniSayisi > 0 {
                    Text("\(yeniSayisi)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 17, minHeight: 17)
                        .background(Capsule().fill(Renk.kirmizi))
                        .offset(x: 14, y: aktif ? -30 : -10)
                }
            }
            .frame(width: 50, height: 26)
            Text(o.baslik)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(aktif ? Renk.murekkep : Renk.soluk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    private func simge(_ o: Oge, boyut: CGFloat) -> some View {
        if o.no == 4, let r = hesapResmi {
            Image(uiImage: r)
                .resizable()
                .scaledToFill()
                .frame(width: boyut + 6, height: boyut + 6)
                .clipShape(Circle())
        } else {
            Sembol(ad: o.sembol, yedek: o.yedek)
                .font(.system(size: boyut, weight: .semibold))
        }
    }
}

/// Yalnızca üst köşeleri yuvarlak dikdörtgen (alt menü zemini).
struct UstKoseYuvarlak: Shape {
    var yaricap: CGFloat

    func path(in r: CGRect) -> Path {
        return Path(UIBezierPath(roundedRect: r, byRoundingCorners: [.topLeft, .topRight],
                                 cornerRadii: CGSize(width: yaricap, height: yaricap)).cgPath)
    }
}

/// dashboard.php — Ana sayfa (sürüm 7 düzeni).
struct AnaEkran: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu
    @Environment(\.colorScheme) private var sema
    @AppStorage("gorunum") private var gorunum = "otomatik"
    /// dashboard.php rozeti: bu haftanın setinde cevap bekleyen soru sayısı.
    @State private var bekleyenSoru = 0
    @State private var yakindaAcik = false
    /// Bilgi Kütüphanesi bir kez açılınca "Yeni" etiketi kalkar (KutuphaneEkrani yazar).
    @AppStorage("kutuphaneGoruldu") private var kutuphaneGoruldu = false
    /// Balık Asistanı kartı yalnızca sunucu "açık" derse görünür (şimdilik yalnızca yönetici). Son durum hatırlanır.
    @AppStorage("asistanAcik") private var asistanAcik = false

    /// Kart zemininin lacivert üst alana binme miktarı (aynı zamanda köşe yuvarlaklığı; sürüm 6 ile aynı).
    static let sayfaBinmesi: CGFloat = 28

    var body: some View {
        YenilenebilirKaydirma {
            VStack(alignment: .leading, spacing: 0) {
                // Lacivert üst alan (sürüm 6 gibi): tek satır "Hoş geldin, Ad 👋" ve arama çubuğu.
                Kahraman(baslik: "Hoş geldin, \(oturum.kullanici?.ad ?? "") 👋",
                         aciklama: "Aradığın mevzuata hızlıca ulaş.",
                         tekSatir: true,
                         baslikBoyutu: 30,
                         ustBosluk: 14,
                         altBosluk: 24 + AnaEkran.sayfaBinmesi) {
                    // Mevzuat arama: dokununca arama sayfası açılır.
                    NavigationLink(destination: AramaEkrani()) {
                        AnaAramaCubugu()
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }

                VStack(alignment: .leading, spacing: 11) {
                    durumSatiri

                    // Tür kartları ve Yenilikler alt sekmelerde olduğu için burada tekrar edilmez.
                    NavigationLink(destination: TekneEkrani()) {
                        AnaKart(sembol: "ferry", renk: .yesil, baslik: "Tekne / Gemi Kontrolü",
                                aciklama: "Belge, ekipman, fiziki durum ve diğer kontroller")
                    }
                    NavigationLink(destination: BolgeEkrani()) {
                        AnaKart(sembol: "map", renk: .mercan, baslik: "Türkiye Geneli Bölge Yasakları",
                                aciklama: "Deniz bölgelerine göre yasak ve kısıtlamaları görüntüle")
                    }
                    NavigationLink(destination: BilgiEkrani()) {
                        AnaKart(sembol: "questionmark.circle", renk: .amber, baslik: "Haftanın soruları",
                                aciklama: "Kısa sorularla bilgini tazele",
                                rozet: bekleyenSoru > 0 ? "\(bekleyenSoru) soru" : nil)
                    }
                    NavigationLink(destination: KutuphaneEkrani()) {
                        AnaKart(sembol: "flag", renk: .mor, baslik: "Bilgi Kütüphanesi",
                                aciklama: "Bayraklar, ses işaretleri ve seyir fenerleri",
                                rozet: kutuphaneGoruldu ? nil : "Yeni")
                    }
                    if asistanAcik {
                        NavigationLink(destination: BalikAsistaniEkrani()) {
                            AnaKart(sembol: "camera.viewfinder", renk: .mavi, baslik: "Balık Asistanı",
                                    aciklama: "Fotoğraftan tür tanı, balıklar hakkında sor",
                                    rozet: "Deneme")
                        }
                    }
                    HStack(spacing: 11) {
                        Button {
                            yakindaAcik = true
                        } label: {
                            KucukAnaKart(sembol: "sparkles", renk: .amber, baslik: "Yakında")
                        }
                        NavigationLink(destination: OneriEkrani()) {
                            KucukAnaKart(sembol: "lightbulb", renk: .mavi, baslik: "Öneri")
                        }
                    }

                    VStack(alignment: .center, spacing: 8) {
                        Text("Bu uygulama resmî kurum uygulaması değildir. İçerikler mevzuata erişim ve referans amacıyla sunulmaktadır; güncel mevzuat metinleri ve yetkili kaynaklar esas alınmalıdır.")
                            .font(.caption)
                            .foregroundColor(Renk.soluk)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        NavigationLink(destination: YasalMetinEkrani(sayfa: "kvkk")) {
                            Text("KVKK aydınlatma metni")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Renk.mavi)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)
                // Kartların zemini yuvarlak köşeli bir sayfa gibi lacivert alanın üstüne biner.
                .background(DenizZemini().clipShape(UstKoseYuvarlak(yaricap: AnaEkran.sayfaBinmesi)))
                .padding(.top, -AnaEkran.sayfaBinmesi)
            }
        }
        // Kart sayfasının bittiği renk; içerik kısa kalırsa altta ek yeri görünmez.
        .background(Renk.denizSon.ignoresSafeArea())
        // Geri düğmesinde görünen ad; başlık ortada gösterilmez.
        .navigationTitle("Mevzuat Rehberi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Color.clear.frame(width: 1, height: 1)
                    .accessibilityHidden(true)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                AnaMarkaEtiketi()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // Sitedeki ay simgesi: koyudaysa gündüze, açıktaysa geceye geçer.
                    gorunum = sema == .dark ? "acik" : "koyu"
                } label: {
                    Image(systemName: sema == .dark ? "sun.max" : "moon")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                        .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                }
                .accessibilityLabel(sema == .dark ? "Gündüz moduna geç" : "Gece moduna geç")
            }
        }
        .onAppear { bekleyenleriYukle() }
        .sheet(isPresented: $yakindaAcik) {
            YakindaEkrani()
                .environmentObject(oturum)
                .environmentObject(depo)
        }
    }

    private func bekleyenleriYukle() {
        guard let t = oturum.token else { return }
        Task {
            if let v = try? await APIIstemci.bilgi(setId: nil, token: t) {
                bekleyenSoru = v.bekleyen
            }
            // Sunucuda asistan dosyası yoksa ya da kapalıysa kart gizlenir; internet yoksa son durum kalır.
            do {
                asistanAcik = try await APIIstemci.asistanDurum(token: t).acik
            } catch APIHatasi.baglanti {
            } catch {
                asistanAcik = false
            }
        }
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
                .padding(.horizontal, 4)
        }
    }
}

/// Ana sayfa üst çubuğu (sürüm 6 ile aynı): amblem | altın "MEVZUAT REHBERİ".
struct AnaMarkaEtiketi: View {
    var body: some View {
        HStack(spacing: 10) {
            Image("AmblemSimge")
                .resizable()
                .scaledToFit()
                .frame(height: 22)
            Rectangle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 1, height: 18)
            Text("MEVZUAT REHBERİ")
                .font(.system(size: 12.5, weight: .semibold))
                .kerning(2.4)
                .foregroundColor(Renk.altin)
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mevzuat Rehberi")
    }
}

/// Ana sayfadaki arama çubuğu (dokununca Mevzuat arama sayfası açılır).
struct AnaAramaCubugu: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Renk.ustEtiket)
            // Dokununca arama sayfası açıldığı baştan anlaşılsın (18.11 kullanıcı kararı).
            VStack(alignment: .leading, spacing: 1) {
                Text("İhlal, sevk ve yaptırım ara")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Renk.murekkep)
                Text("Arama sayfasını açmak için dokun")
                    .font(.caption)
                    .foregroundColor(Renk.soluk)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            // Sitedeki kutu gibi: "Ara" yazısı yerine ok (dokununca arama sayfası açılır).
            Image(systemName: "arrow.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Renk.dugme))
        }
        .padding(.leading, 18)
        .padding(.trailing, 7)
        .padding(.vertical, 7)
        .background(Capsule().fill(Renk.kart))
        .shadow(color: Renk.golge, radius: 10, x: 0, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("İhlal, sevk ve yaptırım ara")
        .accessibilityHint("Arama sayfasını açar")
    }
}

/// Ana sayfa kartlarındaki simge renkleri.
enum KartRengi {
    case mavi, yesil, mercan, amber, mor

    var yazi: Color {
        switch self {
        case .mavi: return Color(UIColor.dinamik(0x0B5CAD, 0x85B7EB))
        case .yesil: return Color(UIColor.dinamik(0x0F6E56, 0x5DCAA5))
        case .mercan: return Color(UIColor.dinamik(0xA3421D, 0xF0997B))
        case .amber: return Color(UIColor.dinamik(0x8A5A00, 0xF0C070))
        case .mor: return Color(UIColor.dinamik(0x3C3489, 0xAFA9EC))
        }
    }

    var zemin: Color {
        switch self {
        case .mavi: return Color(UIColor.dinamik(0xE3F1FB, 0x16304A))
        case .yesil: return Color(UIColor.dinamik(0xE2F5EF, 0x0F2B24))
        case .mercan: return Color(UIColor.dinamik(0xFDEEE8, 0x33190F))
        case .amber: return Color(UIColor.dinamik(0xFFF3DC, 0x2A2210))
        case .mor: return Color(UIColor.dinamik(0xECEBFD, 0x221F45))
        }
    }
}

/// Ana sayfa kartı (sürüm 7): renkli yuvarlak simge, başlık, açıklama, isteğe bağlı rozet.
struct AnaKart: View {
    let sembol: String
    var renk: KartRengi = .mavi
    let baslik: String
    let aciklama: String
    var rozet: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            Sembol(ad: sembol, yedek: "doc.text")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(renk.yazi)
                .frame(width: 46, height: 46)
                .background(Circle().fill(renk.zemin))
            VStack(alignment: .leading, spacing: 3) {
                Text(baslik)
                    .font(.headline)
                    .foregroundColor(Renk.murekkep)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(aciklama)
                    .font(.footnote)
                    .foregroundColor(Renk.soluk)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let r = rozet {
                Text(r)
                    .font(.caption.weight(.bold))
                    .foregroundColor(renk.yazi)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(renk.zemin))
                    .fixedSize()
            } else {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Renk.soluk)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .kart()
    }
}

/// Ana sayfanın en altındaki yan yana küçük kutular (Yakında, Öneri).
struct KucukAnaKart: View {
    let sembol: String
    var renk: KartRengi = .mavi
    let baslik: String

    var body: some View {
        HStack(spacing: 10) {
            Sembol(ad: sembol, yedek: "doc.text")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(renk.yazi)
                .frame(width: 38, height: 38)
                .background(Circle().fill(renk.zemin))
            Text(baslik)
                .font(.subheadline.weight(.bold))
                .foregroundColor(Renk.murekkep)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity)
        .kart()
    }
}

struct YoneticiDugmesi: View {
    let sembol: String
    let baslik: String
    let eylem: () -> Void

    var body: some View {
        Button(action: eylem) {
            YoneticiEtiketi(sembol: sembol, baslik: baslik)
        }
        .buttonStyle(.plain)
    }
}

/// Yönetici düğmelerinin görünümü (düğme ve sayfa bağlantısı için ortak).
struct YoneticiEtiketi: View {
    let sembol: String
    let baslik: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: sembol)
            Text(baslik)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        // Gündüz lacivert, gecede açık mavi yazı (gece modunda okunur).
        .foregroundColor(Renk.mavi)
        .background(Renk.tint)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Renk.mavi.opacity(0.25), lineWidth: 1))
    }
}
