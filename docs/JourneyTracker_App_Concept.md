# JourneyTracker: App Concept & Architecture

**Status:** living document · owned by Jake (lead engineer)

## What the app is

JourneyTracker turns everyday walking into visible progress along a chosen journey. The user picks a route — either a real-world distance (a marathon, "around the world," a specific trail) or an illustrated fantasy path (the road to Ember Spire, and eventually more) — and their real distance, read from Apple Health, moves a marker along that route over time. No app needs to be open for progress to accumulate; it happens passively in the background, on iPhone and eventually Apple Watch.

## Document precedence

Three documents govern this project. When they disagree, this order settles it:

| Document | Governs | Owner |
|---|---|---|
| `docs/JourneyTracker_App_Concept.md` (this doc) | Concepts, architecture, data model, behavior, naming | Jake |
| `docs/DESIGN_SYSTEM.md` | Visual style only — color, type, shape, layout, character rig | Jeff |
| `CLAUDE.md` | Team workflow, roles, Jira process | main session |

**The design system passes style, not concepts.** If it appears to specify a progress formula, a data model, a unit, or a behavior, that text is out of scope and this document wins. Conversely, no one — including this document — overrides the design system on what a thing *looks* like. If a conflict appears, the fix is to amend the wrong doc, not to quietly pick a side in code.

## How to use this document

This isn't a spec to gold-plate before writing code — it's a checklist of *cheap decisions to make correctly now*, so that adding real features later doesn't require rebuilding what already exists. Everything below is meant to cost almost nothing today and save a rewrite later.

**Read the Status column.** Most decisions below are *Decided, not built*. The code today is a small prototype and does not yet contain most of this. Do not assume a system exists because it's described here — check the code.

## The one assumption that matters most

Distance should always be calculated as **cumulative total since the journey's start date**, not "today's distance" or "this week's distance." A journey spans weeks or months; the progress metric needs to be anchored to a fixed start point and summed forward from there. Getting this wrong is the hardest thing to unwind later, because it touches the HealthKit query shape, the SwiftData model, and the background-delivery logic all at once. Build this correctly from day one.

**With multiple simultaneous journeys allowed**, the cleanest way to implement this is a *delta-based* update rather than querying HealthKit separately per journey: track one "last processed distance" anchor, and each time new HealthKit data arrives (one-time query or background observer), calculate the delta since that anchor and add it to every currently-active journey's own `distanceAccumulated`. Each journey still tracks progress from its own start date and totals independently — this avoids redundant HealthKit queries and avoids any risk of double-counting or drift between journeys.

## Distance is the progress metric. Steps are not.

**Decided: progress is driven by HealthKit's `distanceWalkingRunning`, never by steps.**

Steps and distance are two separate HealthKit data types (`stepCount` and `distanceWalkingRunning`), not one calculated from the other. Apple derives distance using a mix of the accelerometer, adaptive stride-length calibration, and GPS where available. A fixed stride multiplier cannot reproduce that, and accuracy is genuinely inconsistent — documented cases of readings off by 10–15% or more depending on where the phone is carried. Apple Watch tends to produce more consistent distance readings than iPhone-only, since it's worn more consistently on the body.

So, concretely:

- **Progress formula:** `progress = min(1.0, journey.distanceAccumulated / journey.totalDistance)`, both in meters.
- Query `distanceWalkingRunning` directly. **Never** estimate distance as `steps × strideLength`.
- Steps may be *displayed* as a secondary stat because some users relate to them intuitively — but a step count never feeds the progress calculation.
- Manage expectations somewhere in the app (onboarding or settings) that distance is an estimate, not GPS-precise.
- Keep the door open to eventually showing *which device* a reading came from (Watch vs. iPhone), since Watch users may trust their number more. See the `sourceDevice` row below.

*(Note: an earlier draft of the design system specified a steps × stride formula. That was a prototype shortcut, is superseded by this section, and has been removed from that document.)*

## Naming: no real-world intellectual property

**Decided.** Journeys, characters, waypoints, color token display names, and UI copy use original names only. Nothing may be lifted from an existing book, film, or game — most pointedly, no Tolkien proper nouns. The fantasy *style* (parchment, faceted figures, a long walk to a volcano) is ours to use; the *names* are not.

The design system was originally authored with placeholder names from a well-known source. Those have been replaced throughout. Canonical names live here:

