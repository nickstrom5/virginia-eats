# Old Dominion Eats (va-eats) — notes for Claude Code sessions

Built 2026-11-05 by a side session for Nick's "build Utah, Vermont, Virginia, West Virginia and Wyoming", ported from `../vt-eats/`
(itself from `../ut-eats/` and `../md-eats/`) with every fix to that day (the 10-29 all-states QA P0/P1s, Nevada's `name_key()` ids, the
exact-outline county lookup, the out-of-county truck rule, Utah's street-word merge fix, Vermont's narrowed "dejavu" rule). Local only:
git-ignored data, no repo, no remote, nothing published. Sources and calibration: `playbook/12-sources.md`. Brand:
`playbook/05-naming.md` — **provisional**, every choice waits for Nick ("Old Dominion Eats: Virginia Restaurants", Home Screen "Old
Dominion Eats"; "Virginia Eats" clashes with the Virginia Eats + Drinks magazine and radio show; a country ham biscuit icon, concept A,
on Blue Ridge navy; the landscape palette from `state-prompts/VIRGINIA_PROMPT.md`: navy #1F3A5F, cardinal #B0172B, peanut gold #E4A11B
fill only, dogwood cream; a band of three receding Blue Ridge ridgelines).

## Virginia is different
- **One open official list: the Fairfax Health District's** (Fairfax County, the Cities of Fairfax and Falls Church, Herndon, Vienna,
  Clifton), from Fairfax County's ArcGIS service (`fetch_official.py`): 3,909 permits with points and about two years of inspections
  with the district's own result (Passed, Partial Pass, Failed - Self Closed, Failed), shown in its words, dated, never a grade. Its
  restaurants (Full Service, Fast Food, Carry Out, Bakery; not schools, care homes, caterers, GMU, Fort Belvoir or Dulles) match the
  map listings (2,428) or come in on their own (272). VDH's statewide portal is search-only and robots.txt disallows crawlers: linked
  only. **Virginia ABC's** licensee export answers, but its terms (abc.virginia.gov) answer 403: not used, so "Serves alcohol" is
  unknown everywhere (Nick's call).
- **Counties:** 95 counties and 38 independent cities from Overture's land division areas; independent cities are named "City of X"
  so Fairfax city isn't Fairfax County. **Regions** (7): Northern Virginia, Richmond Region, Hampton Roads & the Eastern Shore,
  Fredericksburg & the Northern Neck, Central & Southside Virginia, Shenandoah Valley, Roanoke & Southwest Virginia.
- **Honors:** the MICHELIN Guide's D.C. edition lists two places in Washington, Virginia (The Inn at Little Washington, two stars;
  Patty O's Cafe & Bakery). James Beard: Sally Bell's Kitchen (America's Classics 2015), Patrick O'Connell (Lifetime Achievement 2019),
  Field & Main (2026 finalist), The Roosevelt and Smyrna (2026 semifinalists), Tremolo and Maude & the Bear (2025 semifinalists).
- **Guides** (tags in `virginia.py` TAGS; bits 1..128): biscuits & country ham, oyster bars, classic counters & diners, pollo a la brasa &
  pupusas, pho/banh mi & Korean BBQ, Brunswick stew (empty: no source yet), wine & hunt country, oldest (Red Fox Inn 1728, The Tavern in
  Abingdon 1779, Texas Tavern 1930). Sources: the Virginia Tourism Corporation's listings (found through virginia.org's sitemap, read by
  `scripts/read_vtc.py`), Visit Virginia's Blue Ridge, Tasting Table, jamesbeard.org, guide.michelin.com.
- **Adult rule:** a club whose name is all place and plain words ("Crystal City Restaurant", Arlington) matches only its own name, so
  its Crystal City neighbors stay.
- **Ranking:** "Featured first" (honors, then founding year), as everywhere until Nick decides on the all-factor Ranked score
  (`eats-ranked-score-all-states-proposal-2026-11-05.md` in the shared notes). The export already carries its inputs (hand-checked,
  honors, founding year, chain count, Fairfax's results); no health-grade wording anywhere.

## Rebuild
```bash
cd pipeline
../.venv/bin/python check_sources.py URL...   # a new host first
../.venv/bin/python fetch_overture.py && ../.venv/bin/python fetch_extras.py && ../.venv/bin/python fetch_official.py
../.venv/bin/python geocode_official.py && ../.venv/bin/python geocode_census.py && ../.venv/bin/python listings.py
../.venv/bin/python calibrate.py && ../.venv/bin/python virginia.py && ../.venv/bin/python build_research.py && ../.venv/bin/python virginia.py
VA_APP=1 ../.venv/bin/python virginia.py && cd .. && cp data/app/places.json data/app/detail-*.json VirginiaEats/Resources/
.venv/bin/python pipeline/check_websites.py --retry-transient   # link verification; re-export after
.venv/bin/python scripts/make-site.py && .venv/bin/python scripts/publish_app_data.py && .venv/bin/python scripts/publish_app_data.py --check
.venv/bin/python scripts/qa-site.py --static
```
(`listings.py` must run before `calibrate.py`, and `virginia.py` once before `build_research.py`, which matches names against
`site/virginia.json`.) The `.venv` is on the python.org framework Python 3.12 (Homebrew's python@3.12 is gone), with md-eats' versions.
`data/ucsd/meta-Virginia.json.gz` (Google 2021, private, web build only) comes from mcauleylab.ucsd.edu's googlelocal set.
`scripts/read_vtc.py` reads the Virginia Tourism Corporation's listings (one request per 1.5 s) into `data/research/raw/` (private).

## App, site, screenshots
- App: `VirginiaEats/` (XcodeGen `project.yml`, bundle `com.virginiaeats.ios`, display "Old Dominion Eats"), tests in `VirginiaEatsTests/` (data guards:
  adult venues, blocklisted and multi-URL websites, bad and legal names, non-restaurants, listed twice, no Google data; MICHELIN; the
  outline with D.C., Bristol and Bluefield). Run tests: `DEVELOPER_DIR="/Applications/Xcode 1.app/Contents/Developer" xcodebuild test ...
  CODE_SIGNING_ALLOWED=NO` on a temporary simulator. Archive only with Xcode 1.app (now 27.2, 27B52); Xcode.app is a beta.
  Run `xcodegen generate` after the export whenever the set of `Resources/*.json` files changes (an app built without them still
  compiles but opens on "Couldn't open the list").
- Site: `scripts/make-site.py` writes `docs/` and
  `playbook/site-numbers.json`; `scripts/explore.js` is the web app; `scripts/qa-site.py` the QA. Site URL for now:
  nickstrom5.github.io/virginia-eats (no CNAME). Rebuild the site before the unit tests: `ShareLinkTests` reads the web app's ids from `docs/`.
- OTA data: `docs/data/app/` via `scripts/publish_app_data.py` (`../OTA-DATA.md`).
- Screenshots: `scripts/capture-screenshots.sh <sim>` (ScreenshotMode pins downtown Richmond; Norfolk for oysters, Falls Church for
  pollo and pho, Middleburg for hunt country), then `scripts/site-images.sh`, then make-site + qa-site. App Store frames:
  `scripts/appstore-screenshots.py`. Icons: `scripts/icon-concepts.swift` (A country ham biscuit, B oyster on the half shell, C peanut;
  all pass `state-prompts/icon-style/check.swift`) and `scripts/make-brand.swift`.
- Not ported: the App Store listing writer and the private Google-2021 leaderboard. `site/` holds the leaderboard's data and is
  git-ignored with `data/`.

## Fixes after the first build (2026-11-05)
- **UI test:** the "my location" map check used Baltimore's Inner Harbor (from md-eats); now this state's own downtown.
- **Last full run** 2026-11-05: app 17,918 places / 17,486 restaurants, 49 unit tests on iPhone 17 Pro Max (iOS 27.0), 13 iPhone +
  6 iPad screens, `qa-site.py --static` OK, OTA 2026-11-05.1 (local only).
- **ZIPs:** the export (`pipeline/virginia.py`, the place's `z` and the address-strip pattern) still kept only Maryland's 206xx-219xx, carried
  from md-eats, so the app showed addresses without a ZIP and ZIP search found little. Now this state's own range (201xx and 220xx-246xx); the
  detail screenshot was re-captured.
- **Web app:** `scripts/explore.js`'s place panel named Utah's "Department of Alcoholic Beverage Services" as the liquor licensor (a
  ut-eats leftover); it now says what the app's PlaceDetailView says.

## Rules
No commits, pushes, public repos, App Store Connect or DNS changes without Nick's yes each time; never submit for review or accept
agreements; never publish Google-derived data. Support email nick@eatsranked.com. Commit author "Nick Soderstrom"
<329204362+nickstrom5@users.noreply.github.com> via `-c user.name -c user.email`.
