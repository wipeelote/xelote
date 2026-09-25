#!/usr/bin/env python3
"""Generate paste-ready Studio build files from src/.

  STUDIO_BUILD.md          one document for another Claude (or a human) to
                           recreate the game in Roblox Studio, file by file
  studio-installer.luau    one script for the Studio Command Bar (or a Studio
                           MCP "run code" tool) that creates every script

Run from the repo root:  python3 tools/build_paste_doc.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# (source dir, Studio parent path, service, folder name)
LOCATIONS = [
    ("src/shared", "ReplicatedStorage", "DebrisClear"),
    ("src/server", "ServerScriptService", "DebrisClear"),
    ("src/client", "StarterPlayer.StarterPlayerScripts", "DebrisClear"),
]

# Reading order: config and shared helpers first, then server, then client.
ORDER = [
    "src/shared/Config.luau",
    "src/shared/HexGeometry.luau",
    "src/shared/DecahedronMesh.luau",
    "src/shared/Ballistics.luau",
    "src/shared/Remotes.luau",
    "src/server/Main.server.luau",
    "src/server/Arena.luau",
    "src/server/LoadService.luau",
    "src/server/DebrisService.luau",
    "src/server/ThrowService.luau",
    "src/server/RateLimiter.luau",
    "src/client/Main.client.luau",
    "src/client/Hud.luau",
    "src/client/RingMeterController.luau",
    "src/client/InteractionController.luau",
    "src/client/DebrisVisuals.luau",
]


def describe(rel: str):
    path = Path(rel)
    for src_dir, parent, folder in LOCATIONS:
        if rel.startswith(src_dir + "/"):
            stem = path.name[: -len(".luau")]
            if stem.endswith(".server"):
                return parent, folder, stem[: -len(".server")], "Script"
            if stem.endswith(".client"):
                return parent, folder, stem[: -len(".client")], "LocalScript"
            return parent, folder, stem, "ModuleScript"
    raise ValueError(rel)


def main():
    all_files = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "src").rglob("*.luau"))
    missing = set(all_files) - set(ORDER)
    stale = set(ORDER) - set(all_files)
    assert not missing and not stale, f"update ORDER: missing={missing} stale={stale}"

    entries = []
    for rel in ORDER:
        parent, folder, name, cls = describe(rel)
        source = (ROOT / rel).read_text()
        assert "]=====]" not in source, rel
        entries.append((rel, parent, folder, name, cls, source))

    # ---------------------------------------------------------------- markdown
    md = []
    md.append("# Debris Clear: Roblox Studio build sheet\n")
    md.append(
        "> **For Claude:** this document is the complete source of a 4-player, "
        "server-authoritative Roblox minigame (Machine Party-style *Debris Clear*). "
        "Recreate it in the open Roblox Studio place **exactly** as listed below. "
        "Do not rewrite, reformat, or \"improve\" any script while copying it.\n"
    )
    md.append("## How to build it\n")
    md.append(
        "1. Create three **Folders**, each named `DebrisClear`:\n"
        "   - `ReplicatedStorage.DebrisClear`\n"
        "   - `ServerScriptService.DebrisClear`\n"
        "   - `StarterPlayer.StarterPlayerScripts.DebrisClear`\n"
        "2. For every section under **Scripts**, create an instance of the stated **class** "
        "with the stated **name** inside the stated folder, and set its `Source` to the code "
        "block verbatim.\n"
        "   - A `Script` or `LocalScript` must have its class set exactly as written. Scripts "
        "find each other with `script.Parent.<Name>`, so the names must match exactly "
        "(case-sensitive, no extension).\n"
        "3. Leave the rest of the place alone. The server script builds the arena, "
        "pit, platforms, and spawn hub at runtime and disables any other SpawnLocations.\n"
        "4. Optional: set `Players.CharacterAutoLoads = false`. The server also sets it at runtime.\n"
        "5. To test: set `MIN_PLAYERS = 1` in `Config` for solo play, then press **Play**, "
        "or use **Test → Clients and Servers** with 2–4 players.\n"
    )
    md.append(
        "**Shortcut:** `studio-installer.luau` (in the same repo) is a single script that "
        "creates everything below. Paste it into the Studio **Command Bar**, or run it with a "
        "Studio MCP \"run code\" tool.\n"
    )
    md.append("## Instance tree\n")
    md.append("```text")
    current = None
    for rel, parent, folder, name, cls, _ in sorted(entries, key=lambda e: (e[1], e[3])):
        if parent != current:
            md.append(f"{parent}")
            md.append(f"└─ {folder} (Folder)")
            current = parent
        md.append(f"   ├─ {name} ({cls})")
    md.append("```\n")
    md.append("## Controls (what players do)\n")
    md.append(
        "| Action | Keyboard/Mouse | Gamepad | Touch |\n"
        "|---|---|---|---|\n"
        "| Grab nearby debris (within 5 studs) | `E` or click the GRAB button | `X` | Tap the GRAB button |\n"
        "| Throw held debris | Left click (aims at cursor) or the THROW button | `R2` (aims at screen center) | Tap the THROW button (aims at screen center) |\n"
    )
    md.append(
        "While you hold debris, a dotted arc previews where it will land: green means in range, "
        "orange means out of range.\n"
    )
    md.append("## Scripts\n")
    for i, (rel, parent, folder, name, cls, source) in enumerate(entries, 1):
        md.append(f"### {i}. `{parent}.{folder}.{name}`: **{cls}**\n")
        md.append(f"_Repo file: `{rel}`_\n")
        md.append("```lua")
        md.append(source.rstrip("\n"))
        md.append("```\n")
    (ROOT / "STUDIO_BUILD.md").write_text("\n".join(md))

    # --------------------------------------------------------------- installer
    lua = []
    lua.append("-- Debris Clear installer. Generated by tools/build_paste_doc.py; do not edit by hand.")
    lua.append("-- Paste into the Roblox Studio Command Bar (View > Command Bar) and press Enter.")
    lua.append("-- Re-running it replaces the three DebrisClear folders with fresh copies.")
    lua.append("local ChangeHistoryService = game:GetService(\"ChangeHistoryService\")")
    lua.append("local recording = ChangeHistoryService:TryBeginRecording(\"Install Debris Clear\")")
    lua.append("local function folderAt(path)")
    lua.append("\tlocal parent = game")
    lua.append("\tfor segment in string.gmatch(path, \"[^%.]+\") do")
    lua.append("\t\tparent = parent:FindFirstChild(segment) or game:GetService(segment)")
    lua.append("\tend")
    lua.append("\tlocal old = parent:FindFirstChild(\"DebrisClear\")")
    lua.append("\tif old then old:Destroy() end")
    lua.append("\tlocal folder = Instance.new(\"Folder\")")
    lua.append("\tfolder.Name = \"DebrisClear\"")
    lua.append("\tfolder.Parent = parent")
    lua.append("\treturn folder")
    lua.append("end")
    lua.append("local folders = {")
    for _, parent, _ in LOCATIONS:
        lua.append(f"\t[\"{parent}\"] = folderAt(\"{parent}\"),")
    lua.append("}")
    lua.append("local function add(parentPath, className, name, source)")
    lua.append("\tlocal s = Instance.new(className)")
    lua.append("\ts.Name = name")
    lua.append("\ts.Source = source")
    lua.append("\ts.Parent = folders[parentPath]")
    lua.append("end")
    for rel, parent, folder, name, cls, source in entries:
        lua.append(f"add(\"{parent}\", \"{cls}\", \"{name}\", [=====[")
        lua.append(source.rstrip("\n"))
        lua.append("]=====])")
    lua.append("game:GetService(\"Players\").CharacterAutoLoads = false")
    lua.append("if recording then ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end")
    lua.append(f"print(\"[DebrisClear] Installed {len(entries)} scripts. Press Play to test (set Config.MIN_PLAYERS = 1 for solo).\")")
    (ROOT / "studio-installer.luau").write_text("\n".join(lua) + "\n")
    print(f"wrote STUDIO_BUILD.md and studio-installer.luau ({len(entries)} scripts)")


if __name__ == "__main__":
    main()
