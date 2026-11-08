import SwiftUI

/// sevk_islemleri.php — Sevk işlemleri sayfasının karşılığı.
struct SevkEkrani: View {
    @EnvironmentObject var depo: VeriDeposu
    @State private var sorgu = ""

    var body: some View {
        let q = sorgu.trimmingCharacters(in: .whitespacesAndNewlines)
        let sonuc: [SevkKaydi] = q.isEmpty ? [] : depo.sevkler.filter { TRMetin.kelimeEslesir(normalMetin: $0.aramaNormal, sorgu: q) }
        YenilenebilirKaydirma {
            VStack(spacing: 0) {
                Kahraman(baslik: "Sevk işlemleri",
                         aciklama: "İhlal, işlem, mevzuat, madde, kaynak veya sevk makamına göre ara.") {
                    AramaKutusu(ipucu: "Örn. Zıpkın,ruhsat..", metin: $sorgu)
                    HStack {
                        if !q.isEmpty {
                            Text("\(sonuc.count) sonuç")
                        }
                        Spacer()
                        Text("\(depo.sevkler.count) toplam kayıt")
                    }
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 2)
                }

                LazyVStack(alignment: .leading, spacing: 12) {
                    guvenlikUyarisi

                    if !q.isEmpty {
                        if sonuc.isEmpty {
                            VStack(spacing: 6) {
                                Text("Sonuç bulunamadı")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Renk.murekkep)
                                Text("Farklı bir kelime, kaynak veya sevk makamı deneyin.")
                                    .font(.footnote)
                                    .foregroundColor(Renk.soluk)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .kart()
                        } else {
                            ForEach(sonuc) { x in
                                SevkKarti(kayit: x, kaynaklar: depo.kaynakListesi)
                            }
                        }
                    }

                    ResmiKaynakListesi(liste: depo.kaynakListesi)
                        .padding(.top, 8)
                }
                .padding(16)
            }
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle("Mevzuat Rehberi")
        .markaBasligi()
    }

    private var guvenlikUyarisi: some View {
        let a = Text("Bu bölüm ")
        let b = Text("mevzuata erişim ve referans amacıyla").bold()
        let c = Text(" hazırlanmıştır. Bazı kayıtlar geçmiş düzenlemelere veya kaynak sevk kayıtlarına dayanabilir. İşlem tesis edilmeden önce ")
        let d = Text("yürürlükteki güncel mevzuatın ve yetkili resmî kaynakların kontrol edilmesi gerekir.").bold()
        let e = Text(" Bu içerik ")
        let f = Text("resmî talimat, emir veya bağlayıcı hukuki görüş niteliğinde değildir.").bold()
        let ilk: Text = a + b + c
        let metin: Text = ilk + d + e + f
        return VStack(alignment: .leading, spacing: 8) {
            Label("Mevzuat referans uyarısı", systemImage: "exclamationmark.shield")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Renk.amber)
            metin
                .font(.footnote)
                .foregroundColor(Renk.murekkep)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Renk.amberZemin)
        .cornerRadius(14)
    }
}

/// Sevk kaydı kartı (sevk_islemleri.php card).
struct SevkKarti: View {
    let kayit: SevkKaydi
    let kaynaklar: KaynakListesi
    @State private var acik = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { acik.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(kayit.gerekce)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Renk.murekkep)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        EtiketSatiri(kategori: kayit.kategori, sevkMakami: kayit.sevkMakami)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(acik ? 180 : 0))
                        .foregroundColor(Renk.soluk)
                        .padding(.top, 4)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if acik {
                VStack(alignment: .leading, spacing: 10) {
                    AcilirBolum(sembol: "book", baslik: "Mevzuat dayanağını göster") {
                        Text("Bu kayıt hangi mevzuata dayandırılmış?")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Renk.soluk)
                        SevkDayanaklari(dayanaklar: kayit.tekDayanak, kaynaklar: kaynaklar)
                        UyariKutusu(tur: .bilgi, baslik: "Kontrol gerekli:",
                                    metin: "Bu kayıt kaynak bilgisine dayanmaktadır. Güncel mevzuat, madde/fiil eşleştirmesi, yetki ve sevk makamı işlem tesis edilmeden önce ayrıca doğrulanmalıdır.")
                    }
                    AcilirBolum(sembol: "mappin.and.ellipse", baslik: "İşlem / sevk bilgisini göster") {
                        islemBilgisi
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .kart(vurgulu: acik)
    }

    @ViewBuilder
    private var islemBilgisi: some View {
        if kayit.durum == "red" {
            Text("İşlem ve sevk bilgisi")
                .font(.footnote.weight(.semibold))
                .foregroundColor(Renk.soluk)
            IslemSatiri(baslik: "Sevk yeri / makamı", metin: kayit.sevkMakami ?? "Kaynak kaydında belirtilmemiş.")
        } else {
            Text("Bu kayıtta kaynak olarak bulunan işlem ve sevk bilgileri")
                .font(.footnote.weight(.semibold))
                .foregroundColor(Renk.soluk)
            if let m = kayit.sevkMakami {
                IslemSatiri(baslik: "Kaynak kaydındaki sevk makamı", metin: m)
            } else {
                IslemSatiri(baslik: "Sevk makamı", metin: "Kaynak kaydında belirtilmemiş.")
            }
            // Otomatik eklenmiş işlem/yaptırım notları doğrulanmamış madde kısaltmaları içerdiği için
            // kartta gösterilmez; yalnızca sevk makamı (sevk_islemleri.php, 8 Kasım 2026). Aramada kullanılır.
        }
        UyariKutusu(tur: .dikkat, baslik: "Dikkat:",
                    metin: "Bu sevk yeri/makamı mevcut kaynak kaydından alınmıştır. Güncel mevzuat, yetki ve somut olay koşulları doğrulanmadan kesin sevk talimatı olarak kabul edilmemelidir.")
    }
}

struct EtiketSatiri: View {
    let kategori: String
    let sevkMakami: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !kategori.isEmpty {
                Hap(metin: kategori)
            }
            if let m = sevkMakami {
                Hap(metin: "Sevk: " + m, renk: Renk.yesil, zemin: Renk.yesilZemin)
            }
        }
    }
}

struct IslemSatiri: View {
    let baslik: String
    let metin: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(baslik)
                .font(.caption.weight(.semibold))
                .foregroundColor(Renk.soluk)
            Text(metin)
                .font(.footnote)
                .foregroundColor(Renk.murekkep)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Renk.ikincil)
        .cornerRadius(10)
    }
}
