import SwiftUI
import UIKit

// MARK: - Veri (api/yonetim-turler.php — sitedeki admin/turler.php ile aynı)

struct TurYonetimVerisi: Codable {
    struct Oneri: Codable {
        let ad: String
        let url: String
    }
    let turler: [TurYonetimKaydi]
    let fotosuz: Int
    let gruplar: [String]
    let kaynakOnerileri: [Oneri]
}

struct TurYonetimKaydi: Codable, Identifiable, Equatable {
    let id: Int
    let ad: String
    let digerAdlar: String
    let bilimselAd: String
    let grup: String
    let fotoUrl: String?
    let fotoKredi: String
    let boyTicari: String
    let boyAmator: String
    let yasakDonemi: String
    let notlar: String
    let kaynak: String
    let kaynakUrl: String
    let aktif: Bool
}

struct FotoBulSonucu {
    let durum: String
    let mesaj: String
    let kredi: String
    let aranan: String
}

enum TurYonetimKurallari {
    static func ara(_ liste: [TurYonetimKaydi], _ metin: String) -> [TurYonetimKaydi] {
        let q = metin.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return liste }
        return liste.filter { t in
            let alan = [t.ad, t.digerAdlar, t.bilimselAd, t.grup].joined(separator: " ")
            return alan.range(of: q, options: [.caseInsensitive, .diacriticInsensitive], locale: TRMetin.tr) != nil
        }
    }

    /// Yüklemeden önce fotoğraf küçültülür (sunucu zaten en fazla 1200 px yapar; sınır 8 MB).
    static func yuklenecekFoto(_ resim: UIImage) -> Data? {
        let enFazla: CGFloat = 1600
        let olcek = min(1, enFazla / max(resim.size.width, resim.size.height))
        let boyut = CGSize(width: resim.size.width * olcek, height: resim.size.height * olcek)
        let bicim = UIGraphicsImageRendererFormat.default()
        bicim.scale = 1
        let kucuk = UIGraphicsImageRenderer(size: boyut, format: bicim).image { _ in
            resim.draw(in: CGRect(origin: .zero, size: boyut))
        }
        return kucuk.jpegData(compressionQuality: 0.85)
    }
}

// MARK: - Liste

