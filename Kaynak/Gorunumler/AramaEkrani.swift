import SwiftUI

/// mevzuat.php — Mevzuat arama sayfasının karşılığı.
struct AramaEkrani: View {
    @EnvironmentObject var depo: VeriDeposu
    @State private var sorgu = ""
    @State private var filtre: AramaFiltresi = .tumu
    @State private var sonuclar: [AramaKaydi] = []
    @State private var aramaGorevi: Task<Void, Never>?

    private let ornekler = ["can yeleği", "ruhsat", "trol", "gırgır", "zıpkın", "boğaz"]

    var body: some View {
        YenilenebilirKaydirma {
            VStack(spacing: 0) {
                Kahraman(baslik: "Mevzuat arama",
                         aciklama: "Karşılaştığın konuya göre ilgili fiili, maddeyi ve mevzuat açıklamasını hızlıca bul.") {
                    AramaKutusu(ipucu: "Can yeleği, ruhsat, ADB, trol...", metin: $sorgu)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(AramaFiltresi.allCases) { f in
                                Button {
                                    filtre = f
                                } label: {
                                    Text(f.baslik)
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .foregroundColor(filtre == f ? Renk.lacivert : .white)
                                        .background(filtre == f ? Color.white : Color.white.opacity(0.14))
                                        .cornerRadius(999)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 4)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    sonucBolumu
                    hizliErisim
                    ResmiKaynakListesi(liste: depo.kaynakListesi)
                }
                .padding(16)
            }
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle("Mevzuat Rehberi")
        .markaBasligi()
        .onChange(of: sorgu) { _ in aramayiPlanla() }
    }

    private var gosterilen: [AramaKaydi] {
        return sonuclar.filter { filtre.uygun($0) }
    }

    private func aramayiPlanla() {
        aramaGorevi?.cancel()
        let q = sorgu
        aramaGorevi = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled { return }
            sonuclar = depo.motor.ara(q)
        }
    }

    @ViewBuilder
    private var sonucBolumu: some View {
        let q = sorgu.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.count < 2 {
            VStack(alignment: .leading, spacing: 10) {
                Text("Soru yerine anahtar kelime yazın.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Renk.murekkep)
                Text("Örneğin \"boğazda avcılık yasak mı\" yerine \"boğaz\" yazın.")
                    .font(.footnote)
                    .foregroundColor(Renk.soluk)
                OrnekKelimeler(kelimeler: ornekler) { sorgu = $0 }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .kart()
        } else {
            let liste = gosterilen
            HStack(spacing: 12) {
                Image(systemName: "book")
                    .foregroundColor(Renk.mavi)
                    .frame(width: 36, height: 36)
                    .background(Renk.tint)
                    .cornerRadius(10)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(liste.count) sonuç bulundu.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Renk.murekkep)
                    Text("Aradığınız konuya ilişkin eşleşen fiiller aşağıda listelenmiştir.")
                        .font(.caption)
                        .foregroundColor(Renk.soluk)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .kart()

            if liste.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Bu arama için uygun bir fiil bulunamadı.")
                        .font(.subheadline)
                        .foregroundColor(Renk.murekkep)
                    Text("Soru yerine anahtar kelime yazın:")
                        .font(.footnote)
                        .foregroundColor(Renk.soluk)
                    OrnekKelimeler(kelimeler: ornekler) { sorgu = $0 }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .kart()
            } else {
                ForEach(liste) { k in
                    SonucKarti(kayit: k, kaynaklar: depo.kaynakListesi)
                }
            }
        }
    }

    private var hizliErisim: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hızlı erişim")
                .font(.headline)
                .foregroundColor(Renk.murekkep)
                .padding(.top, 6)
            NavigationLink(destination: TekneEkrani()) {
                HizliKart(sembol: "ferry", baslik: "Tekne / Gemi Kontrolü",
                          aciklama: "Belge, ekipman, fiziki durum ve diğer kontroller")
            }
            NavigationLink(destination: YaptirimEkrani()) {
                HizliKart(sembol: "scalemass", baslik: "1380 İDARİ YAPTIRIM REHBERİ",
                          aciklama: "2026 yılı su ürünleri idari yaptırım bilgilerini hızlıca bul")
            }
            NavigationLink(destination: SevkEkrani()) {
                HizliKart(sembol: "doc.text", baslik: "SEVK İŞLEMLERİ",
                          aciklama: "Tespit sonrası ceza, ruhsat/tezkere, teslim-muhafaza ve adli işlem süreçlerini değerlendir")
            }
            NavigationLink(destination: BolgeEkrani()) {
                HizliKart(sembol: "map", baslik: "Türkiye Geneli Bölge Yasakları",
                          aciklama: "Deniz bölgelerine göre yasak ve kısıtlamaları görüntüle")
            }
        }
        .buttonStyle(.plain)
    }
}

struct HizliKart: View {
    let sembol: String
    let baslik: String
    let aciklama: String

    var body: some View {
        HStack(spacing: 12) {
            Sembol(ad: sembol, yedek: "doc.text")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Renk.mavi)
                .frame(width: 40, height: 40)
                .background(Renk.tint)
                .cornerRadius(12)
            VStack(alignment: .leading, spacing: 3) {
                Text(baslik)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Renk.murekkep)
                    .multilineTextAlignment(.leading)
                Text(aciklama)
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
        .padding(14)
        .kart()
    }
}

