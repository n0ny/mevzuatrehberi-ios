# Araçlar

## tekne-cikar.py

Sitedeki Tekne / Gemi Kontrolü sayfalarından (tekne.php ve 10 alt sayfası) sunucudaki
`api/tekne.json` dosyasını üretir. Sitedeki bu sayfalardan biri değişirse tekne.json
yeniden üretilip sunucuya yüklenmelidir; uygulama içeriği oradan alır.

    python3 Araclar/tekne-cikar.py <site klasörü> tekne.json Araclar/tekne-dizi.php

Gerekenler: Python 3 + beautifulsoup4 + lxml, PHP (özel tekne listelerindeki PHP dizilerini okumak için).
