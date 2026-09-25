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

# (source dir, Studio path of the DebrisClear folder that holds it)
LOCATIONS = [
    ("src/shared", "ReplicatedStorage.DebrisClear"),
    ("src/server", "ServerScriptService.DebrisClear"),
    ("src/client", "StarterPlayer.StarterPlayerScripts.DebrisClear"),
]


def describe(rel: str):
    """-> (studio parent path, name, class). Subdirectories become nested Folders."""
    path = Path(rel)
    for src_dir, base in LOCATIONS:
        if rel.startswith(src_dir + "/"):
            sub = path.parent.relative_to(src_dir).parts
            parent = ".".join((base, *sub))
            stem = path.name[: -len(".luau")]
            if stem.endswith(".server"):
                return parent, stem[: -len(".server")], "Script"
            if stem.endswith(".client"):
                return parent, stem[: -len(".client")], "LocalScript"
            return parent, stem, "ModuleScript"
    raise ValueError(rel)


def sort_key(rel: str):
    """Reading order: shared, server, client; Config and Main first, top-level
    before subfolders, then alphabetical."""
    location = next(i for i, (d, _) in enumerate(LOCATIONS) if rel.startswith(d + "/"))
    path = Path(rel)
    depth = len(path.parts)
    stem = path.name.split(".")[0]
    first = 0 if stem == "Config" else 1 if stem == "Main" else 2
    return (location, depth, first, str(path.parent), stem)


def main():
    all_files = sorted((str(p.relative_to(ROOT)) for p in (ROOT / "src").rglob("*.luau")), key=sort_key)

    entries = []
    for rel in all_files:
        parent, name, cls = describe(rel)
        source = (ROOT / rel).read_text()
        assert "]=====]" not in source, rel
        entries.append((rel, parent, name, cls, source))
    folders = []
    for _, parent, _, _, _ in entries:
        if parent not in folders:
            folders.append(parent)

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
        "1. Create these **Folders** (the last path segment is the folder's name; the rest already exist):\n"
        + "".join(f"   - `{f}`\n" for f in folders)
        + "2. For every section under **Scripts**, create an instance of the stated **class** "
        "with the stated **name** inside the stated folder, and set its `Source` to the code "
        "block verbatim.\n"
        "   - A `Script` or `LocalScript` must have its class set exactly as written. Scripts "
        "find each other with `script.Parent.<Name>`, so the names must match exactly "
        "(case-sensitive, no extension).\n"
        "3. Leave the rest of the place alone (a Baseplate is fine; it can be deleted). The server script builds "
        "the whole NEON PIT set at runtime: lava crater, stage, towers, light rig, platforms, spawn hub and "
        "showcase gallery, and disables any other SpawnLocations.\n"
        "4. Optional: set `Players.CharacterAutoLoads = false`. The server also sets it at runtime.\n"
        "5. In the Explorer select **Lighting** and set **Technology = Future** (a script can't set it). "
        "ShadowMap works too but loses the glossy floor reflections.\n"
        "6. To test: set `MIN_PLAYERS = 1` in `Config` for solo play, then press **Play**, "
        "or use **Test → Clients and Servers** with 2–4 players.\n"
    )
    md.append(
        "**Shortcut:** `studio-installer.luau` (in the same repo) is a single script that "
        "creates everything below. Paste it into the Studio **Command Bar**, or run it with a "
        "Studio MCP \"run code\" tool.\n"
    )
    md.append("## Instance tree\n")
    md.append("```text")
    for folder in folders:
        md.append(f"{folder} (Folder)")
        for rel, parent, name, cls, _ in entries:
            if parent == folder:
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
    for i, (rel, parent, name, cls, source) in enumerate(entries, 1):
        md.append(f"### {i}. `{parent}.{name}`: **{cls}**\n")
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
    lua.append("local function ensureFolder(path)")
    lua.append("\tlocal parent = game")
    lua.append("\tlocal segments = string.split(path, \".\")")
    lua.append("\tfor i, segment in segments do")
    lua.append("\t\tlocal child = parent:FindFirstChild(segment)")
    lua.append("\t\tif not child and i == 1 then child = game:GetService(segment) end")
    lua.append("\t\tif not child then")
    lua.append("\t\t\tchild = Instance.new(\"Folder\")")
    lua.append("\t\t\tchild.Name = segment")
    lua.append("\t\t\tchild.Parent = parent")
    lua.append("\t\tend")
    lua.append("\t\tparent = child")
    lua.append("\tend")
    lua.append("\treturn parent")
    lua.append("end")
    lua.append("-- Start fresh: remove any previous install.")
    for _, base in LOCATIONS:
        service, folder = base.rsplit(".", 1)
        lua.append(f"do local old = ensureFolder(\"{service}\"):FindFirstChild(\"{folder}\") if old then old:Destroy() end end")
    lua.append("local folders = {")
    for f in folders:
        lua.append(f"\t[\"{f}\"] = ensureFolder(\"{f}\"),")
    lua.append("}")
    lua.append("local function add(parentPath, className, name, source)")
    lua.append("\tlocal s = Instance.new(className)")
    lua.append("\ts.Name = name")
    lua.append("\ts.Source = source")
    lua.append("\ts.Parent = folders[parentPath]")
    lua.append("end")
    for rel, parent, name, cls, source in entries:
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
