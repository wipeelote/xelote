# NEON PIT — Final Build Brief (Debris Clear map redesign)

## 0. What this is

A televised game-show set built over a lava crater. Glossy black and deep-navy surfaces, a few cyan neon edge lines, a fan of nine hot-magenta pillars with searchlight beams rising behind the pit, an overhead truss ring that throws a colored spot and a white key spot on each black hex podium, a studio camera jib hanging over the lava, and two tiers of audience banks flashing cameras from the wings. Hot magenta is reserved for the thrown d10 and the towers (plus the show logo, spawn ring, ON AIR tally and the showcase return gate), so the ball is always the most saturated object in view and the towers read as "made of ball" without a caption. The lava is the only red in the map.

**Start point:** the winning "NEON PIT" design. **Every judge-named weakness is fixed here:**

| Judge weakness | Fix in this brief |
|---|---|
| Generic black-gloss + cyan-grid look | Stage grid (24 strips) and crater inner lines (16) removed; replaced with purposeful props: PIT CAM jib over the lava, audience banks with camera flashes, alternating-height backdrop skyline with a giant DEBRIS / CLEAR logo, ON AIR tally. |
| Saturation overload; P3 violet vs magenta ball; P2 amber vs lava | P3 = Sky Blue (60,140,255); P2 = Sun Yellow (255,230,60) (clean yellow, not orange); glass tint neutral (200,220,255); back-wall top strip cyan not magenta. Magenta whitelist is explicit (section 7). |
| Weakest showcase (identical pedestals in a U, no plaques, no per-pedestal lights, padding exhibits) | Forge-style arc of 7 pedestals all facing the arrival point, tilted plaques (title + caption), a ceiling spot head over every pedestal (Crusher Bay), a hero D10 pedestal, animated PISTON, live ring-meter HEX exhibit, working PIT CAM and RIG exhibits; the display-only teleport pad is gone. |
| Cyan neon cap on the hub front rail blooms at the bottom of the view | Cap is matte Studio Grey; the cyan line is on its OUTER (pit-facing) face only, invisible from the hub camera. |
| RimPosts violated the "collidable tops <= Y 38" rule | Rim posts, tower rings, crust plates, sleeves, audience tiers are all CanCollide=false; every collidable top outside hub/showcase is <= Y 38. |
| 8 shadowed rig SpotLights too costly | Every light in the map has Shadows=false. |
| Exhibit spin with MapKit.spin tears multi-part models apart | Only single parts spin; a new MapKit.spinBob helper combines spin+bob (spin and bob each overwrite CFrame and would fight). |
| Stage corner wedges under-specified (would be 8 parts) | Exact single-WedgePart CFrame recipe per corner (4 parts). |
| Half-scale hex needs Arena internals | buildHexDeck / buildRingMeter move into MapKit with radius/thickness params. |
| showcaseDebris scale ignored by the client | 4-line DebrisVisuals change reading a VisualScale attribute. |
| T3/T4 only 3 studs from the hub sight fan | Moved out to (+-44, 70): 8-stud margin. |
| T7/T9 plinths overlapped the crater vertex posts | Moved to radius 82. |
| Blow-out risk of 100-radius Neon lava | LavaBase stays dim (140,18,4); Bloom Threshold 1.0. |
| Dark ambient makes rivals silhouettes on non-Future graphics | OutdoorAmbient raised to (56,44,96); rig spots (unshadowed) light every deck on ShadowMap too. |

## 0.1 Coordinate conventions (read before building)

- **World coordinates everywhere unless marked hub-local.** `Config.ARENA_CENTER` C = (0, 60, 0), so X/Z are already relative to C and relative Y = worldY − 60. Platform tops are at Y 60, pit floor (lava top) at Y 15 = C.Y − PIT_DEPTH, kill line Y 40, rescue line Y 58, hub floor top Y 88, stage top Y 36.
- **Platform slot s** center = (28·cos a, 60, 28·sin a), a = 45 + 90(s−1) deg: P1 (19.8, 19.8) front-right from the hub, P2 (−19.8, 19.8) front-left, P3 (−19.8, −19.8) back-left, P4 (19.8, −19.8) back-right. `topCFrame` local −Z faces the pit; hex corners lie on local ±X (circumradius 12), flat edges on local ±Z (apothem 10.39). Hex column footprint reaches radius 40 at most.
- **Hub-local h(x, y, z)** = world (x, 88 + y, 95 + z). `hubCFrame = CFrame.lookAt((0,88,95), (0,88,0))` has identity rotation: local +X = world +X, local −Z = toward the arena. Use `hubCFrame * CFrame.new(x, y, z)`.
- **Showcase** origin S = C + SHOWCASE_OFFSET = (180, 88, 95) (floor top center). Positions are given in world coordinates directly.
- `MapKit.ring(center, radius, count, startAngle, fn)` hands each `cf` with **local −Z toward the center and local X tangential**; the Front face of a block placed at `cf` faces the center. `MapKit.cylinder/disc/column` rotate the part 90° about Z, so a cylinder's **local +X points along its axis (up for columns/discs)**; place attachments with `WorldPosition` after parenting.
- Sizes are X × Y × Z studs unless the part is a cylinder (radius × height). TrussPart sizes must be multiples of 2 on every axis (all trusses here comply).

## 0.2 Global rules and recipes

- **Materials:** SmoothPlastic for all black/navy surfaces (glossy under Future lighting; still reads on ShadowMap because identity comes from neon and lights). Neon for glowing trim. Metal only for piston collars/rods. Glass for rails.
- **Every Neon strip/ring/disc/post that is not a floor:** `CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false`. Anything a piece could rest on above Y 38 outside hub/showcase must be non-collidable.
- **Every light:** `Shadows = false` (MapKit.pointLight default; set it on every SpotLight too).
- **BLINK(period, maxT):** `TweenService:Create(part, TweenInfo.new(period/2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = maxT}):Play()`. Add as `MapKit.blink(part, period, maxT)`.
- **SPOT(part, face, color, angle, brightness, range):** SpotLight with Shadows=false. Add as `MapKit.spotLight`.
- **SEARCHLIGHT(part, height, w0, w1, color):** Attachment0 at the part center, Attachment1 with `WorldPosition = part.Position + (0, height, 0)`; Beam: Color = color, Width0 w0, Width1 w1, Transparency NumberSequence 0.6 → 1, LightEmission 1, LightInfluence 0, Brightness 2, FaceCamera true, Segments 1, no Texture. Add as `MapKit.beamUp`.
- **EMBERS(rate):** ParticleEmitter, default texture, Color 255,140,50 → 255,40,10, Size 0.25 → 0.7, Lifetime 2–4, Speed 5–10, Rate = rate, SpreadAngle (12,12), Acceleration (0,1.5,0), LightEmission 1, LightInfluence 0, Transparency 0.1 → 1, EmissionDirection Top, ShapeStyle Volume.
- **HAZE:** ParticleEmitter Color 140,30,12, Size 10 → 16, Transparency 0.88 → 1, Lifetime 5–7, Speed 1.5, Rate 3, LightEmission 0.3.
- **TEXT:** `MapKit.surfaceText(part, face, text, props)` (PixelsPerStud 20, LightInfluence 0). Logo style = GothamBlack, TextColor 255,40,170, UIStroke Color 0,220,255 Thickness 4. Caption style = Gotham, TextColor 0,220,255.
- **Part names:** every part named as the structure heading below (so PlatformDressing can find "Deck"/"PistonRod", and later polish can find things).

## 0.3 Config changes (src/shared/Config.luau)