struct OrnekKelimeler: View {
    let kelimeler: [String]
    let sec: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(kelimeler, id: \.self) { k in
                    Button {
                        sec(k)
                    } label: {
                        Text(k)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundColor(Renk.mavi)
                            .background(Renk.tint)
                            .cornerRadius(999)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Arama sonucu kartı (mevzuat.php result-card).
struct SonucKarti: View {
    let kayit: AramaKaydi
    let kaynaklar: KaynakListesi
    @State private var acik = false

    private var madde: String { AramaGosterim.maddeMetni(kayit.madde) }

    private var etiket: String {
        if kayit.sevkMi {
            return kayit.etiket.isEmpty ? AramaGosterim.kanunKisa(kayit.mevzuat) : kayit.etiket
        }
        return kayit.mevzuat.isEmpty ? "" : AramaGosterim.kanunKisa(kayit.mevzuat)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { acik.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "doc.text")
                        .foregroundColor(Renk.mavi)
                        .frame(width: 34, height: 34)
                        .background(Renk.tint)
                        .cornerRadius(10)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(kayit.fiil)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Renk.murekkep)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            if !etiket.isEmpty { Hap(metin: etiket) }
                            if !madde.isEmpty {
                                Hap(metin: "Madde " + madde + (kayit.bent.isEmpty ? "" : " · " + kayit.bent),
                                    renk: Renk.soluk, zemin: Renk.ikincil)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(acik ? 180 : 0))
                        .foregroundColor(Renk.soluk)
                        .padding(.top, 8)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if acik {
                VStack(alignment: .leading, spacing: 12) {
                    AcilirBolum(sembol: "book", baslik: "Mevzuat dayanağını göster",
                                altBaslik: "Mevzuat açıklaması ve madde bilgisini görüntüle") {
                        if kayit.sevkMi {
                            SevkDayanaklari(dayanaklar: kayit.dayanaklar.isEmpty && !kayit.mevzuat.isEmpty
                                                ? [kayit.mevzuat] : kayit.dayanaklar,
                                            kaynaklar: kaynaklar, aciklamaBasligi: "Ne anlatıyor?")
                        } else {
                            DayanakBlogu(baslik: kayit.mevzuat.isEmpty ? "Mevzuat bilgisi bulunamadı." : kayit.mevzuat,
                                         madde: madde, bent: kayit.bent,
                                         kaynak: kaynaklar.bul(mevzuat: kayit.mevzuat, kaynak: kayit.kaynakMetni, madde: kayit.madde))
                            AciklamaBlogu(baslik: "Mevzuat açıklaması",
                                          metin: kayit.aciklama.isEmpty ? "Açıklama bulunmuyor." : kayit.aciklama)
                        }
                        UyariKutusu(tur: .bilgi, baslik: "Kontrol gerekli:",
                                    metin: "Güncel mevzuat, madde/fiil eşleştirmesi, yetki ve sevk makamı işlem tesis edilmeden önce ayrıca doğrulanmalıdır.")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .kart(vurgulu: acik)
    }
}

/// "Mevzuat dayanağı" bloğu.
struct DayanakBlogu: View {
    let baslik: String
    var madde: String = ""
    var bent: String = ""
    let kaynak: ResmiKaynak

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Mevzuat dayanağı", systemImage: "book")
                .font(.caption.weight(.semibold))
                .foregroundColor(Renk.soluk)
            Text(baslik)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Renk.murekkep)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if !madde.isEmpty || !bent.isEmpty {
                HStack(spacing: 6) {
                    if !madde.isEmpty { Hap(metin: "Madde " + madde) }
                    if !bent.isEmpty { Hap(metin: bent, renk: Renk.soluk, zemin: Renk.ikincil) }
                }
            }
            ResmiKaynakSatiri(kaynak: kaynak)
        }
    }
}

/// "Ne anlatıyor?" / "Mevzuat açıklaması" kutusu.
struct AciklamaBlogu: View {
    let baslik: String
    let metin: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(baslik, systemImage: "doc.plaintext")
                .font(.caption.weight(.semibold))
                .foregroundColor(Renk.soluk)
            Text(metin)
                .font(.footnote)
                .foregroundColor(Renk.murekkep)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Renk.ikincil)
        .cornerRadius(12)
    }
}

/// Sevk kaynaklı dayanak listesi: doğrulanmış 1380 maddeleri için açıklama, diğerlerinde temkinli genel metin.
struct SevkDayanaklari: View {
    let dayanaklar: [String]
    let kaynaklar: KaynakListesi
    var aciklamaBasligi = "Ne anlatıyor?"

    var body: some View {
        if dayanaklar.isEmpty {
            Text("Bu kayıtta mevzuat dayanağı belirtilmemiş.")
                .font(.footnote)
                .foregroundColor(Renk.soluk)
        } else {
            ForEach(Array(dayanaklar.enumerated()), id: \.offset) { _, d in
                let bilgi = kaynaklar.dogrulanmis1380(d)
                VStack(alignment: .leading, spacing: 10) {
                    DayanakBlogu(baslik: bilgi?.title ?? d,
                                 kaynak: kaynaklar.bul(mevzuat: bilgi != nil ? "1380 sayılı Su Ürünleri Kanunu" : d))
                    AciklamaBlogu(baslik: aciklamaBasligi, metin: bilgi?.explain ?? kaynaklar.genelAciklama)
                }
            }
        }
    }
}
