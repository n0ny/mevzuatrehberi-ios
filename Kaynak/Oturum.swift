import Foundation

/// Giriş durumu. Giriş anahtarı Keychain'de, kullanıcı adı/ismi telefonda saklanır.
@MainActor
final class Oturum: ObservableObject {
    enum Durum: Equatable {
        case girisGerekli
        case acik(KullaniciOzet)
    }

    @Published private(set) var durum: Durum
    private(set) var token: String?

    private static let kullaniciAnahtari = "oturum.kullanici"

    init() {
        if let t = AnahtarZinciri.oku(), let k = Oturum.kayitliKullanici() {
            token = t
            durum = .acik(k)
        } else {
            token = nil
            durum = .girisGerekli
        }
    }

    var kullanici: KullaniciOzet? {
        if case .acik(let k) = durum { return k }
        return nil
    }

    func girisYap(kullanici: String, sifre: String) async throws {
        let sonuc = try await APIIstemci.giris(kullanici: kullanici, sifre: sifre)
        AnahtarZinciri.yaz(sonuc.token)
        token = sonuc.token
        Oturum.kullaniciKaydet(sonuc.kullanici)
        durum = .acik(sonuc.kullanici)
    }

    /// Giriş hâlâ geçerli mi? Geçersizse false döner. İnternet yoksa dokunmaz.
    func kontrolEt() async -> Bool {
        guard let t = token else { return false }
        do {
            let k = try await APIIstemci.ben(token: t)
            Oturum.kullaniciKaydet(k)
            durum = .acik(k)
            return true
        } catch APIHatasi.yetkisiz(_) {
            return false
        } catch {
            return true
        }
    }

    func cikisYap() {
        AnahtarZinciri.sil()
        UserDefaults.standard.removeObject(forKey: Oturum.kullaniciAnahtari)
        token = nil
        durum = .girisGerekli
    }

    private static func kayitliKullanici() -> KullaniciOzet? {
        guard let veri = UserDefaults.standard.data(forKey: kullaniciAnahtari) else { return nil }
        return try? JSONDecoder().decode(KullaniciOzet.self, from: veri)
    }

    private static func kullaniciKaydet(_ k: KullaniciOzet) {
        if let veri = try? JSONEncoder().encode(k) {
            UserDefaults.standard.set(veri, forKey: kullaniciAnahtari)
        }
    }
}
