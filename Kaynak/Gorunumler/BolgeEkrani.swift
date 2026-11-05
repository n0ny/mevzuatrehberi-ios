import SwiftUI
import MapKit

// bolge_yasaklari.php — Bölge / yer yasakları sayfasının karşılığı.

enum BolgeKurallari {
    static let denizler = ["Akdeniz", "Ege", "Marmara", "Karadeniz", "İç Sular"]

    static func bugun() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Istanbul")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// trdate: gg.aa.yyyy
    static func tarih(_ s: String?) -> String {
        guard let s = s, s.count >= 10 else { return "" }
        let p = s.prefix(10).split(separator: "-")
        guard p.count == 3 else { return s }
        return "\(p[2]).\(p[1]).\(p[0])"
    }

    /// mb_strimwidth(desc, 0, 145, '…')
    static func ozet(_ s: String) -> String {
        if s.count <= 145 { return s }
        return String(s.prefix(144)) + "…"
    }

    static func googleHarita(_ n: BolgeHaritasi.Nokta) -> URL? {
        let q = String(format: "%.6f,%.6f", n.enlem, n.boylam)
        let kodlu = q.replacingOccurrences(of: ",", with: "%2C")
        return URL(string: "https://www.google.com/maps/search/?api=1&query=" + kodlu)
    }

    /// Sitedeki sıralama: aktif önce, sonra il, ilçe, başlık.
    static func once(_ a: Bolge, _ b: Bolge) -> Bool {
        if a.aktif != b.aktif { return a.aktif }
        if a.il != b.il { return Metin.once(a.il, b.il) }
        let ai = a.ilce ?? ""
        let bi = b.ilce ?? ""
        if ai != bi { return Metin.once(ai, bi) }
        return Metin.once(a.baslik, b.baslik)
    }
}

struct BolgeEkrani: View {
    @EnvironmentObject var depo: VeriDeposu
    @State private var deniz = "Akdeniz"
    @State private var teblig = ""
    @State private var il = ""
    @State private var ilce = ""
    @State private var sorgu = ""

    var body: some View {
        let denizKayitlari = depo.bolgeler.filter { $0.deniz == deniz }
        let iller: [String] = Array(Set(denizKayitlari.map { $0.il }.filter { !$0.isEmpty })).sorted { Metin.once($0, $1) }
        let ilceler: [String] = il.isEmpty ? [] : Array(Set(denizKayitlari.filter { $0.il == il }.compactMap { $0.ilce })).sorted { Metin.once($0, $1) }
        let q = sorgu.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: TRMetin.tr)
        let liste = denizKayitlari.filter { b in
            (q.isEmpty || b.aramaSite.contains(q))
                && (il.isEmpty || b.il == il)
                && (ilce.isEmpty || b.ilce == ilce)
                && (teblig.isEmpty || b.tebligTuru == teblig)
        }.sorted(by: BolgeKurallari.once)
        let bugun = BolgeKurallari.bugun()

