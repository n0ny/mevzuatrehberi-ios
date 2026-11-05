# Sitedeki tekne / gemi kontrolü sayfalarından api/tekne.json üretir (metinler birebir).
import json, re, subprocess, sys
from bs4 import BeautifulSoup, NavigableString

SITE = sys.argv[1]
CIKTI = sys.argv[2]
SAYFALAR = ["tekne", "balikci", "ticari_balikcilik", "kontrol_cek_listesi", "amator_balikcilik",
            "kontrol_cek_listesi_amator", "amator_balikci_av_araci", "ozel_tekne",
            "ozel_tekne_cek_listesi_buyuk", "ozel_tekne_cek_listesi_kucuk", "ticari-kontrol-liste"]

def sade(t):
    return re.sub(r"\s+", " ", t or "").strip()

def metin(el, atla=()):
    parcalar = []
    for c in el.descendants:
        if isinstance(c, NavigableString):
            if any(p.name in atla for p in c.parents if p is not el and getattr(p, "name", None)):
                continue
            if c.parent.name in ("script", "style"):
                continue
            parcalar.append(str(c))
    return sade(" ".join(parcalar))

def satirli(el):
    # <br> → satır sonu
    for br in el.find_all("br"):
        br.replace_with("\n")
    satirlar = [sade(s) for s in el.get_text().split("\n")]
    return "\n".join(s for s in satirlar if s)

def hedef(href):
    if not href:
        return None
    h = href.split("?")[0].replace(".php", "")
    return h if h in SAYFALAR else None

def oku(ad):
    ham = open(f"{SITE}/{ad}.php", encoding="utf-8").read()
    # PHP bloklarını HTML'den çıkar (diziler ayrıca okunur)
    html = re.sub(r"<\?(php|=).*?\?>", "", ham, flags=re.S)
    return ham, BeautifulSoup(html, "lxml")

