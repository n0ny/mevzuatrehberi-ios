import Foundation
import Security

/// Giriş anahtarını (token) telefonun güvenli deposunda (Keychain) saklar.
enum AnahtarZinciri {
    private static let servis = "com.barisguresci.sgmevzuat.oturum"
    private static let hesap = "token"

    private static func temelSorgu() -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servis,
            kSecAttrAccount as String: hesap,
        ]
    }

    static func yaz(_ deger: String) {
        sil()
        var sorgu = temelSorgu()
        sorgu[kSecValueData as String] = Data(deger.utf8)
        sorgu[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(sorgu as CFDictionary, nil)
    }

    static func oku() -> String? {
        var sorgu = temelSorgu()
        sorgu[kSecReturnData as String] = true
        sorgu[kSecMatchLimit as String] = kSecMatchLimitOne
        var sonuc: AnyObject?
        let durum = SecItemCopyMatching(sorgu as CFDictionary, &sonuc)
        guard durum == errSecSuccess, let veri = sonuc as? Data else { return nil }
        return String(data: veri, encoding: .utf8)
    }

    static func sil() {
        SecItemDelete(temelSorgu() as CFDictionary)
    }
}
