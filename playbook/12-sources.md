# Virginia sources and calibration (checked 2026-11-05)

## Official sources
| Source | What it has | Can a script read it? | Used |
|---|---|---|---|
| Fairfax Health District (Fairfax County GIS, gispub2 .../Health/PermittedFoodEstablishments/FeatureServer) | layer 0: 3,909 permits with a point (category, jurisdiction, status); table 1: 13,312 inspections 2024-11-04 to 2026-10-25 with the district's result | yes (ArcGIS REST; GIS disclaimer: "provided as a public resource", no warranty) | yes: 2,428 listings matched, 272 permit-only restaurants added, 2,4xx results shown |
| VDH inspection portal (inspections.myhealthdepartment.com/virginia) | every district's reports | no: search-only, robots.txt disallows all crawlers | linked from every place |
| Virginia ABC licensee export (salicenseeexport.blob.core.windows.net/export/LicenseSearchReport.xlsx, 12.5 MB, updated daily) | statewide licensees | answers a plain request, but abc.virginia.gov (its terms) answers 403 behind Cloudflare | no: Nick's call |
| Arlington "Food Service Inspections" (data.arlingtonva.us/dataset/42) | 2016-2018 only | yes | no (history, never current) |

Fairfax's STAMP field (213 "Yes") isn't documented in the metadata: not used.

## Calibration
- BLS QCEW: 17,410 private NAICS 722 establishments (2025 average, per the prompt). Overture: 35,614 eating and drinking listings in
  Virginia's box; 35,333 after cleaning; the family's keep rule keeps 17,992; the App Store build ships **17,918 places, 17,486
  restaurants** (133 county-equivalents, 7 regions).
- Fairfax: 3,097 of its 3,909 permits are places to go out to eat; 2,428 matched a map listing.
- Google 2021 (private, web build only): 22,711 Virginia food listings, 17,613 matched.

## Research sources (each place cites its own; data/research/app/*.json)
- The Virginia Tourism Corporation's per-business listings, www.virginia.org/listing/<slug>/<id> (20,066 in its sitemap; robots allows
  them), read by scripts/read_vtc.py, one request per 1.5 s; Visit Virginia's Blue Ridge (Texas Tavern).
- Tasting Table: oldest restaurant in every state (2025-09-23: Red Fox Inn & Tavern, 1728) and oldest bar (2025-02-17: The Tavern,
  Abingdon, 1779).
- jamesbeard.org: 2026 semifinalists and nominees, 2025 semifinalists, the 2015 America's Classics post (Sally Bell's Kitchen), the 2019
  Lifetime Achievement post (Patrick O'Connell).
- guide.michelin.com's Virginia page: two places in Washington, Virginia (the D.C. guide).
- Not usable: richmondmagazine.com, virginialiving.com, pilotonline.com, eater.com, styleweekly.com (robots disallow Claude's fetcher).
