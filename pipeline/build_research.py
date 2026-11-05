"""Writes data/research/app/*.json (hand-checked Virginia guides), data/research/michelin.json, jbf.json and closed.json from the
compact lists below. Ported from vt-eats/pipeline/build_research.py.

Each entry cites the page that names it, read on 2026-11-05: an official Virginia tourism listing (www.virginia.org/listing/<slug>/<id>,
the Virginia Tourism Corporation's per-business pages, read by scripts/read_vtc.py; robots allows them), a regional tourism office's
listing (Visit Virginia's Blue Ridge), or a page dated 2025-26 on a robots-checked host (check_sources.py). The address comes from the
map listing we already hold for that name in that town (site/virginia.json); a name that isn't found exactly once in its town (or at the
street number given) is left out and listed in data/research/app/LEADS.md. A place the map data doesn't show as a place to eat is
added only with a street address from its official listing or our own map data (ADDR).
Usage: ../.venv/bin/python build_research.py   (then virginia.py)"""
import json, os, re
from brands import brand_of
from common import norm_name
ROOT = os.path.join(os.path.dirname(__file__), "..")
R = os.path.join(ROOT, "data", "research")
d = json.load(open(os.path.join(ROOT, "site", "virginia.json")))
C, M = d["cols"], d["meta"]
norm = lambda s: re.sub(r"\s+", " ", re.sub(r"[^a-z0-9 ]", " ", (s or "").lower().replace("'", "").replace("’", ""))).strip()

# each dated on its face, or an official tourism page (read 2026-11-05)
L = lambda path: f"https://www.virginia.org/listing/{path}/"                                         # Virginia Tourism Corporation listing
VR_TEXAS = "https://www.visitroanokeva.com/listings/texas-tavern/5887/"                             # Visit Virginia's Blue Ridge listing
TT_OLDREST = "https://www.tastingtable.com/1975409/oldest-restaurant-every-state-still-open/"          # 2025-09-23
TT_OLDBAR = "https://www.tastingtable.com/1786324/oldest-bar-every-state/"                          # 2025-02-17
MI_VA = "https://guide.michelin.com/us/en/virginia/restaurants"                                      # the D.C. guide's two Virginia places
JBF26 = "https://www.jamesbeard.org/stories/james-beard-award-semifinalists-2026"                   # 2026-01-21
JBF26N = "https://www.jamesbeard.org/stories/james-beard-awards-restaurant-and-chef-nominees-2026"  # 2026-03-31
JBF25 = "https://www.jamesbeard.org/stories/the-2025-james-beard-award-semifinalists"               # 2025-01-22
JBF15_SB = "https://www.jamesbeard.org/stories/2015-americas-classics-sally-bells-kitchen"            # 2015 America's Classics
JBF19_PO = "https://www.jamesbeard.org/stories/2019-lifetime-achievement-award-winner-patrick-oconnell"  # 2019 Lifetime Achievement

