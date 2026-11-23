import SwiftUI
import UIKit

// Balık Asistanı — sitedeki balik-asistani.php'nin uygulama karşılığı.
// Sunucu: api/asistan.php (asistan-cekirdek.php'yi kullanır; kurallar, sınırlar ve kayıt sunucuda).
// Sohbet geçmişi yalnızca bu ekranda tutulur; "Yeni sohbet" ile silinir. Fotoğraf telefonda küçültülür.

struct AsistanDurumu {
    let acik: Bool
    let kalanYazi: String
    let uyari: String
    /// Yurt dışına aktarım için açık rıza verilmemiş (KVKK md. 9/6-a); sohbet yerine onay metni gösterilir.
    var onayGerekli: Bool = false
    var onayBaslik: String = "Yurt dışına aktarım onayı"
    var onayMetni: [String] = []
}

struct AsistanKarti: Identifiable, Hashable {
    let id: Int
    let ad: String
}

struct AsistanCevabi {
    let cevap: String
    let kartlar: [AsistanKarti]
    let kalanYazi: String
}

struct AsistanMesaji: Identifiable {
    enum Rol {
        case kullanici, asistan, hata
    }

    let id = UUID()
    let rol: Rol
    let metin: String
    var foto: UIImage? = nil
    var kartlar: [AsistanKarti] = []
    /// Asistan cevabında: cevabın verildiği soru (Bildir için).
    var soru: String = ""
    var bildirildi = false
}

enum AsistanKurallari {
    /// "Ayrıntılar" ile açılan tam uyarı (ilk cümle kutunun başında her zaman görünür).
    static let uyariMetni = "Boy, yasak dönem ve miktar gibi kurallar yalnızca uygulamadaki tür kartlarından verilir. Fotoğrafa kişi, yüz, tekne adı veya plaka gelmemesine dikkat et. Sorular ve fotoğraflar cevap üretilmesi için yapay zekâ hizmetine (Anthropic, yurt dışı) gönderilir; fotoğraflar sunucuda saklanmaz. Soru ve cevaplar kalite ve maliyet kontrolü için kaydedilir."

    /// Sunucuya gönderilecek en fazla geçmiş mesaj (sitedeki gibi son 12).
    static let gecmisSiniri = 12

    /// Fotoğraf en uzun kenarı 1280 piksel olacak şekilde küçültülür (sitedeki gibi), JPEG 0.82.
    static func gonderilecekFoto(_ resim: UIImage) -> Data? {
        let enFazla: CGFloat = 1280
        let olcek = min(1, enFazla / max(resim.size.width, resim.size.height))
        let boyut = CGSize(width: (resim.size.width * olcek).rounded(), height: (resim.size.height * olcek).rounded())
        let bicim = UIGraphicsImageRendererFormat.default()
        bicim.scale = 1
        let kucuk = UIGraphicsImageRenderer(size: boyut, format: bicim).image { _ in
            resim.draw(in: CGRect(origin: .zero, size: boyut))
        }
        return kucuk.jpegData(compressionQuality: 0.82)
    }

    /// Önceki mesajlardan sunucuya gidecek geçmiş (hata balonları gönderilmez).
    static func gecmis(_ mesajlar: [AsistanMesaji]) -> [[String: String]] {
        var liste: [[String: String]] = []
        for m in mesajlar {
            switch m.rol {
            case .kullanici:
                let soru = m.metin.isEmpty ? "Bu fotoğraftaki canlı hangi tür?" : m.metin
                liste.append(["rol": "user", "metin": (m.foto != nil ? "[Fotoğraf gönderildi] " : "") + soru])
            case .asistan:
                liste.append(["rol": "assistant", "metin": m.metin])
            case .hata:
                continue
            }
        }
        return Array(liste.suffix(gecmisSiniri))
    }

    /// "- madde" satırlarını • yapar; **kalın** ve *eğik* yazıyı biçimler.
    static func bicimli(_ ham: String) -> Text {
        var sonuc = Text("")
        var ilk = true
        for satir in ham.components(separatedBy: "\n") {
            var s = satir
            let kirpik = s.trimmingCharacters(in: .whitespaces)
            if kirpik.hasPrefix("- ") || kirpik.hasPrefix("• ") {
                s = "•  " + String(kirpik.dropFirst(2))
            }
            let parca: Text
            if let a = try? AttributedString(markdown: s,
                                             options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                parca = Text(a)
            } else {
                parca = Text(s)
            }
            sonuc = ilk ? parca : sonuc + Text("\n") + parca
            ilk = false
        }
        return sonuc
    }
}

