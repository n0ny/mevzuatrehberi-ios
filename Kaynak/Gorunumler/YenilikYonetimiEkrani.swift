import SwiftUI

// MARK: - Veri (api/yonetim-yenilikler.php — sitedeki admin/yenilikler.php ile aynı)

struct YenilikYonetimVerisi: Codable {
    let bugun: String
    let kategoriler: [String]
    let kayitlar: [YenilikYonetimKaydi]
}

struct YenilikYonetimKaydi: Codable, Identifiable {
    let id: Int
    let baslik: String
    let aciklama: String
    let kategori: String
    let tarih: String
    let tarihYazi: String
    let link: String
    let aktif: Bool
    let durum: String
    let durumTuru: String
    let bildirim: String?
}

// MARK: - Liste

/// admin/yenilikler.php — Yenilikler yönetimi.
struct YenilikYonetimiEkrani: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu

    @State private var veri: YenilikYonetimVerisi?
    @State private var hata: String?
    @State private var mesaj: (metin: String, hata: Bool)?
    @State private var bekliyor = false
    @State private var soru: YonetimEkrani.Soru?

    var body: some View {
        YenilenebilirKaydirma(eylem: { await yukle() }) {
            VStack(spacing: 0) {
                Kahraman(baslik: "Yenilikler",
                         aciklama: "Eklenen mevzuatı ve yenilikleri personele duyur.")
                VStack(alignment: .leading, spacing: 14) {
                    if let m = mesaj {
                        Bildirim(metin: m.metin, hata: m.hata)
                    }
                    if let v = veri {
                        NavigationLink(destination: YenilikFormuEkrani(kayit: nil, kategoriler: v.kategoriler,
                                                                       bugun: v.bugun, sonuc: sonuc)) {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                Text("Yenilik ekle").fontWeight(.semibold)
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
                        UyariKutusu(tur: .bilgi, baslik: "Kayıtlar yüklenemedi.", metin: h)
                    } else {
                        HStack { Spacer(); ProgressView(); Spacer() }.padding(.top, 20)
                    }
                }
                .padding(16)
            }
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle("Yenilikler")
        .markaBasligi()
        .task { if veri == nil { await yukle() } }
        .alert(item: $soru) { s in
            Alert(title: Text(s.baslik),
                  primaryButton: .destructive(Text(s.dugme)) { Task { await islem(s.islem, s.alanlar) } },
                  secondaryButton: .cancel(Text("Vazgeç")))
        }
    }

    private func listeKarti(_ v: YenilikYonetimVerisi) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                KartSimgesi(sembol: "text.bubble")
                Text("Kayıtlar").font(.headline).foregroundColor(Renk.murekkep)
                Spacer()
                Hap(metin: "\(v.kayitlar.count)")
            }
            if v.kayitlar.isEmpty {
                Text("Henüz yenilik eklenmedi.").font(.footnote).foregroundColor(Renk.soluk)
            }
            ForEach(v.kayitlar) { k in
                VStack(alignment: .leading, spacing: 6) {
                    Text(k.baslik)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Renk.murekkep)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(k.tarihYazi) · \(k.kategori)" + (k.bildirim.map { " · Bildirim: " + $0 } ?? ""))
                        .font(.caption)
                        .foregroundColor(Renk.soluk)
                        .fixedSize(horizontal: false, vertical: true)
                    durumHapi(k)
                    HStack(spacing: 8) {
                        NavigationLink(destination: YenilikFormuEkrani(kayit: k, kategoriler: v.kategoriler,
                                                                       bugun: v.bugun, sonuc: sonuc)) {
                            kucukDugme("Düzenle", Renk.mavi, Renk.tint)
                        }
                        .buttonStyle(.plain)
                        Button {
                            Task { await islem("gorunurluk", ["id": String(k.id)]) }
                        } label: {
                            kucukDugme(k.aktif ? "Gizle" : "Yayınla", Renk.murekkep, Renk.kart)
                        }
                        .buttonStyle(.plain)
                        Button {
                            soru = YonetimEkrani.Soru(baslik: "Bu yenilik kalıcı olarak silinsin mi?",
                                                      dugme: "Sil", yikici: true, islem: "sil",
                                                      alanlar: ["id": String(k.id)])
                        } label: {
                            kucukDugme("Sil", Renk.kirmizi, Renk.kirmiziZemin)
                        }
                        .buttonStyle(.plain)
                    }
                    .disabled(bekliyor)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Renk.ikincil)
                .cornerRadius(12)
            }
        }
        .padding(16)
        .kart()
    }

    @ViewBuilder
    private func durumHapi(_ k: YenilikYonetimKaydi) -> some View {
        switch k.durumTuru {
        case "yayinda": Hap(metin: k.durum, renk: Renk.yesil, zemin: Renk.yesilZemin)
        case "ileri": Hap(metin: k.durum, renk: Renk.amber, zemin: Renk.amberZemin)
        default: Hap(metin: k.durum, renk: Renk.soluk, zemin: Renk.kart)
        }
    }

    private func kucukDugme(_ metin: String, _ renk: Color, _ zemin: Color) -> some View {
        Text(metin)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundColor(renk)
            .background(zemin)
            .cornerRadius(8)
    }

    /// Formdan dönen sonuç (kayıt yapılmış olabilir; bildirim uyarısı hata olarak gelebilir).
    private func sonuc(_ m: String, _ hataMi: Bool) {
        mesaj = (m, hataMi)
        Task {
            await yukle()
            await Eylemler.guncelle(oturum: oturum, depo: depo)
        }
    }

    private func yukle() async {
        guard let t = oturum.token else { return }
        do {
            veri = try await APIIstemci.yenilikYonetimi(token: t)
            hata = nil
        } catch APIHatasi.yetkisiz(_) {
            Eylemler.cikis(oturum: oturum, depo: depo)
        } catch let e as APIHatasi {
            hata = e.aciklama
        } catch {
            hata = APIHatasi.baglanti.aciklama
        }
    }

    private func islem(_ ad: String, _ alanlar: [String: String]) async {
        guard let t = oturum.token, !bekliyor else { return }
        bekliyor = true
        defer { bekliyor = false }
        mesaj = nil
        do {
            mesaj = (try await APIIstemci.yenilikIslem(ad, alanlar: alanlar, token: t), false)
        } catch APIHatasi.yetkisiz(_) {
            Eylemler.cikis(oturum: oturum, depo: depo)
            return
        } catch let e as APIHatasi {
            mesaj = (e.aciklama, true)
        } catch {
            mesaj = (APIHatasi.baglanti.aciklama, true)
        }
        await yukle()
        await Eylemler.guncelle(oturum: oturum, depo: depo)
    }
}

