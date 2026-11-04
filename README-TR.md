# Mevzuat Rehberi — iOS (yerel uygulama)

SwiftUI ile yazılmış yerel iOS uygulaması. Siteyi açmaz; içeriği
`https://sg.barisguresci.com.tr/api/` veri katmanından indirir, telefonda saklar
ve internet yokken son indirilen veriyle çalışır.

## Yapı
- `project.yml` — Xcode projesi bu dosyadan XcodeGen ile oluşturulur (CI'da otomatik).
- `Kaynak/` — uygulama kodu (modeller, veri deposu, ekranlar).
- `Destek/` — Info.plist ve gizlilik bildirimi.
- `Testler/` — birim testleri.
- `.github/workflows/ios-build.yml` — her gönderimde imzasız IPA üretir, sonra testleri çalıştırır.

## Derleme
GitHub → Actions → "iOS derleme". İş bitince **MevzuatRehberi-imzasiz-IPA**
çıktısını indirin; içindeki `.ipa` Esign vb. ile imzalanıp kurulur.

## Gereksinimler
- iOS 15+, yalnızca iPhone.
- Paket adı: `com.barisguresci.sgmevzuat`.
