import SwiftUI
import UIKit
import PhotosUI

/// Hesabım'daki profil fotoğrafı. Yalnızca bu telefonda saklanır, sunucuya gönderilmez.
/// Her kullanıcının fotoğrafı ayrı dosyadadır; çıkış yapınca silinmez,
/// aynı hesapla tekrar girince geri gelir. Başka hesapla girilirse görünmez.
@MainActor
final class ProfilFotografi: ObservableObject {
    static let paylasilan = ProfilFotografi()

    @Published private(set) var resim: UIImage?
    private var kullaniciId: Int?

    private static var klasor: URL {
        let destek = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: destek, withIntermediateDirectories: true)
        return destek
    }

    private static func dosya(_ id: Int) -> URL {
        return klasor.appendingPathComponent("profil-foto-\(id).jpg")
    }

    /// Önceki sürümün tek dosyası (kullanıcıya bağlı değildi).
    private static var eskiDosya: URL {
        return klasor.appendingPathComponent("profil-foto.jpg")
    }

    /// Giriş yapan kullanıcı değişince çağrılır.
    func kullaniciAyarla(_ id: Int?) {
        if id == kullaniciId && (id == nil || resim != nil) { return }
        kullaniciId = id
        guard let id = id else {
            resim = nil
            return
        }
        let hedef = ProfilFotografi.dosya(id)
        let fm = FileManager.default
        if !fm.fileExists(atPath: hedef.path), fm.fileExists(atPath: ProfilFotografi.eskiDosya.path) {
            try? fm.moveItem(at: ProfilFotografi.eskiDosya, to: hedef)
        }
        if let d = try? Data(contentsOf: hedef) {
            resim = UIImage(data: d)
        } else {
            resim = nil
        }
    }

    func kaydet(_ yeni: UIImage) {
        guard let id = kullaniciId else { return }
        let enFazla: CGFloat = 600
        let olcek = min(1, enFazla / max(yeni.size.width, yeni.size.height))
        let boyut = CGSize(width: yeni.size.width * olcek, height: yeni.size.height * olcek)
        let bicim = UIGraphicsImageRendererFormat.default()
        bicim.scale = 1
        let kucuk = UIGraphicsImageRenderer(size: boyut, format: bicim).image { _ in
            yeni.draw(in: CGRect(origin: .zero, size: boyut))
        }
        if let d = kucuk.jpegData(compressionQuality: 0.82) {
            try? d.write(to: ProfilFotografi.dosya(id), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            resim = UIImage(data: d)
        }
    }

    func sil() {
        guard let id = kullaniciId else { return }
        try? FileManager.default.removeItem(at: ProfilFotografi.dosya(id))
        resim = nil
    }

    /// Alttaki "Hesabım" sekmesi için yuvarlak küçük fotoğraf.
    func sekmeSimgesi(secili: Bool, vurgu: UIColor) -> UIImage? {
        guard let r = resim else { return nil }
        let boyut: CGFloat = 28
        let cizgi: CGFloat = secili ? 2 : 0
        let alan = CGRect(x: 0, y: 0, width: boyut, height: boyut)
        let gorsel = UIGraphicsImageRenderer(size: alan.size).image { _ in
            let ic = alan.insetBy(dx: cizgi, dy: cizgi)
            UIBezierPath(ovalIn: ic).addClip()
            let oran = max(ic.width / r.size.width, ic.height / r.size.height)
            let w = r.size.width * oran
            let h = r.size.height * oran
            r.draw(in: CGRect(x: ic.midX - w / 2, y: ic.midY - h / 2, width: w, height: h))
        }
        guard secili else { return gorsel.withRenderingMode(.alwaysOriginal) }
        let halkali = UIGraphicsImageRenderer(size: alan.size).image { _ in
            gorsel.draw(in: alan)
            let halka = UIBezierPath(ovalIn: alan.insetBy(dx: cizgi / 2, dy: cizgi / 2))
            halka.lineWidth = cizgi
            vurgu.setStroke()
            halka.stroke()
        }
        return halkali.withRenderingMode(.alwaysOriginal)
    }
}

/// Fotoğraf seçici (iOS 15 uyumlu PHPicker).
struct FotoSecici: UIViewControllerRepresentable {
    let secildi: (UIImage) -> Void
    @Environment(\.dismiss) private var kapat

    func makeCoordinator() -> Koordinator {
        return Koordinator(self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var ayar = PHPickerConfiguration()
        ayar.filter = .images
        ayar.selectionLimit = 1
        let v = PHPickerViewController(configuration: ayar)
        v.delegate = context.coordinator
        return v
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Koordinator: NSObject, PHPickerViewControllerDelegate {
        let ust: FotoSecici

        init(_ ust: FotoSecici) {
            self.ust = ust
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            let saglayici = results.first?.itemProvider
            if let s = saglayici, s.canLoadObject(ofClass: UIImage.self) {
                s.loadObject(ofClass: UIImage.self) { nesne, _ in
                    if let resim = nesne as? UIImage {
                        DispatchQueue.main.async { self.ust.secildi(resim) }
                    }
                }
            }
            DispatchQueue.main.async { self.ust.kapat() }
        }
    }
}

/// Yuvarlak profil görseli: fotoğraf varsa o, yoksa kullanıcı adının ilk harfi.
struct ProfilResmi: View {
    let resim: UIImage?
    let harf: String
    var boyut: CGFloat = 64

    var body: some View {
        ZStack {
            if let r = resim {
                Image(uiImage: r)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.white
                Text(harf)
                    .font(.system(size: boyut * 0.42, weight: .bold))
                    .foregroundColor(Renk.lacivert)
            }
        }
        .frame(width: boyut, height: boyut)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 2))
    }
}
