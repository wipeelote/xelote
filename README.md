# Debris Clear

A 4-player, server-authoritative Roblox minigame based on Machine Party's *Debris Clear*.
Each player stands on a hex platform over a pit. d10-shaped debris rains down and every piece
resting on your platform adds 15 load. Reach 100 and your piston drops, crushing you and
your debris. You can pick debris up and throw it off the edge, or throw it onto a rival's
platform. The last platform standing wins.

## Getting it into Studio

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
| `src/shared/Remotes.luau` | both | RemoteEvent definitions |
| `src/server/Arena.luau` | server | (1) Hex platforms, piston rods, pit, lobby, ring-meter SurfaceGui, piston tween |
| `src/server/DebrisService.luau` | server | (2) Spawner, partial-gravity physics, landing detection |
| `src/server/ThrowService.luau` | server | (3) ProximityPrompt pickup, validated throw remote, knockback |
| `src/server/LoadService.luau` | server | (4) `platformLoads[player]`, elimination |
| `src/server/RateLimiter.luau` | server | (5) Per-player token bucket for remotes |
| `src/server/Main.server.luau` | server | Spawning and round loop |
| `src/client/*` | client | Ring animation, local d10 visuals, throw input and knockback, HUD |

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