struct BalikAsistaniEkrani: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu

    @State private var mesajlar: [AsistanMesaji] = []
    @State private var yazi = ""
    @State private var foto: UIImage?
    @State private var bekliyor = false
    @State private var kalanYazi = ""
    @State private var uyari = ""
    @State private var kapali: String?
    @State private var fotoMenusu = false
    @State private var arsivAcik = false
    @State private var kameraAcik = false
    @State private var acikTur: Tur?
    @State private var kartBulunamadi = false
    @State private var uyariAcik = false
    @State private var bildirilen: AsistanMesaji?
    @State private var durumYuklendi = false
    @State private var onay: AsistanDurumu?
    @State private var onayBekliyor = false
    @State private var onayHata: String?
    @State private var geriAlSor = false

    var body: some View {
        Group {
            if !durumYuklendi || onay != nil {
                onayGorunumu
            } else {
                sohbetGorunumu
            }
        }
        .task { await durumYukle() }
        // Yazma alanı altta kalsın diye yüzen sekme çubuğu bu ekranda gizlenir (geri dönünce yeniden görünür).
        .onAppear { SekmeCubuguDurumu.paylasilan.gizli = true }
        .onDisappear { SekmeCubuguDurumu.paylasilan.gizli = false }
        .alert("Onayı geri al", isPresented: $geriAlSor) {
            Button("Geri al", role: .destructive) { onayDegistir(false) }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Onayını geri alırsan Balık Asistanı'nı kullanamazsın. İstediğin zaman yeniden onay verebilirsin.")
        }
    }

    /// Yurt dışına aktarım için açık rıza ekranı. Metin sunucudan gelir (asistan-cekirdek.php), sitede ve Android'de de aynıdır.
    private var onayGorunumu: some View {
        ScrollView {
            VStack(spacing: 0) {
                Kahraman(baslik: "Balık Asistanı", aciklama: "Kullanmaya başlamadan önce lütfen oku.") { EmptyView() }
                VStack(alignment: .leading, spacing: 12) {
                    if let d = onay {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(d.onayBaslik)
                                .font(.headline)
                                .foregroundColor(Renk.murekkep)
                            ForEach(Array(d.onayMetni.enumerated()), id: \.offset) { _, p in
                                Text(p)
                                    .font(.subheadline)
                                    .foregroundColor(Renk.murekkep)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            NavigationLink(destination: YasalMetinEkrani(sayfa: "kvkk")) {
                                Text("KVKK Aydınlatma Metni →")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Renk.mavi)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Renk.kart)
                        .cornerRadius(18)
                        if let h = onayHata {
                            Bildirim(metin: h, hata: true)
                        }
                        Button {
                            onayDegistir(true)
                        } label: {
                            HStack {
                                Spacer()
                                if onayBekliyor { ProgressView().tint(.white) }
                                Text(onayBekliyor ? "Kaydediliyor…" : "Okudum, onaylıyorum")
                                    .font(.body.weight(.semibold))
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .background(Renk.dugme)
                            .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                        .disabled(onayBekliyor)
                    } else {
                        HStack { Spacer(); ProgressView(); Spacer() }
                            .padding(.vertical, 30)
                    }
                }
                .padding(16)
            }
        }
        .background(DenizZemini().ignoresSafeArea())
        .navigationTitle("Balık Asistanı")
        .markaBasligi()
    }

    private var sohbetGorunumu: some View {
        VStack(spacing: 0) {
            ScrollViewReader { kaydir in
                ScrollView {
                    VStack(spacing: 0) {
                        Kahraman(baslik: "Balık Asistanı",
                                 aciklama: "Balık ve su ürünleri hakkında sor ya da fotoğraf gönder.") {
                            if !kalanYazi.isEmpty {
                                Text(kalanYazi)
                                    .font(.footnote)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.14))
                                    .cornerRadius(999)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            uyariKutusu
                            if let k = kapali {
                                Bildirim(metin: k, hata: true)
                            }
                            if mesajlar.isEmpty {
                                bosDurum
                            }
                            ForEach(mesajlar) { m in
                                mesajBalonu(m)
                            }
                            if bekliyor {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text("Asistan yazıyor…")
                                        .font(.footnote)
                                        .foregroundColor(Renk.soluk)
                                }
                                .padding(.horizontal, 4)
                            }
                            Color.clear.frame(height: 1).id("son")
                        }
                        .padding(16)
                    }
                }
                .onChange(of: mesajlar.count) { _ in
                    withAnimation { kaydir.scrollTo("son", anchor: .bottom) }
                }
                .onChange(of: bekliyor) { _ in
                    withAnimation { kaydir.scrollTo("son", anchor: .bottom) }
                }
            }
            yazmaAlani
        }
        .background(DenizZemini().ignoresSafeArea())
        .navigationTitle("Balık Asistanı")
        .markaBasligi()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Yeni sohbet") {
                    mesajlar = []
                    yazi = ""
                    foto = nil
                }
                .foregroundColor(.white)
                .disabled(mesajlar.isEmpty || bekliyor)
            }
        }
        .confirmationDialog("Fotoğraf ekle", isPresented: $fotoMenusu, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Fotoğraf çek") { kameraAcik = true }
            }
            Button("Fotoğraflardan seç") { arsivAcik = true }
            Button("Vazgeç", role: .cancel) {}
        }
        .sheet(isPresented: $arsivAcik) {
            FotoSecici { resim in foto = resim }
        }
        .fullScreenCover(isPresented: $kameraAcik) {
            KameraSecici { resim in foto = resim }
                .ignoresSafeArea()
        }
        .sheet(item: $acikTur) { t in
            TurKartiPenceresi(tur: t)
        }
        .sheet(item: $bildirilen) { m in
            AsistanBildirPenceresi(mesaj: m) { id in
                if let i = mesajlar.firstIndex(where: { $0.id == id }) {
                    mesajlar[i].bildirildi = true
                }
            }
            .environmentObject(oturum)
        }
        .alert("Tür kartı bulunamadı", isPresented: $kartBulunamadi) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Bu kart telefondaki verilerde yok. İçeriği yenileyip (ana sayfada aşağı çek) tekrar dene.")
        }
    }

    // MARK: Parçalar

    /// Kısa uyarı; "Ayrıntılar" ile tam metin (KVKK / yurt dışı aktarım bilgisi) açılır.
    private var uyariKutusu: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(Renk.amber)
                (Text("Tanıma bir tahmindir. ").bold()
                    + Text("İşlem yapmadan önce tür kartıyla karşılaştır."))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            if uyariAcik {
                Text(AsistanKurallari.uyariMetni)
                    .foregroundColor(Renk.soluk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 18) {
                Button(uyariAcik ? "Kısalt" : "Ayrıntılar") {
                    withAnimation(.easeInOut(duration: 0.2)) { uyariAcik.toggle() }
                }
                .font(.footnote.weight(.semibold))
                .foregroundColor(Renk.mavi)
                Button("Onayı geri al") { geriAlSor = true }
                    .font(.footnote)
                    .underline()
                    .foregroundColor(Renk.soluk)
            }
        }
        .font(.footnote)
        .foregroundColor(Renk.murekkep)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Renk.amberZemin)
        .cornerRadius(14)
    }

    private var bosDurum: some View {
        VStack(spacing: 6) {
            Text("Örnek: ") + Text("\"İstavritle kolyozu nasıl ayırt ederim?\"").bold()
                + Text(", ") + Text("\"Lüfer kaç cm'den avlanır?\"").bold()
            Text("ya da bir balığın fotoğrafını gönder.")
        }
        .font(.subheadline)
        .foregroundColor(Renk.soluk)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func mesajBalonu(_ m: AsistanMesaji) -> some View {
        switch m.rol {
        case .kullanici:
            HStack {
                Spacer(minLength: 40)
                VStack(alignment: .trailing, spacing: 6) {
                    if let f = m.foto {
                        Image(uiImage: f)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 220, maxHeight: 220)
                            .cornerRadius(12)
                    }
                    if !m.metin.isEmpty {
                        Text(m.metin)
                            .font(.body)
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Renk.dugme)
                .cornerRadius(18)
            }
        case .asistan:
            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    AsistanKurallari.bicimli(m.metin)
                        .font(.body)
                        .foregroundColor(Renk.murekkep)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    if !m.kartlar.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(m.kartlar) { k in
                                Button {
                                    kartAc(k)
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("\(k.ad) kartını aç")
                                        Image(systemName: "arrow.right")
                                    }
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(Renk.mavi)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(Renk.tint))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if m.bildirildi {
                        Label("Bildirildi, teşekkürler", systemImage: "checkmark")
                            .font(.caption)
                            .foregroundColor(Renk.yesil)
                    } else {
                        Button {
                            bildirilen = m
                        } label: {
                            Label("Bildir", systemImage: "flag")
                                .font(.caption)
                                .foregroundColor(Renk.soluk)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Bu cevabı bildir")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .kart()
                Spacer(minLength: 24)
            }
        case .hata:
            Text(m.metin)
                .font(.footnote)
                .foregroundColor(Renk.kirmizi)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Renk.kirmiziZemin)
                .cornerRadius(12)
                .frame(maxWidth: .infinity)
        }
    }

    private var yazmaAlani: some View {
        VStack(spacing: 8) {
            if let f = foto {
                HStack(spacing: 10) {
                    Image(uiImage: f)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 46, height: 46)
                        .clipped()
                        .cornerRadius(10)
                    Text("Fotoğraf eklendi")
                        .font(.footnote)
                        .foregroundColor(Renk.soluk)
                    Spacer()
                    Button("Kaldır") { foto = nil }
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Renk.mavi)
                }
            }
            HStack(spacing: 8) {
                Button {
                    fotoMenusu = true
                } label: {
                    Image(systemName: "camera")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Renk.mavi)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Renk.tint))
                }
                .disabled(bekliyor || kapali != nil)
                .accessibilityLabel("Fotoğraf ekle")

                TextField("Balık hakkında sor…", text: $yazi)
                    .textFieldStyle(.plain)
                    .submitLabel(.send)
                    .onSubmit { gonder() }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Capsule().fill(Renk.kart))
                    .overlay(Capsule().stroke(Renk.cizgi, lineWidth: 1))
                    .disabled(kapali != nil)

                Button(action: gonder) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Renk.dugme))
                }
                .disabled(!gonderilebilir)
                .opacity(gonderilebilir ? 1 : 0.5)
                .accessibilityLabel("Gönder")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Renk.ikincil.opacity(0.97))
        .overlay(Rectangle().fill(Renk.cizgi).frame(height: 1), alignment: .top)
    }

    private var gonderilebilir: Bool {
        return !bekliyor && kapali == nil
            && (!yazi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || foto != nil)
    }

    // MARK: İşlemler

    private func durumYukle() async {
        guard let t = oturum.token else { durumYuklendi = true; return }
        do {
            let d = try await APIIstemci.asistanDurum(token: t)
            kalanYazi = d.kalanYazi
            uyari = d.uyari
            kapali = d.acik ? nil : "Balık Asistanı şu anda kullanıma kapalı."
            onay = (d.acik && d.onayGerekli) ? d : nil
        } catch {
            // İnternet yoksa ekran açık kalır; soru gönderilince hata gösterilir.
        }
        durumYuklendi = true
    }

    /// ver = true: açık rıza verilir; false: geri alınır (sohbet temizlenir).
    private func onayDegistir(_ ver: Bool) {
        guard let t = oturum.token, !onayBekliyor else { return }
        onayBekliyor = true
        onayHata = nil
        Task {
            do {
                try await APIIstemci.asistanOnay(ver: ver, token: t)
                if !ver {
                    mesajlar = []
                    foto = nil
                }
                await durumYukle()
            } catch let h as APIHatasi {
                onayHata = h.aciklama
            } catch {
                onayHata = "İşlem yapılamadı. Tekrar dene."
            }
            onayBekliyor = false
        }
    }

    private func gonder() {
        guard gonderilebilir, let t = oturum.token else { return }
        let metin = String(yazi.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000))
        let resim = foto
        let gecmis = AsistanKurallari.gecmis(mesajlar)
        var veri: Data? = nil
        if let r = resim {
            veri = AsistanKurallari.gonderilecekFoto(r)
            if veri == nil {
                mesajlar.append(AsistanMesaji(rol: .hata, metin: "Fotoğraf hazırlanamadı. Başka bir fotoğraf dene."))
                return
            }
        }
        mesajlar.append(AsistanMesaji(rol: .kullanici, metin: metin, foto: resim))
        yazi = ""
        foto = nil
        bekliyor = true
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        Task {
            do {
                let c = try await APIIstemci.asistanSor(soru: metin, foto: veri, gecmis: gecmis, token: t)
                mesajlar.append(AsistanMesaji(rol: .asistan, metin: c.cevap, kartlar: c.kartlar,
                                              soru: metin.isEmpty ? "(yalnızca fotoğraf)" : metin))
                if !c.kalanYazi.isEmpty {
                    kalanYazi = c.kalanYazi
                }
            } catch let h as APIHatasi {
                mesajlar.append(AsistanMesaji(rol: .hata, metin: h.aciklama))
                await durumYukle() // onay geri alındıysa (ör. sitede) onay metni yeniden gösterilir
            } catch {
                mesajlar.append(AsistanMesaji(rol: .hata, metin: "Bir hata oluştu. Tekrar dene."))
            }
            bekliyor = false
        }
    }

    private func kartAc(_ k: AsistanKarti) {
        if let t = depo.turler.first(where: { $0.id == k.id }) {
            acikTur = t
        } else {
            kartBulunamadi = true
        }
    }
}

