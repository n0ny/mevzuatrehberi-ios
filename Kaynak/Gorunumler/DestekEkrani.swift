import SwiftUI

// MARK: - Veri (api/destek.php — sitedeki yanit.php ile aynı)

struct DestekListesi: Codable {
    let durum: String
    let bekleyen: Int
    let yanitlanan: Int
    let talepler: [DestekTalepOzeti]
}

struct DestekTalepOzeti: Codable, Identifiable {
    let id: Int
    let ad: String
    let konu: String
    let durum: String
    let tarih: String
}

struct DestekAyrintisi: Codable {
    let talep: DestekTalebi
    let yanitlar: [DestekYaniti]
}

struct DestekTalebi: Codable {
    let id: Int
    let ad: String
    let eposta: String
    let epostaGecerli: Bool
    let konu: String
    let mesaj: String
    let durum: String
    let tarih: String
}

struct DestekYaniti: Codable, Identifiable {
    let id: Int
    let yanit: String
    let tarih: String
}

// MARK: - Liste

/// yanit.php — Destek paneli (öneri ve geri bildirimlere e-postayla yanıt).
struct DestekEkrani: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu

    @State private var filtre = "acik"
    @State private var veri: DestekListesi?
    @State private var hata: String?
    @State private var mesaj: (metin: String, hata: Bool)?

    var body: some View {
        YenilenebilirKaydirma(eylem: { await yukle() }) {
            VStack(spacing: 0) {
                Kahraman(baslik: "Destek paneli",
                         aciklama: "Öneri ve geri bildirimlere e-postayla yanıt ver.")
                VStack(alignment: .leading, spacing: 14) {
                    if let m = mesaj {
                        Bildirim(metin: m.metin, hata: m.hata)
                    }
                    Picker("Talepler", selection: $filtre) {
                        Text(veri.map { "Bekleyen (\($0.bekleyen))" } ?? "Bekleyen").tag("acik")
                        Text("Yanıtlanan").tag("yanitlandi")
                        Text("Tümü").tag("hepsi")
                    }
                    .pickerStyle(.segmented)

                    if let v = veri, v.durum == filtre {
                        if v.talepler.isEmpty {
                            Text("Bu listede talep yok.")
                                .font(.footnote)
                                .foregroundColor(Renk.soluk)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 24)
                        }
                        ForEach(v.talepler) { t in
                            NavigationLink(destination: DestekTalepEkrani(talepId: t.id, sonuc: sonuc)) {
                                talepSatiri(t)
                            }
                            .buttonStyle(.plain)
                        }
                    } else if let h = hata {
                        UyariKutusu(tur: .bilgi, baslik: "Talepler yüklenemedi.", metin: h)
                    } else {
                        HStack { Spacer(); ProgressView(); Spacer() }.padding(.top, 20)
                    }
                }
                .padding(16)
            }
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle("Destek paneli")
        .markaBasligi()
        .task { if veri == nil { await yukle() } }
        .onChange(of: filtre) { _ in
            mesaj = nil
            Task { await yukle() }
        }
    }

    private func talepSatiri(_ t: DestekTalepOzeti) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(t.ad)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Renk.murekkep)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    DestekDurumHapi(durum: t.durum)
                }
                Text(t.konu)
                    .font(.footnote)
                    .foregroundColor(Renk.soluk)
                    .lineLimit(1)
                Text(t.tarih)
                    .font(.caption)
                    .foregroundColor(Renk.soluk)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundColor(Renk.soluk)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .kart()
    }

    /// Ayrıntı ekranından dönen sonuç: liste yenilenir, varsa mesaj gösterilir.
    private func sonuc(_ m: String?, _ hataMi: Bool) {
        if let m = m {
            mesaj = (m, hataMi)
        }
        Task { await yukle() }
    }

    private func yukle() async {
        guard let t = oturum.token else { return }
        let istenen = filtre
        do {
            let v = try await APIIstemci.destekListesi(durum: istenen, token: t)
            if istenen == filtre {
                veri = v
                hata = nil
            }
        } catch APIHatasi.yetkisiz(_) {
            Eylemler.cikis(oturum: oturum, depo: depo)
        } catch let e as APIHatasi {
            hata = e.aciklama
            veri = nil
        } catch {
            hata = APIHatasi.baglanti.aciklama
            veri = nil
        }
    }
}

struct DestekDurumHapi: View {
    let durum: String

    var body: some View {
        if durum == "yanitlandi" {
            Hap(metin: "Yanıtlandı", renk: Renk.yesil, zemin: Renk.yesilZemin)
        } else {
            Hap(metin: "Bekliyor", renk: Renk.amber, zemin: Renk.amberZemin)
        }
    }
}

// MARK: - Talep ayrıntısı ve yanıt

struct DestekTalepEkrani: View {
    let talepId: Int
    let sonuc: (String?, Bool) -> Void

    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu
    @Environment(\.dismiss) private var geri