/// admin/turler.php — Tür kartları yönetimi.
struct TurYonetimiEkrani: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu

    @State private var veri: TurYonetimVerisi?
    @State private var hata: String?
    @State private var mesaj: (metin: String, hata: Bool)?
    @State private var bekliyor = false
    @State private var arama = ""
    @State private var soru: YonetimEkrani.Soru?

    var body: some View {
        YenilenebilirKaydirma(eylem: { await yukle() }) {
            VStack(spacing: 0) {
                Kahraman(baslik: "Tür kartları",
                         aciklama: "Fotoğraf, asgari av boyu ve yasak dönemi bilgilerini gir.")
                VStack(alignment: .leading, spacing: 14) {
                    if let m = mesaj {
                        Bildirim(metin: m.metin, hata: m.hata)
                    }
                    if let v = veri {
                        if !v.turler.isEmpty {
                            fotoBulKarti(v)
                        }
                        NavigationLink(destination: TurFormuEkrani(tur: nil, gruplar: v.gruplar,
                                                                   oneriler: v.kaynakOnerileri,
                                                                   kaydedildi: kaydedildi)) {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                Text("Tür ekle").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .foregroundColor(.white)
                            .background(Renk.lacivert)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        listeKarti(v)
                    } else if let h = hata {
                        UyariKutusu(tur: .bilgi, baslik: "Liste yüklenemedi.", metin: h)
                    } else {
                        HStack { Spacer(); ProgressView(); Spacer() }.padding(.top, 20)
                    }
                }
                .padding(16)
            }
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle("Tür kartları")
        .markaBasligi()
        .task { if veri == nil { await yukle() } }
        .alert(item: $soru) { s in
            Alert(title: Text(s.baslik),
                  primaryButton: .destructive(Text(s.dugme)) {
                      Task { await islem(s.islem, id: Int(s.alanlar["id"] ?? "") ?? 0) }
                  },
                  secondaryButton: .cancel(Text("Vazgeç")))
        }
    }

    private func fotoBulKarti(_ v: TurYonetimVerisi) -> some View {
        NavigationLink(destination: FotoBulEkrani(turler: v.turler.filter { $0.fotoUrl == nil },
                                                  bitti: { Task { await yukle(); await Eylemler.guncelle(oturum: oturum, depo: depo) } })) {
            HStack(spacing: 12) {
                KartSimgesi(sembol: "photo.on.rectangle.angled")
                VStack(alignment: .leading, spacing: 3) {
                    Text("Fotoğrafları otomatik bul")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Renk.murekkep)
                    Text(v.fotosuz > 0
                         ? "\(v.fotosuz) kartın fotoğrafı yok. Wikipedia / Wikimedia Commons'tan serbest lisanslı fotoğraflar bulunur."
                         : "Bütün kartların fotoğrafı var.")
                        .font(.caption)
                        .foregroundColor(Renk.soluk)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Renk.soluk)
            }
            .padding(16)
            .kart()
        }
        .buttonStyle(.plain)
    }

    private func listeKarti(_ v: TurYonetimVerisi) -> some View {
        let liste = TurYonetimKurallari.ara(v.turler, arama)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                KartSimgesi(sembol: "fish")
                Text("Kayıtlı türler").font(.headline).foregroundColor(Renk.murekkep)
                Spacer()
                Hap(metin: "\(v.turler.count)")
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(Renk.soluk)
                TextField("Tür adı, bilimsel ad veya grup ara", text: $arama)
                    .disableAutocorrection(true)
                    .foregroundColor(Renk.murekkep)
            }
            .padding(11)
            .background(Renk.ikincil)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Renk.cizgi, lineWidth: 1))

            if v.turler.isEmpty {
                Text("Henüz tür eklenmedi.").font(.footnote).foregroundColor(Renk.soluk)
            } else if liste.isEmpty {
                Text("Aramanızla eşleşen tür bulunamadı.").font(.footnote).foregroundColor(Renk.soluk)
            }
            LazyVStack(spacing: 8) {
                ForEach(liste) { t in
                    satir(t, v)
                }
            }
        }
        .padding(16)
        .kart()
    }

    private func satir(_ t: TurYonetimKaydi, _ v: TurYonetimVerisi) -> some View {
        HStack(alignment: .top, spacing: 12) {
            KucukFoto(url: t.fotoUrl)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(t.ad).font(.subheadline.weight(.semibold)).foregroundColor(Renk.murekkep)
                    if !t.aktif {
                        Hap(metin: "Gizli", renk: Renk.soluk, zemin: Renk.ikincil)
                    }
                }
                Text("\(t.grup) · Ticari: \(t.boyTicari.isEmpty ? "—" : t.boyTicari) · Amatör: \(t.boyAmator.isEmpty ? "—" : t.boyAmator)")
                    .font(.caption)
                    .foregroundColor(Renk.soluk)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    NavigationLink(destination: TurFormuEkrani(tur: t, gruplar: v.gruplar,
                                                               oneriler: v.kaynakOnerileri,
                                                               kaydedildi: kaydedildi)) {
                        kucukDugme("Düzenle", renk: Renk.mavi, zemin: Renk.tint)
                    }
                    .buttonStyle(.plain)
                    Button {
                        Task { await islem("gorunurluk", id: t.id) }
                    } label: {
                        kucukDugme(t.aktif ? "Gizle" : "Yayınla", renk: Renk.murekkep, zemin: Renk.kart)
                    }
                    .buttonStyle(.plain)
                    Button {
                        soru = YonetimEkrani.Soru(baslik: "\(t.ad) kartı ve fotoğrafı silinsin mi?",
                                                  dugme: "Sil", yikici: true, islem: "sil",
                                                  alanlar: ["id": String(t.id)])
                    } label: {
                        kucukDugme("Sil", renk: Renk.kirmizi, zemin: Renk.kirmiziZemin)
                    }
                    .buttonStyle(.plain)
                }
                .disabled(bekliyor)
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Renk.ikincil)
        .cornerRadius(12)
    }

    private func kucukDugme(_ metin: String, renk: Color, zemin: Color) -> some View {
        Text(metin)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundColor(renk)
            .background(zemin)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Renk.cizgi, lineWidth: zemin == Renk.kart ? 1 : 0))
    }

    private func kaydedildi(_ m: String) {
        mesaj = (m, false)
        Task {
            await yukle()
            await Eylemler.guncelle(oturum: oturum, depo: depo)
        }
    }

    private func yukle() async {
        guard let t = oturum.token else { return }
        do {
            veri = try await APIIstemci.turYonetimi(token: t)
            hata = nil
        } catch APIHatasi.yetkisiz(_) {
            Eylemler.cikis(oturum: oturum, depo: depo)
        } catch let e as APIHatasi {
            hata = e.aciklama
        } catch {
            hata = APIHatasi.baglanti.aciklama
        }
    }

    private func islem(_ ad: String, id: Int) async {
        guard let t = oturum.token, !bekliyor else { return }
        bekliyor = true
        defer { bekliyor = false }
        mesaj = nil
        do {
            mesaj = (try await APIIstemci.turIslem(ad, id: id, token: t), false)
            await yukle()
            await Eylemler.guncelle(oturum: oturum, depo: depo)
        } catch APIHatasi.yetkisiz(_) {
            Eylemler.cikis(oturum: oturum, depo: depo)
        } catch let e as APIHatasi {
            mesaj = (e.aciklama, true)
        } catch {
            mesaj = (APIHatasi.baglanti.aciklama, true)
        }
    }
}