# (name as the source writes it or as our listing spells it, town as our listing has it, street number to pick the location (or
# None), note, founded, founded_note, [sources])
RIC, NOR = "Richmond", "Norfolk"
GUIDES = {
 "ham biscuit": [   # Virginia Tourism's listings that name country ham biscuits or a biscuit kitchen
  ("Virginia Diner", "Wakefield", "408", "Country ham on buttermilk biscuits at breakfast; family dining here since 1929.", None, None, [L("virginia-diner-restaurant/2513")]),
  ("Michie Tavern ca. 1784", "Charlottesville", "683", "Country ham biscuits in the 1784 Pub, in the tavern's oldest section, in the late afternoon.", None, None,
   [L("michie-tavern-1784-pub/2903"), L("michie-tavern-dining/1885")]),
  ("Dishman's Corner Store", "Woodford", None, "A renovated country store whose menu has country ham biscuits and thick-slab bacon.", None, None, [L("dishmans-corner-store/12825")]),
  ("Early Bird Biscuit Company", RIC, "119", "A new specialty biscuit every day, savory or sweet.", None, None, [L("early-bird-biscuit-company/3474")]),
  ("Handsome Biscuit", NOR, "2511", "More than ten biscuit sandwiches, built on sweet potato biscuits.", None, None, [L("handsome-biscuit/1895")]),
  ("Scratch Biscuit Company", "Roanoke", "1820", "Southern biscuits made from scratch, for breakfast.", None, None, [L("scratch-biscuit-company/1819")]),
  ("Buford's Biscuits", "Leesburg", "7", "Cathead biscuits and simple Southern food, sourced locally.", None, None, [L("bufords-biscuits/29978")]),
 ],
 "oyster bar": [
  ("A W Shucks Raw Bar & Grill", NOR, "2200", "A family raw bar and grill on Colonial Avenue.", None, None, [L("a-w-shucks-raw-bar-%26-grill/3543")]),
  ("Big Easy Grill & Oyster Bar", NOR, "111", "An oyster bar with French Old World technique downtown.", None, None, [L("big-easy-grill-%26-oyster-bar/1321")]),
  ("Chick's Oyster Bar", "Virginia Beach", "2143", "A Lynnhaven waterfront bar whose menu is heavy on oysters.", None, None, [L("chicks-oyster-bar/630")]),
  ("Fish Hawk Oyster Bar", "Irvington", "480", "At the Tides Inn: a raw bar, live shucking and beachside oyster roasts.", None, None, [L("fish-hawk-oyster-bar/2413")]),
  ("Hank's Oyster Bar", "Alexandria", "1026", "Old Town's coastal kitchen since 2005: oysters, lobster rolls and meat 'n' two.", None, None, [L("hanks-oyster-bar/1432")]),
  ("King Street Oyster Bar", "Leesburg", "12", "Shucked oysters and fish dishes in downtown Leesburg, with a covered patio.", None, None,
   [L("king-street-oyster-bar/1815"), L("king-street-oyster-bar/30291")]),
  ("Public Fish & Oyster", "Charlottesville", "513", "East Coast seafood and a raw bar on West Main.", None, None, [L("public-fish-%26-oyster/821")]),
  ("Oyster Farm Seafood Eatery", "Cape Charles", "500", "Seafood on the Chesapeake Bay shore at Kings Creek.", None, None, [L("the-oyster-farm-seafood-eatery/2246")]),
  ("Hooked Seafood & Raw Bar", "Mechanicsville", "6078", "A locally owned seafood restaurant and raw bar.", None, None, [L("hooked-seafood-%26-raw-bar/34973")]),
  ("Fish & Slips Marina Raw Bar & Grill", "Portsmouth", "10", "A marina raw bar on the Elizabeth River: lump crab, crab legs and oysters.", None, None,
   [L("fish-%26-slips-marina-raw-bar-%26-grill/1604")]),
 ],
 "classic counter": [
  ("Texas Tavern", "Roanoke", "114", "A ten-seat lunch counter open around the clock: chili, hot dogs and the Cheesy Western.", 1930,
   "Visit Virginia's Blue Ridge listing: a Roanoke landmark since 1930, run by the Bullington family for four generations.", [VR_TEXAS]),
  ("Sally Bell's Kitchen", RIC, "2337", "Box lunches, cupcakes and potato salad to take out; a James Beard America's Classic (2015).", None, None,
   [L("sally-bell%e2%80%99s-kitchen/3692"), JBF15_SB]),
  ("Doumar's Cones and Barbecue", NOR, "1919", "Waffle cones and barbecue on Monticello Avenue.", None, None, [L("doumars-cones-%26-barbecue/3809")]),
  ("Frost Diner", "Warrenton", "55", "A historic silver diner with home-style cooking.", None, None, [L("frost-diner/3409")]),
  ("Bob & Edith's Diner", "Arlington", "2310", "An old-school diner on Columbia Pike, open around the clock; the Boltons bought it in 1969.", None, None,
   [L("bob-%26-ediths-diner/1456")]),
  ("Exmore Diner", "Exmore", "4264", "An Eastern Shore favorite on U.S. 13 for decades.", None, None, [L("exmore-diner/2850")]),
  ("Virginia Diner", "Wakefield", "408", "Family dining in Wakefield since 1929, open for breakfast, lunch and dinner.", None, None, [L("virginia-diner-restaurant/2513")]),
 ],
 "pollo a la brasa": [
  ("King Pollo of Chantilly", "Chantilly", "4080", "Peruvian charcoal rotisserie chicken; the chain began in Sterling in 2008.", None, None, [L("king-pollo/33978")]),
  ("Peru 703", "Chantilly", "5005", "A Peruvian restaurant in Chantilly.", None, None, [L("peru-703/24607")]),
  ("Spin Pollo", "Falls Church", "6672", "Peruvian chicken and dishes.", None, None, [L("spin-pollo/24682")]),
  ("Perfect Pollo", "Ashland", "11657", "Pollo a la brasa from a chef with twenty years in restaurants.", None, None, [L("perfect-pollo/29810")]),
 ],
 "pupusas": [
  ("Rosita's Tienda y Pupuseria", "Colonial Heights", "2231", "A Latin American store with pupusas to go.", None, None, [L("rosita%e2%80%99s-tienda-y-pupuseria/26624")]),
  ("Pupuseria Los Robles", "Stanardsville", "76", "Salvadoran cooking on Main Street.", None, None, [L("los-robles-pupuseria-and-restaurant/29137")]),
 ],
 "vietnamese korean": [
  ("Banh Mi So 1", "Falls Church", "6799", "Fresh-baked banh mi at the Eden Center, famous for its ham and pâté combination.", None, None,
   [L("banh-mi-so-1/23184"), L("eden-center/19106")]),
  ("Pho 75", "Falls Church", "3103", "Big bowls of pho with a long-simmered broth.", None, None, [L("pho-75/31833")]),
  ("Kogiya Korean BBQ", "Annandale", None, "Korean barbecue in Annandale: marbled short ribs and pork belly.", None, None, [L("kogiya-korean-bbq/24724")]),
  ("Ingle Korean Steakhouse", "Vienna", "8369", "A Korean steakhouse in Tysons.", None, None, [L("ingle-korean-steakhouse/26194")]),
  ("Gogi 92 Korean BBQ", "Leesburg", None, "Korean barbecue at the Village at Leesburg.", None, None, [L("gogi-92-korean-bbq/30214")]),
  ("The WOO Korean BBQ & Cuisine", "Fairfax", "4070", "Upscale Korean barbecue.", None, None, [L("the-woo-korean-bbq-%26-cuisine/35541")]),
  ("Pho Tay Do", RIC, "6328", "A family-owned pho shop on Rigsby Road.", None, None, [L("pho-tay-do/26450")]),
  ("Vietnam One", RIC, "6215", "Vietnamese noodles and barbecue on West Broad.", None, None, [L("vietnam-one/27155")]),
 ],
 "wine country": [
  ("Red Fox Inn & Tavern", "Middleburg", None, "A fieldstone inn and tavern in Middleburg, in the heart of hunt country.", 1728,
   "Tasting Table's oldest restaurant in every state (September 2025): Virginia's is the Red Fox Inn & Tavern, first opened in 1728.",
   [TT_OLDREST, L("red-fox-inn-%26-tavern/8277")]),
  ("The Inn at Little Washington", "Washington", None, "Patrick O'Connell's country inn: two MICHELIN stars and a 14,000-bottle cellar.", None, None,
   [L("inn-at-little-washington-dining/2845"), MI_VA]),
  ("Goodstone Inn & Restaurant", "Middleburg", "36205", "A country inn and restaurant in Virginia's wine and hunt country.", None, None, [L("goodstone-inn-%26-restaurant/8889")]),
  ("Field & Main Restaurant", "Marshall", "8369", "A James Beard finalist in 2026 for its wine and beverage program.", None, None, [JBF26N, JBF26]),
 ],
 "oldest": [
  ("The Tavern", "Abingdon", "222", "Dinner in Abingdon's oldest building, a tavern and inn from its beginning.", 1779,
   "Tasting Table's oldest bar in every state (February 2025) and Virginia Tourism's listing: built in 1779 and used as a tavern from the start.",
   [TT_OLDBAR, L("the-tavern-restaurant-in-abingdon/3383")]),
 ],
}
# street addresses for places the map data doesn't show as a place to eat: from the official listing, or our own map listing for it
ADDR = {("Dishman's Corner Store", "Woodford"): "4539 Fredericksburg Turnpike", ("Red Fox Inn & Tavern", "Middleburg"): "2 E Washington St",
        ("The Inn at Little Washington", "Washington"): "309 Middle St", ("Gogi 92 Korean BBQ", "Leesburg"): "1603 Village Market Blvd SE"}