sonuc = {}
for ad in SAYFALAR:
    ham, s = oku(ad)
    for x in s(["script", "style", "svg"]):
        x.decompose()
    sayfa = {}
    h1 = s.find("h1")
    sayfa["baslik"] = sade(h1.get_text()) if h1 else ""
    p = h1.find_next_sibling("p") if h1 else None
    if p:
        sayfa["aciklama"] = sade(p.get_text())
    main = s.find("main")
    bloklar = []

    def ekle(b):
        bloklar.append(b)

    kartlar = None
    maddeler = None
    for el in main.find_all(True, recursive=True):
        if el.attrs is None:
            continue
        cls = el.get("class") or []
        if "teblig-box" in cls:
            st = el.find("strong")
            ekle({"tur": "dayanak", "baslik": sade(st.get_text()), "metin": metin(el, atla=("strong",))})
        elif "badge" in cls and el.find_parent(class_="hero"):
            ekle({"tur": "dayanak", "baslik": "Mevzuat Dayanağı", "metin": sade(el.get_text())})
        elif "info-banner" in cls:
            st = el.find("strong")
            ekle({"tur": "bilgi", "baslik": sade(st.get_text()), "metin": metin(el, atla=("strong",))})
        elif "section-note" in cls:
            ekle({"tur": "aciklama", "metin": sade(el.get_text())})
        elif "section-label" in cls or "quick-title" in cls or "list-heading-title" in cls:
            sayi = None
            ust = el.find_parent(class_=["section-header", "list-heading"])
            if ust:
                pill = ust.find(class_=["count-pill", "list-heading-badge"])
                if pill and sade(pill.get_text()):
                    sayi = sade(pill.get_text())
            b = {"tur": "etiket", "metin": sade(el.get_text())}
            if sayi:
                b["sayi"] = sayi
            ekle(b)
        elif ("control-card" in cls) or ("quick-card" in cls):
            if kartlar is None or bloklar[-1] is not kartlar:
                kartlar = {"tur": "kartlar", "kartlar": []}
                ekle(kartlar)
            if "quick-card" in cls:
                bas = el.find("strong")
                alt = bas.find_next_sibling("span") if bas else None
                k = {"baslik": sade(bas.get_text()), "aciklama": sade(alt.get_text()) if alt else ""}
            else:
                k = {"baslik": sade(el.find("h2").get_text()),
                     "aciklama": sade(el.find("p").get_text()) if el.find("p") else ""}
            hd = hedef(el.get("href"))
            if hd:
                k["hedef"] = hd
            if "disabled" in cls or el.find(class_="coming-soon"):
                k["yakinda"] = sade(el.find(class_="coming-soon").get_text()) if el.find(class_="coming-soon") else "Yakında"
            kartlar["kartlar"].append(k)
        elif "check-item" in cls:
            if maddeler is None or bloklar[-1] is not maddeler:
                maddeler = {"tur": "liste", "maddeler": []}
                ekle(maddeler)
            it = el.find(class_="item-text")
            sm = it.find("small")
            m = {"baslik": metin(it, atla=("small",))}
            if sm:
                m["not"] = sade(sm.get_text())
            maddeler["maddeler"].append(m)
        elif "check-list" in cls and not el.find(class_="check-item"):
            # özel tekne listeleri: maddeler PHP dizisinden
            cik = json.loads(subprocess.check_output(["php", sys.argv[3], f"{SITE}/{ad}.php"]))
            liste = []
            if "items" in cik:
                for ik, bs, et, alt in cik["items"]:
                    liste.append({"simge": ik, "baslik": bs, "etiket": et, "alt": alt})
            else:
                for ik, bs, alt in cik["liste"]:
                    liste.append({"simge": ik, "baslik": bs, "etiket": "Kontrol edilecek hususlar", "alt": alt})
            ekle({"tur": "liste", "maddeler": liste})
            # başlıktaki "<?= count() ?> Kalem"
            for b in bloklar:
                if b["tur"] == "etiket" and not re.match(r"\d", b.get("sayi", "")):
                    b["sayi"] = f"{len(liste)} Kalem"
        elif "card" in cls and el.find(class_="card-toggle"):
            ac = {"tur": "acilir",
                  "simge": sade(el.find(class_="card-icon").get_text()),
                  "baslik": sade(el.find("h2").get_text()),
                  "ozet": sade(el.find(class_="card-summary").get_text())}
            ex = el.find(class_="explain")
            if ex:
                ac["aciklama"] = sade(ex.get_text())
            mv = el.find(class_="mevzuat")
            if mv:
                st = mv.find("strong")
                bas = sade(st.get_text()) if st else ""
                if st:
                    st.decompose()
                ac["mevzuat"] = satirli(mv)
            ekle(ac)
        elif "warning" in cls:
            st = el.find("strong")
            ekle({"tur": "uyari", "baslik": sade(st.get_text()), "metin": metin(el, atla=("strong",))})
        elif "notice" in cls:
            st = el.find("strong")
            ekle({"tur": "not", "baslik": sade(st.get_text()).rstrip(":"), "metin": metin(el, atla=("strong",))})
        elif "source-card" in cls:
            a = el.find("a")
            site = el.find(class_="official-source-site")
            ekle({"tur": "kaynak", "baslik": sade(el.find("h2").get_text()),
                  "ad": sade(a.get_text()), "url": a.get("href"), "site": sade(site.get_text()) if site else ""})
        elif "footer-note" in cls:
            ekle({"tur": "altnot", "metin": sade(el.get_text())})
    sayfa["bloklar"] = bloklar
    sonuc[ad] = sayfa

json.dump({"surum": 1, "kok": "tekne", "sayfalar": sonuc}, open(CIKTI, "w", encoding="utf-8"),
          ensure_ascii=False, indent=1)
print("tamam", {k: len(v["bloklar"]) for k, v in sonuc.items()})
