# Debris Clear

A 4-player, server-authoritative Roblox minigame based on Machine Party's *Debris Clear*.
Each player stands on a hex platform over a pit. d10-shaped debris rains down and every piece
resting on your platform adds 15 load. Reach 100 and your piston drops, crushing you and
your debris. You can pick debris up and throw it off the edge, or throw it onto a rival's
platform. The last platform standing wins.

## Getting it into Studio

Pick whichever is easiest:

- **Paste into another Claude / by hand:** [`STUDIO_BUILD.md`](STUDIO_BUILD.md) holds every script with its exact
  Studio location and class, plus build instructions.
- **One paste in Studio:** paste [`studio-installer.luau`](studio-installer.luau) into the Command Bar
  (View → Command Bar) and press Enter. It creates all 16 scripts.
- **Rojo** (for editing in the repo), described below.

Both paste files are generated from `src/`. After changing code, run `python3 tools/build_paste_doc.py`.

This is a [Rojo](https://rojo.space) project.

```sh
rokit install              # or: aftman / cargo install rojo --version 7.4.4
rojo serve                 # then click "Connect" in the Rojo Studio plugin
# or build a place file directly:
rojo build -o DebrisClear.rbxlx
```

To test alone, set `Config.MIN_PLAYERS = 1`. For a real match, use **Test → Clients and Servers**
with 2–4 players.

**EditableMesh:** the d10 is generated at runtime with `EditableMesh`. In a published game this
needs the Mesh/Image APIs enabled for the experience (Game Settings → Security). If it's
unavailable, debris falls back to a sphere with a warning. To avoid the dependency, import
`assets/decahedron.obj` through the Asset Manager and paste its id into `Config.DEBRIS_MESH_ID`.

## Layout

| Path | Runs on | Purpose |
|---|---|---|
| `src/shared/Config.luau` | both | **Every tunable value** |
| `src/shared/HexGeometry.luau` | both | Hex corners, point-in-hex, random spawn point |
| `src/shared/DecahedronMesh.luau` | both | Pentagonal trapezohedron via EditableMesh / asset |
| `src/shared/Ballistics.luau` | both | Throw arc math shared by the server launch and the client aim preview |
| `src/shared/Remotes.luau` | both | RemoteEvent definitions |
| `src/server/Arena.luau` | server | (1) Hex platforms, piston rods, pit, spawn hub, ring-meter SurfaceGui, piston tween |
| `src/server/DebrisService.luau` | server | (2) Spawner, partial-gravity physics, landing detection |
| `src/server/ThrowService.luau` | server | (3) ProximityPrompt pickup, validated throw remote, knockback |
| `src/server/LoadService.luau` | server | (4) `platformLoads[player]`, elimination |
| `src/server/RateLimiter.luau` | server | (5) Per-player token bucket for remotes |
| `src/server/Main.server.luau` | server | Spawning and round loop |
| `src/client/InteractionController.luau` | client | Grab/throw action button, key and gamepad bindings, aim arc, knockback |
| `src/client/*` (others) | client | Ring animation, local d10 visuals, status HUD |

## Controls

| Action | Keyboard/Mouse | Gamepad | Touch |
|---|---|---|---|
| Grab debris within 5 studs | `E`, or click GRAB | `X` | Tap GRAB |
| Throw | Left click (aims at cursor), or click THROW | `R2` (aims at screen center) | Tap THROW (aims at screen center) |

While you hold debris, a dotted arc previews the exact server trajectory. Green means in range,
orange means out of range.

## Spawn hub

Players spawn on a raised overlook 95 studs from the pit and 28 studs above the platforms, facing
the arena. A glass front rail and a status scoreboard sit on the back wall. The pit kill line
applies only inside the arena column (`ARENA_KILL_RADIUS`) and to players still in the round.
Spectators who fall off the hub are teleported back instead of killed.

## How the pieces fit

- **Load is derived from resting debris.** Every 0.1s the server checks each loose piece. If it
  is over a live hex, within `LAND_HEIGHT_BAND` of the deck, and slower than `LAND_MAX_SPEED`,
  it gets assigned to that platform (+15). When it leaves (picked up, rolled off, knocked off),
  the 15 is removed again. Body hits never move load.
- **Throws:** the client sends only a camera-raycast aim point. The server checks type,
  finiteness, rate, cooldown, and hold ownership. It launches from its own view of the hold
  position, solves a ballistic arc at 60 studs/s, drives it with `LinearVelocity` for
  `THROW_BOOST_TIME`, and then lets gravity take over.
- **Debris gravity:** at default gravity (196.2), a 60 stud/s throw maxes out at ~18 studs of
  range, which is too short to reach a rival platform. Each debris piece carries a `VectorForce`
  cancelling 70% of gravity (`DEBRIS_GRAVITY_SCALE = 0.3`), for ~61 studs of range. Players are
  unaffected.
- **Knockback:** the server detects the hit and decides the velocity. Because the victim's client
  owns its character physics, the server sends that velocity to the victim, which applies it with
  a short `PlatformStand`.
- **Ring meter:** the server writes the `Load`/`Capacity` attributes. Each client tweens a
  two-half clipped ring (UIGradient sweep). The ring drains as load rises and shifts green → red.
