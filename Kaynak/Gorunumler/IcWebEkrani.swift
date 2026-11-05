import SwiftUI
import UIKit
import WebKit

/// Uygulama içinde açılan site sayfası (Yönetim paneli, Destek paneli, KVKK).
/// Adres çubuğu yoktur; üstte yalnızca sayfa adı, Kapat, Geri ve Yenile görünür.
struct IcWebSayfasi: Identifiable {
    let id = UUID()
    let baslik: String
    let url: URL
}

@MainActor
final class WebDurumu: ObservableObject {
    @Published var yukleniyor = false
    @Published var ilerleme: Double = 0
    @Published var geriGidebilir = false
    @Published var hata: String?
    weak var web: WKWebView?
    var kapat: (() -> Void)?
}

struct IcWebEkrani: View {
    let sayfa: IcWebSayfasi
    @Environment(\.dismiss) private var kapat
    @StateObject private var durum = WebDurumu()

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                WebGorunumu(url: sayfa.url, durum: durum)
                    .background(Renk.zemin)
                    .ignoresSafeArea(edges: .bottom)

                if durum.yukleniyor {
                    ProgressView(value: max(0.05, durum.ilerleme))
                        .progressViewStyle(.linear)
                        .tint(Color(UIColor(onaltilik: 0x4AA8ED)))
                }

                if let h = durum.hata {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 34))
                            .foregroundColor(Renk.soluk)
                        Text(h)
                            .font(.callout)
                            .foregroundColor(Renk.murekkep)
                            .multilineTextAlignment(.center)
                        Button("Tekrar dene") {
                            durum.hata = nil
                            if let w = durum.web {
                                if w.url == nil {
                                    w.load(URLRequest(url: sayfa.url))
                                } else {
                                    w.reload()
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Renk.lacivert)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Renk.zemin)
                }
            }
            // Üst çubuğun arkası lacivert kalsın (sayfa beyaz olsa da başlık okunur).
            .background(Color(UIColor.dinamik(0x08243A, 0x050E17)).ignoresSafeArea())
            .navigationTitle(sayfa.baslik)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") { kapat() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 18) {
                        Button {
                            durum.web?.goBack()
                        } label: {
                            Image(systemName: "chevron.backward")
                        }
                        .disabled(!durum.geriGidebilir)
                        .opacity(durum.geriGidebilir ? 1 : 0.35)
                        Button {
                            durum.hata = nil
                            durum.web?.reload()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear { durum.kapat = { kapat() } }
    }
}

struct WebGorunumu: UIViewRepresentable {
    let url: URL
    let durum: WebDurumu

    func makeCoordinator() -> Koordinator {
        return Koordinator(durum: durum, ilkAdres: url)
    }

