# Rival at the Wheel — Pokémon FireRed

A two-player hack for **Pokémon FireRed (USA)**. Player 1 plays the game normally in mGBA, turbo included. Player 2 controls the opposing trainers in every trainer battle, from a phone or a PC anywhere on the internet.

On the trainer's turn, the game pauses and waits. Player 2 picks a move (and a target in double battles), uses one of the trainer's items, switches Pokémon, or lets the game's own AI decide. Then the battle continues.

```
 Player 1 (PC)                                     Player 2 (phone / PC)
┌──────────────────────────┐   HTTP    ┌─────────┐   HTTPS   ┌──────────────┐
│ mGBA                     │◄─────────►│ tunnel  │◄─────────►│ web page     │
│  ├─ patched FireRed ROM  │  :8888    │ (cloud- │           │ (moves, items│
│  └─ rival_at_the_wheel   │           │ flared) │           │  switches)   │
│     .lua (web server     │           └─────────┘           └──────────────┘
│     inside the emulator) │
└──────────────────────────┘
```

## What's in this repository

| Path | What it is |
|---|---|
| `patches/RivalAtTheWheel_FireRed_v1.0.bps` | Patch for FireRed USA rev 1.0 (SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`) |
| `patches/RivalAtTheWheel_FireRed_v1.1.bps` | Patch for FireRed USA rev 1.1 (SHA-1 `dd5945db9b930750cb39d00c84da8571feebf417`) |
| `rival_at_the_wheel.lua` | The mGBA script: web server, game bridge and the player 2 page, all in one file |
| `start_tunnel.bat` | Windows helper that puts the script online through a free Cloudflare quick tunnel |
| `source/pokefirered-rival-at-the-wheel.diff` | All game code changes, as a patch for the [pret/pokefirered](https://github.com/pret/pokefirered) decompilation |
| `tools/` | Script templates, the player 2 page and the generators used to build `rival_at_the_wheel.lua` |

No ROMs are included. You need your own copy of the game.

> The game-side code uses the internal name *remote trainer* (`battle_remote.c`, `gRemoteControl`, ROM signature `REMOTE-TRAINER-1`). It's the same project.

## Requirements

- Your own **Pokémon FireRed (USA, English)** ROM, rev 1.0 or 1.1. Other languages (Italian, French…) won't work.
- **mGBA 0.10.5 or newer** ([mgba.io](https://mgba.io)), which has Lua scripting.
- For internet play: **cloudflared**. `start_tunnel.bat` tries to install it with `winget`.

## Quick start

### 1. Patch the ROM (once)

1. Open [Rom Patcher JS](https://www.marcrobledo.com/RomPatcher.js/).
2. Select your FireRed ROM and `RivalAtTheWheel_FireRed_v1.0.bps`, then click **Apply patch**.
3. If it reports a checksum error, your ROM is rev 1.1: use `RivalAtTheWheel_FireRed_v1.1.bps` instead.

Existing FireRed save files keep working. Give the `.sav` file the same name as the patched ROM.

### 2. Start the game (player 1)

1. Open the patched ROM in mGBA.
2. Go to **Tools → Scripting…**, then **File → Load script…** and choose `rival_at_the_wheel.lua`.
3. The scripting console shows `Patch detected` and a **6-character code** for player 2.

Load the script again each time you restart mGBA. To try it on the same PC, open `http://127.0.0.1:8888`.

### 3. Put it online

1. Double-click `start_tunnel.bat`. The first time, it installs cloudflared: close the window and run it again.
2. After a few seconds it prints an address like `https://random-words.trycloudflare.com`.
3. Send player 2 that address and the code. Keep the window open while you play.

There's no need to open router ports or touch the firewall. The address changes every time the tunnel restarts.

### 4. Playing as player 2

Open the link and enter the code. When player 1 starts a trainer battle, the page vibrates and beeps and shows **Your turn!**:

- **Moves**: type, PP, power, accuracy and an effectiveness hint (x2, x½, x0). In double battles you also choose the target.
- **Items**: the items that trainer actually carries in the original game (Potions, Full Heal, X items…). Items that would do nothing right now are greyed out.
- **Switch / Party**: switch Pokémon, or choose the next one after a faint.
- **Let the game's AI decide**: hand a single decision to the built-in AI.
- **Auto AI** switch (top right): the AI plays every decision until it's turned off.

Player 2 sees everything about their own team. For player 1's Pokémon they only see what the game shows on screen: species, level, HP as a percentage, status, stat changes and the last move used.

## Settings

These are at the top of `rival_at_the_wheel.lua`:

```lua
local PORT = 8888        -- web server port
local CODE = nil         -- e.g. "PIKA42" for a fixed code; nil = random each time
local LOCAL_ONLY = true  -- false also accepts devices on your home network (LAN)
local AUTO_AI = false    -- true = start with the AI in control
```

If you change `PORT`, change it in `start_tunnel.bat` too.

## What is and isn't controlled

**Remote-controlled:** every trainer battle, including rival, Gym Leaders, Elite Four and double battles.

**Unchanged:** wild Pokémon, the Old Man catching tutorial, the Safari Zone, the Pokémon Dude tutorial, link battles and multi battles.

**Notes:**
- The game waits forever for player 2, so turbo mode is safe.
- Don't **pause** mGBA. While it's paused the script stops too, and player 2's page stops updating.
- If cloudflared shows `Unable to reach the origin service ... [::1]:8888`, the tunnel is pointing at `localhost`, which Windows resolves to IPv6. The script's server only listens on IPv4, so the tunnel must use `http://127.0.0.1:8888`. The included `start_tunnel.bat` already does this.
- If a battle seems stuck, it's waiting for player 2. The mGBA console says so.
- If player 2 isn't around, player 1 can open `http://127.0.0.1:8888` and turn on **Auto AI**.

## How it works

### Game side (C, in the decompilation)

The opponent's battle controller (`src/battle_controller_opponent.c`) normally asks the AI what to do. With this patch, in trainer battles it calls into `src/battle_remote.c`:

1. It writes a **request** and a **snapshot of the battle** into a 600-byte mailbox in RAM (`gRemoteControl`). The snapshot covers both sides' active Pokémon, the trainer's party and items, which moves and switches are legal, and field effects.
2. It **keeps polling** the mailbox every frame, without advancing the battle.
3. When an **answer** arrives it validates it with the game's own rules: PP, Disable/Taunt/Encore and Choice Band, trapping abilities and moves, whether the item would have any effect. It then feeds the choice to the battle engine exactly as the AI would. A rejected answer re-posts the request with an error code that the page displays.

An answer of "AI" falls back to the normal AI for that decision.

Mailbox layout (little-endian, defined in `include/battle_remote.h`):

| Offset | Field |
|---|---|
| `0x000` | magic `"RCTL"` |
| `0x004` | `reqSeq`, `reqType` (1 action, 2 move, 3 replacement), `reqBattler`, `respSeq` |
| `0x008` | `respType` (1 move, 2 item, 3 switch, 4 AI), `respArg1`, `respArg2`, `lastError` |
| `0x00C` | battle type flags, trainer id, battler count, in-battle flag |
| `0x014` | trainer items, class and name |
| `0x038` | unusable-move mask, can-switch, usable-item mask, switchable-party mask, turn, weather, side statuses |
| `0x048` | 4 × 64-byte battler records |
| `0x148` | 6 × 44-byte party records |
| `0x250` | player 1's party summary (ok / status / fainted) |

A request is answered by writing `respType`/`respArg*` and then copying `reqSeq` into `respSeq`.

### Emulator side (Lua)

`rival_at_the_wheel.lua` runs inside mGBA. It finds the patch through a signature string in ROM (`REMOTE-TRAINER-1`), reads and writes the mailbox, and runs a small HTTP server using mGBA's socket API. The server serves the page and a tiny JSON API:

- `GET /api/state?k=CODE` — current state
- `POST /api/choose` — `seq, type, a1, a2`
- `POST /api/auto` — `on=0|1`

All API calls need the code, and requests for a stale `seq` are refused. Pokémon, move, item and ability names are extracted from the built ROM, so the page matches the game exactly.

## Building from source

On Linux or WSL:

```sh
git clone https://github.com/pret/pokefirered
cd pokefirered
git checkout 037335f4c725d7c9aecdac87066f2002b4bd7e14
# set up agbcc + arm-none-eabi binutils as described in INSTALL.md
git apply /path/to/source/pokefirered-rival-at-the-wheel.diff
make                 # pokefirered.gba       (rev 1.0)
make firered_rev1    # pokefirered_rev1.gba  (rev 1.1)

# game data for the page, and the final script
python3 tools/gen_gamedata.py pokefirered.gba pokefirered.map charmap.txt gamedata.json
python3 tools/build_lua.py gamedata.json rival_at_the_wheel.lua \
    "FireRed 1.0=pokefirered.map" "FireRed 1.1=pokefirered_rev1.map"

# patches (Floating IPS)
flips --create --bps-delta firered_original.gba pokefirered.gba RivalAtTheWheel_FireRed_v1.0.bps
```

`build_lua.py` and `gen_gamedata.py` live in `tools/`. Run them with the pokefirered checkout as the working directory, or adjust the paths. Building from this diff reproduces the patched ROMs byte for byte.

The diff also contains an optional `REMOTE_TEST_BOOT` mode, enabled with `make EXTRA_CPPFLAGS=-DREMOTE_TEST_BOOT`. It boots straight into a single and a double trainer battle and was used for automated testing. Release builds don't include it.

## Testing

The game and script were tested end to end in a headless mGBA build, with a scripted player 1 and an HTTP client acting as player 2. The tests covered:

- single battles (Giovanni) and double battles (Twins);
- moves, voluntary switches, replacements after fainting and items (Hyper Potion consumed and HP restored);
- delegating to the AI, Auto AI mode, and rejection of illegal or stale answers.

The web page was also driven in a headless Chromium. A new game on the patched ROM reaches the overworld normally.

Not tested by a human yet: a full playthrough with two real players.

## Credits

- [pret/pokefirered](https://github.com/pret/pokefirered) — the FireRed decompilation this is built on
- [mGBA](https://mgba.io) — emulator and Lua scripting API
- [Floating IPS](https://github.com/Alcaro/Flips) — BPS patches
- [cloudflared](https://github.com/cloudflare/cloudflared) — quick tunnels

Pokémon is © Nintendo / Creatures Inc. / GAME FREAK inc. This is an unofficial fan project. It doesn't contain or distribute any ROM, and you must own the game to use it.