```lua
Config.DEBRIS_COLOR = Color3.fromRGB(255, 40, 170)      -- Hot Magenta
Config.DEBRIS_MATERIAL = Enum.Material.SmoothPlastic    -- Neon would hide the d10 facets
Config.PLATFORM_COLORS = {                               -- identity color: rim, under-disc, collar ring, rig color spot
	Color3.fromRGB(120, 255, 60),  -- P1 Lime
	Color3.fromRGB(255, 230, 60),  -- P2 Sun Yellow
	Color3.fromRGB(60, 140, 255),  -- P3 Sky Blue
	Color3.fromRGB(240, 240, 255), -- P4 Ice White
}
Config.PLATFORM_DECK_TINTS = {                           -- NEW: near-black deck plastic tinted toward the slot color
	Color3.fromRGB(18, 34, 14), Color3.fromRGB(36, 34, 10), Color3.fromRGB(12, 22, 40), Color3.fromRGB(34, 34, 40),
}
Config.TOWER_NEON_TRIM = true                            -- NEW: false = rings/cap SmoothPlastic for dead-flat mono towers
```
Everything else (ARENA_*, PIT_DEPTH, KILL_DEPTH, HUB_*, SHOWCASE_OFFSET, throw physics) is unchanged.

## 0.4 Module map

| Module | Builds | Parts |
|---|---|---|
| Map/Lighting.apply() | Lighting service props, Atmosphere, Bloom, ColorCorrection (no parts) | 0 |
| Map/Pit.build(folder) → model "Pit" | lava layers, crust, piston sleeves, crater wall, rim, stage, backdrop, audience banks | 109 |
| Map/Towers.build(folder) → models "Towers" and "Rig" | 9 towers; truss ring, 8 spot fixtures, PIT CAM jib (rig lives here because Lighting.apply has no parent folder and the rig needs no platform objects, only Config) | 60 + 44 |
| Map/PlatformDressing.dress(model, topCFrame, color, slot) | deck/rod restyle + 9 dressing parts per platform | 36 new (+28 existing) |
| Map/Hub.build(folder) → {spawn, statusLabel, floorY} | balcony, monolith, board, spawn, showcase gate + pad | 44 |
| Map/Showcase.build(folder) → {spawnCFrame} | backstage gallery, 7 pedestals, exhibits, return gate + pad | 105 |
| **Total static** | | **426** (+ up to 80 runtime debris, + 80 client d10 visuals) |

---

## 1. PIT (Pit.build) — 109 parts

The crater: a red lava lake with a hot core and heart under the podiums, cooled crust plates, an octagonal black crater wall rising to a glossy black stage at Y 36, a 12-sided backdrop wall closing the horizon, and two audience banks in the wings. Inside radius 65 nothing solid exists between Y 15.4 and Y 40 except the (visual-only, non-collidable) rod sleeves.

| # | Structure | Parts | Dimensions | Position (world) | Material / Color | Effects |
|---|---|---|---|---|---|---|
| P1 | LavaBase | 1 disc `MapKit.disc(CFrame.new(0,14,0), 100, 2)` | radius 100, thick 2 (Y 13..15) | center (0,14,0); extends under the stage (hidden) | Neon 140,18,4; **CanCollide true** (this is the pit floor) | PointLight 255,70,15 brightness 3 range 60 |
| P2 | LavaCore | 1 disc | radius 44, thick 0.4 (Y 15.0..15.4) | (0,15.2,0) | Neon 255,70,15; non-collide | EMBERS(30) + HAZE |
| P3 | LavaHeart | 1 disc | radius 12, thick 0.25 (Y 15.4..15.65) | (0,15.525,0) | Neon 255,160,60; non-collide | none (the PIT CAM spot pools here) |
| P4 | HotSpots | 2 discs | radius 14, thick 0.4 (Y 15.3..15.7) | (30,15.5,−18) and (−26,15.5,28) | Neon 255,120,30; non-collide | none |
| P5 | CrustPlates | 14 blocks | thick 0.4, center Y 15.9 (15.7..16.1); footprints X×Z: #1 16×11, #2 12×9, #3 10×14, #4 18×8, #5 9×9, #6 14×10, #7 12×12, #8 16×9, #9 11×7, #10 13×10, #11 15×9, #12 10×12, #13 9×6, #14 12×8 | (X, Z, yaw°): #1 (4,−10,15) #2 (−33,26,70) #3 (33,30,40) #4 (−29,−34,110) #5 (33,−29,30) #6 (−36,12,160) #7 (4,36,5) #8 (−6,−38,80) #9 (44,30,125) #10 (−48,−30,20) #11 (46,−36,95) #12 (−46,34,50) #13 (18,54,140) #14 (−24,−54,35). All clear the rod sleeves by ≥1 stud and stay inside the crater (r < 67.8) | SmoothPlastic 28,6,4; CanCollide false, CanQuery false | none |
| P6 | PistonSleeve ×4 | 4 cylinders `MapKit.column(Vector3.new(±19.8, 15.2, ±19.8), 4.2, 5.5)` | radius 5.5, height 4.2 (Y 15.2..19.4) | one at each platform center XZ | SmoothPlastic 16,16,24; **CanCollide false, CanQuery false** (visual only; pit stays open) | none. Top at 19.4 = 0.1 under the dropped under-disc (Y 19.5): the crushed deck visibly bottoms out on it (PISTON_DROP_DISTANCE 38 → deck bottom lands at Y 20) |
| P7 | HeatRing ×4 | 4 discs | radius 6.5, thick 0.4 (Y 15.45..15.85) | same XZ as the sleeves, center Y 15.65 | Neon 255,70,15; non-collide | PointLight 255,80,20 brightness 1.5 range 40 (paints rods and deck undersides orange) |
| P8 | CraterWall | 8 blocks via `MapKit.ring(Vector3.new(0,25.5,0), 68.55, 8, 0, fn)` | 56.8 × 21 × 1.5 (Y 15..36) | side centers at radius 68.55, angles 0,45,…,315; inner (Front) face at apothem 67.8 = 0.2 proud of the stage edge (68) so the two never z-fight; outer face embedded in the stage | SmoothPlastic 12,12,20 | none |
| P9 | CraterRimStrip | 8 blocks via ring(center (0,36.25,0), radius 68.1) | 56.8 × 0.5 × 0.6 (Y 36..36.5), radial 67.8..68.4 | same 8 angles; covers the wall/stage seam | Neon 0,220,255; non-collide | none |
| P10 | RimPost | 8 blocks | 1.2 × 8 × 1.2 (Y 36..44) | octagon vertices: (73.6·cos a, 40, 73.6·sin a), a = 22.5 + 45k | Neon 0,220,255; **non-collide** | PointLight 0,220,255 brightness 1.5 range 25 |
| P11 | StageGround | 4 blocks + 4 WedgeParts | blocks: N/S 440 × 2 × 152, E/W 152 × 2 × 136; wedges Size (2, 39.8, 39.8) | top Y 36. N (0,35,144), S (0,35,−144), E (144,35,0), W (−144,35,0) → square hole half-width 68. Corner wedge for each (sx, sz) ∈ {±1}²: `Size = Vector3.new(2, 39.8, 39.8)`, `CFrame = CFrame.fromMatrix(Vector3.new(48.1*sx, 35, 48.1*sz), Vector3.new(0, sx*sz, 0), Vector3.new(-sx, 0, 0), Vector3.new(0, 0, sz))` (thickness along world Y, right angle at the square corner (68·sx, 68·sz), hypotenuse = the octagon edge at apothem 68) | SmoothPlastic 12,12,20 | none |
| P12 | BackdropWall | 12 blocks via `MapKit.ring(Vector3.zero, 141, 12, 0, fn)`; per panel `h = (i % 2 == 1) and 46 or 40`, `MapKit.block(cf * CFrame.new(0, 36 + h/2, 0), Vector3.new(75.6, h, 2))` | 75.6 × h × 2, h alternating 46 (angles 0,60,…,300) and 40 (30,90,…,330); Y 36..82 / 36..76 | 12-gon, inner face at apothem 140, side centers at radius 141 | SmoothPlastic 10,10,18 | Front (pit-facing) face of panel i=9 (240°): logo text "DEBRIS"; panel i=11 (300°): "CLEAR" (Logo style, label Size (0.9,0.5) Position (0.05,0.05)). From the hub they read left and right of tower T8. |
| P13 | BackdropTopStrip | 12 blocks | 75.6 × 0.5 × 2.4 | radius 141, same angles, center Y = panel top + 0.25 (82.25 or 76.25) | Neon 0,170,210; non-collide | none |
| P14 | BackdropCornerPost | 12 blocks | 0.8 × 46 × 0.8 (Y 36..82; all posts full height so the skyline steps between them) | 12-gon vertices: (144.9·cos a, 59, 144.9·sin a), a = 15 + 30k | Neon 0,220,255; non-collide | PointLight 0,200,255 brightness 1 range 40 on posts with even k (6 lights) |
| P15 | AudienceBank ×2 (east X>0, west X<0) | 6 tier blocks each = 12 | tier k = 0..5: Size (6, 5(k+1), 80); center (±(101 + 6k), 36 + 2.5(k+1), 0) → tiers span X 98..134, tops at Y 41 + 5k (max 66), Z −40..40 | wings of the set, outside the tower ring (T1/T6 body edge at 82) and inside the backdrop (corner (134, ±40) projects to 136 < 140 on the 30° sides) | SmoothPlastic 18,18,28; **CanCollide false, CanQuery false** | Optional zero-part seat rows: SurfaceGui Face Top, PixelsPerStud 4, Frame BackgroundColor3 26,26,40 with UIGradient Rotation 90 and 20 keypoints alternating 26,26,40 / 12,12,20 at times k/10 and (k+1)/10 − 0.0001 (times strictly increasing) |
| P16 | AudienceFlash ×2 | 2 invisible blocks | 40 × 3 × 76, Transparency 1, non-collide | center (±116, 57, 0), rotated about world Z by +39.8° (east) / −39.8° (west) so the slab lies parallel to the tier slope, 3.5 studs above the treads | SmoothPlastic, any color | ParticleEmitter "CameraFlash": Shape Box, ShapeStyle Volume, Rate 1.2, Lifetime 0.12, Speed 0, Size 2.2, Color 255,255,255, Transparency 0 → 1, LightEmission 1, LightInfluence 0, Brightness 3 (random white pops = an audience taking pictures; peripheral from the hub, never behind a deck) |

