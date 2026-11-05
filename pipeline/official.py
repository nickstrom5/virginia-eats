"""Official records for Virginia -> one table of licensed food businesses (playbook/12-sources.md).

Virginia's 35 local health districts (VDH) inspect about 31,000 food establishments; their reports are on VDH's statewide portal
(inspections.myhealthdepartment.com/virginia), which is search-only and disallows crawlers, so it is linked, never read. The one open
feed is the Fairfax Health District's (Fairfax County, the Cities of Fairfax and Falls Church, Herndon, Vienna and Clifton): its
permitted food establishments with a point, and about two years of inspections with the district's own result (Passed, Partial
Pass, Failed - Self Closed, Failed), shown as the district words it, dated, never as a grade. Virginia ABC's statewide licensee export
answers a plain request, but its terms (on abc.virginia.gov, behind a Cloudflare challenge) can't be read: not used until Nick decides,
so "Serves alcohol" is unknown everywhere.

load() returns: jur, lic (our id), name, keys (name keys), addr, city, zip, num, street, lat, lon, kind, active, ltype, insp, biz.
"""
import os, re, json, datetime
import numpy as np, pandas as pd
from common import norm_name, RAW, name_sim, _stems, GENERIC, canon_city

OFF = os.path.join(RAW, "official")
DIRS = {"N": "N", "S": "S", "E": "E", "W": "W", "NORTH": "N", "SOUTH": "S", "EAST": "E", "WEST": "W"}
TYPES = set("ST STREET AVE AV AVENUE BLVD BOULEVARD RD ROAD DR DRIVE LN LANE CT COURT PL PLACE PKWY PARKWAY TER TRL TRAIL WAY HWY CIR "
            "CIRCLE PLZ SQ MALL BND PASS XING RUN ROW WALK RDG LOOP FWY FREEWAY EXPY EXPRESSWAY PIKE PK PKE".split())


def road(a):
    """One spelling for numbered roads. Virginia writes one road as 'Route 100', 'US 7', 'Rt 2', 'VA 100' or 'VA Route 100', so every
    numbered US or state route is 'SH n' (as in ri-eats); 'N INTERSTATE 95' = 'I-95'; 'COUNTY ROAD 5' = 'CR 5'."""
    a = re.sub(r"(\d)\s*&\s*(\d)", r"\1-\2", a.upper())
    a = re.sub(r"\b(US|VA|SR|SH|CR|I|IH|RT|RTE)-(\w)", r"\1 \2", a)
    a = re.sub(r"\b(?:INTERSTATE(?: HIGHWAY| HWY)?|IH|I H)\s*(?=\d)", "I ", a)
    a = re.sub(r"\b(?:US|U S)\s+(?:HIGHWAY|HWY)\b", "US", a)
    a = re.sub(r"\b(?:FARM[- ]TO[- ]MARKET(?: ROAD| RD)?|FARM (?:ROAD|RD)|F M)\b", "FM", a)
    a = re.sub(r"\b(?:RANCH[- ]TO[- ]MARKET(?: ROAD| RD)?|RANCH (?:ROAD|RD)|RR|RM)\b(?=\s*\d)", "RM", a)
    a = re.sub(r"\b(?:STATE (?:HIGHWAY|HWY|ROAD|RD|ROUTE|RTE)|SR|SH|VERMONT (?:ROUTE|RTE|HIGHWAY|HWY)|VA (?:ROUTE|RTE|RT|HIGHWAY|HWY)|VA|"
               r"US (?:ROUTE|RTE|RT)|US|ROUTE|RTE|RT|HWY)\b\.?(?=\s*\d)", "SH", a)
    a = re.sub(r"\b(?:COUNTY (?:HIGHWAY|HWY|ROAD|RD)|CO RD|CTY (?:HWY|RD)|CR)\b", "CR", a)
    a = re.sub(r"\bHIGHWAY\b", "HWY", a)
    return re.sub(r"\b(US|SH|CR|HWY|FM|RM|I) (\w+)\s*-\s*\w+", r"\1 \2", a)


ORD = {"FIRST": "1ST", "SECOND": "2ND", "THIRD": "3RD", "FOURTH": "4TH", "FIFTH": "5TH", "SIXTH": "6TH", "SEVENTH": "7TH",
       "EIGHTH": "8TH", "NINTH": "9TH", "TENTH": "10TH", "ELEVENTH": "11TH", "TWELFTH": "12TH"}


