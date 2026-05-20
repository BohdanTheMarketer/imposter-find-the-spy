# App Store screenshots (iPhone + iPad)

## iPhone (6.5″ fallback slot)

Apple accepts **1284 × 2778** px portrait (among others). Raw captures from a 6.7″ simulator are often **1290 × 2796** — resize before upload.

```bash
./scripts/resize-app-store-screenshots.sh ./docs/app-store-raw iphone
```

Output: `docs/app-store-raw/app-store-1284x2778/`

## iPad

If the app runs on iPad, Connect requires **at least one** iPad screenshot set. Apple documents several sizes; two common **portrait** targets:

| Preset   | Size (portrait) | When to use |
|----------|-----------------|-------------|
| `ipad13` | **2064 × 2752** | 13″ iPad Pro / Air (listed first for that display class) |
| `ipad`   | **2048 × 2732** | Still valid; scales for 13″ if you don’t ship 2064 |
| `ipad11` | **1668 × 2388** | Optional 11″ slot |

Official reference: [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/) (iPad section).

### Workflow

1. **Figma:** export **four** separate portrait panels (your iPad strip), or one wide artboard then slice — each final asset should fill one Connect slot (not one ultra-wide PNG unless Connect accepts it for iPad — normally you upload **1–10 separate** images).
2. Put PNGs in e.g. `docs/app-store-raw/ipad-source/` (names like `Slice 1.png` work with the script).
3. Resize:

```bash
./scripts/resize-app-store-screenshots.sh ./docs/app-store-raw/ipad-source ipad13
# or
./scripts/resize-app-store-screenshots.sh ./docs/app-store-raw/ipad-source ipad
```

4. Upload files from the generated `app-store-2064x2752/` or `app-store-2048x2732/` folder.

### EN copy — panels 2 & 3 (iPad strip)

Use on **iPad** assets only (iPhone strip can keep «phone» if you want). Panel 2 = big screen / readability; panel 3 = pass-around / social context — so headlines differ.

**Panel 2**

| | Text |
|---|------|
| **Headline** | One iPad. Everyone in on the joke. |
| **Sub** | Full-size hints, player lists, and topics you can read from across the sofa — one shared device, zero logins. |

Shorter sub if the layout is tight: **Big, readable UI for the whole table — one iPad, no sign-ups.**

**Panel 3** (replaces «Everyone plays on one phone» + same sub)

| | Text |
|---|------|
| **Headline** | Hand the iPad around the table. |
| **Sub** | Game night, road trips, or breaking the ice — whoever’s up taps in, then passes it on. Still one device, zero logins. |

Closer to your original one-liner sub, only «phone» removed:

| **Headline** | Everyone plays on one iPad. |
| **Sub** | Pass it around the table — game night, trips, or breaking the ice. |

### Simulator

Run **Debug** with `-AppStoreScreenshots`, choose an **iPad** simulator (e.g. **iPad Pro 13-inch (M4)**), capture screens the same way as iPhone, then resize if pixel size doesn’t match Connect exactly.

## Debug harness

Add launch argument `-AppStoreScreenshots` (scheme **Run → Arguments**) to open the in-app screenshot menu instead of the splash flow. Remove it for normal runs.
