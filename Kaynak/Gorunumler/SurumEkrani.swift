import SwiftUI

// MARK: - Uygulama sürüm takibi
//
// Uygulama açılınca günde bir kez api/surum-bildir.php'ye platform, uygulama sürümü,
// iOS sürümü ve telefon modeli (ör. iPhone14,2) bildirilir. Hata olursa sessizce geçilir.
// Yönetim > Uygulama sürümleri ekranı api/yonetim-surumler.php'den okur (Android ile aynı).

enum SurumBildirimi {
    /// Bugün bu sürüm için bildirildi mi? Anahtar: "kod|yyyy-MM-dd"
    static func anahtar(kod: Int, gun: String) -> String { "\(kod)|\(gun)" }

    static var surum: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "" }
    static var kod: Int { Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0 }

    /// Donanım kimliği, ör. "iPhone14,2" (UIDevice yalnızca "iPhone" verir).
    static var model: String {
        var bilgi = utsname()
        uname(&bilgi)
        let ham = withUnsafePointer(to: &bilgi.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        return ham.isEmpty ? UIDevice.current.model : ham
    }

    @MainActor
    static func gerekirseGonder(token: String) async {
        let bicim = DateFormatter()
        bicim.locale = Locale(identifier: "en_US_POSIX")
        bicim.dateFormat = "yyyy-MM-dd"
        let a = anahtar(kod: kod, gun: bicim.string(from: Date()))
        guard UserDefaults.standard.string(forKey: "surumBildirildi") != a else { return }
        do {
            try await APIIstemci.surumBildir(surum: surum, kod: kod, sistem: UIDevice.current.systemVersion,
                                             model: model, token: token)
            UserDefaults.standard.set(a, forKey: "surumBildirildi")
        } catch {
            // Sessizce geç; yarın yeniden denenir.
        }
    }

    static func platformAdi(_ p: String) -> String { p == "ios" ? "iPhone" : "Android" }

    /// Liste araması (ad, kullanıcı adı, model, sürüm) — Türkçe büyük/küçük harf.
    static func ara(_ liste: [SurumListesi.Kisi], _ metin: String) -> [SurumListesi.Kisi] {
        let tr = Locale(identifier: "tr_TR")
        let q = metin.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: tr)
        if q.isEmpty { return liste }
        return liste.filter { "\($0.ad) \($0.kullaniciAdi) \($0.model) \($0.surum)".lowercased(with: tr).contains(q) }
    }
}

struct SurumListesi: Codable {
    struct Guncel: Codable {
        let android: String
        let androidKod: Int
        let ios: String
        let iosKod: Int
    }

    struct Ozet: Codable, Identifiable {
        let platform: String
        let surum: String
        let kod: Int
        let sayi: Int
        var id: String { platform + "|" + surum }
    }

    struct Kisi: Codable, Identifiable {
        let id: Int
        let ad: String
        let kullaniciAdi: String
        let platform: String
        let surum: String
        let kod: Int
        let sistem: String
        let model: String
        let son: String
        let guncel: Bool
        var satirKimligi: String { "\(id)-\(platform)" }
    }

    let guncel: Guncel
    let ozet: [Ozet]
    let bilinmiyor: Int
    let kisiler: [Kisi]
}

/// Yönetim > Uygulama sürümleri (yalnızca yönetici).
struct SurumYonetimiEkrani: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu
    @State private var veri: SurumListesi?
    @State private var hata: String?
    @State private var arama = ""

    var body: some View {
        YenilenebilirKaydirma(eylem: { await yukle() }) {
            VStack(spacing: 0) {
                Kahraman(baslik: "Uygulama sürümleri",
                         aciklama: "Kim, hangi telefonda, hangi sürümü kullanıyor.")
                VStack(alignment: .leading, spacing: 12) {
                    if let h = hata {
                        Bildirim(metin: h, hata: true)
                    }
                    if let v = veri {
                        ozetKarti(v)
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundColor(Renk.soluk)
                            TextField("Ad, model ya da sürüm ara", text: $arama)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                        }
                        .padding(12)
                        .background(Renk.kart)
                        .cornerRadius(14)
                        let liste = SurumBildirimi.ara(v.kisiler, arama)
                        VStack(spacing: 0) {
                            if liste.isEmpty {
                                Text(v.kisiler.isEmpty ? "Henüz sürüm bildiren olmadı. Yeni sürümü kuranlar burada görünecek." : "Kimse bulunamadı.")
                                    .font(.subheadline)
                                    .foregroundColor(Renk.soluk)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            ForEach(Array(liste.enumerated()), id: \.element.satirKimligi) { i, k in
                                if i > 0 { Divider().padding(.leading, 56) }
                                kisiSatiri(k)
                            }
                        }
                        .kart()
                    } else if hata == nil {
                        HStack { Spacer(); ProgressView(); Spacer() }.padding(.top, 30)
                    }
                }
                .padding(16)
            }
        }
        .background(DenizZemini().ignoresSafeArea())
        .navigationTitle("Uygulama sürümleri")
        .markaBasligi()
        .task { if veri == nil { await yukle() } }
    }

    private func ozetKarti(_ v: SurumListesi) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !v.guncel.android.isEmpty {
                Text("Play'deki son sürüm: Android \(v.guncel.android)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Renk.murekkep)
            }
            ForEach(v.ozet) { o in
                let guncel = (o.platform == "android" && o.kod >= v.guncel.androidKod) || (o.platform == "ios" && o.kod >= v.guncel.iosKod)
                HStack {
                    Text("\(SurumBildirimi.platformAdi(o.platform)) \(o.surum)")
                        .font(.subheadline)
                        .foregroundColor(Renk.murekkep)
                    Spacer()
                    Hap(metin: "\(o.sayi) kişi", renk: guncel ? Renk.yesil : Renk.amber, zemin: guncel ? Renk.yesilZemin : Renk.amberZemin)
                }
            }
            HStack {
                Text("Bilinmiyor (eski sürüm ya da yalnızca site)")
                    .font(.footnote)
                    .foregroundColor(Renk.soluk)
                Spacer()
                Hap(metin: "\(v.bilinmiyor) kişi", renk: Renk.soluk, zemin: Renk.ikincil)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .kart()
    }

    private func kisiSatiri(_ k: SurumListesi.Kisi) -> some View {
        HStack(spacing: 12) {
            Image(systemName: k.platform == "ios" ? "iphone" : "candybarphone")
                .font(.subheadline)
                .foregroundColor(Renk.mavi)
                .frame(width: 30, height: 30)
                .background(Renk.tint)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(k.ad)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Renk.murekkep)
                let ayrinti = [k.model, k.sistem.isEmpty ? "" : "\(SurumBildirimi.platformAdi(k.platform)) \(k.sistem)", k.son]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                if !ayrinti.isEmpty {
                    Text(ayrinti)
                        .font(.caption)
                        .foregroundColor(Renk.soluk)
                }
            }
            Spacer(minLength: 0)
            Hap(metin: k.surum, renk: k.guncel ? Renk.yesil : Renk.amber, zemin: k.guncel ? Renk.yesilZemin : Renk.amberZemin)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func yukle() async {
        guard let t = oturum.token else { return }
        do {
            veri = try await APIIstemci.surumListesi(token: t)
            hata = nil
        } catch APIHatasi.yetkisiz(_) {
            Eylemler.cikis(oturum: oturum, depo: depo)
        } catch let e as APIHatasi {
            hata = e.aciklama
        } catch {
            hata = APIHatasi.baglanti.aciklama
        }
    }
}