CUISINE = {("Dishman's Corner Store", "Woodford"): "Sandwiches & Deli", ("Red Fox Inn & Tavern", "Middleburg"): "American & Other",
           ("The Inn at Little Washington", "Washington"): "European", ("Texas Tavern", "Roanoke"): "Burgers",
           ("Sally Bell's Kitchen", RIC): "Sandwiches & Deli"}
KINDS = {k: [k] for k in ("ham biscuit", "oyster bar", "classic counter", "pollo a la brasa", "pupusas", "vietnamese korean", "wine country", "oldest")}

# MICHELIN: no Virginia guide; the D.C. guide lists two places in Washington, Virginia (guide.michelin.com, 2026-11-05)
MICHELIN = [("The Inn at Little Washington", "Washington", "2 Stars", "French"), ("Patty O's Cafe & Bakery", "Washington", "Recommended", "European")]
MI_MATCH = {"Patty O's Cafe & Bakery": ["PATTY OS CAFE"]}
MI_UT = MI_VA
# James Beard (facts with sources): Virginia's wins named on jamesbeard.org pages we read, and its 2025-26 nominees (finalists) and
# semifinalists; no Virginia winner in 2025 or 2026
MID = "Best Chef: Mid-Atlantic"
JBF = [{"name": "Sally Bell's Kitchen", "city": RIC, "honors": ["America's Classics 2015"], "sources": [JBF15_SB]},
       {"name": "The Inn at Little Washington", "city": "Washington", "address": "309 Middle St",
        "honors": ["Lifetime Achievement winner 2019 (Patrick O'Connell)"], "sources": [JBF19_PO]},
       {"name": "Field & Main Restaurant", "city": "Marshall", "honors": ["Outstanding Wine and Other Beverages Program finalist 2026"], "sources": [JBF26N, JBF26]},
       {"name": "The Roosevelt", "city": RIC, "honors": [f"{MID} semifinalist 2026 (Leah Branch)"], "sources": [JBF26]},
       {"name": "Smyrna", "city": "Charlottesville", "address": "707 W Main St", "honors": [f"{MID} semifinalist 2026 (Tarik Sengul)"], "sources": [JBF26]},
       {"name": "Tremolo", "city": "Middleburg", "honors": [f"{MID} semifinalist 2025 (Jarad Slipp)"], "sources": [JBF25], "match_names": ["TREMOLO BAR"]},
       {"name": "Maude & the Bear", "city": "Staunton", "honors": ["Best New Restaurant semifinalist 2025"], "sources": [JBF25]}]