    func makeUIView(context: Context) -> WKWebView {
        let ayar = WKWebViewConfiguration()
        ayar.websiteDataStore = .default()
        ayar.allowsInlineMediaPlayback = true
        let w = WKWebView(frame: .zero, configuration: ayar)
        w.navigationDelegate = context.coordinator
        w.uiDelegate = context.coordinator
        w.allowsBackForwardNavigationGestures = true
        w.isOpaque = false
        w.backgroundColor = .clear
        w.scrollView.backgroundColor = .clear
        context.coordinator.izle(w)
        durum.web = w
        w.load(URLRequest(url: url))
        return w
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Koordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let durum: WebDurumu
        let siteHost: String?
        private var gozlemler: [NSKeyValueObservation] = []

        init(durum: WebDurumu, ilkAdres: URL) {
            self.durum = durum
            self.siteHost = ilkAdres.host?.lowercased()
        }

        func izle(_ w: WKWebView) {
            gozlemler = [
                w.observe(\.estimatedProgress, options: [.new]) { [weak self] w, _ in
                    let d = w.estimatedProgress
                    Task { @MainActor in self?.durum.ilerleme = d }
                },
                w.observe(\.isLoading, options: [.new]) { [weak self] w, _ in
                    let y = w.isLoading
                    Task { @MainActor in self?.durum.yukleniyor = y }
                },
                w.observe(\.canGoBack, options: [.new]) { [weak self] w, _ in
                    let g = w.canGoBack
                    Task { @MainActor in self?.durum.geriGidebilir = g }
                },
            ]
        }

        // Siteden çıkan bağlantılar Safari'de; çıkış ve ana sayfa bağlantıları paneli kapatır.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let u = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            let sema = (u.scheme ?? "").lowercased()
            if sema == "mailto" || sema == "tel" || sema == "sms" {
                UIApplication.shared.open(u)
                decisionHandler(.cancel)
                return
            }
            guard sema == "http" || sema == "https" else {
                decisionHandler(sema == "about" || sema == "blob" || sema == "data" ? .allow : .cancel)
                return
            }
            let host = u.host?.lowercased()
            if navigationAction.targetFrame?.isMainFrame ?? true, host != nil, host != siteHost {
                UIApplication.shared.open(u)
                decisionHandler(.cancel)
                return
            }
            let son = u.lastPathComponent.lowercased()
            let uygulamaSayfasi = ["logout.php", "dashboard.php", "index.php", "login.php"]
            if navigationAction.navigationType == .linkActivated,
               u.pathComponents.count <= 2,
               uygulamaSayfasi.contains(son) || u.path == "/" {
                let d = durum
                Task { @MainActor in d.kapat?() }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            hataGoster(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            hataGoster(error)
        }

        private func hataGoster(_ error: Error) {
            let e = error as NSError
            if e.domain == NSURLErrorDomain && e.code == NSURLErrorCancelled { return }
            if e.domain == "WebKitErrorDomain" && e.code == 102 { return }
            let d = durum
            Task { @MainActor in d.hata = "Sayfa açılamadı. İnternet bağlantınızı kontrol edip tekrar deneyin." }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let d = durum
            Task { @MainActor in d.hata = nil }
        }

        // target="_blank" bağlantılar aynı ekranda açılır.
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        // Sayfadaki alert / confirm / prompt pencereleri (ör. "Silinsin mi?").
        func webView(_ webView: WKWebView,
                     runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping () -> Void) {
            let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "Tamam", style: .default) { _ in completionHandler() })
            if !Koordinator.goster(a, uzerinde: webView) { completionHandler() }
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (Bool) -> Void) {
            let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "Vazgeç", style: .cancel) { _ in completionHandler(false) })
            a.addAction(UIAlertAction(title: "Tamam", style: .default) { _ in completionHandler(true) })
            if !Koordinator.goster(a, uzerinde: webView) { completionHandler(false) }
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptTextInputPanelWithPrompt prompt: String,
                     defaultText: String?,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (String?) -> Void) {
            let a = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
            a.addTextField { $0.text = defaultText }
            a.addAction(UIAlertAction(title: "Vazgeç", style: .cancel) { _ in completionHandler(nil) })
            a.addAction(UIAlertAction(title: "Tamam", style: .default) { _ in completionHandler(a.textFields?.first?.text) })
            if !Koordinator.goster(a, uzerinde: webView) { completionHandler(nil) }
        }

        private static func goster(_ a: UIAlertController, uzerinde v: UIView) -> Bool {
            var kok = v.window?.rootViewController
            while let ust = kok?.presentedViewController {
                kok = ust
            }
            guard let k = kok else { return false }
            k.present(a, animated: true)
            return true
        }
    }
}

/// Yönetim ve destek paneline şifresiz geçiş: uygulamadaki giriş tek kullanımlık kodla
/// siteye taşınır ve sayfa uygulama içinde açılır.
@MainActor
enum PanelGecisi {
    static func ac(_ hedef: String, baslik: String, oturum: Oturum,
                   sonuc: @escaping (IcWebSayfasi?, String?) -> Void) {
        guard let t = oturum.token else { return }
        Task {
            do {
                let u = try await APIIstemci.webOturum(hedef: hedef, token: t)
                sonuc(IcWebSayfasi(baslik: baslik, url: u), nil)
            } catch let e as APIHatasi {
                sonuc(nil, e.aciklama)
            } catch {
                sonuc(nil, APIHatasi.baglanti.aciklama)
            }
        }
    }
}
