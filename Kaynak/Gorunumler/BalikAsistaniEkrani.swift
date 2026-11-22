import SwiftUI
import UIKit

// Balık Asistanı — sitedeki balik-asistani.php'nin uygulama karşılığı.
// Sunucu: api/asistan.php (asistan-cekirdek.php'yi kullanır; kurallar, sınırlar ve kayıt sunucuda).
// Sohbet geçmişi yalnızca bu ekranda tutulur; "Yeni sohbet" ile silinir. Fotoğraf telefonda küçültülür.

struct AsistanDurumu {
    let acik: Bool
    let kalanYazi: String
    let uyari: String
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
}

enum AsistanKurallari {
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

    var body: some View {
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
        .alert("Tür kartı bulunamadı", isPresented: $kartBulunamadi) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Bu kart telefondaki verilerde yok. İçeriği yenileyip (ana sayfada aşağı çek) tekrar dene.")
        }
        .task { await durumYukle() }
        // Yazma alanı altta kalsın diye yüzen sekme çubuğu bu ekranda gizlenir (geri dönünce yeniden görünür).
        .onAppear { SekmeCubuguDurumu.paylasilan.gizli = true }
        .onDisappear { SekmeCubuguDurumu.paylasilan.gizli = false }
    }

    // MARK: Parçalar

    private var uyariKutusu: some View {
        (Text("Deneme sürümü. ").bold()
            + Text(uyari.isEmpty
                   ? "Tanıma bir tahmindir; işlem yapmadan önce tür kartıyla karşılaştır. Boy, yasak dönem ve miktar gibi kurallar yalnızca uygulamadaki tür kartlarından verilir. Fotoğrafa kişi, yüz, tekne adı veya plaka gelmemesine dikkat et. Sorular ve fotoğraflar cevap üretilmesi için yapay zekâ hizmetine (Anthropic, yurt dışı) gönderilir; fotoğraflar sunucuda saklanmaz. Soru ve cevaplar kalite ve maliyet kontrolü için kaydedilir."
                   : uyari))
            .font(.footnote)
            .foregroundColor(Renk.murekkep)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
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
        guard let t = oturum.token else { return }
        do {
            let d = try await APIIstemci.asistanDurum(token: t)
            kalanYazi = d.kalanYazi
            uyari = d.uyari
            kapali = d.acik ? nil : "Balık Asistanı şu anda kullanıma kapalı."
        } catch {
            // İnternet yoksa ekran açık kalır; soru gönderilince hata gösterilir.
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
                mesajlar.append(AsistanMesaji(rol: .asistan, metin: c.cevap, kartlar: c.kartlar))
                if !c.kalanYazi.isEmpty {
                    kalanYazi = c.kalanYazi
                }
            } catch let h as APIHatasi {
                mesajlar.append(AsistanMesaji(rol: .hata, metin: h.aciklama))
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