        ScrollView {
            VStack(spacing: 0) {
                Kahraman(baslik: "\(deniz) Yer Yasakları",
                         aciklama: "Su ürünleri avcılığında bölge, yer ve dönem bakımından uygulanan yasak ve sınırlamaları hızlıca kontrol et.") {
                    AramaKutusu(ipucu: "Yasak adı, açıklama veya mevzuat ara...", metin: $sorgu)
                }

                LazyVStack(alignment: .leading, spacing: 12) {
                    filtreler(iller: iller, ilceler: ilceler)

                    HStack(alignment: .firstTextBaseline) {
                        Text("Yasak kayıtları")
                            .font(.headline)
                            .foregroundColor(Renk.murekkep)
                        Spacer()
                        (Text("\(liste.count)").bold() + Text(" kayıt (\(deniz)\(teblig.isEmpty ? "" : " — " + teblig))"))
                            .font(.footnote)
                            .foregroundColor(Renk.soluk)
                    }
                    .padding(.top, 4)

                    if liste.isEmpty {
                        Text("Bu bölge ve seçtiğiniz filtrelere uygun kayıt bulunamadı.")
                            .font(.subheadline)
                            .foregroundColor(Renk.soluk)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .kart()
                    } else {
                        ForEach(liste) { b in
                            BolgeKarti(bolge: b, bugun: bugun)
                        }
                    }

                    UyariKutusu(tur: .bilgi, baslik: "Kontrol notu:",
                                metin: "Bölge ve zaman yasakları il, ilçe, koordinat, tür ve tarih bakımından değişebilir. Denetimde kaydın yerini, tarihini ve mevzuat dayanağını birlikte kontrol et.")
                        .padding(.top, 4)
                }
                .padding(16)
            }
        }
        .background(Renk.zemin.ignoresSafeArea())
        .navigationTitle("Mevzuat Rehberi")
        .markaBasligi()
    }

    private func filtreler(iller: [String], ilceler: [String]) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                FiltreSecici(etiket: "Deniz / Bölge", deger: deniz,
                             secenekler: BolgeKurallari.denizler.map { ($0, $0) }) { yeni in
                    deniz = yeni
                    il = ""
                    ilce = ""
                }
                FiltreSecici(etiket: "Tebliğ türü", deger: teblig,
                             secenekler: [("", "Tümü"), ("6/1", "6/1 — Ticari"), ("6/2", "6/2 — Amatör")]) { teblig = $0 }
            }
            HStack(spacing: 10) {
                FiltreSecici(etiket: "İl", deger: il,
                             secenekler: [("", "Tüm iller")] + iller.map { ($0, $0) }) { yeni in
                    il = yeni
                    ilce = ""
                }
                FiltreSecici(etiket: "İlçe", deger: ilce,
                             secenekler: [("", il.isEmpty ? "Önce il seçiniz..." : "Tüm ilçeler")] + ilceler.map { ($0, $0) },
                             kapali: il.isEmpty) { ilce = $0 }
            }
        }
        .padding(12)
        .kart()
    }
}

/// Açılır seçim kutusu (sitedeki <select>).
struct FiltreSecici: View {
    let etiket: String
    let deger: String
    let secenekler: [(String, String)]
    var kapali = false
    let sec: (String) -> Void

    private var gorunen: String {
        return secenekler.first(where: { $0.0 == deger })?.1 ?? (secenekler.first?.1 ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(etiket)
                .font(.caption2.weight(.semibold))
                .foregroundColor(Renk.soluk)
            Menu {
                ForEach(Array(secenekler.enumerated()), id: \.offset) { _, s in
                    Button {
                        sec(s.0)
                    } label: {
                        if s.0 == deger {
                            Label(s.1, systemImage: "checkmark")
                        } else {
                            Text(s.1)
                        }
                    }
                }
            } label: {
                HStack {
                    Text(gorunen)
                        .font(.subheadline)
                        .foregroundColor(kapali ? Renk.soluk : Renk.murekkep)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(Renk.soluk)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Renk.ikincil)
                .cornerRadius(10)
            }
            .disabled(kapali)
        }
        .frame(maxWidth: .infinity)
    }
}

struct BolgeKarti: View {
    let bolge: Bolge
    let bugun: String
    @State private var acik = false
    @State private var haritaAcik = false

