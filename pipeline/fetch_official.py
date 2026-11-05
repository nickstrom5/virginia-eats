"""Virginia's open official records -> data/raw/official/ (git-ignored, never public).

Checked 2026-11-05 (playbook/12-sources.md): the one open feed is the Fairfax Health District's ArcGIS service (Fairfax County, the
Cities of Fairfax and Falls Church and the towns in them): layer 0, permitted food establishments (with a point), and table 1, their
inspections with the district's own result (Passed / Partial Pass / Failed - Self Closed / Failed), about two years rolling. Fairfax
County's GIS disclaimer: its layers "are provided as a public resource", without warranty. VDH's statewide portal is search-only and
disallows crawlers (not read). Virginia ABC's licensee export (salicenseeexport.blob.core.windows.net) answers, but abc.virginia.gov,
where its terms would be, answers 403 to scripts: not used until Nick decides. One request at a time; no owner or person names.
"""
import datetime, json, os, time
import requests

OUT = os.path.join(os.path.dirname(__file__), "..", "data", "raw", "official")
os.makedirs(os.path.join(OUT, "fairfax"), exist_ok=True)
UA = "OldDominionEatsDataCheck/1.0 (+https://nickstrom5.github.io/virginia-eats/; nick@eatsranked.com)"
FX = "https://www.fairfaxcounty.gov/gispub2/rest/services/Health/PermittedFoodEstablishments/FeatureServer"
S = requests.Session(); S.headers["User-Agent"] = UA


def get(url, **params):
    for attempt in range(4):
        r = S.get(url, params=params, timeout=90)
        if r.status_code == 200:
            return r.json()
        time.sleep(5 * (attempt + 1))
    r.raise_for_status()


def arcgis(layer, fields, geometry):
    rows, off = [], 0
    while True:
        d = get(f"{layer}/query", where="1=1", outFields=fields, returnGeometry=str(geometry).lower(), outSR=4326, orderByFields="OBJECTID",
                resultOffset=off, resultRecordCount=2000, f="json")
        feats = d.get("features") or []
        for f in feats:
            a = dict(f["attributes"])
            if geometry and f.get("geometry"):
                a["_lon"], a["_lat"] = f["geometry"].get("x"), f["geometry"].get("y")
            rows.append(a)
        if len(feats) < 2000 and not d.get("exceededTransferLimit"):
            return rows
        off += len(feats)
        time.sleep(1)


meta = {"fairfax": {"name": "Fairfax Health District: Permitted Food Establishments and Food Establishment Inspections",
                    "url": FX, "fetched": datetime.date.today().isoformat(),
                    "terms": "Fairfax County GIS disclaimer (fairfaxcounty.gov/maps/disclaimer): provided as a public resource, no warranty"}}
permits = arcgis(f"{FX}/0", "ESTABLISHMENT_NAME,PERMIT_ADDRESS,PERMIT_CITY,PERMIT_STATE,PERMIT_ZIP,PERMIT_ISSUE_DATE,PERMIT_EXPIRATION_DATE,"
                 "CATEGORY_TYPE,DISTRICT,ESTABLISHMENT_STATUS,RECORDID,LAST_INSPECTION_DATE,JURISDICTION,STAMP,OBJECTID", True)
time.sleep(1)
insp = arcgis(f"{FX}/1", "INSPECTIONID,RECORDID,INSPECTIONDATE,INSPECTIONRESULT,ESTABLISHMENT_NAME,OBJECTID", False)
json.dump(permits, open(os.path.join(OUT, "fairfax", "permits.json"), "w"))
json.dump(insp, open(os.path.join(OUT, "fairfax", "inspections.json"), "w"))
json.dump(meta, open(os.path.join(OUT, "meta.json"), "w"), indent=1)
print("Fairfax permits:", len(permits), "| inspections:", len(insp))
