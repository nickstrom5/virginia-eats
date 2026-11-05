"""Download the Overture Maps extracts that virginia.py reads -> data/va/

- overture_va_bbox.parquet     every place in Virginia's bounding box (name, category, address, point)
- overture_va_sources.parquet  which datasets each Virginia eating/drinking listing came from (Meta, Foursquare, ...)
- va_shapes.json               simplified state and county outlines for the map
- va_state_detail.geojson      the state outline at full detail, for the in-state test

Reads the public Overture bucket over S3 with DuckDB (no account needed). Ported from vt-eats/pipeline/fetch_overture.py.
Virginia: land division areas; the "counties" are Virginia's 95 counties and 38 independent cities (each its own county-equivalent:
Fairfax city is not Fairfax County). The Eastern Shore and the Chesapeake islands (Tangier, Chincoteague) stay in. The script checks the
islands and the towns on the lines with D.C., Maryland, West Virginia, Tennessee and North Carolina (Bristol, Virginia is in; Bristol,
Tennessee is out).
"""
import os, json, time
import duckdb
from shapely import wkb
from shapely.geometry import mapping, Polygon

RELEASE = "2026-10-21.0"
OUT = os.path.join(os.path.dirname(__file__), "..", "data", "va")
# Virginia (42.73°N–45.02°N, 71.46°W–73.44°W) plus a margin for the border towns (Derby Line, the Upper Valley, Bennington's New York
# Virginia (36.54°N–39.47°N, 75.24°W–83.68°W) plus a margin for the border towns (Bristol, Bluefield, the D.C. line, Chincoteague)
BBOX = "bbox.xmin BETWEEN -83.8 AND -75.1 AND bbox.ymin BETWEEN 36.4 AND 39.6"
EAT = "('restaurant','casual_eatery','bar','fast_food_restaurant','coffee_shop','cafe','smoothie_juice_bar','brewery','food_court')"
os.makedirs(OUT, exist_ok=True)

con = duckdb.connect()
con.execute("INSTALL httpfs; LOAD httpfs; INSTALL spatial; LOAD spatial; SET s3_region='us-west-2';")
places = f"s3://overturemaps-us-west-2/release/{RELEASE}/theme=places/type=place/*.parquet"

t = time.time()
if not os.path.exists(f"{OUT}/overture_va_bbox.parquet"):
    con.execute(f"""
COPY (
  SELECT id, names.primary AS name, basic_category AS cat, taxonomy.primary AS tax, taxonomy.hierarchy AS hier, confidence,
         operating_status AS status, brand.names.primary AS brand, addresses[1].freeform AS street, addresses[1].locality AS city,
         addresses[1].postcode AS zip, addresses[1].region AS region, ST_Y(geometry) AS lat, ST_X(geometry) AS lon, websites[1] AS web,
         phones[1] AS phone
  FROM read_parquet('{places}', hive_partitioning=1) WHERE {BBOX}
) TO '{OUT}/overture_va_bbox.parquet' (FORMAT PARQUET)""")
    print("places in bbox", round(time.time() - t), "s", flush=True)
if not os.path.exists(f"{OUT}/overture_va_sources.parquet"):
    con.execute(f"""
COPY (
  SELECT id, list_transform(sources, lambda x: x.dataset) AS ds, list_transform(sources, lambda x: x.update_time) AS ut,
         list_transform(sources, lambda x: x.record_id) AS rid,
         len(socials) AS n_soc, len(websites) AS n_web, len(phones) AS n_ph
  FROM read_parquet('{places}', hive_partitioning=1)
  WHERE {BBOX} AND basic_category IN {EAT}
) TO '{OUT}/overture_va_sources.parquet' (FORMAT PARQUET)""")
    print("sources", round(time.time() - t), "s", flush=True)

areas = f"s3://overturemaps-us-west-2/release/{RELEASE}/theme=divisions/type=division_area/*.parquet"
rows = con.execute(f"""
  SELECT subtype, names.primary AS name, ST_AsWKB(geometry) AS g
  FROM read_parquet('{areas}', hive_partitioning=1)
  WHERE country = 'US' AND region = 'US-VA' AND subtype IN ('region', 'county') AND class = 'land'
    AND bbox.xmin > -83.9 AND bbox.xmax < -75.0 AND bbox.ymin > 36.3 AND bbox.ymax < 39.7""").fetchall()