# closed, each with a source (none verified this pass)
CLOSED = []


def key(s):
    """The name key without a leading "the": "Varsity" is our "The Varsity"."""
    return re.sub(r"^the ", "", norm(s))


def find(name, town, num):
    k = key(name)
    hits = [i for i, n in enumerate(C["name"]) if C["city"][i] is not None and M["cities"][C["city"][i]] == town
            and (key(n) == k or key(n).startswith(k + " ") or k.startswith(key(n) + " ") or key(n).replace(" ", "") == k.replace(" ", "")
                 or (key(n).split()[:2] == k.split()[:2] and len(k.split()) >= 2))]
    if num:
        hits = [i for i in hits if (C["addr"][i] or "").split(" ")[0] == num]
    return hits


leads, n_out = [], {}
for kind, rows in GUIDES.items():
    out = []
    for name, town, num, note, founded, fnote, srcs in rows:
        hits = find(name, town, num)
        if not hits and (name, town) in ADDR:
            out.append({"name": name, "address": ADDR[(name, town)], "city": town, "zip": None, "kinds": KINDS[kind], "dishes": [], "note": note,
                        "founded": founded, "founded_note": fnote, "website": None, "open": True, "evidence_date": "2026-10",
                        "sources": srcs, "match_names": []} | ({"cuisine": CUISINE[(name, town)]} if (name, town) in CUISINE else {}))
            continue
        if len(hits) != 1:
            leads.append(f"- {kind}: {name} ({town}{', ' + num if num else ''}) — {len(hits)} matches in our data; not added"); continue
        i = hits[0]
        out.append({"name": C["name"][i], "address": C["addr"][i], "city": town, "zip": str(C["zip"][i]) if C["zip"][i] else None,
                    "kinds": KINDS[kind], "dishes": [], "note": note, "founded": founded, "founded_note": fnote, "website": None, "open": True,
                    "evidence_date": "2026-10", "sources": srcs, "match_names": [name.upper()] if norm(name) != norm(C["name"][i]) else []})
        if brand_of(norm_name(name)):   # a chain shows under its own spelling at every branch, whatever the listing says
            out[-1]["display"] = name
        if (name, town) in CUISINE:
            out[-1]["cuisine"] = CUISINE[(name, town)]
    fn = re.sub(r"[^a-z]+", "_", kind).strip("_")
    json.dump(out, open(f"{R}/app/{fn}.json", "w"), indent=1, ensure_ascii=False)
    n_out[kind] = len(out)