/// Asistanın bir cevabını bildirme penceresi (Google Play yapay zekâ içeriği kuralı).
struct AsistanBildirPenceresi: View {
    let mesaj: AsistanMesaji
    let bildirildi: (UUID) -> Void
    @EnvironmentObject var oturum: Oturum
    @Environment(\.dismiss) private var kapat
    @State private var neden = ""
    @State private var aciklama = ""
    @State private var bekliyor = false
    @State private var hata: String?

    static let nedenler: [(kod: String, ad: String)] = [
        ("yanlis", "Yanlış bilgi"),
        ("tanima", "Yanlış tür tanıma"),
        ("uygunsuz", "Uygunsuz / rahatsız edici"),
        ("diger", "Diğer"),
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Bu cevapta bir sorun mu var? Bildirimin uygulama yöneticisine iletilir ve asistanı düzeltmek için kullanılır.")
                        .font(.footnote)
                        .foregroundColor(Renk.soluk)
                        .fixedSize(horizontal: false, vertical: true)
                    if let h = hata {
                        Bildirim(metin: h, hata: true)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Neden?")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Renk.murekkep)
                        ForEach(Self.nedenler, id: \.kod) { n in
                            Button {
                                neden = n.kod
                            } label: {
                                HStack {
                                    Image(systemName: neden == n.kod ? "largecircle.fill.circle" : "circle")
                                        .foregroundColor(neden == n.kod ? Renk.mavi : Renk.soluk)
                                    Text(n.ad)
                                        .foregroundColor(Renk.murekkep)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                    .kart()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Açıklama (isteğe bağlı)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Renk.murekkep)
                        TextField("Doğrusu nedir ya da ne rahatsız etti?", text: $aciklama)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(14)
                    .kart()
                    AnaDugme(baslik: "Bildirimi gönder", bekliyor: bekliyor) {
                        Task { await gonder() }
                    }
                    .disabled(neden.isEmpty || bekliyor)
                    .opacity(neden.isEmpty ? 0.5 : 1)
                }
                .padding(16)
            }
            .background(DenizZemini().ignoresSafeArea())
            .navigationTitle("Cevabı bildir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Vazgeç") { kapat() }
                }
            }
        }
    }

    private func gonder() async {
        guard let t = oturum.token, !neden.isEmpty else { return }
        bekliyor = true
        hata = nil
        do {
            _ = try await APIIstemci.asistanBildir(neden: neden,
                                                   aciklama: String(aciklama.prefix(500)),
                                                   soru: mesaj.soru, cevap: mesaj.metin, token: t)
            bildirildi(mesaj.id)
            kapat()
        } catch let h as APIHatasi {
            hata = h.aciklama
        } catch {
            hata = "Bildirim gönderilemedi. Tekrar dene."
        }
        bekliyor = false
    }
}

