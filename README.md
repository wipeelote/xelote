# Debris Clear

A 4-player, server-authoritative Roblox minigame based on Machine Party's *Debris Clear*, staged
as **NEON PIT**: a synthwave game show over a lava crater. Each player stands on a black hex podium
over the lava. Hot-magenta d10 debris rains down and every piece resting on your podium adds 15
load. Reach 100 and your piston drops, crushing you and your debris into the lava. You can pick
debris up and throw it off the edge, or throw it onto a rival's podium. The last podium standing
wins.

## Getting it into Studio

Pick whichever is easiest:

- **Paste into another Claude / by hand:** [`STUDIO_BUILD.md`](STUDIO_BUILD.md) holds every script with its exact
  Studio location and class, plus build instructions.
- **One paste in Studio:** paste [`studio-installer.luau`](studio-installer.luau) into the Command Bar
  (View → Command Bar) and press Enter. It creates every script.
- **Rojo** (for editing in the repo), described below.

Both paste files are generated from `src/`. After changing code, run `python3 tools/build_paste_doc.py`.

This is a [Rojo](https://rojo.space) project.

```sh
rokit install              # or: aftman / cargo install rojo --version 7.4.4
rojo serve                 # then click "Connect" in the Rojo Studio plugin
# or build a place file directly:
rojo build -o DebrisClear.rbxlx
```

Studio notes:

- Set **Lighting → Technology = Future** by hand (scripts can't). The set still works on ShadowMap;
  it just loses the glossy reflections.
- To test alone, set `Config.MIN_PLAYERS = 1`. For a real match, use **Test → Clients and Servers**
  with 2–4 players.
- **EditableMesh:** the d10 is generated at runtime with `EditableMesh`. A published game needs the
  Mesh/Image APIs enabled (Game Settings → Security), otherwise debris falls back to a sphere with a
  warning. To avoid the dependency, import `assets/decahedron.obj` through the Asset Manager and
  paste its id into `Config.DEBRIS_MESH_ID`.

## Layout

| Path | Runs on | Purpose |
|---|---|---|
| `src/shared/Config.luau` | both | **Every tunable value** (values marked `PLACEHOLDER` are first guesses) |
| `src/shared/HexGeometry.luau` | both | Hex corners, point-in-hex, random spawn point |
| `src/shared/DecahedronMesh.luau` | both | Pentagonal trapezohedron via EditableMesh / asset |
| `src/shared/Ballistics.luau` | both | Throw arc math shared by the server launch and the client aim preview |
| `src/shared/Remotes.luau` | both | RemoteEvent definitions (`ThrowDebris`, `Knockback`, `Effects`) |
| `src/server/Main.server.luau` | server | Spawning, teleport pads, fall rescue, round loop |
| `src/server/Arena.luau` | server | The four hex platforms (deck, rod, ring meter, piston drop); calls the `Map/` modules |
| `src/server/DebrisService.luau` | server | Spawner with pressure curve, partial-gravity physics, landing detection with hysteresis, trails, crush scatter |
| `src/server/ThrowService.luau` | server | Pickup, hold timer, validated throw with wind-up, knockback |
| `src/server/LoadService.luau` | server | `platformLoads[player]`, elimination |
| `src/server/RateLimiter.luau` | server | Per-player token bucket for remotes |
| `src/server/Map/MapKit.luau` | server | Primitive-part builder helpers shared by the map modules |
| `src/server/Map/Pit.luau` | server | Lava lake, crust, crater wall, stage, backdrop skyline, audience banks |
| `src/server/Map/Towers.luau` | server | Nine mono-colored towers in the debris color + the truss light rig and PIT CAM jib |
| `src/server/Map/PlatformDressing.luau` | server | Neon rim, under-glow, collar per platform |
| `src/server/Map/Hub.luau` | server | Spawn balcony overlooking the pit, scoreboard, SHOWCASE teleport gate |
| `src/server/Map/Showcase.luau` | server | Backstage gallery of the game's models with plaques, BACK TO HUB gate |
| `src/server/Map/Lighting.luau` | server | Night sky, atmosphere, bloom, color correction |
| `src/client/Main.client.luau` | client | Entry point |
| `src/client/InteractionController.luau` | client | GRAB/THROW action button, key and gamepad bindings, aim arc, hold countdown, arm animation, knockback |
| `src/client/DebrisVisuals.luau` | client | Local d10 rendering and the red landing-warning discs |
| `src/client/RingMeterController.luau` | client | Ring meter animation and rival load billboards |
| `src/client/EffectsController.luau` | client | Camera shake, dust puffs, confetti, winner camera |
| `src/client/Hud.luau` | client | Round status banner |
| `docs/NEON_PIT_BRIEF.md` | — | The full map design brief the `Map/` modules implement |

## Controls

| Action | Keyboard/Mouse | Gamepad | Touch |
|---|---|---|---|
| Grab debris within 5 studs | `E`, or click GRAB | `X` | Tap GRAB |
| Throw | Left click (aims at cursor), or click THROW | `R2` (aims at screen center) | Tap THROW (aims at screen center) |

While you hold debris, a dotted arc previews the exact server trajectory (green in range, orange out
of range) and a bar on the button counts down the 4-second hold limit.

## How a round plays

1. Everyone spawns on the **hub**, a balcony 28 studs above the podiums with a clear view of the pit.
   Step on the cyan **SHOWCASE** pad to visit the gallery; the magenta **BACK TO HUB** pad returns you.
2. After the intermission, up to four players are placed on the podiums. Debris spawns every 2–4s
   over each live podium, tightening to every 1–1.8s over the first minute.
3. A falling piece casts a red warning disc where it will hit. A piece counts toward a podium after
   resting on it for 0.3s and stops counting 0.3s after it leaves; body hits never move load.
4. Grab a piece and throw it off the edge (−15 for you) or onto a rival (+15 for them). A direct hit
   knocks the victim back. Held pieces drop after 4s.
5. At 100 load the piston drops in 0.3s: the deck, the player and their debris go into the lava.
6. Last podium standing wins; confetti and a short winner camera, then everyone returns to the hub.

## How the pieces fit

- **Load is derived from resting debris.** Every 0.1s the server checks each loose piece against
  the live hexes with settle/unsettle timers, so edge-balancing pieces don't flicker the load.
- **Throws:** the client sends only a camera-raycast aim point. The server checks type, finiteness,
  rate, cooldown and hold ownership, waits the 0.15s wind-up, re-validates, launches from its own
  view of the hold position on a ballistic arc at 60 studs/s (`LinearVelocity` for 0.1s, then gravity).
- **Debris gravity:** at default gravity a 60 stud/s throw only reaches ~18 studs. Each piece
  carries a `VectorForce` cancelling 70% of gravity (`DEBRIS_GRAVITY_SCALE = 0.3`) for ~61 studs
  of range. Players are unaffected.
- **Effects:** the server fires one `Effects` remote (`Land`, `Crush`, `Win`); clients render
  puffs, shake, confetti and the winner camera. Nothing gameplay-relevant lives on the client.
- **Map:** everything is built at runtime from primitive parts (no asset ids). The design and every
  dimension are in `docs/NEON_PIT_BRIEF.md`; the colors are in `Config.MAP`. Magenta is reserved
  for the debris and the towers, red for the lava.