/// Küçük kare fotoğraf (fotoğraf yoksa boş kutu).
struct KucukFoto: View {
    let url: String?
    var boyut: CGFloat = 56

    var body: some View {
        Group {
            if let s = url, let u = URL(string: s) {
                AsyncImage(url: u) { asama in
                    switch asama {
                    case .success(let r): r.resizable().scaledToFill()
                    default: Renk.tint
                    }
                }
            } else {
                ZStack {
                    Renk.tint
                    Image(systemName: "photo")
                        .foregroundColor(Renk.soluk)
                }
            }
        }
        .frame(width: boyut, height: boyut)
        .clipped()
        .cornerRadius(10)
    }
}

// MARK: - Ekle / düzenle

/// admin/turler.php formu.
struct TurFormuEkrani: View {
    let tur: TurYonetimKaydi?
    let gruplar: [String]
    let oneriler: [TurYonetimVerisi.Oneri]
    let kaydedildi: (String) -> Void

    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu
    @Environment(\.dismiss) private var geri

    @State private var ad = ""
    @State private var grup = "Balık"
    @State private var bilimselAd = ""
    @State private var digerAdlar = ""
    @State private var boyTicari = ""
    @State private var boyAmator = ""
    @State private var yasakDonemi = ""
    @State private var notlar = ""
    @State private var kaynak = ""
    @State private var kaynakUrl = ""
    @State private var aktif = true
    @State private var fotoSil = false
    @State private var yeniFoto: UIImage?
    @State private var fotoSecici = false
    @State private var hazir = false
    @State private var bekliyor = false
    @State private var hata: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let h = hata {
                    Bildirim(metin: h, hata: true)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Giris(etiket: "Tür adı") {
                        TextField("Ör. Hamsi", text: $ad).foregroundColor(Renk.murekkep)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Grup").font(.caption.weight(.semibold)).foregroundColor(Renk.soluk)
                        Picker("Grup", selection: $grup) {
                            ForEach(gruplar, id: \.self) { g in Text(g).tag(g) }
                        }
                        .pickerStyle(.menu)
                    }
                    Giris(etiket: "Bilimsel adı (isteğe bağlı)") {
                        TextField("Ör. Engraulis encrasicolus", text: $bilimselAd)
                            .disableAutocorrection(true)
                            .textInputAutocapitalization(.never)
                            .foregroundColor(Renk.murekkep)
                    }
                    Giris(etiket: "Diğer / yöresel adları (isteğe bağlı)") {
                        TextField("Aramada da kullanılır", text: $digerAdlar).foregroundColor(Renk.murekkep)
                    }
                    HStack(spacing: 10) {
                        Giris(etiket: "Asgari boy · Ticari") {
                            TextField("Ör. 9 cm", text: $boyTicari).foregroundColor(Renk.murekkep)
                        }
                        Giris(etiket: "Asgari boy · Amatör") {
                            TextField("Ör. 9 cm", text: $boyAmator).foregroundColor(Renk.murekkep)
                        }
                    }
                }
                .padding(16)
                .kart()