/// Asistanın "kartını aç" düğmesiyle açılan tek tür kartı.
struct TurKartiPenceresi: View {
    let tur: Tur
    @Environment(\.dismiss) private var kapat
    @State private var buyuk: Tur?

    var body: some View {
        NavigationView {
            ScrollView {
                TurKarti(tur: tur) { buyuk = tur }
                    .padding(16)
            }
            .background(DenizZemini().ignoresSafeArea())
            .navigationTitle(tur.ad)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { kapat() }
                }
            }
        }
        .fullScreenCover(item: $buyuk) { t in
            BuyukFoto(url: t.fotoURL, ad: t.ad, kredi: t.fotoKredi)
        }
    }
}

/// Kamerayla fotoğraf çekme (iOS 15 uyumlu).
struct KameraSecici: UIViewControllerRepresentable {
    let secildi: (UIImage) -> Void
    @Environment(\.dismiss) private var kapat

    func makeCoordinator() -> Koordinator {
        return Koordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let v = UIImagePickerController()
        v.sourceType = .camera
        v.delegate = context.coordinator
        return v
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Koordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let ust: KameraSecici

        init(_ ust: KameraSecici) {
            self.ust = ust
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let resim = info[.originalImage] as? UIImage {
                ust.secildi(resim)
            }
            ust.kapat()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            ust.kapat()
        }
    }
}
