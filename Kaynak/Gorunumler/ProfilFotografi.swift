import SwiftUI
import UIKit
import PhotosUI

/// Hesabım'daki profil fotoğrafı. Yalnızca bu telefonda saklanır, sunucuya gönderilmez.
enum ProfilFotografi {
    private static var dosya: URL {
        let destek = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: destek, withIntermediateDirectories: true)
        return destek.appendingPathComponent("profil-foto.jpg")
    }

    static func oku() -> UIImage? {
        guard let d = try? Data(contentsOf: dosya) else { return nil }
        return UIImage(data: d)
    }

    static func kaydet(_ resim: UIImage) {
        let enFazla: CGFloat = 600
        let olcek = min(1, enFazla / max(resim.size.width, resim.size.height))
        let boyut = CGSize(width: resim.size.width * olcek, height: resim.size.height * olcek)
        let cizici = UIGraphicsImageRenderer(size: boyut)
        let kucuk = cizici.image { _ in resim.draw(in: CGRect(origin: .zero, size: boyut)) }
        if let d = kucuk.jpegData(compressionQuality: 0.82) {
            try? d.write(to: dosya, options: [.atomic, .completeFileProtection])
        }
    }

    static func sil() {
        try? FileManager.default.removeItem(at: dosya)
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