def street_key(a):
    """'2505 Monroe St' -> ('2505', 'MONROE'); '1000 OSAGE STREET' -> ('1000', 'OSAGE'); 'E Colfax Ave' keeps 'COLFAX'."""
    if not isinstance(a, str):
        return None, None
    a = re.sub(r"[.,#]", " ", road(a))
    # "20940-A North Frederick Ave": a hyphenated unit letter is part of the number (Maryland's Montgomery County wrote them so)
    m = re.match(r"^\s*(\d+)(?:-?[A-Z])?(?:\s*-\s*\d+[A-Z]?)?\s+(.*)$", a)
    if not m:
        return None, None
    words = [w for w in m.group(2).split() if w]
    if len(words) > 1 and words[0] in DIRS:
        words = words[1:]
    core = []
    for w in words:
        if w in TYPES and core:
            break
        core.append(w)
    core = [ORD.get(w, w) for w in core]
    return m.group(1), " ".join(core[:3]) or None


def street_compat(a, b):
    """Same street, or one is a whole-word prefix of the other: Boulder's 2025 set sometimes truncates ("1206 CENTAUR" = Centaur Village Dr)."""
    if not isinstance(a, str) or not isinstance(b, str) or not a or not b:
        return False
    return a == b or a.startswith(b + " ") or b.startswith(a + " ")


def street_nums(a):
    """'157-159 W Main St' -> {'157', '159'}; '2505 Monroe St' -> {'2505'}."""
    if not isinstance(a, str):
        return set()
    a = road(a)
    m = re.match(r"^\s*(\d+)[A-Z]?(?:\s*-\s*(\d+)[A-Z]?)?\s", a.upper() + " ")
    if not m:
        return set()
    lo = int(m.group(1)); hi = int(m.group(2)) if m.group(2) else lo
    if hi < lo:   # "1500-02"
        hi = int(str(lo)[: len(str(lo)) - len(m.group(2))] + m.group(2)) if m.group(2) else lo
    return {str(x) for x in range(lo, hi + 1, 2 if (hi - lo) % 2 == 0 else 1)} if 0 <= hi - lo <= 12 else {str(lo)}


def _names(*vals):
    out = []
    for v in vals:
        if not isinstance(v, str):
            continue
        v = re.sub(r"\s*\((?:MOBILE|MOBILE UNIT|COMMISSARY|CATERING|SPECIAL EVENT|SPEC EVENT|TEMP(?:ORARY)? EVENT|CP|INSIDE [^)]*)\)\s*$", "", v, flags=re.I)
        for part in re.split(r"\s*/\s*|\s+\bdba\b\s+|\s+&\s+(?=[A-Z][a-z])", v, flags=re.I):
            k = norm_name(re.sub(r"\b(?:LLC|INC|CORP|CORPORATION|LTD|CO)\b\.?", "", part, flags=re.I))
            if k and k not in out:
                out.append(k)
    return out


META = json.load(open(os.path.join(OFF, "meta.json"))) if os.path.exists(os.path.join(OFF, "meta.json")) else {}
LIST_DATE = (META.get("fairfax") or {}).get("fetched")   # the day we read Fairfax's feed (it carries no "updated" date of its own)
# Fairfax's own page for its inspection reports (map and search; reports post about two weeks after an inspection, kept two years)
MONT_PAGE = "https://www.fairfaxcounty.gov/health/food/inspection-reports"
# VDH's statewide inspection portal, every district's reports (search-only; robots.txt disallows crawlers, so it is only linked)
INSPECTIONS_URL = "https://inspections.myhealthdepartment.com/virginia"
# the Fairfax Health District's results, as it words them
RESULTS = ("Passed", "Partial Pass", "Failed - Self Closed", "Failed")
ONPREM_T = ()      # no alcohol license list (Virginia ABC's export is unused until Nick decides)


def liq_kind(t):
    """A license type as shown -> on-premises or retail (none in Virginia's data)."""
    if not isinstance(t, str):
        return None
    return "onprem" if t in ONPREM_T else "retail" if "package" in t or "off-premises" in t else None