Pit count: 1+1+1+2+14+4+4+8+8+8+8+12+12+12+12+2 = **109**.

---

## 2. TOWERS (Towers.build, model "Towers") — 60 parts

Nine tall cylinders standing on the stage (base Y 36) in a fan that rises toward the back of the set as seen from the hub: proscenium columns T3/T4 beside the hub at 65 studs, the tallest (T8, 110) dead center behind the pit. The 90° slot (directly between hub and pit) is empty. **Every part of every tower reads `Config.DEBRIS_COLOR` at build time** (255,40,170). Plinth and body are SmoothPlastic; rings and cap are Neon when `Config.TOWER_NEON_TRIM` is true (else SmoothPlastic). All rings and caps are non-collidable; bodies collide (stray debris bounces off and dies below Y 40). All towers stay outside every hub-to-platform sight line (those lie within |X| ≤ 32) and outside the hex columns (r ≤ 40).

| Tower | Base center (X, Z) | Angle / radius | Body H | Rings at Y | Top Y (cap) |
|---|---|---|---|---|---|
| T1 | (78, 0) | 0° / 78 | 85 | 58, 78, 98, 118 | 123 |
| T2 | (67.5, 39) | 30° / 78 | 75 | 58, 78, 98 | 113 |
| T3 | (44, 70) | ~58° / 82.7 | 65 | 58, 78, 98 | 103 |
| T4 | (−44, 70) | ~122° / 82.7 | 65 | 58, 78, 98 | 103 |
| T5 | (−67.5, 39) | 150° / 78 | 75 | 58, 78, 98 | 113 |
| T6 | (−78, 0) | 180° / 78 | 85 | 58, 78, 98, 118 | 123 |
| T7 | (−58, −58) | 225° / 82 | 95 | 58, 78, 98, 118 | 133 |
| T8 | (0, −78) | 270° / 78 | 110 | 58, 78, 98, 118, 138 | 148 |
| T9 | (58, −58) | 315° / 82 | 95 | 58, 78, 98, 118 | 133 |

Per tower:

| Part | Build | Dimensions | Position | Material | Effects |
|---|---|---|---|---|---|
| Plinth | `MapKit.column(base, 2, 6)` | radius 6, height 2 (Y 36..38) | tower base (X, 36, Z) | SmoothPlastic, DEBRIS_COLOR; collidable (top at 38, below the kill line) | PointLight DEBRIS_COLOR brightness 1.5 range 30 (magenta pool on the stage) |
| Body | `MapKit.column(base + (0,2,0), H, 4)` | radius 4, height H (Y 38..38+H) | tower axis | SmoothPlastic, DEBRIS_COLOR; CanCollide true | none |
| Ring ×N | `MapKit.disc(CFrame.new(X, y, Z), 4.5, 0.7)` | radius 4.5, thick 0.7 | y = 38 + 20n while y < top | Neon (or SmoothPlastic if TOWER_NEON_TRIM=false), DEBRIS_COLOR; non-collide | none |
| Cap | `MapKit.disc(CFrame.new(X, top + 0.8, Z), 4.6, 1.6)` | radius 4.6, thick 1.6 | on the body top | Neon (see trim flag), DEBRIS_COLOR; non-collide | PointLight DEBRIS_COLOR brightness 2.5 range 45; SEARCHLIGHT(cap, 140, 7, 0.5, DEBRIS_COLOR) |

Count: 9 plinths + 9 bodies + 33 rings + 9 caps = **60**. Clearances checked: T7/T9 plinth inner edge at r 76 clears the octagon vertex posts (73.6 ± 0.6); T2/T5 plinth inner edge 72 clears the crater edge at 70.4; T3/T4 body edge |X| 40 clears the hub sight fan (|X| ≤ 32) by 8 and the hub's front corner (±32, 75) by 12 in X.

---

## 3. PLATFORMS (PlatformDressing.dress) — 36 new parts (64 total incl. 28 existing)

Geometry untouched (hex R 12, T 2, centers at radius 28, rods to Y 15). `dress()` restyles the existing parts by name and adds 9 non-collidable dressing parts per platform, all **below the deck top** and inside/under the hex, parented to the platform model before `restPivots` is collected so they ride the piston drop. The decks become near-black glossy podiums; identity lives in the neon rim, the under-glow, the collar ring and the rig's colored spot. Positions are in the platform frame T = `topCFrame` (T * (0, dy, 0) has world Y 60 + dy).