    @State private var veri: DestekAyrintisi?
    @State private var hata: String?
    @State private var mesaj: (metin: String, hata: Bool)?
    @State private var yanit = ""
    @State private var bekliyor = false
    @State private var gonderSorusu = false
    @State private var silSorusu = false

    var body: some View {
        YenilenebilirKaydirma(eylem: { await yukle() }) {
            VStack(alignment: .leading, spacing: 14) {
                if let m = mesaj {
                    Bildirim(metin: m.metin, hata: m.hata)
                }
                if let v = veri {
                    icerik(v)
                } else if let h = hata {
                    UyariKutusu(tur: .bilgi, baslik: "Talep yüklenemedi.", metin: h)
                } else {
                    HStack { Spacer(); ProgressView(); Spacer() }.padding(.top, 20)
                }
            }
            .padding(16)
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle("Talep")
        .navigationBarTitleDisplayMode(.inline)
        .task { if veri == nil { await yukle() } }
        .alert("Yanıt e-postayla gönderilsin mi?", isPresented: $gonderSorusu) {
            Button("Gönder") { Task { await islem("yanitla") } }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text(veri.map { "\($0.talep.eposta) adresine gönderilecek." } ?? "")
        }
        .alert("Bu talep kalıcı olarak silinsin mi?", isPresented: $silSorusu) {
            Button("Sil", role: .destructive) { Task { await islem("sil") } }
            Button("Vazgeç", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func icerik(_ v: DestekAyrintisi) -> some View {
        let t = v.talep
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Text(t.konu)
                    .font(.title3.weight(.bold))
                    .foregroundColor(Renk.murekkep)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                DestekDurumHapi(durum: t.durum)
            }
            Text(t.ad + " · " + (t.eposta.isEmpty ? "e-posta bırakmamış" : t.eposta))
                .font(.footnote)
                .foregroundColor(Renk.soluk)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }

        balon(ust: t.tarih, metin: t.mesaj, bizden: false)
        ForEach(v.yanitlar) { y in
            balon(ust: "Yanıtın · " + y.tarih, metin: y.yanit, bizden: true)
        }

        if t.epostaGecerli {
            VStack(alignment: .leading, spacing: 12) {
                MetinAlani(etiket: "\(t.ad) kişisine yanıt yaz", metin: $yanit,
                           ipucu: "Yanıtını yaz…", enFazla: 10000)
                AnaDugme(baslik: "Yanıtı gönder", bekliyor: bekliyor) {
                    mesaj = nil
                    if yanit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        mesaj = ("Yanıt boş olamaz.", true)
                    } else {
                        gonderSorusu = true
                    }
                }
            }
            .padding(16)
            .kart()
        } else {
            UyariKutusu(tur: .dikkat, baslik: "Yanıt gönderilemez.",
                        metin: "Bu kişi e-posta adresi bırakmamış.")
        }

        Button {
            silSorusu = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                Text("Bu talebi sil").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundColor(Renk.kirmizi)
            .background(Renk.kirmiziZemin)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(bekliyor)
        .padding(.top, 6)
    }

    private func balon(ust: String, metin: String, bizden: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ust)
                .font(.caption)
                .foregroundColor(Renk.soluk)
            Text(metin)
                .font(.subheadline)
                .foregroundColor(Renk.murekkep)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bizden ? Renk.tint : Renk.kart)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(bizden ? Color.clear : Renk.cizgi, lineWidth: 1))
    }

    private func yukle() async {
        guard let t = oturum.token else { return }
        do {
            veri = try await APIIstemci.destekTalebi(id: talepId, token: t)
            hata = nil
        } catch APIHatasi.yetkisiz(_) {
            Eylemler.cikis(oturum: oturum, depo: depo)
        } catch let e as APIHatasi {
            hata = e.aciklama
        } catch {
            hata = APIHatasi.baglanti.aciklama
        }
    }

    private func islem(_ ad: String) async {
        guard let t = oturum.token, !bekliyor else { return }
        bekliyor = true
        defer { bekliyor = false }
        mesaj = nil
        do {
            var alanlar = ["id": String(talepId)]
            if ad == "yanitla" {
                alanlar["yanit"] = yanit
            }
            let m = try await APIIstemci.destekIslem(ad, alanlar: alanlar, token: t)
            if ad == "sil" {
                sonuc(m, false)
                geri()
                return
            }
            mesaj = (m, false)
            yanit = ""
            sonuc(nil, false)
            await yukle()
        } catch APIHatasi.yetkisiz(_) {
            Eylemler.cikis(oturum: oturum, depo: depo)
        } catch let e as APIHatasi {
            mesaj = (e.aciklama, true)
        } catch {
            mesaj = (APIHatasi.baglanti.aciklama, true)
        }
    }
}
