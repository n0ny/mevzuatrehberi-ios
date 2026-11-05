import SwiftUI

@main
struct MevzuatRehberiApp: App {
    @StateObject private var oturum = Oturum()
    @StateObject private var depo = VeriDeposu()

    init() {
        // Tür fotoğrafları internetsizken de görünsün diye önbellek büyütülür.
        URLCache.shared = URLCache(memoryCapacity: 32 * 1024 * 1024,
                                   diskCapacity: 300 * 1024 * 1024,
                                   directory: nil)
        Renk.gezinmeCubugunuAyarla()
        Renk.sekmeCubugunuAyarla()
    }

    var body: some Scene {
        WindowGroup {
            KokGorunum()
                .environmentObject(oturum)
                .environmentObject(depo)
        }
    }
}

struct KokGorunum: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu
    @Environment(\.scenePhase) private var faz
    /// Hesabım > Görünüm: otomatik / acik (gündüz) / koyu (gece). Bu cihazda hatırlanır.
    @AppStorage("gorunum") private var gorunum = "otomatik"

    var body: some View {
        Group {
            switch oturum.durum {
            case .girisGerekli:
                GirisEkrani()
            case .acik:
                AnaSekmeler()
            }
        }
        .preferredColorScheme(gorunum == "acik" ? .light : (gorunum == "koyu" ? .dark : nil))
        .task {
            await depo.diskOku()
            await baslangicKontrolu()
        }
        .onChange(of: faz) { yeniFaz in
            if yeniFaz == .active {
                Task { await gerekirseGuncelle() }
            }
        }
    }

    /// Açılışta: giriş geçerli mi, içerik güncel mi?
    private func baslangicKontrolu() async {
        guard oturum.token != nil else { return }
        let gecerli = await oturum.kontrolEt()
        if !gecerli {
            Eylemler.cikis(oturum: oturum, depo: depo)
            return
        }
        await Eylemler.guncelle(oturum: oturum, depo: depo)
    }

    private func gerekirseGuncelle() async {
        guard depo.diskOkundu, depo.kontrolGerekli else { return }
        await Eylemler.guncelle(oturum: oturum, depo: depo)
    }
}

/// Birden çok ekrandan çağrılan ortak işlemler.
@MainActor
enum Eylemler {
    static func guncelle(oturum: Oturum, depo: VeriDeposu) async {
        guard let t = oturum.token else { return }
        let sonuc = await depo.guncelle(token: t)
        if case .yetkisiz = sonuc {
            cikis(oturum: oturum, depo: depo)
        }
    }

    static func cikis(oturum: Oturum, depo: VeriDeposu) {
        oturum.cikisYap()
        depo.temizle()
    }
}