# an independent city is its own county-equivalent: "City of Richmond" is not Richmond County, "City of Fairfax" not Fairfax County
rows = [(sub, name if sub == "region" or name.endswith("County") else "City of " + name, g) for sub, name, g in rows]


def rings(geom, tol, min_area):
    geom = geom.simplify(tol, preserve_topology=True)
    polys = [p for p in getattr(geom, "geoms", [geom]) if p.geom_type == "Polygon" and p.area >= min_area]
    return [[[round(x, 3), round(y, 3)] for x, y in p.exterior.coords] for p in polys]


out = {"state": None, "counties": []}
for sub, name, g in rows:
    geom = wkb.loads(bytes(g)).buffer(0)
    if sub == "region":
        json.dump(mapping(geom.simplify(0.0005, preserve_topology=True)), open(f"{OUT}/va_state_detail.geojson", "w"))
        out["state"] = [[r] for r in rings(geom, 0.002, 0.000005)]
    else:
        out["counties"].append({"name": name, "c": rings(geom, 0.004, 0.00002)})
# full-detail county polygons for assigning each place to a county (not shipped)
json.dump({name: mapping(wkb.loads(bytes(g)).buffer(0).simplify(0.0003, preserve_topology=True))
           for sub, name, g in rows if sub == "county"}, open(f"{OUT}/va_counties_detail.geojson", "w"))
json.dump(out, open(f"{OUT}/va_shapes.json", "w"), separators=(",", ":"))
print("outlines: state", len(out["state"] or []), "rings +", len(out["counties"]), "counties;", round(time.time() - t), "s total")
# islands, shores and border towns: each must fall on the right side of the detailed state outline
from shapely.geometry import shape, Point
st = shape(json.load(open(f"{OUT}/va_state_detail.geojson")))
for nm, lon, lat, want in [("Chincoteague (inland)", -75.3650, 37.9400, True), ("Tangier Island", -75.9930, 37.8260, True), ("Virginia Beach", -75.9780, 36.8530, True),
                           ("Arlington", -77.0910, 38.8816, True), ("Alexandria", -77.0469, 38.8048, True), ("Washington, DC", -77.0365, 38.8977, False),
                           ("Lovettsville", -77.6372, 39.2726, True), ("Harpers Ferry, WV", -77.7389, 39.3254, False), ("Winchester", -78.1633, 39.1857, True),
                           ("Bristol, VA", -82.1617, 36.6083, True), ("Bristol, TN", -82.1888, 36.5823, False), ("Bluefield, VA", -81.2709, 37.2501, True),
                           ("Bluefield, WV", -81.2223, 37.2698, False), ("Danville", -79.3950, 36.5860, True), ("Eden, NC", -79.7664, 36.4882, False)]:
    ok = st.contains(Point(lon, lat))
    print(f"  {nm}: {'inside' if ok else 'outside'}{'' if ok == want else '  <-- WRONG'}")
print("counties:", len(out["counties"]), sorted(c["name"] for c in out["counties"]))

# the neighbours' land (North Carolina, Tennessee, Kentucky, West Virginia, Maryland, D.C.): listings.py widens Virginia's outline ~300 m
# for shores, but only where no neighbour's land is, so a Bristol, TN or D.C. listing on the far side of the line stays out
nb = con.execute(f"""
  SELECT region, ST_AsWKB(geometry) FROM read_parquet('{areas}', hive_partitioning=1)
  WHERE country = 'US' AND region IN ('US-NC', 'US-TN', 'US-KY', 'US-WV', 'US-MD', 'US-DC') AND subtype = 'region' AND class = 'land'""").fetchall()
from shapely.ops import unary_union
from shapely.geometry import box
near = box(-83.9, 36.3, -75.0, 39.7)
nbg = unary_union([wkb.loads(bytes(g)).buffer(0).intersection(near) for _, g in nb])
json.dump(mapping(nbg.simplify(0.0002, preserve_topology=True)), open(f"{OUT}/va_neighbors.geojson", "w"))
print("neighbours:", sorted(r for r, _ in nb))
