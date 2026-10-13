#!/usr/bin/env python3
"""Assemble the mGBA script from the template, the UI and build maps.

Usage: build_lua.py <gamedata.json> <out.lua> <name>=<rom.map> [<name>=<rom.map> ...]
"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).parent


def map_symbol(map_path, name):
    for line in open(map_path, encoding="latin-1"):
        m = re.match(r"^\s+0x([0-9a-f]{8})\s+" + re.escape(name) + r"\s*$", line)
        if m:
            return int(m.group(1), 16)
    raise SystemExit(f"{name} not found in {map_path}")


def lua_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    gamedata_path, out_path = sys.argv[1], sys.argv[2]
    builds = []
    for spec in sys.argv[3:]:
        name, map_path = spec.split("=", 1)
        rc = map_symbol(map_path, "gRemoteControl")
        sig = map_symbol(map_path, "gRemoteControlSignature")
        builds.append((name, rc, sig))

    gamedata = json.loads(Path(gamedata_path).read_text(encoding="utf-8"))
    charmap = gamedata.pop("charmap")
    html = (HERE / "ui.html").read_text(encoding="utf-8")
    html = html.replace("/*GAMEDATA*/null", json.dumps(gamedata, ensure_ascii=False, separators=(",", ":")))
    assert "]==========]" not in html

    build_lines = "\n".join(
        f'  {{ name = {lua_string(n)}, rc = 0x{rc:08X}, sig = 0x{sig:08X} }},' for n, rc, sig in builds)
    charmap_lines = []
    row = []
    for k, v in sorted(((int(k), v) for k, v in charmap.items())):
        row.append(f"[0x{k:02X}]={lua_string(v)}")
        if len(row) == 8:
            charmap_lines.append("  " + ", ".join(row) + ",")
            row = []
    if row:
        charmap_lines.append("  " + ", ".join(row) + ",")

    lua = (HERE / "server.lua.in").read_text(encoding="utf-8")
    lua = lua.replace("--[[BUILDS]]", build_lines)
    lua = lua.replace("--[[CHARMAP]]", "\n".join(charmap_lines))
    lua = lua.replace("--[[HTML]]", html)
    Path(out_path).write_text(lua, encoding="utf-8", newline="\n")
    print(f"wrote {out_path}: {len(lua)} bytes, builds: " + ", ".join(f"{n}@{rc:#x}" for n, rc, _ in builds))


if __name__ == "__main__":
    main()