// MARK: - Ekle / düzenle

/// admin/yenilikler.php formu.
struct YenilikFormuEkrani: View {
    let kayit: YenilikYonetimKaydi?
    let kategoriler: [String]
    let bugun: String
    let sonuc: (String, Bool) -> Void

    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu
    @Environment(\.dismiss) private var geri

    @State private var baslik = ""
    @State private var kategori = "Mevzuat"
    @State private var tarih = Date()
    @State private var aciklama = ""
    @State private var link = ""
    @State private var aktif = true
    @State private var bildirim = false
    @State private var bildirimSorusu = false
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
                    Giris(etiket: "Başlık") {
                        TextField("Ör. 2026 idari yaptırım tutarları eklendi", text: $baslik)
                            .foregroundColor(Renk.murekkep)
                            .onChange(of: baslik) { y in if y.count > 150 { baslik = String(y.prefix(150)) } }
                    }
                    HStack(alignment: .bottom, spacing: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Kategori").font(.caption.weight(.semibold)).foregroundColor(Renk.soluk)
                            Picker("Kategori", selection: $kategori) {
                                ForEach(kategoriler, id: \.self) { k in Text(k).tag(k) }
                            }
                            .pickerStyle(.menu)
                        }
                        Spacer()
                        DatePicker("Tarih", selection: $tarih, displayedComponents: .date)
                            .font(.subheadline)
                            .fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        MetinAlani(etiket: "Açıklama", metin: $aciklama,
                                   ipucu: "Ne eklendi / ne değişti? Personel nerede bulacak?\n- Madde 1\n- Madde 2",
                                   enFazla: 3000)
                        Text("Satırı \"- \" ile başlatırsan maddeli liste olur. Uzun metinler personel sayfasında 3 satır görünür, \"Devamını oku\" ile açılır.")
                            .font(.caption).foregroundColor(Renk.soluk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Giris(etiket: "Bağlantı (isteğe bağlı)") {
                            TextField("idari_yaptirim.php ya da https://www.resmigazete.gov.tr/...", text: $link)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .foregroundColor(Renk.murekkep)
                        }
                        Text("Uygulama içi sayfa adı ya da resmî kaynak adresi yazabilirsin.")
                            .font(.caption).foregroundColor(Renk.soluk)
                    }
                }
                .padding(16)
                .kart()

                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Personele görünsün", isOn: $aktif)
                        .font(.subheadline.weight(.semibold))
                        .tint(Renk.mavi)
                    Toggle("Kaydederken tüm personele bildirim de gönder", isOn: $bildirim)
                        .font(.subheadline.weight(.semibold))
                        .tint(Renk.mavi)
                    if bildirim {
                        Text("Bildirim şimdilik yalnızca Android telefonlara ulaşır.")
                            .font(.caption).foregroundColor(Renk.amber)
                    }
                }
                .padding(16)
                .kart()

                AnaDugme(baslik: kayit == nil ? "Yeniliği ekle" : "Değişiklikleri kaydet", bekliyor: bekliyor) {
                    if bildirim {
                        bildirimSorusu = true
                    } else {
                        kaydet()
                    }
                }
            }
            .padding(16)
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle(kayit == nil ? "Yenilik ekle" : "Yeniliği düzenle")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Kayıt edilecek ve tüm personele bildirim gönderilecek. Devam edilsin mi?", isPresented: $bildirimSorusu) {
            Button("Devam") { kaydet() }
            Button("Vazgeç", role: .cancel) {}
        }
        .onAppear {
            guard !hazir else { return }
            hazir = true
            if let k = kayit {
                baslik = k.baslik
                kategori = k.kategori
                tarih = GunBicimi.tarih(k.tarih)
                aciklama = k.aciklama
                link = k.link
                aktif = k.aktif
            } else {
                kategori = kategoriler.first ?? "Mevzuat"
                tarih = GunBicimi.tarih(bugun)
            }
        }
    }

    private func kaydet() {
        guard let t = oturum.token, !bekliyor else { return }
        hata = nil
        bekliyor = true
        let alanlar: [String: String] = [
            "id": String(kayit?.id ?? 0), "baslik": baslik, "aciklama": aciklama, "kategori": kategori,
            "tarih": GunBicimi.metin(tarih), "link": link,
            "aktif": aktif ? "1" : "0", "bildirim": bildirim ? "1" : "0",
        ]
        Task {
            do {
                let m = try await APIIstemci.yenilikIslem("kaydet", alanlar: alanlar, token: t)
                bekliyor = false
                sonuc(m, false)
                geri()
                return
            } catch APIHatasi.yetkisiz(_) {
                Eylemler.cikis(oturum: oturum, depo: depo)
            } catch let e as APIHatasi {
                // "Yenilik eklendi. Bildirim gönderilmedi…" gibi: kayıt yapıldı, yalnızca bildirim olmadı.
                let m = e.aciklama
                if m.hasPrefix("Yenilik eklendi.") || m.hasPrefix("Yenilik güncellendi.") {
                    bekliyor = false
                    sonuc(m, true)
                    geri()
                    return
                }
                hata = m
            } catch {
                hata = APIHatasi.baglanti.aciklama
            }
            bekliyor = false
        }
    }
}
