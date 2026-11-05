import SwiftUI
import UIKit

/// oneri.php — Öneri & Geri Bildirim. Gönderimi sunucuda sitenin kendi oneri.php sayfası yapar
/// (aynı kurallar, yöneticiye aynı e-posta, destek paneline aynı kayıt).
struct OneriEkrani: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var depo: VeriDeposu

    /// oneri.php'deki seçenekler (sunucudan gelen liste varsa o kullanılır).
    @State private var konular = ["Mevzuat / Madde Önerisi", "Yeni Kontrol Konusu",
                                  "Hata / Eksik Bilgi Bildirimi", "Yeni Özellik Önerisi", "Diğer"]
    @State private var konu = ""
    @State private var mesaj = ""
    @State private var eposta = ""
    @State private var bekliyor = false
    @State private var hata: String?
    @State private var basari: String?
    @State private var epostaYuklendi = false

    private let enFazla = 5000

    var body: some View {
        YenilenebilirKaydirma(eylem: { await epostaYukle(zorla: true) }) {
            VStack(spacing: 0) {
                Kahraman(baslik: "Öneri & Geri Bildirim",
                         aciklama: "Uygulamada görmek istediğin bir mevzuat, kontrol konusu veya geliştirme önerisi varsa bize iletebilirsin.")
                VStack(alignment: .leading, spacing: 14) {
                    if let b = basari {
                        Bildirim(metin: b, hata: false)
                        AnaDugme(baslik: "Yeni öneri yaz", bekliyor: false) {
                            basari = nil
                            konu = ""
                            mesaj = ""
                        }
                    } else {
                        if let h = hata {
                            Bildirim(metin: h, hata: true)
                        }
                        form
                    }

                    (Text("Bilgi: ").bold()
                        + Text("Gönderdiğin öneri doğrudan uygulama yöneticisine iletilir. Adın ve kullanıcı adın, önerinin kim tarafından gönderildiğini belirtmek amacıyla e-postaya eklenir."))
                        .font(.footnote)
                        .foregroundColor(Renk.murekkep)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Renk.tint)
                        .cornerRadius(14)
                }
                .padding(16)
            }
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle("Öneri & Geri Bildirim")
        .markaBasligi()
        .task { await epostaYukle(zorla: false) }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            Giris(etiket: "Öneri konusu") {
                Menu {
                    ForEach(konular, id: \.self) { k in
                        Button(k) { konu = k }
                    }
                } label: {
                    HStack {
                        Text(konu.isEmpty ? "Konu seçiniz..." : konu)
                            .foregroundColor(konu.isEmpty ? Renk.soluk : Renk.murekkep)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundColor(Renk.soluk)
                    }
                    .contentShape(Rectangle())
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Öneriniz")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Renk.soluk)
                ZStack(alignment: .topLeading) {
                    if mesaj.isEmpty {
                        Text("Örneğin: Midye avcılığı için ayrı bir kontrol bölümü eklenebilir mi?")
                            .foregroundColor(Renk.soluk.opacity(0.8))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $mesaj)
                        .saydamMetinKutusu()
                        .frame(minHeight: 150)
                        .foregroundColor(Renk.murekkep)
                        .onChange(of: mesaj) { yeni in
                            if yeni.count > enFazla {
                                mesaj = String(yeni.prefix(enFazla))
                            }
                        }
                }
                .padding(7)
                .background(Renk.ikincil)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Renk.cizgi, lineWidth: 1))
                HStack {
                    Spacer()
                    Text("\(mesaj.count) / \(enFazla)")
                        .font(.caption2)
                        .foregroundColor(Renk.soluk)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Giris(etiket: "E-posta adresin") {
                    TextField("ornek@mail.com", text: $eposta)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .foregroundColor(Renk.murekkep)
                }
                Text("Önerine verilecek cevap bu adrese gönderilir.")
                    .font(.caption)
                    .foregroundColor(Renk.soluk)
            }

            AnaDugme(baslik: bekliyor ? "Gönderiliyor…" : "Öneriyi Gönder", bekliyor: bekliyor) {
                gonder()
            }
        }
        .padding(16)
        .kart()
    }

    private func epostaYukle(zorla: Bool) async {
        guard let t = oturum.token, zorla || !epostaYuklendi else { return }
        do {
            let b = try await APIIstemci.oneriBilgisi(token: t)
            if eposta.isEmpty { eposta = b.eposta }
            if !b.konular.isEmpty { konular = b.konular }
            epostaYuklendi = true
        } catch APIHatasi.yetkisiz(_) {
            Eylemler.cikis(oturum: oturum, depo: depo)
        } catch {
            // E-posta elle de yazılabilir.
        }
    }

    private func gonder() {
        guard let t = oturum.token, !bekliyor else { return }
        hata = nil
        bekliyor = true
        let k = konu
        let m = mesaj
        let e = eposta.trimmingCharacters(in: .whitespaces)
        Task {
            do {
                basari = try await APIIstemci.oneriGonder(konu: k, mesaj: m, eposta: e, token: t)
            } catch APIHatasi.yetkisiz(_) {
                Eylemler.cikis(oturum: oturum, depo: depo)
            } catch let h as APIHatasi {
                hata = h.aciklama
            } catch {
                hata = APIHatasi.baglanti.aciklama
            }
            bekliyor = false
        }
    }
}

extension View {
    /// TextEditor'ün kendi beyaz/siyah zeminini kaldırır (kutunun rengi görünsün).
    @ViewBuilder
    func saydamMetinKutusu() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            // iOS 15: uygulama açılışında UITextView zemini saydam yapılır (MevzuatRehberiApp).
            self
        }
    }
}