    var body: some View {
        let durum = bolge.durum(bugun: bugun)
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { acik.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "nosign")
                        .foregroundColor(Renk.kirmizi)
                        .frame(width: 34, height: 34)
                        .background(Renk.kirmiziZemin)
                        .cornerRadius(10)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(bolge.baslik)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Renk.murekkep)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(BolgeKurallari.ozet(bolge.aciklama ?? "Bölgeye ilişkin yasak ve sınırlama kaydı."))
                            .font(.footnote)
                            .foregroundColor(Renk.soluk)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        etiketler(durum: durum)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if acik {
                VStack(alignment: .leading, spacing: 10) {
                    if bolge.mevzuatAdi != nil || bolge.mevzuatMadde != nil {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Mevzuat")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(Renk.mavi)
                            if let a = bolge.mevzuatAdi {
                                Text(a)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(Renk.murekkep)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if let m = bolge.mevzuatMadde {
                                Hap(metin: m)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Renk.tint.opacity(0.6))
                        .cornerRadius(10)
                    }
                    if let d = bolge.aciklama {
                        Text(d)
                            .font(.footnote)
                            .foregroundColor(Renk.murekkep)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Renk.ikincil)
                            .cornerRadius(10)
                    }
                    VStack(spacing: 6) {
                        MetaSatiri(anahtar: "Deniz", deger: bolge.deniz)
                        MetaSatiri(anahtar: "İl", deger: bolge.il)
                        MetaSatiri(anahtar: "İlçe", deger: bolge.ilce)
                        MetaSatiri(anahtar: "Yasak türü", deger: bolge.yasakTuru)
                        MetaSatiri(anahtar: "İzin verilen av aracı", deger: bolge.izinliAvAraci)
                        if bolge.baslangic != nil || bolge.bitis != nil {
                            MetaSatiri(anahtar: "Tarih",
                                       deger: (bolge.baslangic.map { BolgeKurallari.tarih($0) } ?? "—") + " – "
                                           + (bolge.bitis.map { BolgeKurallari.tarih($0) } ?? "—"))
                        }
                        if let k = bolge.koordinatlar {
                            koordinatBolumu(k)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .kart(vurgulu: acik)
        .sheet(isPresented: $haritaAcik) {
            if let h = bolge.harita {
                BolgeHaritaPenceresi(baslik: bolge.baslik, harita: h)
            }
        }
    }

    private func etiketler(durum: Bolge.Durum) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                if !bolge.yer.isEmpty { Hap(metin: bolge.yer, renk: Renk.soluk, zemin: Renk.ikincil) }
                if let m = bolge.mevzuatMadde { Hap(metin: m) }
            }
            HStack(spacing: 6) {
                if bolge.harita != nil {
                    Hap(metin: "Haritada", renk: Renk.mavi, zemin: Renk.tint)
                }
                switch durum {
                case .aktif:
                    Hap(metin: "● Aktif kayıt", renk: Renk.yesil, zemin: Renk.yesilZemin)
                case .pasif(let m):
                    Hap(metin: "● " + m, renk: Renk.soluk, zemin: Renk.ikincil)
                }
            }
        }
    }

    @ViewBuilder
    private func koordinatBolumu(_ k: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Koordinatlar")
                .font(.caption.weight(.semibold))
                .foregroundColor(Renk.soluk)
            Text(k)
                .font(.footnote)
                .foregroundColor(Renk.murekkep)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if let h = bolge.harita {
                Button {
                    haritaAcik = true
                } label: {
                    Label(h.tur == "alan" ? "Alanı haritada gör" : "Haritada gör", systemImage: "map")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .background(Renk.lacivert)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(h.noktalar.enumerated()), id: \.offset) { i, n in
                            if let u = BolgeKurallari.googleHarita(n) {
                                Link(destination: u) {
                                    Text(h.noktalar.count > 1 ? "\(i + 1). nokta" : "Haritada göster")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .foregroundColor(Renk.mavi)
                                        .background(Renk.tint)
                                        .cornerRadius(999)
                                }
                            }
                        }
                    }
                }
                Text("Harita konumu yardımcı bilgidir. Kıyıdaki köşe noktaları karada görünebilir; yasak alan, noktalar arasında kalan deniz alanıdır. Tebliğde koordinat sistemi belirtilmediğinden küçük sapmalar olabilir; kesin sınır için tebliğ metni esas alınır.")
                    .font(.caption)
                    .foregroundColor(Renk.soluk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Renk.ikincil)
        .cornerRadius(10)
    }
}

struct MetaSatiri: View {
    let anahtar: String
    let deger: String?

    var body: some View {
        if let d = deger, !d.isEmpty {
            HStack(alignment: .top) {
                Text(anahtar)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Renk.soluk)
                    .frame(width: 110, alignment: .leading)
                Text(d)
                    .font(.footnote)
                    .foregroundColor(Renk.murekkep)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(9)
            .background(Renk.ikincil)
            .cornerRadius(8)
        }
    }
}

/// Harita penceresi (sitedeki .hm).
struct BolgeHaritaPenceresi: View {
    let baslik: String
    let harita: BolgeHaritasi
    @Environment(\.dismiss) private var kapat

