import SwiftUI
import UIKit

/// Klavye açıkken yazı alanı dışında bir yere dokununca klavye kapanır (tüm uygulamada).
/// Pencereye bir kez eklenir; düğmelere ve listelere yapılan dokunuşları engellemez.
struct KlavyeKapatici: UIViewRepresentable {
    func makeUIView(context: Context) -> Baglayici {
        let v = Baglayici()
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ uiView: Baglayici, context: Context) {}

    final class Baglayici: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let pencere = window else { return }
            let ad = "klavyeKapatici"
            if pencere.gestureRecognizers?.contains(where: { $0.name == ad }) == true { return }
            let dokunus = UITapGestureRecognizer(target: KlavyeDokunusTemsilcisi.paylasilan,
                                                 action: #selector(KlavyeDokunusTemsilcisi.dokunuldu(_:)))
            dokunus.name = ad
            dokunus.cancelsTouchesInView = false
            dokunus.requiresExclusiveTouchType = false
            dokunus.delegate = KlavyeDokunusTemsilcisi.paylasilan
            pencere.addGestureRecognizer(dokunus)
        }
    }
}

final class KlavyeDokunusTemsilcisi: NSObject, UIGestureRecognizerDelegate {
    static let paylasilan = KlavyeDokunusTemsilcisi()

    @objc func dokunuldu(_ g: UITapGestureRecognizer) {
        g.view?.endEditing(true)
    }

    /// Yazı alanının kendisine dokunulduysa klavye kapanmasın (alanlar arası geçiş bozulmasın).
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var v = touch.view
        while let x = v {
            if x is UITextField || x is UITextView { return false }
            v = x.superview
        }
        return true
    }

    func gestureRecognizer(_ g: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return true
    }
}