| Structure | Parts | Dimensions | Position | Material / Color | Effects |
|---|---|---|---|---|---|
| Deck restyle (existing 1 Block + 4 WedgeParts named "Deck") | 0 new | unchanged | unchanged | Material SmoothPlastic (was DiamondPlate); Color = `Config.PLATFORM_DECK_TINTS[slot]` | ring-meter track color becomes 20,22,34 (in MapKit.ringMeter) |
| PistonRod restyle (existing "PistonRod") | 0 new | unchanged (radius 3, length 43) | unchanged | Metal 36,38,50 (was 70,70,78) | none |
| RimStrip ×6 | 6 blocks | 12 × 0.6 × 0.3 (long axis along the hex side) | center at T * (10.39·cos t, −1, 10.39·sin t), t = 30, 90, 150, 210, 270, 330 deg (side midpoints, deck mid-height, world Y 58.7..59.3); orient with `CFrame.lookAt(mid, T.Position + Vector3.new(0,−1,0))` so Size.X runs along the side and 0.15 studs stand proud of the face | Neon, PLATFORM_COLORS[slot]; non-collide | none |
| Collar | 1 cylinder `MapKit.cylinder(T * CFrame.new(0,−3.5,0), 3, 5)` | radius 5, height 3 (world Y 55..58) | hugging the rod under the deck | Metal 24,24,34 | none |
| CollarRing | 1 disc | radius 5.4, thick 0.5 | T * (0, −3.5, 0) | Neon, platform color; non-collide | none |
| UnderDisc | 1 disc | radius 9.5, thick 0.3 (local Y −2.5..−2.2, 0.2 below the deck bottom) | T * (0, −2.35, 0) | Neon, platform color; non-collide | PointLight platform color brightness 2 range 30 (colored glow on rod, collar, sleeve and the pit) |

Per platform 7 existing + 9 new = 16; ×4 = **64**. On a drop the under-disc lands on the sleeve top (19.4/19.5), the collar disappears inside the sleeve, the rod passes through the lava base as it does today.

---

## 4. HUB (Hub.build, model "SpawnHub") — 44 parts

The audience balcony: a glossy black deck with a cyan floor frame, glass rails, standing on a 50-stud black monolith that rises from the stage and carries the show logo on its pit-facing wall. Back wall: framed scoreboard, blinking ON AIR tally, magenta spawn ring, neon gate around the showcase teleport pad, two white key spots. HUB_OFFSET/HUB_SIZE unchanged. Positions are **hub-local** h(x, y, z) = world (x, 88 + y, 95 + z).

| Structure | Parts | Dimensions | Position (hub-local) | Material / Color | Effects |
|---|---|---|---|---|---|
| HubFloor | 1 block | 64 × 2 × 40 (world Y 86..88) | (0, −1, 0) | SmoothPlastic 14,14,22 | none |
| Monolith | 1 block | 64 × 50 × 40 (world Y 36..86) | (0, −27, 0) | SmoothPlastic 12,12,20 | Front (−Z, arena-facing) face: TEXT "DEBRIS CLEAR", Logo style, label Size (0.9,0.3) Position (0.05,0.3), gui Brightness 1.5. Readable from every platform. |
| MonolithLine ×4 | 4 blocks | 64 × 0.3 × 0.3 | (0, y, −20.15) for y ∈ {−48, −42, −12, −6} (world Y 40, 46, 76, 82; 0.15 proud of the front face; the logo sits between) | Neon 0,170,210; non-collide | none |
| FloorFrame ×6 | 6 blocks | 60 × 0.16 × 0.3 (×2), 0.3 × 0.16 × 36 (×4) | bottom flush with the floor top (y 0.08): long-X at z ±18; long-Z at x ±30 (border) and x ±8 (a runway flanking the spawn toward the front rail) | Neon 0,170,210; non-collide, CanQuery false | none |
| FrontRail | 3 blocks: glass, cap, edge strip | glass 64 × 3.6 × 0.3; cap 64 × 0.4 × 0.6 (top at HUB_RAIL_HEIGHT 4); strip 64 × 0.25 × 0.15 | glass (0, 1.8, −19.85); cap (0, 3.8, −19.85); strip (0, 3.8, −20.22) on the cap's OUTER (−Z) face | glass Glass 200,220,255 Transparency 0.7; cap SmoothPlastic 30,30,40; strip Neon 0,220,255 non-collide | none. The cyan line is seen from the arena, never from the hub camera, so nothing blooms at the bottom of the play view. |
| SideRail ×2 | 4 blocks | glass 0.3 × 3.6 × 40; cap 0.6 × 0.4 × 40 | glass (±31.85, 1.8, 0); cap (±31.85, 3.8, 0) | Glass 200,220,255 T 0.7 / Neon 0,170,210 | none |
| BackWall | 1 block | 64 × 20 × 1 (world Y 88..108) | (0, 10, 19.5) | SmoothPlastic 10,12,30 | Front (−Z) face: "ON AIR" GothamBlack 255,40,170 Size (0.22,0.14) Position (0.04,0.16); "E = GRAB   CLICK = THROW" Caption style Size (0.22,0.1) Position (0.74,0.18) |
| BackWallTrim ×3 | 3 blocks | top 64 × 0.5 × 1.2; verticals 0.5 × 20 × 0.5 | top (0, 20.25, 19.5); verticals (±31.75, 10, 18.9) | top Neon 0,170,210; verticals Neon 0,220,255 | verticals: PointLight 0,220,255 brightness 1 range 25 |
| OnAirTally | 1 block | 8 × 1 × 0.4 | (−22, 18.2, 18.9), above the ON AIR text | Neon 255,40,170; non-collide | BLINK(1.0, 0.7) |
| StatusBoard | 1 block | 36 × 14 × 0.6 (world Y 90..104) | (0, 9, 18.8) | SmoothPlastic 8,9,22 | Front face SurfaceGui: Title "DEBRIS CLEAR" Logo style (UIStroke 3) Size (1,0.45) Position (0,0); label named **"Status"** GothamBold white Size (0.9,0.35) Position (0.05,0.5), returned as `statusLabel` (Arena.setBoardStatus writes it) |
| BoardFrame ×4 | 4 blocks | 38 × 0.5 × 0.8 (×2); 0.5 × 15 × 0.8 (×2) | (0, 16.3, 18.7), (0, 1.7, 18.7), (±18.75, 9, 18.7) | Neon 0,220,255 | none |
| Spawn | 1 SpawnLocation + 4 blocks | SpawnLocation 12 × 0.3 × 12; strips 12.6 × 0.25 × 0.5 (×2), 0.5 × 0.25 × 12.6 (×2) | SpawnLocation "HubSpawn" (0, 0.15, 10), Neutral, Duration 0, the only enabled spawn; strips (0, 0.125, 10 ± 6.05) and (±6.05, 0.125, 10) | SpawnLocation SmoothPlastic 16,16,24; strips Neon 255,40,170 non-collide | PointLight 255,40,170 brightness 1.5 range 18 on the SpawnLocation. `Arena.hubReturnCFrame()` = spawn.CFrame * (0,3.5,0) as today. |
| ShowcasePad | 2 (MapKit.teleportPad) | pad 8 × 0.6 × 8; base 9.5 × 0.4 × 9.5 | `MapKit.teleportPad(model, hubCFrame * CFrame.new(25, 0.3, 11.5), "SHOWCASE", "Showcase", Color3.fromRGB(0,220,255))` (pad X 21..29, clear of the spawn's X ±6 and the side rail) | pad Neon 0,220,255; base SmoothPlastic 20,20,30 (restyle the helper's base from Metal 35,35,42); label text 8,10,20 | helper PointLight (cyan, 2, 14) |
| ShowcaseGate | 3 blocks + 3 neon | pillars 1.5 × 9 × 1.5 (world Y 88..97); lintel 13 × 1.5 × 1.5; neon 0.3 × 9 × 0.3 (×2), 11 × 0.3 × 0.3 | pillars (19.25, 4.5, 16.5), (30.75, 4.5, 16.5); lintel (25, 9.75, 16.5); neon on the pillars' inner faces (20.15, 4.5, 16.5), (29.85, 4.5, 16.5) and under the lintel (25, 8.85, 16.5). The pad sits in front of the gate; the gate stands 2 studs in front of the back wall, clear of the 36-wide board | SmoothPlastic 12,12,20 / Neon 0,220,255 | Lintel Front face TEXT "SHOWCASE" Caption style. Attachment "LinkA" at the lintel center (the showcase LinkBeam ends here). |
| KeyLight ×2 | 2 blocks | 1.4 × 1.4 × 2 | (±16, 19, 18.4), `CFrame.lookAt(pos, pos + Vector3.new(0, −1, −1.1))` so Front looks down across the floor | SmoothPlastic 20,20,28 | SPOT(Front, 230,235,255, Angle 60, Brightness 2.5, Range 45) |