COLUMNS = ["jur", "lic", "name", "dba", "holder", "keys", "addr", "city", "zip", "num", "street", "lat", "lon", "kind", "active", "ltype",
           "insp", "issued", "biz", "drinks", "county"]


def _zip(z):
    z = re.sub(r"\D", "", str(z or ""))
    return z[:5] if len(z) >= 5 else ""


def _addr(a):
    """'2790 VETERANS MEMORIAL BLVD STE 130' -> '2790 Veterans Memorial Blvd Ste 130'."""
    a = re.sub(r"\s+", " ", a or "").strip()
    return re.sub(r"\b([A-Z]{2,})\b", lambda m: m.group(1).title(), a)


def _city(c):
    return canon_city(" ".join(w.capitalize() for w in str(c or "").split())) if isinstance(c, str) and c.strip() else None


def _ms(v):
    """An ArcGIS date (epoch milliseconds, UTC) -> YYYY-MM-DD in Virginia's time (the district's own day)."""
    if not isinstance(v, (int, float)):
        return None
    d = datetime.datetime.fromtimestamp(v / 1000, datetime.timezone.utc) - datetime.timedelta(hours=4)
    return d.date().isoformat()


# Fairfax's categories that are a place to go out to eat; the rest (schools, child and adult care, caterers, commissaries, hotel
# breakfasts, grocery and convenience counters, hospitals, the jail, vending) stay out. A permit on George Mason's campus, Fort Belvoir
# or Dulles Airport is a campus, base or terminal stand.
FX_FOOD = {"Full Service Restaurant", "Fast Food Restaurant", "Carry Out Food Service", "Bakery"}
FX_NOT_PUBLIC = {"GEORGE MASON UNIVERSITY", "FORT BELVOIR", "WASHINGTON DULLES INTERNATIONAL AIRPORT"}


def load_fairfax():
    P = json.load(open(os.path.join(OFF, "fairfax", "permits.json")))
    by = {}
    for r in json.load(open(os.path.join(OFF, "fairfax", "inspections.json"))):
        if r.get("RECORDID") and r.get("INSPECTIONRESULT") in RESULTS:
            by.setdefault(r["RECORDID"], []).append([_ms(r.get("INSPECTIONDATE")), r["INSPECTIONRESULT"], None, r.get("INSPECTIONID")])
    rows = []
    for p in P:
        name = re.sub(r"\s+", " ", p.get("ESTABLISHMENT_NAME") or "").strip()
        cat, jur_ = p.get("CATEGORY_TYPE") or "", p.get("JURISDICTION") or ""
        kind = "food" if cat in FX_FOOD and jur_ not in FX_NOT_PUBLIC else "other"
        addr = _addr(p.get("PERMIT_ADDRESS"))
        num, st = street_key(addr)
        rows.append({"jur": "fairfax", "lic": "fairfax-" + p["RECORDID"], "name": name, "dba": name, "holder": None, "keys": _names(name),
                     "addr": addr, "city": _city(p.get("PERMIT_CITY")), "zip": _zip(p.get("PERMIT_ZIP")), "num": num, "street": st,
                     "lat": p.get("_lat"), "lon": p.get("_lon"), "kind": kind, "active": p.get("ESTABLISHMENT_STATUS") == "Active",
                     "ltype": "Fairfax Health District food establishment permit (" + cat + ")",
                     "insp": sorted(by.get(p["RECORDID"], []), key=lambda v: v[0] or "", reverse=True),
                     "issued": _ms(p.get("PERMIT_ISSUE_DATE")), "drinks": None, "county": None})
    return rows


def load():
    """Fairfax's permits, one row each, with their inspections (the only open records; see the docstring)."""
    rows = load_fairfax() if os.path.exists(os.path.join(OFF, "fairfax", "permits.json")) else []
    df = pd.DataFrame(rows) if rows else pd.DataFrame({c: pd.Series(dtype=object) for c in COLUMNS})
    for c_ in COLUMNS:
        if c_ not in df.columns:
            df[c_] = None
    df["lat"] = df["lat"].astype(float); df["lon"] = df["lon"].astype(float); df["active"] = df["active"].astype(bool)
    df["biz"] = np.arange(len(df))
    return df