                VStack(alignment: .leading, spacing: 12) {
                    MetinAlani(etiket: "Yasak dönemi / bölgesi", metin: $yasakDonemi,
                               ipucu: "Tarih aralığı ve geçerli olduğu bölgeyi tebliğdeki gibi yaz.", enFazla: 2000)
                    MetinAlani(etiket: "Notlar (isteğe bağlı)", metin: $notlar,
                               ipucu: "Ör. avlanması tamamen yasak, miktar sınırı, ayırt edici özellikleri...", enFazla: 2000)
                    Giris(etiket: "Dayanak") {
                        TextField("Ör. 6/1 Tebliğ Ek-1", text: $kaynak).foregroundColor(Renk.murekkep)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Giris(etiket: "Resmî metin bağlantısı") {
                            HStack {
                                TextField("https://...", text: $kaynakUrl)
                                    .keyboardType(.URL)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                    .foregroundColor(Renk.murekkep)
                                Menu {
                                    ForEach(oneriler, id: \.url) { o in
                                        Button(o.ad) { kaynakUrl = o.url }
                                    }
                                } label: {
                                    Image(systemName: "list.bullet").foregroundColor(Renk.mavi)
                                }
                            }
                        }
                        Text("Sağdaki simgeden 6/1 ve 6/2 tebliğ bağlantıları seçilebilir.")
                            .font(.caption).foregroundColor(Renk.soluk)
                    }
                }
                .padding(16)
                .kart()

                fotoKarti

                Toggle("Personele görünsün", isOn: $aktif)
                    .font(.subheadline.weight(.semibold))
                    .tint(Renk.mavi)
                    .padding(16)
                    .kart()