    private var lejant: (String, String) {
        switch harita.tur {
        case "alan":
            return ("Taralı alan:", "tebliğdeki koordinat noktaları arasında kalan alan.")
        case "hat":
            return ("Kesikli çizgi:", "tebliğde tarif edilen hat. Yasağın hattın hangi tarafında olduğu kayıt metninde yazar (ör. “hattın kuzeyi”).")
        default:
            return ("Numaralı noktalar:", "tebliğde adı geçen yerler. Alanın tarifi (ör. “arasında kalan karasuları”) kayıt metnindedir.")
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                BolgeHaritaGorunumu(harita: harita)
                VStack(alignment: .leading, spacing: 6) {
                    (Text(lejant.0 + " ").bold() + Text(lejant.1))
                        .font(.footnote)
                        .foregroundColor(Renk.murekkep)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Kırmızı olanlar bu kayda aittir. Kıyıdaki köşe noktaları karada görünebilir. Kesin sınır ve yasağın kapsamı için kayıt metni ve tebliğ esas alınır.")
                        .font(.caption)
                        .foregroundColor(Renk.soluk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Renk.kart)
            }
            .navigationTitle(baslik)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { kapat() }
                }
            }
        }
    }
}

final class NumaraliNokta: MKPointAnnotation {
    var numara = 0
    var nokta: BolgeHaritasi.Nokta?
}

/// Apple Haritalar üzerinde alan (taralı), hat (kesikli) ve numaralı noktalar.
struct BolgeHaritaGorunumu: UIViewRepresentable {
    let harita: BolgeHaritasi

    static let kirmizi = UIColor(red: 0.776, green: 0.157, blue: 0.157, alpha: 1)

    func makeCoordinator() -> Koordinator {
        return Koordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let m = MKMapView()
        m.delegate = context.coordinator
        m.pointOfInterestFilter = .excludingAll
        ciz(m)
        return m
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {}

    private func koordinat(_ n: BolgeHaritasi.Nokta) -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: n.enlem, longitude: n.boylam)
    }

    private func ciz(_ m: MKMapView) {
        if harita.tur == "alan" && harita.cizim.count >= 3 {
            var k = harita.cizim.map { koordinat($0) }
            m.addOverlay(MKPolygon(coordinates: &k, count: k.count))
        } else if harita.tur == "hat" && harita.noktalar.count >= 2 {
            var k = harita.noktalar.map { koordinat($0) }
            m.addOverlay(MKPolyline(coordinates: &k, count: k.count))
        }

        var alan = MKMapRect.null
        for (i, n) in harita.noktalar.enumerated() {
            let a = NumaraliNokta()
            a.coordinate = koordinat(n)
            a.numara = i + 1
            a.nokta = n
            a.title = "\(i + 1). nokta"
            a.subtitle = n.metin
            m.addAnnotation(a)
            let p = MKMapPoint(a.coordinate)
            alan = alan.union(MKMapRect(x: p.x, y: p.y, width: 0, height: 0))
        }

        if let ilk = harita.noktalar.first {
            let enAz = 600 * MKMapPointsPerMeterAtLatitude(ilk.enlem)
            if alan.size.width < enAz || alan.size.height < enAz {
                let dx = max(0, (enAz - alan.size.width) / 2)
                let dy = max(0, (enAz - alan.size.height) / 2)
                alan = alan.insetBy(dx: -dx, dy: -dy)
            }
            let hedef = alan
            // Harita ekrana yerleştikten sonra yakınlaştır.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                m.setVisibleMapRect(hedef, edgePadding: UIEdgeInsets(top: 50, left: 40, bottom: 50, right: 40), animated: false)
            }
        }
    }

    final class Koordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let p = overlay as? MKPolygon {
                let r = MKPolygonRenderer(polygon: p)
                r.strokeColor = BolgeHaritaGorunumu.kirmizi
                r.fillColor = BolgeHaritaGorunumu.kirmizi.withAlphaComponent(0.18)
                r.lineWidth = 2
                return r
            }
            if let l = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: l)
                r.strokeColor = BolgeHaritaGorunumu.kirmizi
                r.lineWidth = 3
                r.lineDashPattern = [8, 6]
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let a = annotation as? NumaraliNokta else { return nil }
            let kimlik = "nokta"
            let v = (mapView.dequeueReusableAnnotationView(withIdentifier: kimlik) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: a, reuseIdentifier: kimlik)
            v.annotation = a
            v.glyphText = "\(a.numara)"
            v.markerTintColor = BolgeHaritaGorunumu.kirmizi
            v.canShowCallout = true
            v.displayPriority = .required
            v.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            return v
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView,
                     calloutAccessoryControlTapped control: UIControl) {
            guard let a = view.annotation as? NumaraliNokta, let n = a.nokta,
                  let u = BolgeKurallari.googleHarita(n) else { return }
            UIApplication.shared.open(u)
        }
    }
}