MI_ADDR = {"The Inn at Little Washington": "309 Middle St", "Patty O's Cafe & Bakery": "389 Main St"}
json.dump({"restaurants": [{"name": n, "address": MI_ADDR.get(n), "city": t, "zip": None, "distinction": dist, "cuisine": cu, "green_star": False,
                             "michelin_url": MI_UT, "sources": [MI_UT], "match_names": [x.upper() for x in MI_MATCH.get(n, [])], "open": True}
                            for n, t, dist, cu in MICHELIN]}, open(f"{R}/michelin.json", "w"), indent=1, ensure_ascii=False)
json.dump([dict({"address": None}, **j, zip=None, open=True) for j in JBF], open(f"{R}/jbf.json", "w"), indent=1, ensure_ascii=False)
json.dump(CLOSED, open(f"{R}/closed.json", "w"), indent=1, ensure_ascii=False)
open(f"{R}/app/LEADS.md", "w").write("# Virginia research leads (not yet verified)\n\nWritten by pipeline/build_research.py.\n\n" + "\n".join(leads) + """

## Waiting for a source we may use, or for the map data
- Brunswick stew: no 2025-26 page or tourism listing found that names a restaurant serving it (the guide stays empty until three do).
- Oldest: the Virginia Diner (since 1929) and Sally Bell's Kitchen (since 1924) moved since they opened, and Michie Tavern was moved to
  its site in 1927, so none gets an "open here since" year; Doumar's cone story is the listing's claim, not ours.
- Honors: Peter Chang (Outstanding Chef finalist 2022) is tied to no one restaurant on jamesbeard.org; The Inn at Little Washington's
  1993 Outstanding Restaurant award is on jamesbeard.org's search, not a page we read.
- Alcohol: Virginia ABC's statewide licensee export (salicenseeexport.blob.core.windows.net) answers, but its terms page on
  abc.virginia.gov answers 403 (Cloudflare): Nick's call.
- Blocked or unusable hosts: richmondmagazine.com, virginialiving.com, pilotonline.com, eater.com and styleweekly.com disallow Claude's
  fetcher; richmond.com isn't reachable from the search tool; inspections.myhealthdepartment.com disallows all crawlers (linked only).
""")
print(n_out, "| leads:", len(leads))
for l in leads: print(l)
