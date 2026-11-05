"""Read Virginia Tourism Corporation listings (www.virginia.org/listing/<slug>/<id>/; robots.txt allows them) -> data/research/raw/
vtc.json: the page's own LocalBusiness record (name, street address, town, description), one polite request every 1.5 s.
Private research notes only. Usage: .venv/bin/python scripts/read_vtc.py <listing url or slug/id> ..."""
import html, json, os, re, sys, time
import requests
UA = "OldDominionEatsSourceCheck/1.0 (+https://nickstrom5.github.io/virginia-eats/; nick@eatsranked.com)"
OUT = os.path.join(os.path.dirname(__file__), "..", "data", "research", "raw", "vtc.json")
have = json.load(open(OUT)) if os.path.exists(OUT) else {}
for a in sys.argv[1:]:
    url = a if a.startswith("http") else f"https://www.virginia.org/listing/{a.strip('/')}/"
    if url in have:
        continue
    r = requests.get(url, headers={"User-Agent": UA}, timeout=40)
    rec = {"status": r.status_code}
    for x in re.findall(r'<script type="application/ld\+json">(.*?)</script>', r.text, re.S):
        try:
            d = json.loads(x)
        except ValueError:
            continue
        for node in d.get("@graph", [d]):
            if node.get("@type") in ("LocalBusiness", "Restaurant", "FoodEstablishment"):
                ad = node.get("address") or {}
                rec.update({"name": html.unescape(node.get("name") or ""), "street": ad.get("streetAddress"), "town": ad.get("addressLocality"),
                            "zip": ad.get("postalCode"), "desc": html.unescape(re.sub(r"<[^>]+>", " ", node.get("description") or "")).strip()})
    have[url] = rec
    print(r.status_code, rec.get("name"), "|", rec.get("street"), "|", rec.get("town"), "|", (rec.get("desc") or "")[:160].replace("\n", " "), flush=True)
    json.dump(have, open(OUT, "w"), indent=1, ensure_ascii=False)
    time.sleep(1.5)