Count: 1+1+4+6+3+4+1+3+1+1+4+5+2+6+2 = **44**. Nothing rises above hub floor + 4 between the floor edge and the pit except glass; all hub sight lines to the pit and the four decks stay open.

---

## 5. SHOWCASE (Showcase.build, model "Showcase") — 105 parts

A backstage gallery at S = (180, 88, 95), same height as the hub, 180 studs east of it, floating on a black column outside the backdrop (its nearest corner is at radius 163; the backdrop vertices are at 145 and its top ≤ 82, so the lit room is visible from the hub's right). Three navy walls with magenta tops and cyan corner posts; the west side (toward the arena) is open behind a glass rail so visitors look back at the towers and lava. Seven pedestals stand on an arc centered on the arrival point so every tilted plaque faces the visitor; a spot head hangs over each. Positions are **world** coordinates.

**Arrival:** `spawnCFrame = CFrame.lookAt(Vector3.new(167, 91.5, 95), Vector3.new(196, 91.5, 95))` (facing +X into the gallery, 6 studs clear of the return pad's edge). **Arc:** center A = (167, 95), radius 29; pedestal at angle θ is at (167 + 29·cos θ, 95 + 29·sin θ), rotated with `CFrame.lookAt(pos, Vector3.new(167, pos.Y, 95))` so its local −Z faces A.

| θ | Pedestal center (X, Z) | Exhibit |
|---|---|---|
| 0° | (196, 95) | HERO: D10 DEBRIS |
| −21° | (194.1, 84.6) | HEX PLATFORM (half scale, live ring meter) |
| +21° | (194.1, 105.4) | TOWER (1/5 scale) |
| −42° | (188.6, 75.6) | LAVA |
| +42° | (188.6, 114.4) | PIT CAM |
| −60° | (181.5, 69.9) | PISTON (animated) |
| +60° | (181.5, 120.1) | THE RIG |

| Structure | Parts | Dimensions | Position (world) | Material / Color | Effects |
|---|---|---|---|---|---|
| BaseColumn | 1 block + 4 edge strips | column 24 × 50 × 24 (Y 36..86, standing on the stage); strips 0.5 × 50 × 0.5 | column (180, 61, 95); strips at (180 ± 12.1, 61, 95 ± 12.1) | SmoothPlastic 12,12,20 / Neon 0,170,210 | none |
| Floor | 1 block | 60 × 2 × 60 (Y 86..88; X 150..210, Z 65..125) | (180, 87, 95) | SmoothPlastic 14,14,22 | none |
| FloorLines ×6 | 6 blocks | border 56 × 0.16 × 0.3 (×2), 0.3 × 0.16 × 56 (×2); lane 30 × 0.16 × 0.3 (×2) | center Y 88.08: border at (180, ·, 95 ± 28) and (180 ± 28, ·, 95); lane strips (181, ·, 95 ± 4) from the arrival to the hero | Neon 0,170,210; non-collide, CanQuery false | none |
| Walls ×3 | 3 blocks | back 1 × 16 × 60; sides 60 × 16 × 1 (Y 88..104) | back (209.5, 96, 95); south (180, 96, 65.5); north (180, 96, 124.5). West side open | SmoothPlastic 10,12,30 | Back wall Left (−X) face: "SHOWCASE" Logo style Size (0.9,0.28) Position (0.05,0.06) + "THE PIECES OF DEBRIS CLEAR" Caption Size (0.9,0.12) Position (0.05,0.36). South wall Back (+Z) face: "HOW TO PLAY" (cyan header, top 25%) + lines "E or X: grab debris within 5 studs" / "Click or R2: throw at the cursor" / "Off the edge, or onto a rival" (white, GothamMedium). North wall Front (−Z) face: "THE RULES" + "15 load per piece. 100 crushes your piston." / "Last podium standing wins." |
| WallTopStrip ×3 | 3 blocks | 1.2 × 0.5 × 60 (back), 60 × 0.5 × 1.2 (sides) | (209.5, 104.25, 95), (180, 104.25, 65.5), (180, 104.25, 124.5) | Neon 255,40,170; non-collide | none |
| CornerPost ×4 | 4 blocks | 1.2 × 16 × 1.2 (Y 88..104) | (209.5, 96, 65.5), (209.5, 96, 124.5), (150.5, 96, 65.5), (150.5, 96, 124.5) | Neon 0,220,255 | PointLight 200,230,255 brightness 1.2 range 45 each (room ambient) |
| WestRail | 2 blocks | glass 0.3 × 3.6 × 60; cap 0.6 × 0.4 × 60 | glass (150.5, 89.8, 95); cap (150.5, 91.8, 95) | Glass 200,220,255 T 0.7 / Neon 0,170,210 | none |
| LightBar ×2 | 2 TrussParts | 2 × 2 × 58 (Y 102..104, Z 66..124, touching both side walls) | (184, 103, 95) and (200, 103, 95), Style BridgeStyleSupports | color 30,30,40 | none |
| SpotHead ×7 | 7 blocks | 1.4 × 1.4 × 2.2 | hanging under a bar at (barX, 101.4, pz): barX = 184 for pedestals at X 181.5 and 188.6, 200 for X 194.1 and 196; `CFrame.lookAt(pos, discTop)` | SmoothPlastic 20,20,28 | SPOT(Front, 230,235,255, Angle 45, Brightness 3, Range 20) onto its pedestal |
| Pedestal ×6 (standard) | base + disc + plaque = 18 | base 6 × 2.6 × 6 (Y 88..90.6); disc radius 3.2 thick 0.3 (Y 90.6..90.9); plaque 6 × 1.6 × 0.3 | base at (px, 89.3, pz) with the arc rotation; disc at (px, 90.75, pz); plaque `baseCF * CFrame.new(0, 0.5, −3.45) * CFrame.Angles(math.rad(28), 0, 0)` (leans back 28°, top edge level with the base top, on the face toward the arrival) | base SmoothPlastic 16,16,24; disc Neon 0,220,255 non-collide; plaque SmoothPlastic 12,12,20 | disc PointLight 0,220,255 brightness 1 range 10. Plaque Front (−Z) face SurfaceGui (PixelsPerStud 40, LightInfluence 0): Title label Size (0.94,0.5) Position (0.03,0.04) GothamBlack white with TextStrokeTransparency 0 and TextStrokeColor3 0,90,120; Caption label Size (0.94,0.42) Position (0.03,0.55) Gotham 0,220,255 |
| Pedestal HERO | base + disc + plaque = 3 | base 8 × 4 × 8 (Y 88..92); disc radius 4.2 thick 0.3 (Y 92..92.3); plaque 8 × 1.8 × 0.3 | base (196, 90, 95) facing A; disc (196, 92.15, 95); plaque `baseCF * CFrame.new(0, 1.2, −4.45) * CFrame.Angles(math.rad(28), 0, 0)` | base SmoothPlastic 16,16,24; disc Neon 255,40,170 non-collide; plaque as above | same plaque GUI |
| Exhibit D10 DEBRIS (hero) | 1 anchor `MapKit.showcaseDebris(model, CFrame.new(196, 97.5, 95), 3)` (client renders the d10) | 3× scale = 6 studs across | 5.5 above the hero disc | Config.DEBRIS_MATERIAL, Config.DEBRIS_COLOR | `MapKit.spinBob(anchor, 30, 0.6, 3)` (new helper: 30°/s spin + 0.6-stud bob on a 3 s sine, one Heartbeat); PointLight 255,40,170 brightness 3 range 24. Plaque: "D10 DEBRIS" / "15 load each. Grab it (E), throw it (click)." |
| Exhibit HEX PLATFORM | Model "ExhibitPlatform": 1 block + 4 wedges (`MapKit.hexDeck(top, 6, 1, {Material SmoothPlastic, Color 18,34,14, Name "Deck"})`) + 6 rim strips + 1 under-disc + 1 rod + 1 collar + 1 meter (`MapKit.ringMeter(top, 6, model)`) = 15 | hex R 6 T 1 (deck Y 94.5..95.5); rim 6 × 0.3 × 0.15 at the six side midpoints (apothem 5.2), mid-height, 0.075 proud; under-disc radius 4.75 thick 0.15 (Y 94.3..94.45); rod radius 1.5 length 3.6 (Y 90.9..94.5); collar radius 2.5 height 1 (Y 93.5..94.5); meter side 2·5.2·0.92 | `top = CFrame.lookAt(Vector3.new(194.1, 95.5, 84.6), Vector3.new(167, 95.5, 95))` (a flat edge faces the arrival) | rim/disc Neon 120,255,60; rod Metal 36,38,50; collar Metal 24,24,34 | Model attributes Slot 0, Load 0, Capacity 100, OwnerName "" (keeps the rival billboard off), Eliminated false; tag `DebrisClearPlatform` so RingMeterController animates the ring. Server loop in Showcase.build: `task.spawn` → every Heartbeat raise Load linearly 0 → 100 over 8 s, hold 1.5 s, set 0, wait 1 s, repeat (attribute writes only; nothing else reads this tag on the server). Under-disc PointLight 120,255,60 brightness 1.5 range 10. Plaque: "HEX PLATFORM" / "Your podium. The ring drains as load climbs; 100 drops the piston." |
| Exhibit TOWER | 6 cylinders | plinth radius 1.2 h 0.4 (Y 90.9..91.3); body radius 0.8 h 12 (Y 91.3..103.3); rings radius 0.9 h 0.15 at Y 94.3, 98.3, 102.3; cap radius 0.95 h 0.3 at 103.3..103.6 | axis (194.1, ·, 105.4) (clears the light bar at X 199..201) | DEBRIS_COLOR on all six; plinth/body SmoothPlastic, rings/cap Neon (trim flag) | cap PointLight DEBRIS_COLOR brightness 1.5 range 12; SEARCHLIGHT(cap, 8, 1.2, 0.1, DEBRIS_COLOR). Plaque: "TOWER" / "Nine of these ring the set, every part in debris pink." |
| Exhibit PISTON | 6 parts: sleeve, rod, collar, ring, cap disc, cap rim | sleeve radius 2.2 h 2 (Y 90.9..92.9); rod radius 1.5 h 6 (Y 90.9..96.9); collar radius 2.5 h 1.5 (Y 95.4..96.9); ring radius 2.7 h 0.3 at 96.15; cap disc radius 4 h 0.6 (Y 96.9..97.5); cap rim radius 4.2 h 0.3 at 97.2 | axis (181.5, ·, 69.9) | sleeve SmoothPlastic 16,16,24; rod Metal 36,38,50; collar Metal 24,24,34; ring + cap rim Neon 255,230,60; cap disc SmoothPlastic 36,34,10 | Loop (TweenService, sleeve static): rod+collar+ring+cap+rim drop 4 studs in 0.3 s (Quad In), hold 1.2 s, rise 4 studs in 1.5 s (Sine Out), hold 1.5 s. Plaque: "PISTON" / "Load 100: 38 studs down in 0.3 s. You go with it." |
| Exhibit LAVA | 1 disc + 3 blocks | disc radius 2.8 thick 0.3 (Y 90.9..91.2); plates 1.6 × 0.2 × 2.4, 2.2 × 0.2 × 1.4, 1.2 × 0.2 × 1.2 at Y 91.3, yaws 20/75/130° | centered (188.6, ·, 75.6) | disc Neon 255,70,15; plates SmoothPlastic 28,6,4 | EMBERS(6) with Size 0.15 → 0.35; PointLight 255,80,20 brightness 1.5 range 10. Plaque: "LAVA" / "The pit. Below Y 40 nothing comes back." |
| Exhibit PIT CAM | 5 parts: post, arm, head, lens, tally | post TrussPart 2 × 8 × 2 (Y 90.9..98.9); arm 0.6 × 0.6 × 5; head 1.2 × 1 × 1.6; lens cylinder radius 0.45 length 1; tally 0.3³ | post at (188.6, 94.9, 114.4); arm from the post top toward the arrival (pedestal local −Z), center pedestalCF * (0, 9.9, −2.5) relative to the floor top; head hanging 0.8 under the arm end, `CFrame.lookAt(headPos, discTop)`; lens at headCF * CFrame.new(0,0,−1.1) with its axis along the look (`* CFrame.Angles(−math.pi/2, 0, 0)` before MapKit.cylinder); tally on the head top | post/arm/head/lens SmoothPlastic 20,20,28; tally Neon 255,40,170 | head SPOT(Front, 230,235,255, Angle 35, Brightness 3, Range 12) onto its own disc; tally BLINK(1.2, 0.7). Plaque: "PIT CAM" / "The jib over the pit. Every crush, live." |
| Exhibit THE RIG | 5 parts: 2 posts, truss, 2 fixtures | posts 0.4 × 5 × 0.4 (Y 90.9..95.9) at pedestal-local x ±2.5; truss 2 × 2 × 6 along pedestal-local X (Y 95.9..97.9); fixtures 1.2 × 1.2 × 1.6 at truss-local (±1.5, −1.2, 0), `CFrame.lookAt(pos, discTop)` | centered (181.5, ·, 120.1) | SmoothPlastic 30,30,40, fixtures 20,20,28; TrussPart Style BridgeStyleSupports | fixture 1: SPOT(Front, 120,255,60, Angle 35, Brightness 4, Range 12); fixture 2: SPOT(Front, 230,235,255, Angle 45, Brightness 2.5, Range 12). Plaque: "THE RIG" / "One color spot and one key spot on every podium." |
| ReturnPad | 2 (MapKit.teleportPad) | pad 8 × 0.6 × 8; base 9.5 × 0.4 × 9.5 | `MapKit.teleportPad(model, CFrame.new(157, 88.3, 95), "BACK TO HUB", "Hub", Color3.fromRGB(255,40,170))` (pad X 153..161; arrival at X 167) | pad Neon 255,40,170; base SmoothPlastic 20,20,30 | helper PointLight |
| ReturnGate | 3 blocks + 3 neon | pillars 1.5 × 9 × 1.5 (Y 88..97); lintel 1.5 × 1.5 × 13 (along Z); neon 0.3 × 9 × 0.3 (×2), 0.3 × 0.3 × 11 | pillars (157, 92.5, 89.25), (157, 92.5, 100.75); lintel (157, 97.75, 95); neon on the pillars' inner faces (157, 92.5, 90.15), (157, 92.5, 99.85) and under the lintel (157, 96.85, 95). Players walk −X through the arch onto the pad | SmoothPlastic 12,12,20 / Neon 255,40,170 | Lintel Right (+X, room-facing) face TEXT "BACK TO HUB" 255,40,170. Attachment "LinkB" at the lintel center + **LinkBeam**: Beam (Attachment0 = LinkB, Attachment1 = the hub gate's LinkA at world (25, 97.75, 111.5)), Color 0,220,255, Width0/Width1 0.5, Transparency 0.55, LightEmission 1, Segments 1, no texture: a thin cyan data line over the backdrop and the east audience bank (tops ≤ 82 and 66) linking the two gates |
| ArrivalMarker | 1 disc | radius 3, thick 0.15 | (167, 88.08, 95) | Neon 0,170,210; non-collide | none (not a teleport pad, no tag) |

Count: 5+1+6+3+3+4+2+2+7+18+3 + exhibits (1+15+6+6+4+5+5 = 42) + 2+6+1 = **105**.

---

## 6. LIGHTING — service settings (0 parts) + rig and PIT CAM (44 parts, built by Towers.build in model "Rig")

### 6.1 Lighting.apply()
- `Lighting`: ClockTime 1.5 (midnight; default procedural night sky with stars — **do not add a Sky instance**, it needs skybox asset ids), GeographicLatitude 41, Brightness 0.6, Ambient (30,22,55), OutdoorAmbient (56,44,96), ColorShift_Top (80,40,140), ColorShift_Bottom (20,10,40), EnvironmentDiffuseScale 0.25, EnvironmentSpecularScale 0.75, GlobalShadows true, ShadowSoftness 0.2, ExposureCompensation 0.15, FogEnd 100000 (fog off; Atmosphere handles depth).
- `Atmosphere` "DebrisClearAtmosphere": Density 0.3, Offset 0.2, Color (120,40,170), Decay (30,10,70), Glare 0.3, Haze 2.2 (violet horizon glow; backdrop at 140 studs stays crisp).
- `BloomEffect`: Intensity 0.7, Size 28, Threshold 1.0 (only Neon and lava bloom; the dim LavaBase does not white out).
- `ColorCorrectionEffect`: Brightness 0.02, Contrast 0.15, Saturation 0.25, TintColor (250,240,255).
- No SunRays, no DepthOfField. **Lighting.Technology is not scriptable: set Future in Studio (ShadowMap fallback is acceptable; the rig spots still light the decks, only the glossy specular pools are lost).** Create the three effects if missing, update them if present (idempotent).

### 6.2 Truss rig (aim data comes from Config: deck center s = (28·cos a_s, 60, 28·sin a_s))

| Structure | Parts | Dimensions | Position (world) | Material / Color | Effects |
|---|---|---|---|---|---|
| TrussRing | 16 TrussParts | 2 × 2 × 20 each (16-gon chord at radius 51 is 19.9; ends overlap 0.05 inside the joints) | vertices V_k = (51·cos 22.5k, 104, 51·sin 22.5k), k = 0..15; segment k centered on the chord midpoint with `CFrame.lookAt(mid, V_{k+1})` so Size.Z runs along the chord; Style BridgeStyleSupports | color 30,30,40 | none. Radius 51 clears the hex columns (max 40); ring bottom Y 103 is above the throw apex (~94) and above every hub sight line |
| TrussJoint | 16 blocks | 1.6 × 1.6 × 1.6 | at the 16 vertices | Neon 0,220,255; non-collide | none (hides the segment overlaps) |
| SpotFixture ×8 | 8 blocks | 1.4 × 1.4 × 2.2 | hanging under the odd vertices at (51·cos a, 102.2, 51·sin a). For slot s (a_s = 45 + 90(s−1)): the fixture at a_s − 22.5 is the COLOR spot, at a_s + 22.5 the KEY spot (P1: 22.5/67.5, P2: 112.5/157.5, P3: 202.5/247.5, P4: 292.5/337.5). `CFrame.lookAt(fixturePos, deckCenter_s)` (distance ≈ 50) | SmoothPlastic 20,20,28 | COLOR: SPOT(Front, PLATFORM_COLORS[s], Angle 38, Brightness 5, Range 60); KEY: SPOT(Front, 230,235,255, Angle 48, Brightness 3, Range 60). Shadows false on all. A colored pool + white key on every black podium is what makes it read as a game show and lights rivals and landing debris. |
| PitCam jib | 1 TrussPart + 3 blocks/cylinders = 4 | arm 2 × 2 × 32; head 3 × 2.5 × 4; lens cylinder radius 1.2 length 2.5; tally 0.6³ | arm `CFrame.new(0, 104, −35)` (spans Z −51..−19 from the 270° joint inward over the pit; X ±1 clears the nearest hex corner at X ±8.2 by 7); head `CFrame.lookAt(Vector3.new(0, 102.5, −18), Vector3.new(0, 15.65, 0))` (Y 101.25..103.75, 7 above the throw apex, hanging under the arm end); lens at headCF * CFrame.new(0, 0, −3) with axis along the look; tally at headCF * CFrame.new(0, 1.55, 0.5) | arm 30,30,40; head/lens SmoothPlastic 20,20,28; tally Neon 255,40,170 | head SPOT(Front, 230,235,255, Angle 22, Brightness 2, Range 100): a hard white pool on the LavaHeart, the set's focal point; tally BLINK(1.2, 0.7); head Right face TEXT "PIT CAM" Caption style |

Rig count: 16 + 16 + 8 + 4 = **44**.

**Light inventory (all Shadows=false):** PointLights ≈ 60 (lava base 1, heat rings 4, rim posts 8, backdrop posts 6, tower plinths 9 + caps 9, under-discs 4, hub 4, showcase 15). SpotLights 21 (8 rig, PIT CAM, 2 hub keys, 7 showcase heads, 3 mini-exhibit spots). ParticleEmitters 6 (embers, haze, 2 camera flashes, lava exhibit, + none in the arena air). Beams 11 (9 searchlights, tower exhibit, LinkBeam). Tween loops: 3 blinks + piston exhibit + load cycle.

---

## 7. Palette and DEBRIS_COLOR

**`Config.DEBRIS_COLOR = Color3.fromRGB(255, 40, 170)`** (Hot Magenta), `DEBRIS_MATERIAL = SmoothPlastic`.

**Magenta whitelist (nothing else may use it):** the d10 and its throw trail (DebrisService already fades DEBRIS_COLOR → white), every tower part and the tower exhibit, the DEBRIS CLEAR logo text (monolith, board, backdrop), hub spawn ring + light, ON AIR text and tally, PIT CAM tallies, showcase wall-top strips, hero pedestal disc, return pad and return gate neon.

| Name | RGB | Material | Used on |
|---|---|---|---|
| Hot Magenta (DEBRIS_COLOR) | 255, 40, 170 | SmoothPlastic / Neon | see whitelist above |
| Void Black | 12, 12, 20 | SmoothPlastic | stage, crater wall, monolith, gates, showcase column, plaques |
| Backdrop Black | 10, 10, 18 | SmoothPlastic | backdrop wall panels |
| Panel Black | 14, 14, 22 | SmoothPlastic | hub floor, showcase floor |
| Pedestal Black | 16, 16, 24 | SmoothPlastic | pedestal bases, spawn pad, rod sleeves, exhibit sleeve |
| Deep Navy | 10, 12, 30 | SmoothPlastic | hub back wall, showcase walls; scoreboard face 8, 9, 22 |
| Audience Navy | 18, 18, 28 | SmoothPlastic | audience tiers |
| Studio Grey | 30, 30, 40 | SmoothPlastic / Truss | truss ring, light bars, jib arm, rail caps; fixture housings 20, 20, 28 |
| Collar Iron | 24, 24, 34 | Metal | piston collars |
| Rod Steel | 36, 38, 50 | Metal | piston rods (recolored) |
| Electric Cyan | 0, 220, 255 | Neon | rail edge strip, crater rim strip, rim posts, board frame, back-wall verticals, corner posts, truss joints, showcase pad, gate neon (hub side), pedestal discs, caption text |
| Grid Cyan | 0, 170, 210 | Neon | floor frames/lanes, monolith lines, backdrop top strips, side-rail caps, column edge strips, arrival marker, LinkBeam is Electric Cyan |
| Lava Base | 140, 18, 4 | Neon | full-pit lava disc |
| Lava Core | 255, 70, 15 | Neon | core disc, heat rings, lava exhibit; lava lights 255, 80, 20 |
| Lava Flow | 255, 120, 30 | Neon | two hot-spot discs |
| Lava Heart | 255, 160, 60 | Neon | center heart disc |
| Lava Crust | 28, 6, 4 | SmoothPlastic | crust plates |
| P1 Lime | 120, 255, 60 | Neon / light | platform 1 rim, under-disc, collar ring, rig color spot; deck tint 18, 34, 14 |
| P2 Sun Yellow | 255, 230, 60 | Neon / light | platform 2; deck tint 36, 34, 10 |
| P3 Sky Blue | 60, 140, 255 | Neon / light | platform 3; deck tint 12, 22, 40 |
| P4 Ice White | 240, 240, 255 | Neon / light | platform 4; deck tint 34, 34, 40 |
| Rail Glass | 200, 220, 255 | Glass, Transparency 0.7 | hub and showcase rails |
| Key White | 230, 235, 255 | light | key spots, hub key lights, PIT CAM, showcase heads; corner-post lights 200, 230, 255 |

---

## 8. Part budget

| Area | Parts |
|---|---|
| Pit + stage + backdrop + audience | 109 |
| Towers | 60 |
| Rig + PIT CAM | 44 |
| Platforms (28 existing + 36 dressing) | 64 |
| Hub | 44 |
| Showcase | 105 |
| **Static total** | **426** |
| Runtime debris cap (server parts) | +80 (plus 80 client-side d10 visuals) |

Well under 700; ~190 remain for later polish (more crust plates, a second backdrop skyline, more audience).

---

## 9. Code touchpoints (implementers)

1. **Config.luau:** changes in section 0.3.
2. **MapKit.luau additions:** `hexDeck(topCFrame, radius, thickness, props): (Part, {BasePart})` and `ringMeter(topCFrame, radius, parent): Part` (move `triangleWedges`, `buildHexDeck`, `ringElement`, `buildRingMeter` out of Arena; track color 20,22,34; the ring GUI tree must stay exactly Meter → RingMeter → Root → Left/Right → Fill (+Sweep), Value, Owner, which RingMeterController waits for); `blink(part, period, maxT)`; `spotLight(part, face, color, angle, brightness, range)` (Shadows false); `beamUp(part, height, w0, w1, color)`; `spinBob(part, dps, amplitude, period)` (single Heartbeat: `part.CFrame = CFrame.new(origin.Position + (0, sin, 0)) * CFrame.Angles(0, angle, 0) * origin.Rotation`); restyle `teleportPad`'s base to SmoothPlastic 20,20,30; `showcaseDebris` sets `anchor:SetAttribute("VisualScale", scale or 1)`.
3. **Arena.luau:** `buildPlatform` calls `MapKit.hexDeck(topCFrame, Config.PLATFORM_RADIUS, Config.PLATFORM_THICKNESS, {Color = color, Material = DiamondPlate, Name = "Deck"})` and `MapKit.ringMeter(topCFrame, Config.PLATFORM_RADIUS, model)`; nothing else changes (dress() recolors the Deck parts and rod by name afterwards).
4. **DebrisVisuals.luau (client), in `track`:** after cloning the template, `local scale = debris:GetAttribute("VisualScale"); if typeof(scale) == "number" and scale > 0 and scale ~= 1 then clone.Size = clone.Size * scale end` — the 3× hero d10 then renders 6 studs across (MeshPart resizes scale the EditableMesh geometry; the Ball fallback scales too).
5. **Towers.build** builds both the "Towers" and "Rig" models (rig aim targets computed from Config.ARENA_RADIUS / slot angles, not from Arena.platforms).
6. **Showcase.build** owns the two animation loops (piston tween sequence, Load 0→100 cycle) and the LinkBeam (create the Beam after Hub.build has run — Arena.build calls Hub.build before Showcase.build, so `workspace.DebrisClearArena` is not yet parented; find the hub lintel's "LinkA" attachment through the folder passed in as `parent`).
7. **Studio:** set Lighting.Technology = Future by hand. Mention it in STUDIO_BUILD.md when the paste files are next regenerated.
8. **Paste files:** do not regenerate STUDIO_BUILD.md / studio-installer.luau until the owner asks for the final copy. If the session is about to run out, run `python3 tools/build_paste_doc.py` at a clean stopping point and tell the owner: give the other Claude `STUDIO_BUILD.md` (it lists every script with its Studio location) or paste `studio-installer.luau` into Studio's Command Bar.

## 10. Acceptance checklist (verify in Studio before calling it done)

- Kill line: no collidable top between Y 40 and Y 86 within radius 100 (stage 36, plinths 38, crater rim 36.5 non-collide, rim posts non-collide, audience non-collide, tower rings non-collide, truss ring ≥ 103). Drop a piece on each tower body and the stage: it dies.
- Columns: nothing inside any hex footprint above Y 60 or in its column (rig at r 51, jib at X 0 with |X| ≤ 1 vs nearest corner 8.2, tower beams outside r 74).
- Sight lines: from the hub eye (0, 92, 95) the whole lava lake from Z 57.6 south, all four decks and their spawn columns are unobstructed; T3/T4 body edges at |X| 40 vs the sight fan |X| ≤ 32.
- Pit: everything inside r 65 below Y 40 except LavaBase is CanCollide=false; the crushed deck's under-disc lands on the sleeve top.
- Colors: nothing magenta outside the whitelist; nothing red outside the lava (LAND_SHADOW discs stay red by Config); P3 is sky blue.
- Z-fighting guards: lava layers at distinct heights (15.0 / 15.4 / 15.65 / 15.7 / 16.1 tops), crater wall 0.2 proud of the stage edge with the rim strip over the seam, neon strips 0.15–0.25 proud of host faces, sleeve top 0.1 under the dropped under-disc.
- Showcase: arrival faces the hero, plaques readable from the arrival, ring meter on the HEX exhibit cycles, piston pumps, PIT CAM and RIG spots visibly pool on their discs, return pad teleports to the hub spawn, hub pad teleports to the arrival, LinkBeam spans the gates.
- Budget: static part count 426 ± the optional seat SurfaceGuis (0 parts).

### Residual risks
- On graphics levels < 5 SmoothPlastic loses its specular; the set reads matte black with neon — intended fallback, still coherent.
- Bloom on the lava at graphics 10: if the core blows out, darken LavaBase to (110,14,3) first, then raise Threshold to 1.05; keep LavaCore bright.
- T8 stands behind the pit center in the ball's color (≈2.6° of the hub view). A crossing d10 is lit orange from below by the lava lights (range 60 reaches Y 74) and carries its white-fading trail, while T8 sits in dim ambient beyond the lava light; if playtests still show confusion, move T8 to radius 90.
- Default night sky shows a moon; acceptable for the synthwave look. Do not add a Sky with blank textures (renders undefined).
- EditableMesh d10 needs Mesh/Image APIs enabled for a published place (existing README note); the showcase hero falls back to a 6-stud ball.