                AnaDugme(baslik: tur == nil ? "Türü ekle" : "Değişiklikleri kaydet", bekliyor: bekliyor) {
                    kaydet()
                }
            }
            .padding(16)
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle(tur.map { $0.ad + " — düzenle" } ?? "Tür ekle")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $fotoSecici) {
            FotoSecici { r in
                yeniFoto = r
                fotoSil = false
            }
        }
        .onAppear {
            guard !hazir else { return }
            hazir = true
            if let t = tur {
                ad = t.ad
                grup = gruplar.contains(t.grup) ? t.grup : "Diğer"
                bilimselAd = t.bilimselAd
                digerAdlar = t.digerAdlar
                boyTicari = t.boyTicari
                boyAmator = t.boyAmator
                yasakDonemi = t.yasakDonemi
                notlar = t.notlar
                kaynak = t.kaynak
                kaynakUrl = t.kaynakUrl
                aktif = t.aktif
            } else if let ilk = gruplar.first {
                grup = ilk
            }
        }
    }

    private var fotoKarti: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fotoğraf").font(.caption.weight(.semibold)).foregroundColor(Renk.soluk)
            HStack(spacing: 12) {
                if let r = yeniFoto {
                    Image(uiImage: r)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipped()
                        .cornerRadius(10)
                } else {
                    KucukFoto(url: fotoSil ? nil : tur?.fotoUrl, boyut: 72)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        fotoSecici = true
                    } label: {
                        Label(yeniFoto == nil ? "Fotoğraf seç" : "Başka fotoğraf seç", systemImage: "photo")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Renk.mavi)
                    }
                    if yeniFoto != nil {
                        Button("Seçimi kaldır") { yeniFoto = nil }
                            .font(.footnote)
                            .foregroundColor(Renk.kirmizi)
                    } else if tur?.fotoUrl != nil {
                        Toggle("Mevcut fotoğrafı kaldır", isOn: $fotoSil)
                            .font(.footnote)
                            .tint(Renk.kirmizi)
                    }
                }
            }
            if let k = tur?.fotoKredi, !k.isEmpty, yeniFoto == nil, !fotoSil {
                Text("Otomatik bulunan fotoğraf: " + k)
                    .font(.caption).foregroundColor(Renk.soluk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("JPG, PNG veya WEBP, en fazla 8 MB. Kendi çektiğin ya da kullanım izni olan fotoğrafları yükle. Konum bilgisi otomatik silinir.")
                .font(.caption).foregroundColor(Renk.soluk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .kart()
    }

    private func kaydet() {
        guard let t = oturum.token, !bekliyor else { return }
        hata = nil
        bekliyor = true
        var alanlar: [String: String] = [
            "id": String(tur?.id ?? 0), "ad": ad, "grup": grup, "bilimsel_ad": bilimselAd,
            "diger_adlar": digerAdlar, "boy_ticari": boyTicari, "boy_amator": boyAmator,
            "yasak_donemi": yasakDonemi, "notlar": notlar, "kaynak": kaynak, "kaynak_url": kaynakUrl,
            "aktif": aktif ? "1" : "0",
        ]
        if fotoSil && yeniFoto == nil {
            alanlar["foto_sil"] = "1"
        }
        let veri = yeniFoto.flatMap { TurYonetimKurallari.yuklenecekFoto($0) }
        Task {
            do {
                let m = try await APIIstemci.turKaydet(alanlar: alanlar, foto: veri, token: t)
                bekliyor = false
                kaydedildi(m)
                geri()
            } catch APIHatasi.yetkisiz(_) {
                Eylemler.cikis(oturum: oturum, depo: depo)
            } catch let e as APIHatasi {
                hata = e.aciklama
            } catch {
                hata = APIHatasi.baglanti.aciklama
            }
            bekliyor = false
        }
    }
}

/// Çok satırlı metin alanı (etiket + ipucu + karakter sınırı).
struct MetinAlani: View {
    let etiket: String
    @Binding var metin: String
    let ipucu: String
    let enFazla: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(etiket).font(.caption.weight(.semibold)).foregroundColor(Renk.soluk)
            ZStack(alignment: .topLeading) {
                if metin.isEmpty {
                    Text(ipucu)
                        .foregroundColor(Renk.soluk.opacity(0.8))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $metin)
                    .saydamMetinKutusu()
                    .frame(minHeight: 90)
                    .foregroundColor(Renk.murekkep)
                    .onChange(of: metin) { y in if y.count > enFazla { metin = String(y.prefix(enFazla)) } }
            }
            .padding(7)
            .background(Renk.ikincil)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Renk.cizgi, lineWidth: 1))
        }
    }
}

// MARK: - Fotoğrafları otomatik bul (admin/fotobul.php)

struct FotoBulEkrani: View {
    let turler: [TurYonetimKaydi]
    let bitti: () -> Void

