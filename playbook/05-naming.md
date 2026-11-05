# Old Dominion Eats: name, icon and palette (provisional, 2026-11-05; Nick decides)

## Name
- **Old Dominion Eats** (App Store name "Old Dominion Eats: Virginia Restaurants", Home Screen "Old Dominion Eats"). A web search
  (2026-11-05) found no business, app or publication by that name; the nickname is shared with Old Dominion University, ODFL and
  Dominion Energy (the prompt's caution).
- Avoided: **Virginia Eats**: Virginia Eats + Drinks is a statewide magazine and a WNIS radio show (Patrick Evans-Hylton), the same kind
  of clash as "Louisiana Eats!". Also avoided: any "Virginia is for…" play (Virginia Tourism's trademark), "Virginia Grown", "Virginia's
  Finest", "Cavalier", "Hokie".
- **Watch out:** a restaurant called **Dominion Eats** (1038 Spring Hill Rd, McLean) is in the app's own data, one word from the app's
  name. scripts/qa-site.py excludes "Old Dominion Eats" from its named-places check so the brand doesn't trip it; the McLean place is
  a real near-clash for Nick to weigh.
- Alternative for Nick: **Commonwealth Eats** (KY, MA and PA are commonwealths too).

## Icon (state-prompts/ICON-STYLE.md; all three pass state-prompts/icon-style/check.swift)
- **A, chosen provisionally: a country ham biscuit**, a split biscuit with a slice of ham, on Blue Ridge navy.
- B: an oyster on the half shell with a lemon wedge (distinct from Maryland's crab).
- C: a peanut in the shell, lying level.
Drawn by `scripts/icon-concepts.swift`; `scripts/make-brand.swift` makes the app icon, the site icons and docs/og.png from A.

## Palette (the prompt's landscape palette; no in-state major-league team)
Blue Ridge navy #1F3A5F (11.5:1 on white) for titles, tint and the icon background; cardinal red #B0172B (white on it 7.0:1) for the
hand-checked guide cards and honors chips; peanut gold #E4A11B only as a fill under navy text (5.2:1); dogwood cream #FBF7EE pages.
Header band: three receding Blue Ridge ridgelines over a cardinal baseline.
