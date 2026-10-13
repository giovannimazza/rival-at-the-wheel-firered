#!/usr/bin/env python3
"""Extract names and move data from a built ROM + its linker map.

Usage: gen_gamedata.py <rom.gba> <rom.map> <charmap.txt> <out.json>
Writes JSON with species, moves, items, abilities, types and the
single-byte character map used to decode in-game strings.
"""
import json
import re
import sys

ROM_BASE = 0x08000000


def parse_map(path):
    syms = {}
    for line in open(path, encoding="latin-1"):
        m = re.match(r"^\s+0x([0-9a-f]{8})\s+(g\w+)\s*$", line)
        if m:
            syms[m.group(2)] = int(m.group(1), 16)
    return syms


def parse_charmap(path):
    table = {}
    for line in open(path, encoding="utf-8"):
        line = line.split("@")[0].strip()
        m = re.match(r"^'(.+)'\s*=\s*([0-9A-Fa-f]{2})$", line)
        if not m:
            continue
        ch, byte = m.group(1), int(m.group(2), 16)
        if ch.startswith("\\"):
            continue
        if byte not in table:
            table[byte] = ch
    table[0x00] = " "
    return table


def main():
    rom_path, map_path, charmap_path, out_path = sys.argv[1:5]
    rom = open(rom_path, "rb").read()
    syms = parse_map(map_path)
    cmap = parse_charmap(charmap_path)

    def raw(addr, n):
        off = addr - ROM_BASE
        return rom[off:off + n]

    def text(addr, n):
        out = []
        for b in raw(addr, n):
            if b == 0xFF:
                break
            out.append(cmap.get(b, "?"))
        return "".join(out).strip()

    NUM_SPECIES, MOVES_COUNT, ITEMS_COUNT, ABILITIES_COUNT, NUM_TYPES = 412, 355, 375, 78, 18

    species = [text(syms["gSpeciesNames"] + i * 11, 11) for i in range(NUM_SPECIES)]
    species_types = []
    for i in range(NUM_SPECIES):
        info = raw(syms["gSpeciesInfo"] + i * 28, 28)
        species_types.append([info[6], info[7]])
    moves = []
    for i in range(MOVES_COUNT):
        d = raw(syms["gBattleMoves"] + i * 12, 12)
        moves.append({
            "n": text(syms["gMoveNames"] + i * 13, 13),
            "e": d[0], "p": d[1], "t": d[2], "a": d[3], "pp": d[4],
            "c": d[5], "tg": d[6], "pr": d[7] - 256 if d[7] > 127 else d[7],
        })
    items = [text(syms["gItems"] + i * 44, 14) for i in range(ITEMS_COUNT)]
    abilities = [text(syms["gAbilityNames"] + i * 13, 13) for i in range(ABILITIES_COUNT)]
    types = [text(syms["gTypeNames"] + i * 7, 7) for i in range(NUM_TYPES)]

    # Sanity checks against well-known values
    assert species[1] == "BULBASAUR", species[1]
    assert moves[1]["n"] == "POUND" and moves[1]["p"] == 40, moves[1]
    assert items[13] == "POTION", items[13]
    assert types[10] == "FIRE", types
    assert species_types[1] == [12, 3]

    data = {
        "species": species,
        "speciesTypes": species_types,
        "moves": moves,
        "items": items,
        "abilities": abilities,
        "types": types,
        "charmap": {str(k): v for k, v in sorted(cmap.items())},
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    print("ok", len(species), len(moves), len(items), len(abilities))


if __name__ == "__main__":
    main()