    @EnvironmentObject var oturum: Oturum
    @State private var calisiyor = false
    @State private var durdur = false
    @State private var sira = 0
    @State private var bulunan = 0
    @State private var bulunamayan = 0
    @State private var durumYazisi = ""
    @State private var sonuclar: [(ad: String, metin: String, tamam: Bool)] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        KartSimgesi(sembol: "photo.on.rectangle.angled")
                        Text("Fotoğrafsız kartlar").font(.headline).foregroundColor(Renk.murekkep)
                        Spacer()
                        Hap(metin: "\(max(0, turler.count - bulunan))")
                    }
                    if turler.isEmpty {
                        Text("Bütün kartların fotoğrafı var.").font(.footnote).foregroundColor(Renk.soluk)
                    } else {
                        Text("Her kart için bilimsel adıyla Wikipedia'da arama yapılır ve sayfanın serbest lisanslı ana fotoğrafı sunucuya indirilir. Fotoğrafın sahibi ve lisansı kartın köşesinde yazılır. Elle eklediğin fotoğraflara dokunulmaz. Bulunan fotoğraflar sonradan kartı düzenleyerek değiştirilebilir.")
                            .font(.caption).foregroundColor(Renk.soluk)
                            .fixedSize(horizontal: false, vertical: true)
                        ProgressView(value: turler.isEmpty ? 0 : Double(sira) / Double(turler.count))
                            .tint(Renk.lacivert)
                        Text(durumYazisi.isEmpty
                             ? "Hazır. \(turler.count) kart işlenecek (kart başına birkaç saniye). Yarıda kalırsa ya da bazıları bulunamazsa tekrar çalıştırabilirsin; yalnızca fotoğrafsız kartlar denenir."
                             : durumYazisi)
                            .font(.caption).foregroundColor(Renk.soluk)
                            .fixedSize(horizontal: false, vertical: true)
                        if calisiyor {
                            Button {
                                durdur = true
                            } label: {
                                Text("Durdur")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .foregroundColor(Renk.mavi)
                                    .background(Renk.tint)
                                    .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        } else if sira == 0 {
                            AnaDugme(baslik: "Fotoğrafları bul", bekliyor: false) { baslat() }
                        }
                    }
                }
                .padding(16)
                .kart()

                if !sonuclar.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            KartSimgesi(sembol: "checklist")
                            Text("Sonuçlar").font(.headline).foregroundColor(Renk.murekkep)
                            Spacer()
                            Hap(metin: "\(bulunan)")
                        }
                        ForEach(Array(sonuclar.enumerated()), id: \.offset) { _, s in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.ad).font(.subheadline.weight(.semibold)).foregroundColor(Renk.murekkep)
                                Text(s.metin)
                                    .font(.caption)
                                    .foregroundColor(s.tamam ? Renk.yesil : Renk.soluk)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(16)
                    .kart()
                }
            }
            .padding(16)
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle("Fotoğrafları otomatik bul")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { durdur = true }
    }

    private func baslat() {
        guard let t = oturum.token, !calisiyor else { return }
        calisiyor = true
        durdur = false
        let liste = turler
        Task {
            for (i, tur) in liste.enumerated() {
                if durdur { break }
                durumYazisi = "\(i + 1) / \(liste.count) · \(tur.ad) aranıyor…"
                let satir: (ad: String, metin: String, tamam: Bool)
                do {
                    let r = try await APIIstemci.turFotoBul(id: tur.id, token: t)
                    switch r.durum {
                    case "bulundu":
                        bulunan += 1
                        satir = (tur.ad, "✓ \(r.aranan) · \(r.kredi)", true)
                    case "var":
                        satir = (tur.ad, "Zaten fotoğrafı var", false)
                    default:
                        bulunamayan += 1
                        satir = (tur.ad, "✗ " + (r.mesaj.isEmpty ? "Bulunamadı." : r.mesaj), false)
                    }
                } catch let e as APIHatasi {
                    bulunamayan += 1
                    satir = (tur.ad, "✗ " + e.aciklama, false)
                } catch {
                    bulunamayan += 1
                    satir = (tur.ad, "✗ Bağlantı hatası", false)
                }
                sonuclar.insert(satir, at: 0)
                sira = i + 1
                // Wikimedia'yı yormamak için kartlar arasında kısa bekleme (sitedeki gibi)
                if i + 1 < liste.count && !durdur {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                }
            }
            if durdur {
                durumYazisi = "Durduruldu. \(bulunan) karta fotoğraf eklendi. Kaldığı yerden devam etmek için sayfayı kapatıp tekrar başlat."
            } else {
                durumYazisi = "Bitti. \(bulunan) karta fotoğraf eklendi"
                    + (bulunamayan > 0 ? ", \(bulunamayan) kart için bulunamadı (elle eklenebilir)." : ".")
            }
            calisiyor = false
            bitti()
        }
    }
}