**Journey 1 — "The Road to Ember Spire"** · `totalDistance` = 1,800 mi (2,896,819 m)

| Order | Waypoint | Cumulative miles |
|---|---|---|
| 0 | Thistledown | 0 |
| 1 | Crosswater | 120 |
| 2 | Silvergate | 460 |
| 3 | The Deepdelve | 660 |
| 4 | Whisperwood | 720 |
| 5 | The Windmark | 1,040 |
| 6 | Whitewatch | 1,540 |
| 7 | Ember Spire | 1,800 |

These numbers live in journey *data* (a bundled JSON file or SwiftData records), never as Swift literals in view code. The table above is the source they're seeded from, not a second copy to keep in sync by hand.

**Character 1 — "Wren,"** a faceted wayfarer of the small-folk. Additional characters follow the same `Character` model.

## Future-proofing checklist

`Built` = exists in the code today. `Decided` = settled, not yet implemented — implement it this way when you get there. `Open` = still needs a call.

| Area | Status | Where this could go later | Assumption to avoid baking in | Lightweight choice instead |
|---|---|---|---|---|
| **Progress anchor** | Decided | Long-running journeys over weeks/months | Querying "today's distance" as the whole metric | Cumulative since `startDate`, always (see above). |
| **Progress metric** | Decided | — | Deriving distance from steps × stride | `distanceWalkingRunning` only; steps are a display stat. |
| **Multiple journeys** | Decided | User runs more than one journey, switches between them, keeps a history of completed ones | "There is only one journey, ever" (a singleton) | Model `Journey` as a list, with `isActive` per journey. Costs nothing today, avoids a rewrite. |
| **Multiple simultaneous journeys** | Decided | Yes — a user can run several journeys at once (e.g. Ember Spire and Around the World together) | Assuming only one journey can ever be "active" at a time | The delta-based update above: one shared "last processed distance" anchor, applied to every active journey's own accumulated total. |
| **Journey types** | Decided | Fantasy illustrated path today; real-world MapKit routes later | Baking "progress = position on my custom image" into the core progress logic | Keep "distance accumulated" and "how that's visualized" as separate concerns. The map screen reads progress; it doesn't own it. |
| **Fantasy map rendering** | Decided | The signature faceted map; zoom/pan; more journeys later | Hand-placing glyphs; fractional-of-screen coordinates; a per-glyph view hierarchy; the map computing its own progress | Author as region records + a deterministic seed; one logical map-unit space + a single camera transform; a single culled SwiftUI `Canvas` pass. See "The fantasy map" section below. |
| **Activity data source** | Decided | Cycling, swimming, wheelchair distance, manual entry for offline days | Hardcoding "distance = HealthKit walking/running distance" deep in many places | Wrap HealthKit access in one small "distance provider." Everything else calls that, not HealthKit directly. |
| **Units** | Decided | Users outside the US expecting km | Hardcoding "miles" into display strings | Store distance in **meters** internally, always. Format for display in one place based on locale. |
| **Journey content** | Decided | New journeys added without an app update; eventually user-created routes | Waypoints hardcoded as Swift literals scattered in view code | Define waypoints as structured data (a small JSON file or SwiftData records), even if bundled locally for now. |
| **Visual styling / art** | Decided | Placeholder art now; commissioned art later; possibly a distinct art style per journey | Hardcoding image names, colors, or marker shapes directly inside view code | Global design tokens for surfaces/ink; a `JourneyTheme` for per-journey art and accents. See "Theme vs. tokens" below. |
| **Distance accuracy & source device** | Decided | Showing users whether a reading came from Watch or iPhone | Treating the distance number as a single, unlabeled, always-accurate value | Tag stored progress updates with a `sourceDevice` field (watch / phone / unknown) now, even if unused in the UI today. |
| **Character / avatar selection** | Decided | A handful of selectable characters at MVP; more later, possibly customizable or purchasable | Hardcoding the journey marker as one fixed icon | Define a `Character` type (name, asset reference, short description) as SwiftData records. Store the user's `selectedCharacter` reference. |
| **Widget / Lock Screen support** | Decided | A home screen widget or Live Activity showing journey progress | Storing SwiftData in the default app-private container | Set up the SwiftData container in an **App Group** from day one. Costs nothing now; avoids a real data migration when a widget extension needs the same store. |
| **Localized text** | Decided | Non-English users | Hardcoding UI strings in view code | Use SwiftUI's String Catalog from the start. Same English text today, just organized for translation later. |
| **Time zones** | Decided | User travels during a long-running journey | Comparing "since start" dates in local time, which drifts near midnight across time zones | Store journey start timestamps and progress timestamps in **UTC**; compare consistently regardless of the user's current time zone. |
| **iPhone + Watch + iCloud sync** | Decided | Watch app needs the same progress; eventually multi-device | A SwiftData model that's hard to retroactively CloudKit-sync | Build the model **CloudKit-compatible from the start**: default values on every property, optional relationships, no unique constraints. Retrofitting this later is genuinely painful. |
| **Monetization** | Decided | Unlocking journey packs, one-time purchase or subscription | Assuming all journeys are always free/unlocked everywhere in the UI | Add an `isPremium` field to `Journey` now, even if every journey is unlocked today. |
| **Completion behavior** | Decided | What happens at 100%? | Assuming progress stops cleanly at 100% with no defined next state | Cap `progress` at 1.0, set `isCompleted`, stop accumulating for that journey. Looping (e.g. repeating "around the world") is a v2 decision. |
| **Notifications & milestones** | Decided | Notify when passing a named landmark | Waypoints as bare coordinates with no metadata | Give each waypoint a `name` and `description` now, even if unused today — costs nothing, enables notifications later without a model change. |
| **Manual correction** | Open | HealthKit data is occasionally wrong, or a user bikes and doesn't want it counted | Treating HealthKit as the sole, unquestionable source of truth forever | Not needed for v1 — just don't design anything that would make an "adjustment" field impossible to add later (it won't). |
| **Social / sharing** | Open | Friends, leaderboards, group journeys | No structural blocker — just don't assume it can't happen | Nothing to do now. Local-first data doesn't prevent adding this later. |

## Theme vs. design tokens

Two layers, and they are not the same thing:

**Global design tokens** (`docs/DESIGN_SYSTEM.md`) define the app's shell: `bg/parchment`, `ink`, `surface/card`, `bg/dark`, plus the four accent hues. These are app-wide, live in the Asset Catalog as colorsets with light/Deepdark variants, and every screen uses them.

**`JourneyTheme`** defines what varies *per journey*: art assets and which accents that journey leans on.

```swift
struct JourneyTheme {
    let backgroundImageName: String   // e.g. "ember_spire_bg"
    let markerImageName: String       // e.g. "marker_wren"
    let accentColor: Color            // usually a design token, not a literal
    let pathColor: Color
}
```

Each `Journey` holds a `theme: JourneyTheme`. Views read colors and image names from tokens or from `journey.theme` — never `Image("ember_spire_bg")` or `Color.red` typed inline. Swapping placeholder art for commissioned art later becomes: change the asset, update one string in one place.

**Open question for Jake:** the design system notes that Deepdark mode can be triggered "inside cave milestones" — i.e. the journey's current waypoint drives appearance. That's a third thing, neither a global token nor a static per-journey theme. Decide whether `JourneyTheme` gains an optional per-waypoint override before anyone implements waypoint-driven appearance.

## The fantasy map: faceted cartography system

The fantasy-journey map is the app's signature surface, and it has enough moving parts to earn its own decisions here. The **visual** style of the terrain — facet recipes, color triads, glyph sizes, the fixed back-to-front draw order — lives in `docs/DESIGN_SYSTEM.md` (Jeff owns it, and is adding the terrain section there in parallel). This section owns the **behavior, data, and architecture** underneath that style: how a map is authored, what coordinate space it lives in, how it's drawn, and how the camera moves. Where the two meet they cross-reference; neither restates the other.

Real-world journeys (Around the World, a specific trail) are a *separate* visualization and will use MapKit when built — see the Journey types row. Everything below is the **custom fantasy** renderer. Camera behavior (zoom, pan, framing) should feel consistent across both kinds of journey.

**Decided: a map is authored as a short list of REGION records plus a deterministic seed — never as hand-placed glyphs.**

A range, a forest, a river, a lake, a coastline, a village site are each one *region record* describing a shape and a few parameters (extent, density, jitter, edge feathering) in map units. A seeded procedural scatter generator expands those regions into the hundreds of tiny glyph placements the style calls for (a forest is dozens of scattered trees, a range is many small peaks, a village is a tight cluster of homes — the visual recipes are Jeff's).

- *Trap:* authoring a map by placing individual glyphs by hand. It doesn't scale, it can't be re-tuned, and it can't be validated. Explicitly rejected.
- *Mitigation:* author regions; generate glyphs.
- **Determinism is a hard requirement.** The same regions + the same seed must produce identical placements on every launch and every device. The generator is a pure function of `(regions, seed)` — no wall-clock, no `Date()`, no unseeded RNG. A map that reshuffles between launches is a bug. This also lets the map stay stable across a user's iCloud devices without syncing any glyph positions: only the small authoring input travels, and each device regenerates the same map.

**Decided: placement rules are build-time validators, not runtime conventions.**

The design session fixed logical constraints on how terrain relates: rivers start off-screen or in mountains and terminate in a lake or at the coastline (never mid-land, never continuing under the ocean fill); roads and the trek path stay on land and never cross a lake or ocean; settlements sit near water (river bank, lake shore, coast). These are checked when a map is authored/generated, and a violation **fails authoring, not the render**.

- *Trap:* checking these at runtime and drawing a "best-effort" broken map, or trusting authors to remember them.
- *Mitigation:* a validator over the region set and its generated placement, so a map that breaks a rule is an authoring error the author fixes. The shipped map is correct by construction.

**Decided: each journey has a fixed logical map-unit coordinate space; rendering applies one camera transform.**

Waypoints, regions, and the trek path are all authored in *map units* — the journey's own logical coordinate space — not as a fraction of the screen. A map may be far larger than the screen. Rendering maps logical units → screen points through a single camera transform (translate + scale).

- *Trap:* the current placeholder in `JourneyMapView.swift`, which places waypoints as fractions of the container (`waypoint.x * geometry.size.width`, `y * geometry.size.height`). That can't zoom, can't exceed the screen, and ties layout to device size. **This decision supersedes that placeholder.**
- *Mitigation:* one map-unit space per journey (its bounds are journey data), one camera transform at draw time.

**Decided: terrain is drawn in a single-pass SwiftUI `Canvas`, visible-rect culled; no per-glyph view hierarchy.**

Hundreds of glyphs cannot each be a SwiftUI `View` — layout and diffing would collapse. The terrain is one `Canvas` that draws the generated glyphs in the design system's fixed back-to-front order, culling anything outside the current visible rect. Terrain is fully **static** — it does not animate and does not change once generated; only the marker and the camera move. So the generated glyph set is produced once per map (per LOD bucket) and redrawn cheaply.

- *Trap:* a `ZStack`/`ForEach` of glyph views, or animating the terrain.
- *Mitigation:* one culled `Canvas` pass; all motion lives in the marker and the camera.

**Decided: the camera supports pinch-zoom and pan, defaults to a "chapter view," and thins density as it zooms out (LOD).**

- Gesture: pinch zoom and pan, backed by `UIScrollView` (via a representable) for correct momentum, bounce, and zoom feel.
- Default framing = **chapter view**: the current leg only (last waypoint reached → next waypoint), marker centered. A toggle switches to a **full-journey overview**.
- **LOD:** as zoom decreases, each glyph's *on-screen* size stays roughly constant while the scatter *density* thins. Zooming out keeps masses reading as textured terrain — never collapsing to dust, never popping into a few large icons.
- *Rationale — why the camera is not optional:* a day's walking is on the order of 0.2% of Ember Spire's 1,800 miles. Framed to the whole journey, a day's progress is sub-pixel and the marker never visibly moves — the core motivation loop dies. Chapter view makes daily progress legible. This is *why* the map-unit space and camera exist at all.

**Decided: the map reads progress; it never owns or computes it.**

This reinforces the Journey types row. The marker's position along the trek path is a pure function of the journey's distance-based progress (`distanceAccumulated / totalDistance`, per "The one assumption that matters most" and the Progress metric section). The map has no distance math of its own — no steps, no per-view constants. The current placeholder violates this (it drives the marker off a HealthKit step count plus a unitless distance literal); that is drift to remove, not a pattern to copy.

**Phased delivery — epic KAN-16.** Each phase is gated on Justin's visual approval before the next begins:

- **P1** — a hand-placed `Canvas` specimen that proves the faceted look (one screen, static, no generator). Validates the aesthetic cheaply before building machinery. Hand-placement here is a deliberate one-off proof, not the authoring model.
- **P2** — the seeded generator plus a **persistent** tuning harness: an authoring tool with live knobs for density, jitter, feather, and seed. The harness stays in the repo as the map-authoring surface; it is *not* throwaway like a `Mockups/` variant.
- **P3** — camera, LOD, and performance: UIScrollView-backed zoom/pan, chapter-view framing, density-thinning LOD, `Canvas` culling.
- **P4** — the real Ember Spire map, authored as regions + seed, replacing the `JourneyMapView` placeholder and wired to distance-based progress.

**Naming.** The design session's sample map used a placeholder proper noun lifted from a well-known source; it must **never** ship. All map content uses original names — see the naming section (Ember Spire, Thistledown, Crosswater, and the rest).

## What's actually built today

The current code is a prototype. Treat everything else in this document as a plan.

- A single `JourneyProgress` SwiftData model, fetched as a de-facto singleton (`journeyProgresses.first`). **This is the singleton the doc says not to build** — it should become `Journey` + `JourneyProgress` when the multi-journey work lands.
- `HealthKitManager` with one-time reads and background delivery.
- A `JourneyMapView` prototype: waypoints placed as fractions of the screen (0…1 × `geometry.size`) and a marker driven partly by a HealthKit step count and partly by a unitless distance constant. Both are drift, and both are superseded by "The fantasy map" section — fractional coordinates give way to a map-unit space plus a camera transform, and the step-driven marker gives way to distance-based progress. This placeholder is *replaced* in phase P4 of epic KAN-16, not patched in place.
- **Not built:** `Journey`, `Character`, `Waypoint`, `JourneyTheme`, `sourceDevice`, `isPremium`, App Group container, CloudKit compatibility, String Catalog, meters as the canonical unit, and the entire faceted cartography system (region authoring, seeded generator + tuning harness, map-unit space, `Canvas` renderer, camera/LOD — epic KAN-16, phases P1–P4).

## What NOT to worry about yet

To be precise about "database": a **local database is already part of the plan** — SwiftData (SQLite under the hood) runs entirely on the user's device and is the right home for journeys, characters, and progress data, with zero server involved. What to skip for now is a **backend/server database** — one running on the internet that many users' apps talk to over a network. That's only needed for cross-device sync beyond what iCloud offers for free, social features, or pushing new content without an app update. Journeys, characters, and progress all belong in SwiftData from day one; none of that requires a backend.

## Rough data model sketch

All properties need inline default values and optional relationships to stay CloudKit-compatible. Never name a type plain `Task` — it collides with Swift's concurrency type.

**Journey**
- `id`, `name`, `type` (fantasy / realWorld)
- `totalDistance` — meters
- `distanceAccumulated` — meters
- `startDate` (UTC), `isActive`, `isCompleted`, `isPremium`
- `theme`, relationship to its waypoints
- for `fantasy` journeys, a reference to its map authoring data (map-unit bounds + region records + scatter seed — see below)

**Waypoint**
- `id`, `order`, `position` — **map units** for fantasy journeys (the journey's logical coordinate space, per "The fantasy map"), lat/long for real-world journeys. *Not* a fraction of the screen.
- `distanceFromStart` — meters
- `name`, `descriptionText` (for future notifications)

**Map authoring data** (fantasy journeys only — the input to the seeded scatter generator)
- the journey's map-unit `bounds` (its logical coordinate space) and a single scatter `seed`
- an ordered list of **MapRegion** records: `kind` (range / forest / river / lake / coast / groundCover / settlement / road / trekPath), a shape spec in map units (blob or ellipse extent; river source→mouth; village site; path polyline), and scatter parameters (density, jitter, feather)
- This is *static authored content*, not user-mutable state. It travels with the bundled journey definition (JSON), the generator expands it to glyphs deterministically at load, and — unlike `Journey` / `Waypoint` / `ProgressUpdate` — it does **not** need to be a CloudKit-synced SwiftData model. Nothing here changes as the user walks; only the marker's position (read from progress) does.

**Character**
- `id`, `name`, `assetName`, `descriptionText`

**ProgressUpdate** (the delta-based anchor)
- `lastProcessedDistance` — meters, one shared anchor across all active journeys
- `lastUpdated` (UTC)
- `sourceDevice` (watch / phone / unknown)
