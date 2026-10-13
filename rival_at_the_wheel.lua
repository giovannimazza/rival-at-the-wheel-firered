-- ===========================================================================
--  RIVAL AT THE WHEEL - script for mGBA (0.10 or newer)
--  Pokemon FireRed (USA) with the "Rival at the Wheel" patch.
--
--  Load this file in mGBA:  Tools > Scripting... > File > Load script
--  The second player opens the web page shown in the console and enters
--  the code. On the trainer's turn, the game waits for their choice.
-- ===========================================================================

-- -------------------------------- SETTINGS ---------------------------------
local PORT = 8888           -- web server port (change it if it's already in use)
local CODE = nil            -- e.g. "PIKA42" for a fixed code; nil = random
local LOCAL_ONLY = true     -- true: only the tunnel / this PC can connect. false: also other devices on your LAN
local AUTO_AI = false       -- true: start with the AI in control (player 2 can take over from the page)
-- ---------------------------------------------------------------------------

local SIGNATURE = "REMOTE-TRAINER-1"
local MAILBOX_SIZE = 0x258
local REMOTE_MAGIC = 0x4C544352

-- Addresses generated automatically for each patch build
local BUILDS = {
  { name = "FireRed 1.0", rc = 0x0203F468, sig = 0x08251C18 },
  { name = "FireRed 1.1", rc = 0x0203F468, sig = 0x08251C88 },
}

-- Game character table (byte -> text)
local CHARMAP = {
  [0x00]=" ", [0x01]="À", [0x02]="Á", [0x03]="Â", [0x04]="Ç", [0x05]="È", [0x06]="É", [0x07]="Ê",
  [0x08]="Ë", [0x09]="Ì", [0x0A]="こ", [0x0B]="Î", [0x0C]="Ï", [0x0D]="Ò", [0x0E]="Ó", [0x0F]="Ô",
  [0x10]="Œ", [0x11]="Ù", [0x12]="Ú", [0x13]="Û", [0x14]="Ñ", [0x15]="ß", [0x16]="à", [0x17]="á",
  [0x18]="ね", [0x19]="ç", [0x1A]="è", [0x1B]="é", [0x1C]="ê", [0x1D]="ë", [0x1E]="ì", [0x1F]="ま",
  [0x20]="î", [0x21]="ï", [0x22]="ò", [0x23]="ó", [0x24]="ô", [0x25]="œ", [0x26]="ù", [0x27]="ú",
  [0x28]="û", [0x29]="ñ", [0x2A]="º", [0x2B]="ª", [0x2C]="わ", [0x2D]="&", [0x2E]="+", [0x2F]="ぁ",
  [0x30]="ぃ", [0x31]="ぅ", [0x32]="ぇ", [0x33]="ぉ", [0x34]="ゃ", [0x35]="=", [0x36]=";", [0x37]="が",
  [0x38]="ぎ", [0x39]="ぐ", [0x3A]="げ", [0x3B]="ご", [0x3C]="ざ", [0x3D]="じ", [0x3E]="ず", [0x3F]="ぜ",
  [0x40]="ぞ", [0x41]="だ", [0x42]="ぢ", [0x43]="づ", [0x44]="で", [0x45]="ど", [0x46]="ば", [0x47]="び",
  [0x48]="ぶ", [0x49]="べ", [0x4A]="ぼ", [0x4B]="ぱ", [0x4C]="ぴ", [0x4D]="ぷ", [0x4E]="ぺ", [0x4F]="ぽ",
  [0x50]="っ", [0x51]="¿", [0x52]="¡", [0x53]="ウ", [0x54]="エ", [0x55]="オ", [0x56]="カ", [0x57]="キ",
  [0x58]="ク", [0x59]="ケ", [0x5A]="Í", [0x5B]="%", [0x5C]="(", [0x5D]=")", [0x5E]="セ", [0x5F]="ソ",
  [0x60]="タ", [0x61]="チ", [0x62]="ツ", [0x63]="テ", [0x64]="ト", [0x65]="ナ", [0x66]="ニ", [0x67]="ヌ",
  [0x68]="â", [0x69]="ノ", [0x6A]="ハ", [0x6B]="ヒ", [0x6C]="フ", [0x6D]="ヘ", [0x6E]="ホ", [0x6F]="í",
  [0x70]="ミ", [0x71]="ム", [0x72]="メ", [0x73]="モ", [0x74]="ヤ", [0x75]="ユ", [0x76]="ヨ", [0x77]="ラ",
  [0x78]="リ", [0x79]="ル", [0x7A]="レ", [0x7B]="ロ", [0x7C]="ワ", [0x7D]="ヲ", [0x7E]="ン", [0x7F]="ァ",
  [0x80]="ィ", [0x81]="ゥ", [0x82]="ェ", [0x83]="ォ", [0x84]="ャ", [0x85]="<", [0x86]=">", [0x87]="ガ",
  [0x88]="ギ", [0x89]="グ", [0x8A]="ゲ", [0x8B]="ゴ", [0x8C]="ザ", [0x8D]="ジ", [0x8E]="ズ", [0x8F]="ゼ",
  [0x90]="ゾ", [0x91]="ダ", [0x92]="ヂ", [0x93]="ヅ", [0x94]="デ", [0x95]="ド", [0x96]="バ", [0x97]="ビ",
  [0x98]="ブ", [0x99]="ベ", [0x9A]="ボ", [0x9B]="パ", [0x9C]="ピ", [0x9D]="プ", [0x9E]="ペ", [0x9F]="ポ",
  [0xA0]="ッ", [0xA1]="0", [0xA2]="1", [0xA3]="2", [0xA4]="3", [0xA5]="4", [0xA6]="5", [0xA7]="6",
  [0xA8]="7", [0xA9]="8", [0xAA]="9", [0xAB]="!", [0xAC]="?", [0xAD]=".", [0xAE]="-", [0xAF]="·",
  [0xB0]="…", [0xB1]="“", [0xB2]="”", [0xB3]="‘", [0xB4]="’", [0xB5]="♂", [0xB6]="♀", [0xB7]="¥",
  [0xB8]=",", [0xB9]="×", [0xBA]="/", [0xBB]="A", [0xBC]="B", [0xBD]="C", [0xBE]="D", [0xBF]="E",
  [0xC0]="F", [0xC1]="G", [0xC2]="H", [0xC3]="I", [0xC4]="J", [0xC5]="K", [0xC6]="L", [0xC7]="M",
  [0xC8]="N", [0xC9]="O", [0xCA]="P", [0xCB]="Q", [0xCC]="R", [0xCD]="S", [0xCE]="T", [0xCF]="U",
  [0xD0]="V", [0xD1]="W", [0xD2]="X", [0xD3]="Y", [0xD4]="Z", [0xD5]="a", [0xD6]="b", [0xD7]="c",
  [0xD8]="d", [0xD9]="e", [0xDA]="f", [0xDB]="g", [0xDC]="h", [0xDD]="i", [0xDE]="j", [0xDF]="k",
  [0xE0]="l", [0xE1]="m", [0xE2]="n", [0xE3]="o", [0xE4]="p", [0xE5]="q", [0xE6]="r", [0xE7]="s",
  [0xE8]="t", [0xE9]="u", [0xEA]="v", [0xEB]="w", [0xEC]="x", [0xED]="y", [0xEE]="z", [0xEF]="▶",
  [0xF0]=":", [0xF1]="Ä", [0xF2]="Ö", [0xF3]="Ü", [0xF4]="ä", [0xF5]="ö", [0xF6]="ü", [0xFF]="$",
}

local HTML = [==========[
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#14161c">
<title>Rival at the Wheel</title>
<style>
:root {
  --bg: #14161c; --panel: #1d2029; --panel2: #262a35; --line: #333847;
  --text: #eceef3; --muted: #9aa1b2; --accent: #ffcb05; --danger: #ff5a5f;
  --ok: #46d17d; --warn: #ffb547; --blue: #4ea8ff;
  --radius: 14px;
}
* { box-sizing: border-box; }
html, body { margin: 0; background: var(--bg); color: var(--text);
  font: 15px/1.35 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
body { padding: 0 0 120px; }
button { font: inherit; color: inherit; }
.wrap { max-width: 760px; margin: 0 auto; padding: 0 16px; }
header { position: sticky; top: 0; z-index: 5; background: rgba(20,22,28,.94);
  backdrop-filter: blur(6px); border-bottom: 1px solid var(--line); }
header .wrap { display: flex; align-items: center; gap: 10px; min-height: 56px; }
.logo { font-weight: 800; letter-spacing: .5px; font-size: 16px; white-space: nowrap; }
.logo span { color: var(--accent); }
.dot { width: 10px; height: 10px; border-radius: 50%; background: var(--muted); flex: none; }
.dot.on { background: var(--ok); box-shadow: 0 0 8px var(--ok); }
.dot.off { background: var(--danger); }
.spacer { flex: 1; }
.toggle { display: flex; align-items: center; gap: 8px; font-size: 13px; color: var(--muted); cursor: pointer; user-select: none; }
.toggle input { display: none; }
.toggle .sw { width: 38px; height: 22px; border-radius: 11px; background: var(--panel2); border: 1px solid var(--line); position: relative; transition: .2s; }
.toggle .sw::after { content: ""; position: absolute; top: 2px; left: 2px; width: 16px; height: 16px; border-radius: 50%; background: var(--muted); transition: .2s; }
.toggle input:checked + .sw { background: #3a3215; border-color: var(--accent); }
.toggle input:checked + .sw::after { left: 18px; background: var(--accent); }

.banner { margin: 16px 0; padding: 16px 18px; border-radius: var(--radius); background: var(--panel);
  border: 1px solid var(--line); display: flex; gap: 14px; align-items: center; }
.banner .big { font-size: 19px; font-weight: 800; }
.banner .small { color: var(--muted); font-size: 13px; margin-top: 2px; }
.banner.turn { background: linear-gradient(135deg, #3d3410, #2a2412); border-color: var(--accent); animation: glow 1.6s ease-in-out infinite; }
.banner.turn .big { color: var(--accent); }
.banner.err { border-color: var(--danger); background: #2b1719; }
@keyframes glow { 50% { box-shadow: 0 0 0 4px rgba(255,203,5,.15); } }
.icon { font-size: 26px; width: 34px; text-align: center; flex: none; }

h2 { font-size: 12px; text-transform: uppercase; letter-spacing: 1.2px; color: var(--muted); margin: 22px 0 8px; font-weight: 700; }
.card { background: var(--panel); border: 1px solid var(--line); border-radius: var(--radius); padding: 12px 14px; }
.grid2 { display: grid; grid-template-columns: 1fr; gap: 10px; }
@media (min-width: 600px) { .grid2 { grid-template-columns: 1fr 1fr; } }

.mon { display: flex; flex-direction: column; gap: 6px; }
.mon.dim { opacity: .45; }
.mon .top { display: flex; align-items: baseline; gap: 8px; flex-wrap: wrap; }
.mon .name { font-weight: 800; font-size: 16px; }
.mon .lv { color: var(--muted); font-size: 13px; }
.mon .tag { font-size: 11px; color: var(--muted); border: 1px solid var(--line); border-radius: 6px; padding: 1px 6px; }
.hp { height: 8px; background: #0e1015; border-radius: 4px; overflow: hidden; }
.hp > i { display: block; height: 100%; background: var(--ok); border-radius: 4px; transition: width .4s; }
.hp > i.mid { background: var(--warn); } .hp > i.low { background: var(--danger); }
.hptext { font-size: 12px; color: var(--muted); display: flex; justify-content: space-between; gap: 8px; }
.chips { display: flex; flex-wrap: wrap; gap: 4px; }
.type { font-size: 10.5px; font-weight: 800; letter-spacing: .4px; padding: 2px 7px; border-radius: 5px; color: #fff; text-shadow: 0 1px 1px rgba(0,0,0,.35); }
.st { font-size: 10.5px; font-weight: 800; padding: 2px 7px; border-radius: 5px; background: #444; color: #fff; }
.st.psn { background: #a040a0; } .st.brn { background: #f08030; } .st.frz { background: #6ac6e8; color: #111; }
.st.par { background: #e0c020; color: #111; } .st.slp { background: #8a8a9a; } .st.tox { background: #702a8a; } .st.fnt { background: #3a3a3a; color: #bbb; }
.st.misc { background: #2f3646; color: #cdd3e1; }
.stage { font-size: 11px; padding: 1px 6px; border-radius: 5px; background: #23324a; color: #9cc8ff; }
.stage.neg { background: #4a2328; color: #ffaab0; }
.meta { font-size: 12px; color: var(--muted); }

.choices { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.choice { text-align: left; background: var(--panel2); border: 2px solid transparent; border-radius: 12px; padding: 10px 12px;
  cursor: pointer; min-height: 64px; display: flex; flex-direction: column; gap: 4px; transition: transform .08s, border-color .15s; }
.choice:active { transform: scale(.98); }
.choice .t { font-weight: 800; font-size: 15px; }
.choice .s { font-size: 12px; color: var(--muted); display: flex; gap: 6px; flex-wrap: wrap; align-items: center; }
.choice.sel { border-color: var(--accent); background: #34301c; }
.choice:disabled { opacity: .35; cursor: not-allowed; }
.choice.wide { grid-column: 1 / -1; }
.eff { font-size: 10.5px; font-weight: 800; padding: 1px 6px; border-radius: 5px; }
.eff.x2 { background: #1f4d2e; color: #7dffa6; } .eff.x4 { background: #145c2c; color: #a6ffc2; }
.eff.half { background: #4d3a1f; color: #ffc777; } .eff.zero { background: #4d1f22; color: #ff9da1; }
.tabs { display: flex; gap: 6px; margin: 4px 0 10px; overflow-x: auto; }
.tabs button { background: var(--panel2); border: 1px solid var(--line); border-radius: 20px; padding: 7px 14px; cursor: pointer; white-space: nowrap; font-weight: 700; font-size: 13px; }
.tabs button.on { background: var(--accent); color: #1a1600; border-color: var(--accent); }
.note { font-size: 12.5px; color: var(--muted); margin: 8px 2px 0; }
.ai-btn { width: 100%; margin-top: 10px; background: transparent; border: 1px dashed #4a5064; color: var(--muted); border-radius: 12px; padding: 11px; cursor: pointer; font-weight: 700; }
.ai-btn.sel { border-style: solid; border-color: var(--accent); color: var(--accent); }

.confirm { position: fixed; left: 0; right: 0; bottom: 0; z-index: 10; background: rgba(20,22,28,.97);
  border-top: 1px solid var(--line); padding: 12px 16px calc(12px + env(safe-area-inset-bottom)); transform: translateY(110%); visibility: hidden; transition: transform .2s, visibility .2s; }
.confirm.show { transform: none; visibility: visible; }
.confirm .wrap { display: flex; gap: 10px; align-items: center; padding: 0; }
.confirm .what { flex: 1; font-size: 14px; } .confirm .what b { color: var(--accent); }
.btn { border: 0; border-radius: 12px; padding: 13px 20px; font-weight: 800; cursor: pointer; }
.btn.go { background: var(--accent); color: #1a1600; } .btn.no { background: var(--panel2); }
.btn:disabled { opacity: .5; }

.party { display: flex; flex-direction: column; gap: 8px; }
.prow { display: grid; grid-template-columns: 1fr auto; gap: 4px 10px; background: var(--panel); border: 1px solid var(--line); border-radius: 12px; padding: 10px 12px; }
.prow.field { border-color: #4b5570; }
.prow .moves { grid-column: 1 / -1; display: flex; flex-wrap: wrap; gap: 4px; }
.mv { font-size: 11.5px; background: var(--panel2); border-radius: 6px; padding: 2px 7px; color: #c9cfdc; }
.balls { display: flex; gap: 6px; }
.ball { width: 14px; height: 14px; border-radius: 50%; border: 2px solid #555; background: #222; }
.ball.ok { background: linear-gradient(#ff5050 50%, #fff 50%); border-color: #222; }
.ball.stat { background: linear-gradient(#e0a020 50%, #fff 50%); border-color: #222; }
.ball.fnt { background: #444; border-color: #333; }

.login { max-width: 380px; margin: 12vh auto 0; text-align: center; padding: 0 16px; }
.login h1 { font-size: 26px; margin: 0 0 6px; } .login h1 span { color: var(--accent); }
.login p { color: var(--muted); }
.login input { width: 100%; font: 800 26px/1 ui-monospace, monospace; letter-spacing: 6px; text-align: center; text-transform: uppercase;
  background: var(--panel); color: var(--text); border: 2px solid var(--line); border-radius: 14px; padding: 16px; margin: 14px 0; }
.login input:focus { outline: none; border-color: var(--accent); }
.login .btn { width: 100%; }
.toast { position: fixed; left: 50%; top: 70px; transform: translateX(-50%); background: var(--danger); color: #fff; padding: 10px 16px; border-radius: 10px; font-weight: 700; z-index: 20; box-shadow: 0 6px 20px rgba(0,0,0,.4); max-width: 90vw; }
.hidden { display: none !important; }
.modal-bg { position: fixed; inset: 0; background: rgba(0,0,0,.6); z-index: 30; display: flex; align-items: flex-end; justify-content: center; }
.modal { background: var(--panel); width: 100%; max-width: 520px; border-radius: 18px 18px 0 0; padding: 16px 16px calc(18px + env(safe-area-inset-bottom)); }
.modal h3 { margin: 4px 0 12px; }
</style>
</head>
<body>

<div id="login" class="login hidden">
  <h1>Rival at <span>the Wheel</span></h1>
  <p>Enter the code player 1 sees in the mGBA scripting console.</p>
  <input id="codeInput" maxlength="12" autocomplete="off" autocapitalize="characters" spellcheck="false" placeholder="CODE">
  <button class="btn go" id="codeBtn">Join</button>
  <p id="loginErr" style="color:var(--danger)"></p>
</div>

<div id="app" class="hidden">
  <header><div class="wrap">
    <div class="dot" id="dot"></div>
    <div class="logo">Rival at <span>the Wheel</span></div>
    <div class="spacer"></div>
    <label class="toggle" title="The game's AI chooses for you"><input type="checkbox" id="autoAi"><span class="sw"></span>Auto AI</label>
  </div></header>
  <main class="wrap">
    <div id="banner"></div>
    <div id="action"></div>
    <div id="field"></div>
    <div id="partyBox"></div>
  </main>
</div>

<div class="confirm" id="confirm"><div class="wrap">
  <div class="what" id="confirmWhat"></div>
  <button class="btn no" id="cancelBtn">Cancel</button>
  <button class="btn go" id="sendBtn">Confirm</button>
</div></div>

<div id="modalRoot"></div>
<div id="toast" class="toast hidden"></div>

<script>
const GAME = {"species":["??????????","BULBASAUR","IVYSAUR","VENUSAUR","CHARMANDER","CHARMELEON","CHARIZARD","SQUIRTLE","WARTORTLE","BLASTOISE","CATERPIE","METAPOD","BUTTERFREE","WEEDLE","KAKUNA","BEEDRILL","PIDGEY","PIDGEOTTO","PIDGEOT","RATTATA","RATICATE","SPEAROW","FEAROW","EKANS","ARBOK","PIKACHU","RAICHU","SANDSHREW","SANDSLASH","NIDORAN♀","NIDORINA","NIDOQUEEN","NIDORAN♂","NIDORINO","NIDOKING","CLEFAIRY","CLEFABLE","VULPIX","NINETALES","JIGGLYPUFF","WIGGLYTUFF","ZUBAT","GOLBAT","ODDISH","GLOOM","VILEPLUME","PARAS","PARASECT","VENONAT","VENOMOTH","DIGLETT","DUGTRIO","MEOWTH","PERSIAN","PSYDUCK","GOLDUCK","MANKEY","PRIMEAPE","GROWLITHE","ARCANINE","POLIWAG","POLIWHIRL","POLIWRATH","ABRA","KADABRA","ALAKAZAM","MACHOP","MACHOKE","MACHAMP","BELLSPROUT","WEEPINBELL","VICTREEBEL","TENTACOOL","TENTACRUEL","GEODUDE","GRAVELER","GOLEM","PONYTA","RAPIDASH","SLOWPOKE","SLOWBRO","MAGNEMITE","MAGNETON","FARFETCH’D","DODUO","DODRIO","SEEL","DEWGONG","GRIMER","MUK","SHELLDER","CLOYSTER","GASTLY","HAUNTER","GENGAR","ONIX","DROWZEE","HYPNO","KRABBY","KINGLER","VOLTORB","ELECTRODE","EXEGGCUTE","EXEGGUTOR","CUBONE","MAROWAK","HITMONLEE","HITMONCHAN","LICKITUNG","KOFFING","WEEZING","RHYHORN","RHYDON","CHANSEY","TANGELA","KANGASKHAN","HORSEA","SEADRA","GOLDEEN","SEAKING","STARYU","STARMIE","MR. MIME","SCYTHER","JYNX","ELECTABUZZ","MAGMAR","PINSIR","TAUROS","MAGIKARP","GYARADOS","LAPRAS","DITTO","EEVEE","VAPOREON","JOLTEON","FLAREON","PORYGON","OMANYTE","OMASTAR","KABUTO","KABUTOPS","AERODACTYL","SNORLAX","ARTICUNO","ZAPDOS","MOLTRES","DRATINI","DRAGONAIR","DRAGONITE","MEWTWO","MEW","CHIKORITA","BAYLEEF","MEGANIUM","CYNDAQUIL","QUILAVA","TYPHLOSION","TOTODILE","CROCONAW","FERALIGATR","SENTRET","FURRET","HOOTHOOT","NOCTOWL","LEDYBA","LEDIAN","SPINARAK","ARIADOS","CROBAT","CHINCHOU","LANTURN","PICHU","CLEFFA","IGGLYBUFF","TOGEPI","TOGETIC","NATU","XATU","MAREEP","FLAAFFY","AMPHAROS","BELLOSSOM","MARILL","AZUMARILL","SUDOWOODO","POLITOED","HOPPIP","SKIPLOOM","JUMPLUFF","AIPOM","SUNKERN","SUNFLORA","YANMA","WOOPER","QUAGSIRE","ESPEON","UMBREON","MURKROW","SLOWKING","MISDREAVUS","UNOWN","WOBBUFFET","GIRAFARIG","PINECO","FORRETRESS","DUNSPARCE","GLIGAR","STEELIX","SNUBBULL","GRANBULL","QWILFISH","SCIZOR","SHUCKLE","HERACROSS","SNEASEL","TEDDIURSA","URSARING","SLUGMA","MAGCARGO","SWINUB","PILOSWINE","CORSOLA","REMORAID","OCTILLERY","DELIBIRD","MANTINE","SKARMORY","HOUNDOUR","HOUNDOOM","KINGDRA","PHANPY","DONPHAN","PORYGON2","STANTLER","SMEARGLE","TYROGUE","HITMONTOP","SMOOCHUM","ELEKID","MAGBY","MILTANK","BLISSEY","RAIKOU","ENTEI","SUICUNE","LARVITAR","PUPITAR","TYRANITAR","LUGIA","HO-OH","CELEBI","?","?","?","?","?","?","?","?","?","?","?","?","?","?","?","?","?","?","?","?","?","?","?","?","?","TREECKO","GROVYLE","SCEPTILE","TORCHIC","COMBUSKEN","BLAZIKEN","MUDKIP","MARSHTOMP","SWAMPERT","POOCHYENA","MIGHTYENA","ZIGZAGOON","LINOONE","WURMPLE","SILCOON","BEAUTIFLY","CASCOON","DUSTOX","LOTAD","LOMBRE","LUDICOLO","SEEDOT","NUZLEAF","SHIFTRY","NINCADA","NINJASK","SHEDINJA","TAILLOW","SWELLOW","SHROOMISH","BRELOOM","SPINDA","WINGULL","PELIPPER","SURSKIT","MASQUERAIN","WAILMER","WAILORD","SKITTY","DELCATTY","KECLEON","BALTOY","CLAYDOL","NOSEPASS","TORKOAL","SABLEYE","BARBOACH","WHISCASH","LUVDISC","CORPHISH","CRAWDAUNT","FEEBAS","MILOTIC","CARVANHA","SHARPEDO","TRAPINCH","VIBRAVA","FLYGON","MAKUHITA","HARIYAMA","ELECTRIKE","MANECTRIC","NUMEL","CAMERUPT","SPHEAL","SEALEO","WALREIN","CACNEA","CACTURNE","SNORUNT","GLALIE","LUNATONE","SOLROCK","AZURILL","SPOINK","GRUMPIG","PLUSLE","MINUN","MAWILE","MEDITITE","MEDICHAM","SWABLU","ALTARIA","WYNAUT","DUSKULL","DUSCLOPS","ROSELIA","SLAKOTH","VIGOROTH","SLAKING","GULPIN","SWALOT","TROPIUS","WHISMUR","LOUDRED","EXPLOUD","CLAMPERL","HUNTAIL","GOREBYSS","ABSOL","SHUPPET","BANETTE","SEVIPER","ZANGOOSE","RELICANTH","ARON","LAIRON","AGGRON","CASTFORM","VOLBEAT","ILLUMISE","LILEEP","CRADILY","ANORITH","ARMALDO","RALTS","KIRLIA","GARDEVOIR","BAGON","SHELGON","SALAMENCE","BELDUM","METANG","METAGROSS","REGIROCK","REGICE","REGISTEEL","KYOGRE","GROUDON","RAYQUAZA","LATIAS","LATIOS","JIRACHI","DEOXYS","CHIMECHO"],"speciesTypes":[[0,0],[12,3],[12,3],[12,3],[10,10],[10,10],[10,2],[11,11],[11,11],[11,11],[6,6],[6,6],[6,2],[6,3],[6,3],[6,3],[0,2],[0,2],[0,2],[0,0],[0,0],[0,2],[0,2],[3,3],[3,3],[13,13],[13,13],[4,4],[4,4],[3,3],[3,3],[3,4],[3,3],[3,3],[3,4],[0,0],[0,0],[10,10],[10,10],[0,0],[0,0],[3,2],[3,2],[12,3],[12,3],[12,3],[6,12],[6,12],[6,3],[6,3],[4,4],[4,4],[0,0],[0,0],[11,11],[11,11],[1,1],[1,1],[10,10],[10,10],[11,11],[11,11],[11,1],[14,14],[14,14],[14,14],[1,1],[1,1],[1,1],[12,3],[12,3],[12,3],[11,3],[11,3],[5,4],[5,4],[5,4],[10,10],[10,10],[11,14],[11,14],[13,8],[13,8],[0,2],[0,2],[0,2],[11,11],[11,15],[3,3],[3,3],[11,11],[11,15],[7,3],[7,3],[7,3],[5,4],[14,14],[14,14],[11,11],[11,11],[13,13],[13,13],[12,14],[12,14],[4,4],[4,4],[1,1],[1,1],[0,0],[3,3],[3,3],[4,5],[4,5],[0,0],[12,12],[0,0],[11,11],[11,11],[11,11],[11,11],[11,11],[11,14],[14,14],[6,2],[15,14],[13,13],[10,10],[6,6],[0,0],[11,11],[11,2],[11,15],[0,0],[0,0],[11,11],[13,13],[10,10],[0,0],[5,11],[5,11],[5,11],[5,11],[5,2],[0,0],[15,2],[13,2],[10,2],[16,16],[16,16],[16,2],[14,14],[14,14],[12,12],[12,12],[12,12],[10,10],[10,10],[10,10],[11,11],[11,11],[11,11],[0,0],[0,0],[0,2],[0,2],[6,2],[6,2],[6,3],[6,3],[3,2],[11,13],[11,13],[13,13],[0,0],[0,0],[0,0],[0,2],[14,2],[14,2],[13,13],[13,13],[13,13],[12,12],[11,11],[11,11],[5,5],[11,11],[12,2],[12,2],[12,2],[0,0],[12,12],[12,12],[6,2],[11,4],[11,4],[14,14],[17,17],[17,2],[11,14],[7,7],[14,14],[14,14],[0,14],[6,6],[6,8],[0,0],[4,2],[8,4],[0,0],[0,0],[11,3],[6,8],[6,5],[6,1],[17,15],[0,0],[0,0],[10,10],[10,5],[15,4],[15,4],[11,5],[11,11],[11,11],[15,2],[11,2],[8,2],[17,10],[17,10],[11,16],[4,4],[4,4],[0,0],[0,0],[0,0],[1,1],[1,1],[15,14],[13,13],[10,10],[0,0],[0,0],[13,13],[10,10],[11,11],[5,4],[5,4],[5,17],[14,2],[10,2],[14,12],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[12,12],[12,12],[12,12],[10,10],[10,1],[10,1],[11,11],[11,4],[11,4],[17,17],[17,17],[0,0],[0,0],[6,6],[6,6],[6,2],[6,6],[6,3],[11,12],[11,12],[11,12],[12,12],[12,17],[12,17],[6,4],[6,2],[6,7],[0,2],[0,2],[12,12],[12,1],[0,0],[11,2],[11,2],[6,11],[6,2],[11,11],[11,11],[0,0],[0,0],[0,0],[4,14],[4,14],[5,5],[10,10],[17,7],[11,4],[11,4],[11,11],[11,11],[11,17],[11,11],[11,11],[11,17],[11,17],[4,4],[4,16],[4,16],[1,1],[1,1],[13,13],[13,13],[10,4],[10,4],[15,11],[15,11],[15,11],[12,12],[12,17],[15,15],[15,15],[5,14],[5,14],[0,0],[14,14],[14,14],[13,13],[13,13],[8,8],[1,14],[1,14],[0,2],[16,2],[14,14],[7,7],[7,7],[12,3],[0,0],[0,0],[0,0],[3,3],[3,3],[12,2],[0,0],[0,0],[0,0],[11,11],[11,11],[11,11],[17,17],[7,7],[7,7],[3,3],[0,0],[11,5],[8,5],[8,5],[8,5],[0,0],[6,6],[6,6],[5,12],[5,12],[5,6],[5,6],[14,14],[14,14],[14,14],[16,16],[16,16],[16,2],[8,14],[8,14],[8,14],[5,5],[15,15],[8,8],[11,11],[4,4],[16,2],[16,14],[16,14],[8,14],[14,14],[14,14]],"moves":[{"n":"-","e":0,"p":0,"t":0,"a":0,"pp":0,"c":0,"tg":0,"pr":0},{"n":"POUND","e":0,"p":40,"t":0,"a":100,"pp":35,"c":0,"tg":0,"pr":0},{"n":"KARATE CHOP","e":43,"p":50,"t":1,"a":100,"pp":25,"c":0,"tg":0,"pr":0},{"n":"DOUBLESLAP","e":29,"p":15,"t":0,"a":85,"pp":10,"c":0,"tg":0,"pr":0},{"n":"COMET PUNCH","e":29,"p":18,"t":0,"a":85,"pp":15,"c":0,"tg":0,"pr":0},{"n":"MEGA PUNCH","e":0,"p":80,"t":0,"a":85,"pp":20,"c":0,"tg":0,"pr":0},{"n":"PAY DAY","e":34,"p":40,"t":0,"a":100,"pp":20,"c":100,"tg":0,"pr":0},{"n":"FIRE PUNCH","e":4,"p":75,"t":10,"a":100,"pp":15,"c":10,"tg":0,"pr":0},{"n":"ICE PUNCH","e":5,"p":75,"t":15,"a":100,"pp":15,"c":10,"tg":0,"pr":0},{"n":"THUNDERPUNCH","e":6,"p":75,"t":13,"a":100,"pp":15,"c":10,"tg":0,"pr":0},{"n":"SCRATCH","e":0,"p":40,"t":0,"a":100,"pp":35,"c":0,"tg":0,"pr":0},{"n":"VICEGRIP","e":0,"p":55,"t":0,"a":100,"pp":30,"c":0,"tg":0,"pr":0},{"n":"GUILLOTINE","e":38,"p":1,"t":0,"a":30,"pp":5,"c":0,"tg":0,"pr":0},{"n":"RAZOR WIND","e":39,"p":80,"t":0,"a":100,"pp":10,"c":0,"tg":8,"pr":0},{"n":"SWORDS DANCE","e":50,"p":0,"t":0,"a":0,"pp":30,"c":0,"tg":16,"pr":0},{"n":"CUT","e":0,"p":50,"t":0,"a":95,"pp":30,"c":0,"tg":0,"pr":0},{"n":"GUST","e":149,"p":40,"t":2,"a":100,"pp":35,"c":0,"tg":0,"pr":0},{"n":"WING ATTACK","e":0,"p":60,"t":2,"a":100,"pp":35,"c":0,"tg":0,"pr":0},{"n":"WHIRLWIND","e":28,"p":0,"t":0,"a":100,"pp":20,"c":0,"tg":0,"pr":-6},{"n":"FLY","e":155,"p":70,"t":2,"a":95,"pp":15,"c":0,"tg":0,"pr":0},{"n":"BIND","e":42,"p":15,"t":0,"a":75,"pp":20,"c":100,"tg":0,"pr":0},{"n":"SLAM","e":0,"p":80,"t":0,"a":75,"pp":20,"c":0,"tg":0,"pr":0},{"n":"VINE WHIP","e":0,"p":35,"t":12,"a":100,"pp":10,"c":0,"tg":0,"pr":0},{"n":"STOMP","e":150,"p":65,"t":0,"a":100,"pp":20,"c":30,"tg":0,"pr":0},{"n":"DOUBLE KICK","e":44,"p":30,"t":1,"a":100,"pp":30,"c":0,"tg":0,"pr":0},{"n":"MEGA KICK","e":0,"p":120,"t":0,"a":75,"pp":5,"c":0,"tg":0,"pr":0},{"n":"JUMP KICK","e":45,"p":70,"t":1,"a":95,"pp":25,"c":0,"tg":0,"pr":0},{"n":"ROLLING KICK","e":31,"p":60,"t":1,"a":85,"pp":15,"c":30,"tg":0,"pr":0},{"n":"SAND-ATTACK","e":23,"p":0,"t":4,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"HEADBUTT","e":31,"p":70,"t":0,"a":100,"pp":15,"c":30,"tg":0,"pr":0},{"n":"HORN ATTACK","e":0,"p":65,"t":0,"a":100,"pp":25,"c":0,"tg":0,"pr":0},{"n":"FURY ATTACK","e":29,"p":15,"t":0,"a":85,"pp":20,"c":0,"tg":0,"pr":0},{"n":"HORN DRILL","e":38,"p":1,"t":0,"a":30,"pp":5,"c":0,"tg":0,"pr":0},{"n":"TACKLE","e":0,"p":35,"t":0,"a":95,"pp":35,"c":0,"tg":0,"pr":0},{"n":"BODY SLAM","e":6,"p":85,"t":0,"a":100,"pp":15,"c":30,"tg":0,"pr":0},{"n":"WRAP","e":42,"p":15,"t":0,"a":85,"pp":20,"c":100,"tg":0,"pr":0},{"n":"TAKE DOWN","e":48,"p":90,"t":0,"a":85,"pp":20,"c":0,"tg":0,"pr":0},{"n":"THRASH","e":27,"p":90,"t":0,"a":100,"pp":20,"c":100,"tg":4,"pr":0},{"n":"DOUBLE-EDGE","e":198,"p":120,"t":0,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"TAIL WHIP","e":19,"p":0,"t":0,"a":100,"pp":30,"c":0,"tg":8,"pr":0},{"n":"POISON STING","e":2,"p":15,"t":3,"a":100,"pp":35,"c":30,"tg":0,"pr":0},{"n":"TWINEEDLE","e":77,"p":25,"t":6,"a":100,"pp":20,"c":20,"tg":0,"pr":0},{"n":"PIN MISSILE","e":29,"p":14,"t":6,"a":85,"pp":20,"c":0,"tg":0,"pr":0},{"n":"LEER","e":19,"p":0,"t":0,"a":100,"pp":30,"c":0,"tg":8,"pr":0},{"n":"BITE","e":31,"p":60,"t":17,"a":100,"pp":25,"c":30,"tg":0,"pr":0},{"n":"GROWL","e":18,"p":0,"t":0,"a":100,"pp":40,"c":0,"tg":8,"pr":0},{"n":"ROAR","e":28,"p":0,"t":0,"a":100,"pp":20,"c":0,"tg":0,"pr":-6},{"n":"SING","e":1,"p":0,"t":0,"a":55,"pp":15,"c":0,"tg":0,"pr":0},{"n":"SUPERSONIC","e":49,"p":0,"t":0,"a":55,"pp":20,"c":0,"tg":0,"pr":0},{"n":"SONICBOOM","e":130,"p":1,"t":0,"a":90,"pp":20,"c":0,"tg":0,"pr":0},{"n":"DISABLE","e":86,"p":0,"t":0,"a":55,"pp":20,"c":0,"tg":0,"pr":0},{"n":"ACID","e":69,"p":40,"t":3,"a":100,"pp":30,"c":10,"tg":8,"pr":0},{"n":"EMBER","e":4,"p":40,"t":10,"a":100,"pp":25,"c":10,"tg":0,"pr":0},{"n":"FLAMETHROWER","e":4,"p":95,"t":10,"a":100,"pp":15,"c":10,"tg":0,"pr":0},{"n":"MIST","e":46,"p":0,"t":15,"a":0,"pp":30,"c":0,"tg":16,"pr":0},{"n":"WATER GUN","e":0,"p":40,"t":11,"a":100,"pp":25,"c":0,"tg":0,"pr":0},{"n":"HYDRO PUMP","e":0,"p":120,"t":11,"a":80,"pp":5,"c":0,"tg":0,"pr":0},{"n":"SURF","e":0,"p":95,"t":11,"a":100,"pp":15,"c":0,"tg":8,"pr":0},{"n":"ICE BEAM","e":5,"p":95,"t":15,"a":100,"pp":10,"c":10,"tg":0,"pr":0},{"n":"BLIZZARD","e":5,"p":120,"t":15,"a":70,"pp":5,"c":10,"tg":8,"pr":0},{"n":"PSYBEAM","e":76,"p":65,"t":14,"a":100,"pp":20,"c":10,"tg":0,"pr":0},{"n":"BUBBLEBEAM","e":70,"p":65,"t":11,"a":100,"pp":20,"c":10,"tg":0,"pr":0},{"n":"AURORA BEAM","e":68,"p":65,"t":15,"a":100,"pp":20,"c":10,"tg":0,"pr":0},{"n":"HYPER BEAM","e":80,"p":150,"t":0,"a":90,"pp":5,"c":0,"tg":0,"pr":0},{"n":"PECK","e":0,"p":35,"t":2,"a":100,"pp":35,"c":0,"tg":0,"pr":0},{"n":"DRILL PECK","e":0,"p":80,"t":2,"a":100,"pp":20,"c":0,"tg":0,"pr":0},{"n":"SUBMISSION","e":48,"p":80,"t":1,"a":80,"pp":25,"c":0,"tg":0,"pr":0},{"n":"LOW KICK","e":196,"p":1,"t":1,"a":100,"pp":20,"c":0,"tg":0,"pr":0},{"n":"COUNTER","e":89,"p":1,"t":1,"a":100,"pp":20,"c":0,"tg":1,"pr":-5},{"n":"SEISMIC TOSS","e":87,"p":1,"t":1,"a":100,"pp":20,"c":0,"tg":0,"pr":0},{"n":"STRENGTH","e":0,"p":80,"t":0,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"ABSORB","e":3,"p":20,"t":12,"a":100,"pp":20,"c":0,"tg":0,"pr":0},{"n":"MEGA DRAIN","e":3,"p":40,"t":12,"a":100,"pp":10,"c":0,"tg":0,"pr":0},{"n":"LEECH SEED","e":84,"p":0,"t":12,"a":90,"pp":10,"c":0,"tg":0,"pr":0},{"n":"GROWTH","e":13,"p":0,"t":0,"a":0,"pp":40,"c":0,"tg":16,"pr":0},{"n":"RAZOR LEAF","e":43,"p":55,"t":12,"a":95,"pp":25,"c":0,"tg":8,"pr":0},{"n":"SOLARBEAM","e":151,"p":120,"t":12,"a":100,"pp":10,"c":0,"tg":0,"pr":0},{"n":"POISONPOWDER","e":66,"p":0,"t":3,"a":75,"pp":35,"c":0,"tg":0,"pr":0},{"n":"STUN SPORE","e":67,"p":0,"t":12,"a":75,"pp":30,"c":0,"tg":0,"pr":0},{"n":"SLEEP POWDER","e":1,"p":0,"t":12,"a":75,"pp":15,"c":0,"tg":0,"pr":0},{"n":"PETAL DANCE","e":27,"p":70,"t":12,"a":100,"pp":20,"c":100,"tg":4,"pr":0},{"n":"STRING SHOT","e":20,"p":0,"t":6,"a":95,"pp":40,"c":0,"tg":8,"pr":0},{"n":"DRAGON RAGE","e":41,"p":1,"t":16,"a":100,"pp":10,"c":0,"tg":0,"pr":0},{"n":"FIRE SPIN","e":42,"p":15,"t":10,"a":70,"pp":15,"c":100,"tg":0,"pr":0},{"n":"THUNDERSHOCK","e":6,"p":40,"t":13,"a":100,"pp":30,"c":10,"tg":0,"pr":0},{"n":"THUNDERBOLT","e":6,"p":95,"t":13,"a":100,"pp":15,"c":10,"tg":0,"pr":0},{"n":"THUNDER WAVE","e":67,"p":0,"t":13,"a":100,"pp":20,"c":0,"tg":0,"pr":0},{"n":"THUNDER","e":152,"p":120,"t":13,"a":70,"pp":10,"c":30,"tg":0,"pr":0},{"n":"ROCK THROW","e":0,"p":50,"t":5,"a":90,"pp":15,"c":0,"tg":0,"pr":0},{"n":"EARTHQUAKE","e":147,"p":100,"t":4,"a":100,"pp":10,"c":0,"tg":32,"pr":0},{"n":"FISSURE","e":38,"p":1,"t":4,"a":30,"pp":5,"c":0,"tg":0,"pr":0},{"n":"DIG","e":155,"p":60,"t":4,"a":100,"pp":10,"c":0,"tg":0,"pr":0},{"n":"TOXIC","e":33,"p":0,"t":3,"a":85,"pp":10,"c":100,"tg":0,"pr":0},{"n":"CONFUSION","e":76,"p":50,"t":14,"a":100,"pp":25,"c":10,"tg":0,"pr":0},{"n":"PSYCHIC","e":72,"p":90,"t":14,"a":100,"pp":10,"c":10,"tg":0,"pr":0},{"n":"HYPNOSIS","e":1,"p":0,"t":14,"a":60,"pp":20,"c":0,"tg":0,"pr":0},{"n":"MEDITATE","e":10,"p":0,"t":14,"a":0,"pp":40,"c":0,"tg":16,"pr":0},{"n":"AGILITY","e":52,"p":0,"t":14,"a":0,"pp":30,"c":0,"tg":16,"pr":0},{"n":"QUICK ATTACK","e":103,"p":40,"t":0,"a":100,"pp":30,"c":0,"tg":0,"pr":1},{"n":"RAGE","e":81,"p":20,"t":0,"a":100,"pp":20,"c":0,"tg":0,"pr":0},{"n":"TELEPORT","e":153,"p":0,"t":14,"a":0,"pp":20,"c":0,"tg":16,"pr":0},{"n":"NIGHT SHADE","e":87,"p":1,"t":7,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"MIMIC","e":82,"p":0,"t":0,"a":100,"pp":10,"c":0,"tg":0,"pr":0},{"n":"SCREECH","e":59,"p":0,"t":0,"a":85,"pp":40,"c":0,"tg":0,"pr":0},{"n":"DOUBLE TEAM","e":16,"p":0,"t":0,"a":0,"pp":15,"c":0,"tg":16,"pr":0},{"n":"RECOVER","e":32,"p":0,"t":0,"a":0,"pp":20,"c":0,"tg":16,"pr":0},{"n":"HARDEN","e":11,"p":0,"t":0,"a":0,"pp":30,"c":0,"tg":16,"pr":0},{"n":"MINIMIZE","e":108,"p":0,"t":0,"a":0,"pp":20,"c":0,"tg":16,"pr":0},{"n":"SMOKESCREEN","e":23,"p":0,"t":0,"a":100,"pp":20,"c":0,"tg":0,"pr":0},{"n":"CONFUSE RAY","e":49,"p":0,"t":7,"a":100,"pp":10,"c":0,"tg":0,"pr":0},{"n":"WITHDRAW","e":11,"p":0,"t":11,"a":0,"pp":40,"c":0,"tg":16,"pr":0},{"n":"DEFENSE CURL","e":156,"p":0,"t":0,"a":0,"pp":40,"c":0,"tg":16,"pr":0},{"n":"BARRIER","e":51,"p":0,"t":14,"a":0,"pp":30,"c":0,"tg":16,"pr":0},{"n":"LIGHT SCREEN","e":35,"p":0,"t":14,"a":0,"pp":30,"c":0,"tg":16,"pr":0},{"n":"HAZE","e":25,"p":0,"t":15,"a":0,"pp":30,"c":0,"tg":16,"pr":0},{"n":"REFLECT","e":65,"p":0,"t":14,"a":0,"pp":20,"c":0,"tg":16,"pr":0},{"n":"FOCUS ENERGY","e":47,"p":0,"t":0,"a":0,"pp":30,"c":0,"tg":16,"pr":0},{"n":"BIDE","e":26,"p":1,"t":0,"a":100,"pp":10,"c":0,"tg":16,"pr":0},{"n":"METRONOME","e":83,"p":0,"t":0,"a":0,"pp":10,"c":0,"tg":1,"pr":0},{"n":"MIRROR MOVE","e":9,"p":0,"t":2,"a":0,"pp":20,"c":0,"tg":1,"pr":0},{"n":"SELFDESTRUCT","e":7,"p":200,"t":0,"a":100,"pp":5,"c":0,"tg":32,"pr":0},{"n":"EGG BOMB","e":0,"p":100,"t":0,"a":75,"pp":10,"c":0,"tg":0,"pr":0},{"n":"LICK","e":6,"p":20,"t":7,"a":100,"pp":30,"c":30,"tg":0,"pr":0},{"n":"SMOG","e":2,"p":20,"t":3,"a":70,"pp":20,"c":40,"tg":0,"pr":0},{"n":"SLUDGE","e":2,"p":65,"t":3,"a":100,"pp":20,"c":30,"tg":0,"pr":0},{"n":"BONE CLUB","e":31,"p":65,"t":4,"a":85,"pp":20,"c":10,"tg":0,"pr":0},{"n":"FIRE BLAST","e":4,"p":120,"t":10,"a":85,"pp":5,"c":10,"tg":0,"pr":0},{"n":"WATERFALL","e":0,"p":80,"t":11,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"CLAMP","e":42,"p":35,"t":11,"a":75,"pp":10,"c":100,"tg":0,"pr":0},{"n":"SWIFT","e":17,"p":60,"t":0,"a":0,"pp":20,"c":0,"tg":8,"pr":0},{"n":"SKULL BASH","e":145,"p":100,"t":0,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"SPIKE CANNON","e":29,"p":20,"t":0,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"CONSTRICT","e":70,"p":10,"t":0,"a":100,"pp":35,"c":10,"tg":0,"pr":0},{"n":"AMNESIA","e":54,"p":0,"t":14,"a":0,"pp":20,"c":0,"tg":16,"pr":0},{"n":"KINESIS","e":23,"p":0,"t":14,"a":80,"pp":15,"c":0,"tg":0,"pr":0},{"n":"SOFTBOILED","e":157,"p":0,"t":0,"a":100,"pp":10,"c":0,"tg":16,"pr":0},{"n":"HI JUMP KICK","e":45,"p":85,"t":1,"a":90,"pp":20,"c":0,"tg":0,"pr":0},{"n":"GLARE","e":67,"p":0,"t":0,"a":75,"pp":30,"c":0,"tg":0,"pr":0},{"n":"DREAM EATER","e":8,"p":100,"t":14,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"POISON GAS","e":66,"p":0,"t":3,"a":55,"pp":40,"c":0,"tg":0,"pr":0},{"n":"BARRAGE","e":29,"p":15,"t":0,"a":85,"pp":20,"c":0,"tg":0,"pr":0},{"n":"LEECH LIFE","e":3,"p":20,"t":6,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"LOVELY KISS","e":1,"p":0,"t":0,"a":75,"pp":10,"c":0,"tg":0,"pr":0},{"n":"SKY ATTACK","e":75,"p":140,"t":2,"a":90,"pp":5,"c":30,"tg":0,"pr":0},{"n":"TRANSFORM","e":57,"p":0,"t":0,"a":0,"pp":10,"c":0,"tg":0,"pr":0},{"n":"BUBBLE","e":70,"p":20,"t":11,"a":100,"pp":30,"c":10,"tg":8,"pr":0},{"n":"DIZZY PUNCH","e":76,"p":70,"t":0,"a":100,"pp":10,"c":20,"tg":0,"pr":0},{"n":"SPORE","e":1,"p":0,"t":12,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"FLASH","e":23,"p":0,"t":0,"a":70,"pp":20,"c":0,"tg":0,"pr":0},{"n":"PSYWAVE","e":88,"p":1,"t":14,"a":80,"pp":15,"c":0,"tg":0,"pr":0},{"n":"SPLASH","e":85,"p":0,"t":0,"a":0,"pp":40,"c":0,"tg":16,"pr":0},{"n":"ACID ARMOR","e":51,"p":0,"t":3,"a":0,"pp":40,"c":0,"tg":16,"pr":0},{"n":"CRABHAMMER","e":43,"p":90,"t":11,"a":85,"pp":10,"c":0,"tg":0,"pr":0},{"n":"EXPLOSION","e":7,"p":250,"t":0,"a":100,"pp":5,"c":0,"tg":32,"pr":0},{"n":"FURY SWIPES","e":29,"p":18,"t":0,"a":80,"pp":15,"c":0,"tg":0,"pr":0},{"n":"BONEMERANG","e":44,"p":50,"t":4,"a":90,"pp":10,"c":0,"tg":0,"pr":0},{"n":"REST","e":37,"p":0,"t":14,"a":0,"pp":10,"c":0,"tg":16,"pr":0},{"n":"ROCK SLIDE","e":31,"p":75,"t":5,"a":90,"pp":10,"c":30,"tg":8,"pr":0},{"n":"HYPER FANG","e":31,"p":80,"t":0,"a":90,"pp":15,"c":10,"tg":0,"pr":0},{"n":"SHARPEN","e":10,"p":0,"t":0,"a":0,"pp":30,"c":0,"tg":16,"pr":0},{"n":"CONVERSION","e":30,"p":0,"t":0,"a":0,"pp":30,"c":0,"tg":16,"pr":0},{"n":"TRI ATTACK","e":36,"p":80,"t":0,"a":100,"pp":10,"c":20,"tg":0,"pr":0},{"n":"SUPER FANG","e":40,"p":1,"t":0,"a":90,"pp":10,"c":0,"tg":0,"pr":0},{"n":"SLASH","e":43,"p":70,"t":0,"a":100,"pp":20,"c":0,"tg":0,"pr":0},{"n":"SUBSTITUTE","e":79,"p":0,"t":0,"a":0,"pp":10,"c":0,"tg":16,"pr":0},{"n":"STRUGGLE","e":48,"p":50,"t":0,"a":100,"pp":1,"c":0,"tg":0,"pr":0},{"n":"SKETCH","e":95,"p":0,"t":0,"a":0,"pp":1,"c":0,"tg":0,"pr":0},{"n":"TRIPLE KICK","e":104,"p":10,"t":1,"a":90,"pp":10,"c":0,"tg":0,"pr":0},{"n":"THIEF","e":105,"p":40,"t":17,"a":100,"pp":10,"c":100,"tg":0,"pr":0},{"n":"SPIDER WEB","e":106,"p":0,"t":6,"a":100,"pp":10,"c":0,"tg":0,"pr":0},{"n":"MIND READER","e":94,"p":0,"t":0,"a":100,"pp":5,"c":0,"tg":0,"pr":0},{"n":"NIGHTMARE","e":107,"p":0,"t":7,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"FLAME WHEEL","e":125,"p":60,"t":10,"a":100,"pp":25,"c":10,"tg":0,"pr":0},{"n":"SNORE","e":92,"p":40,"t":0,"a":100,"pp":15,"c":30,"tg":0,"pr":0},{"n":"CURSE","e":109,"p":0,"t":9,"a":0,"pp":10,"c":0,"tg":0,"pr":0},{"n":"FLAIL","e":99,"p":1,"t":0,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"CONVERSION 2","e":93,"p":0,"t":0,"a":100,"pp":30,"c":0,"tg":16,"pr":0},{"n":"AEROBLAST","e":43,"p":100,"t":2,"a":95,"pp":5,"c":0,"tg":0,"pr":0},{"n":"COTTON SPORE","e":60,"p":0,"t":12,"a":85,"pp":40,"c":0,"tg":0,"pr":0},{"n":"REVERSAL","e":99,"p":1,"t":1,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"SPITE","e":100,"p":0,"t":7,"a":100,"pp":10,"c":0,"tg":0,"pr":0},{"n":"POWDER SNOW","e":5,"p":40,"t":15,"a":100,"pp":25,"c":10,"tg":8,"pr":0},{"n":"PROTECT","e":111,"p":0,"t":0,"a":0,"pp":10,"c":0,"tg":16,"pr":3},{"n":"MACH PUNCH","e":103,"p":40,"t":1,"a":100,"pp":30,"c":0,"tg":0,"pr":1},{"n":"SCARY FACE","e":60,"p":0,"t":0,"a":90,"pp":10,"c":0,"tg":0,"pr":0},{"n":"FAINT ATTACK","e":17,"p":60,"t":17,"a":0,"pp":20,"c":0,"tg":0,"pr":0},{"n":"SWEET KISS","e":49,"p":0,"t":0,"a":75,"pp":10,"c":0,"tg":0,"pr":0},{"n":"BELLY DRUM","e":142,"p":0,"t":0,"a":0,"pp":10,"c":0,"tg":16,"pr":0},{"n":"SLUDGE BOMB","e":2,"p":90,"t":3,"a":100,"pp":10,"c":30,"tg":0,"pr":0},{"n":"MUD-SLAP","e":73,"p":20,"t":4,"a":100,"pp":10,"c":100,"tg":0,"pr":0},{"n":"OCTAZOOKA","e":73,"p":65,"t":11,"a":85,"pp":10,"c":50,"tg":0,"pr":0},{"n":"SPIKES","e":112,"p":0,"t":4,"a":0,"pp":20,"c":0,"tg":64,"pr":0},{"n":"ZAP CANNON","e":6,"p":100,"t":13,"a":50,"pp":5,"c":100,"tg":0,"pr":0},{"n":"FORESIGHT","e":113,"p":0,"t":0,"a":100,"pp":40,"c":0,"tg":0,"pr":0},{"n":"DESTINY BOND","e":98,"p":0,"t":7,"a":0,"pp":5,"c":0,"tg":16,"pr":0},{"n":"PERISH SONG","e":114,"p":0,"t":0,"a":0,"pp":5,"c":0,"tg":16,"pr":0},{"n":"ICY WIND","e":70,"p":55,"t":15,"a":95,"pp":15,"c":100,"tg":8,"pr":0},{"n":"DETECT","e":111,"p":0,"t":1,"a":0,"pp":5,"c":0,"tg":16,"pr":3},{"n":"BONE RUSH","e":29,"p":25,"t":4,"a":80,"pp":10,"c":0,"tg":0,"pr":0},{"n":"LOCK-ON","e":94,"p":0,"t":0,"a":100,"pp":5,"c":0,"tg":0,"pr":0},{"n":"OUTRAGE","e":27,"p":90,"t":16,"a":100,"pp":15,"c":100,"tg":4,"pr":0},{"n":"SANDSTORM","e":115,"p":0,"t":5,"a":0,"pp":10,"c":0,"tg":16,"pr":0},{"n":"GIGA DRAIN","e":3,"p":60,"t":12,"a":100,"pp":5,"c":0,"tg":0,"pr":0},{"n":"ENDURE","e":116,"p":0,"t":0,"a":0,"pp":10,"c":0,"tg":16,"pr":3},{"n":"CHARM","e":58,"p":0,"t":0,"a":100,"pp":20,"c":0,"tg":0,"pr":0},{"n":"ROLLOUT","e":117,"p":30,"t":5,"a":90,"pp":20,"c":0,"tg":0,"pr":0},{"n":"FALSE SWIPE","e":101,"p":40,"t":0,"a":100,"pp":40,"c":0,"tg":0,"pr":0},{"n":"SWAGGER","e":118,"p":0,"t":0,"a":90,"pp":15,"c":100,"tg":0,"pr":0},{"n":"MILK DRINK","e":157,"p":0,"t":0,"a":0,"pp":10,"c":0,"tg":16,"pr":0},{"n":"SPARK","e":6,"p":65,"t":13,"a":100,"pp":20,"c":30,"tg":0,"pr":0},{"n":"FURY CUTTER","e":119,"p":10,"t":6,"a":95,"pp":20,"c":0,"tg":0,"pr":0},{"n":"STEEL WING","e":138,"p":70,"t":8,"a":90,"pp":25,"c":10,"tg":0,"pr":0},{"n":"MEAN LOOK","e":106,"p":0,"t":0,"a":100,"pp":5,"c":0,"tg":0,"pr":0},{"n":"ATTRACT","e":120,"p":0,"t":0,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"SLEEP TALK","e":97,"p":0,"t":0,"a":0,"pp":10,"c":0,"tg":1,"pr":0},{"n":"HEAL BELL","e":102,"p":0,"t":0,"a":0,"pp":5,"c":0,"tg":16,"pr":0},{"n":"RETURN","e":121,"p":1,"t":0,"a":100,"pp":20,"c":0,"tg":0,"pr":0},{"n":"PRESENT","e":122,"p":1,"t":0,"a":90,"pp":15,"c":0,"tg":0,"pr":0},{"n":"FRUSTRATION","e":123,"p":1,"t":0,"a":100,"pp":20,"c":0,"tg":0,"pr":0},{"n":"SAFEGUARD","e":124,"p":0,"t":0,"a":0,"pp":25,"c":0,"tg":16,"pr":0},{"n":"PAIN SPLIT","e":91,"p":0,"t":0,"a":100,"pp":20,"c":0,"tg":0,"pr":0},{"n":"SACRED FIRE","e":125,"p":100,"t":10,"a":95,"pp":5,"c":50,"tg":0,"pr":0},{"n":"MAGNITUDE","e":126,"p":1,"t":4,"a":100,"pp":30,"c":0,"tg":32,"pr":0},{"n":"DYNAMICPUNCH","e":76,"p":100,"t":1,"a":50,"pp":5,"c":100,"tg":0,"pr":0},{"n":"MEGAHORN","e":0,"p":120,"t":6,"a":85,"pp":10,"c":0,"tg":0,"pr":0},{"n":"DRAGONBREATH","e":6,"p":60,"t":16,"a":100,"pp":20,"c":30,"tg":0,"pr":0},{"n":"BATON PASS","e":127,"p":0,"t":0,"a":0,"pp":40,"c":0,"tg":16,"pr":0},{"n":"ENCORE","e":90,"p":0,"t":0,"a":100,"pp":5,"c":0,"tg":0,"pr":0},{"n":"PURSUIT","e":128,"p":40,"t":17,"a":100,"pp":20,"c":0,"tg":0,"pr":0},{"n":"RAPID SPIN","e":129,"p":20,"t":0,"a":100,"pp":40,"c":0,"tg":0,"pr":0},{"n":"SWEET SCENT","e":24,"p":0,"t":0,"a":100,"pp":20,"c":0,"tg":8,"pr":0},{"n":"IRON TAIL","e":69,"p":100,"t":8,"a":75,"pp":15,"c":30,"tg":0,"pr":0},{"n":"METAL CLAW","e":139,"p":50,"t":8,"a":95,"pp":35,"c":10,"tg":0,"pr":0},{"n":"VITAL THROW","e":78,"p":70,"t":1,"a":100,"pp":10,"c":0,"tg":0,"pr":-1},{"n":"MORNING SUN","e":132,"p":0,"t":0,"a":0,"pp":5,"c":0,"tg":16,"pr":0},{"n":"SYNTHESIS","e":133,"p":0,"t":12,"a":0,"pp":5,"c":0,"tg":16,"pr":0},{"n":"MOONLIGHT","e":134,"p":0,"t":0,"a":0,"pp":5,"c":0,"tg":16,"pr":0},{"n":"HIDDEN POWER","e":135,"p":1,"t":0,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"CROSS CHOP","e":43,"p":100,"t":1,"a":80,"pp":5,"c":0,"tg":0,"pr":0},{"n":"TWISTER","e":146,"p":40,"t":16,"a":100,"pp":20,"c":20,"tg":8,"pr":0},{"n":"RAIN DANCE","e":136,"p":0,"t":11,"a":0,"pp":5,"c":0,"tg":16,"pr":0},{"n":"SUNNY DAY","e":137,"p":0,"t":10,"a":0,"pp":5,"c":0,"tg":16,"pr":0},{"n":"CRUNCH","e":72,"p":80,"t":17,"a":100,"pp":15,"c":20,"tg":0,"pr":0},{"n":"MIRROR COAT","e":144,"p":1,"t":14,"a":100,"pp":20,"c":0,"tg":1,"pr":-5},{"n":"PSYCH UP","e":143,"p":0,"t":0,"a":0,"pp":10,"c":0,"tg":0,"pr":0},{"n":"EXTREMESPEED","e":103,"p":80,"t":0,"a":100,"pp":5,"c":0,"tg":0,"pr":1},{"n":"ANCIENTPOWER","e":140,"p":60,"t":5,"a":100,"pp":5,"c":10,"tg":0,"pr":0},{"n":"SHADOW BALL","e":72,"p":80,"t":7,"a":100,"pp":15,"c":20,"tg":0,"pr":0},{"n":"FUTURE SIGHT","e":148,"p":80,"t":14,"a":90,"pp":15,"c":0,"tg":0,"pr":0},{"n":"ROCK SMASH","e":69,"p":20,"t":1,"a":100,"pp":15,"c":50,"tg":0,"pr":0},{"n":"WHIRLPOOL","e":42,"p":15,"t":11,"a":70,"pp":15,"c":100,"tg":0,"pr":0},{"n":"BEAT UP","e":154,"p":10,"t":17,"a":100,"pp":10,"c":0,"tg":0,"pr":0},{"n":"FAKE OUT","e":158,"p":40,"t":0,"a":100,"pp":10,"c":0,"tg":0,"pr":1},{"n":"UPROAR","e":159,"p":50,"t":0,"a":100,"pp":10,"c":100,"tg":4,"pr":0},{"n":"STOCKPILE","e":160,"p":0,"t":0,"a":0,"pp":10,"c":0,"tg":16,"pr":0},{"n":"SPIT UP","e":161,"p":100,"t":0,"a":100,"pp":10,"c":0,"tg":0,"pr":0},{"n":"SWALLOW","e":162,"p":0,"t":0,"a":0,"pp":10,"c":0,"tg":16,"pr":0},{"n":"HEAT WAVE","e":4,"p":100,"t":10,"a":90,"pp":10,"c":10,"tg":8,"pr":0},{"n":"HAIL","e":164,"p":0,"t":15,"a":0,"pp":10,"c":0,"tg":16,"pr":0},{"n":"TORMENT","e":165,"p":0,"t":17,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"FLATTER","e":166,"p":0,"t":17,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"WILL-O-WISP","e":167,"p":0,"t":10,"a":75,"pp":15,"c":0,"tg":0,"pr":0},{"n":"MEMENTO","e":168,"p":0,"t":17,"a":100,"pp":10,"c":0,"tg":0,"pr":0},{"n":"FACADE","e":169,"p":70,"t":0,"a":100,"pp":20,"c":0,"tg":0,"pr":0},{"n":"FOCUS PUNCH","e":170,"p":150,"t":1,"a":100,"pp":20,"c":0,"tg":0,"pr":-3},{"n":"SMELLINGSALT","e":171,"p":60,"t":0,"a":100,"pp":10,"c":0,"tg":0,"pr":0},{"n":"FOLLOW ME","e":172,"p":0,"t":0,"a":100,"pp":20,"c":0,"tg":16,"pr":3},{"n":"NATURE POWER","e":173,"p":0,"t":0,"a":0,"pp":20,"c":0,"tg":1,"pr":0},{"n":"CHARGE","e":174,"p":0,"t":13,"a":100,"pp":20,"c":0,"tg":16,"pr":0},{"n":"TAUNT","e":175,"p":0,"t":17,"a":100,"pp":20,"c":0,"tg":0,"pr":0},{"n":"HELPING HAND","e":176,"p":0,"t":0,"a":100,"pp":20,"c":0,"tg":16,"pr":5},{"n":"TRICK","e":177,"p":0,"t":14,"a":100,"pp":10,"c":0,"tg":0,"pr":0},{"n":"ROLE PLAY","e":178,"p":0,"t":14,"a":100,"pp":10,"c":0,"tg":0,"pr":0},{"n":"WISH","e":179,"p":0,"t":0,"a":100,"pp":10,"c":0,"tg":16,"pr":0},{"n":"ASSIST","e":180,"p":0,"t":0,"a":100,"pp":20,"c":0,"tg":1,"pr":0},{"n":"INGRAIN","e":181,"p":0,"t":12,"a":100,"pp":20,"c":0,"tg":16,"pr":0},{"n":"SUPERPOWER","e":182,"p":120,"t":1,"a":100,"pp":5,"c":0,"tg":0,"pr":0},{"n":"MAGIC COAT","e":183,"p":0,"t":14,"a":100,"pp":15,"c":0,"tg":1,"pr":4},{"n":"RECYCLE","e":184,"p":0,"t":0,"a":100,"pp":10,"c":0,"tg":16,"pr":0},{"n":"REVENGE","e":185,"p":60,"t":1,"a":100,"pp":10,"c":0,"tg":0,"pr":-4},{"n":"BRICK BREAK","e":186,"p":75,"t":1,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"YAWN","e":187,"p":0,"t":0,"a":100,"pp":10,"c":0,"tg":0,"pr":0},{"n":"KNOCK OFF","e":188,"p":20,"t":17,"a":100,"pp":20,"c":100,"tg":0,"pr":0},{"n":"ENDEAVOR","e":189,"p":1,"t":0,"a":100,"pp":5,"c":0,"tg":0,"pr":0},{"n":"ERUPTION","e":190,"p":150,"t":10,"a":100,"pp":5,"c":0,"tg":8,"pr":0},{"n":"SKILL SWAP","e":191,"p":0,"t":14,"a":100,"pp":10,"c":0,"tg":0,"pr":0},{"n":"IMPRISON","e":192,"p":0,"t":14,"a":100,"pp":10,"c":0,"tg":16,"pr":0},{"n":"REFRESH","e":193,"p":0,"t":0,"a":100,"pp":20,"c":0,"tg":16,"pr":0},{"n":"GRUDGE","e":194,"p":0,"t":7,"a":100,"pp":5,"c":0,"tg":16,"pr":0},{"n":"SNATCH","e":195,"p":0,"t":17,"a":100,"pp":10,"c":0,"tg":1,"pr":4},{"n":"SECRET POWER","e":197,"p":70,"t":0,"a":100,"pp":20,"c":30,"tg":0,"pr":0},{"n":"DIVE","e":155,"p":60,"t":11,"a":100,"pp":10,"c":0,"tg":0,"pr":0},{"n":"ARM THRUST","e":29,"p":15,"t":1,"a":100,"pp":20,"c":0,"tg":0,"pr":0},{"n":"CAMOUFLAGE","e":213,"p":0,"t":0,"a":100,"pp":20,"c":0,"tg":16,"pr":0},{"n":"TAIL GLOW","e":53,"p":0,"t":6,"a":100,"pp":20,"c":0,"tg":16,"pr":0},{"n":"LUSTER PURGE","e":72,"p":70,"t":14,"a":100,"pp":5,"c":50,"tg":0,"pr":0},{"n":"MIST BALL","e":71,"p":70,"t":14,"a":100,"pp":5,"c":50,"tg":0,"pr":0},{"n":"FEATHERDANCE","e":58,"p":0,"t":2,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"TEETER DANCE","e":199,"p":0,"t":0,"a":100,"pp":20,"c":0,"tg":32,"pr":0},{"n":"BLAZE KICK","e":200,"p":85,"t":10,"a":90,"pp":10,"c":10,"tg":0,"pr":0},{"n":"MUD SPORT","e":201,"p":0,"t":4,"a":100,"pp":15,"c":0,"tg":16,"pr":0},{"n":"ICE BALL","e":117,"p":30,"t":15,"a":90,"pp":20,"c":0,"tg":0,"pr":0},{"n":"NEEDLE ARM","e":150,"p":60,"t":12,"a":100,"pp":15,"c":30,"tg":0,"pr":0},{"n":"SLACK OFF","e":32,"p":0,"t":0,"a":100,"pp":10,"c":0,"tg":16,"pr":0},{"n":"HYPER VOICE","e":0,"p":90,"t":0,"a":100,"pp":10,"c":0,"tg":8,"pr":0},{"n":"POISON FANG","e":202,"p":50,"t":3,"a":100,"pp":15,"c":30,"tg":0,"pr":0},{"n":"CRUSH CLAW","e":69,"p":75,"t":0,"a":95,"pp":10,"c":50,"tg":0,"pr":0},{"n":"BLAST BURN","e":80,"p":150,"t":10,"a":90,"pp":5,"c":0,"tg":0,"pr":0},{"n":"HYDRO CANNON","e":80,"p":150,"t":11,"a":90,"pp":5,"c":0,"tg":0,"pr":0},{"n":"METEOR MASH","e":139,"p":100,"t":8,"a":85,"pp":10,"c":20,"tg":0,"pr":0},{"n":"ASTONISH","e":150,"p":30,"t":7,"a":100,"pp":15,"c":30,"tg":0,"pr":0},{"n":"WEATHER BALL","e":203,"p":50,"t":0,"a":100,"pp":10,"c":0,"tg":0,"pr":0},{"n":"AROMATHERAPY","e":102,"p":0,"t":12,"a":0,"pp":5,"c":0,"tg":16,"pr":0},{"n":"FAKE TEARS","e":62,"p":0,"t":17,"a":100,"pp":20,"c":0,"tg":0,"pr":0},{"n":"AIR CUTTER","e":43,"p":55,"t":2,"a":95,"pp":25,"c":0,"tg":8,"pr":0},{"n":"OVERHEAT","e":204,"p":140,"t":10,"a":90,"pp":5,"c":100,"tg":0,"pr":0},{"n":"ODOR SLEUTH","e":113,"p":0,"t":0,"a":100,"pp":40,"c":0,"tg":0,"pr":0},{"n":"ROCK TOMB","e":70,"p":50,"t":5,"a":80,"pp":10,"c":100,"tg":0,"pr":0},{"n":"SILVER WIND","e":140,"p":60,"t":6,"a":100,"pp":5,"c":10,"tg":0,"pr":0},{"n":"METAL SOUND","e":62,"p":0,"t":8,"a":85,"pp":40,"c":0,"tg":0,"pr":0},{"n":"GRASSWHISTLE","e":1,"p":0,"t":12,"a":55,"pp":15,"c":0,"tg":0,"pr":0},{"n":"TICKLE","e":205,"p":0,"t":0,"a":100,"pp":20,"c":0,"tg":0,"pr":0},{"n":"COSMIC POWER","e":206,"p":0,"t":14,"a":0,"pp":20,"c":0,"tg":16,"pr":0},{"n":"WATER SPOUT","e":190,"p":150,"t":11,"a":100,"pp":5,"c":0,"tg":8,"pr":0},{"n":"SIGNAL BEAM","e":76,"p":75,"t":6,"a":100,"pp":15,"c":10,"tg":0,"pr":0},{"n":"SHADOW PUNCH","e":17,"p":60,"t":7,"a":0,"pp":20,"c":0,"tg":0,"pr":0},{"n":"EXTRASENSORY","e":150,"p":80,"t":14,"a":100,"pp":30,"c":10,"tg":0,"pr":0},{"n":"SKY UPPERCUT","e":207,"p":85,"t":1,"a":90,"pp":15,"c":0,"tg":0,"pr":0},{"n":"SAND TOMB","e":42,"p":15,"t":4,"a":70,"pp":15,"c":100,"tg":0,"pr":0},{"n":"SHEER COLD","e":38,"p":1,"t":15,"a":30,"pp":5,"c":0,"tg":0,"pr":0},{"n":"MUDDY WATER","e":73,"p":95,"t":11,"a":85,"pp":10,"c":30,"tg":8,"pr":0},{"n":"BULLET SEED","e":29,"p":10,"t":12,"a":100,"pp":30,"c":0,"tg":0,"pr":0},{"n":"AERIAL ACE","e":17,"p":60,"t":2,"a":0,"pp":20,"c":0,"tg":0,"pr":0},{"n":"ICICLE SPEAR","e":29,"p":10,"t":15,"a":100,"pp":30,"c":0,"tg":0,"pr":0},{"n":"IRON DEFENSE","e":51,"p":0,"t":8,"a":0,"pp":15,"c":0,"tg":16,"pr":0},{"n":"BLOCK","e":106,"p":0,"t":0,"a":100,"pp":5,"c":0,"tg":0,"pr":0},{"n":"HOWL","e":10,"p":0,"t":0,"a":0,"pp":40,"c":0,"tg":16,"pr":0},{"n":"DRAGON CLAW","e":0,"p":80,"t":16,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"FRENZY PLANT","e":80,"p":150,"t":12,"a":90,"pp":5,"c":0,"tg":0,"pr":0},{"n":"BULK UP","e":208,"p":0,"t":1,"a":0,"pp":20,"c":0,"tg":16,"pr":0},{"n":"BOUNCE","e":155,"p":85,"t":2,"a":85,"pp":5,"c":30,"tg":0,"pr":0},{"n":"MUD SHOT","e":70,"p":55,"t":4,"a":95,"pp":15,"c":100,"tg":0,"pr":0},{"n":"POISON TAIL","e":209,"p":50,"t":3,"a":100,"pp":25,"c":10,"tg":0,"pr":0},{"n":"COVET","e":105,"p":40,"t":0,"a":100,"pp":40,"c":100,"tg":0,"pr":0},{"n":"VOLT TACKLE","e":198,"p":120,"t":13,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"MAGICAL LEAF","e":17,"p":60,"t":12,"a":0,"pp":20,"c":0,"tg":0,"pr":0},{"n":"WATER SPORT","e":210,"p":0,"t":11,"a":100,"pp":15,"c":0,"tg":16,"pr":0},{"n":"CALM MIND","e":211,"p":0,"t":14,"a":0,"pp":20,"c":0,"tg":16,"pr":0},{"n":"LEAF BLADE","e":43,"p":70,"t":12,"a":100,"pp":15,"c":0,"tg":0,"pr":0},{"n":"DRAGON DANCE","e":212,"p":0,"t":16,"a":0,"pp":20,"c":0,"tg":16,"pr":0},{"n":"ROCK BLAST","e":29,"p":25,"t":5,"a":80,"pp":10,"c":0,"tg":0,"pr":0},{"n":"SHOCK WAVE","e":17,"p":60,"t":13,"a":0,"pp":20,"c":0,"tg":0,"pr":0},{"n":"WATER PULSE","e":76,"p":60,"t":11,"a":100,"pp":20,"c":20,"tg":0,"pr":0},{"n":"DOOM DESIRE","e":148,"p":120,"t":8,"a":85,"pp":5,"c":0,"tg":0,"pr":0},{"n":"PSYCHO BOOST","e":204,"p":140,"t":14,"a":90,"pp":5,"c":100,"tg":0,"pr":0}],"items":["????????","MASTER BALL","ULTRA BALL","GREAT BALL","POKé BALL","SAFARI BALL","NET BALL","DIVE BALL","NEST BALL","REPEAT BALL","TIMER BALL","LUXURY BALL","PREMIER BALL","POTION","ANTIDOTE","BURN HEAL","ICE HEAL","AWAKENING","PARLYZ HEAL","FULL RESTORE","MAX POTION","HYPER POTION","SUPER POTION","FULL HEAL","REVIVE","MAX REVIVE","FRESH WATER","SODA POP","LEMONADE","MOOMOO MILK","ENERGYPOWDER","ENERGY ROOT","HEAL POWDER","REVIVAL HERB","ETHER","MAX ETHER","ELIXIR","MAX ELIXIR","LAVA COOKIE","BLUE FLUTE","YELLOW FLUTE","RED FLUTE","BLACK FLUTE","WHITE FLUTE","BERRY JUICE","SACRED ASH","SHOAL SALT","SHOAL SHELL","RED SHARD","BLUE SHARD","YELLOW SHARD","GREEN SHARD","????????","????????","????????","????????","????????","????????","????????","????????","????????","????????","????????","HP UP","PROTEIN","IRON","CARBOS","CALCIUM","RARE CANDY","PP UP","ZINC","PP MAX","????????","GUARD SPEC.","DIRE HIT","X ATTACK","X DEFEND","X SPEED","X ACCURACY","X SPECIAL","POKé DOLL","FLUFFY TAIL","????????","SUPER REPEL","MAX REPEL","ESCAPE ROPE","REPEL","????????","????????","????????","????????","????????","????????","SUN STONE","MOON STONE","FIRE STONE","THUNDERSTONE","WATER STONE","LEAF STONE","????????","????????","????????","????????","TINYMUSHROOM","BIG MUSHROOM","????????","PEARL","BIG PEARL","STARDUST","STAR PIECE","NUGGET","HEART SCALE","????????","????????","????????","????????","????????","????????","????????","????????","????????","ORANGE MAIL","HARBOR MAIL","GLITTER MAIL","MECH MAIL","WOOD MAIL","WAVE MAIL","BEAD MAIL","SHADOW MAIL","TROPIC MAIL","DREAM MAIL","FAB MAIL","RETRO MAIL","CHERI BERRY","CHESTO BERRY","PECHA BERRY","RAWST BERRY","ASPEAR BERRY","LEPPA BERRY","ORAN BERRY","PERSIM BERRY","LUM BERRY","SITRUS BERRY","FIGY BERRY","WIKI BERRY","MAGO BERRY","AGUAV BERRY","IAPAPA BERRY","RAZZ BERRY","BLUK BERRY","NANAB BERRY","WEPEAR BERRY","PINAP BERRY","POMEG BERRY","KELPSY BERRY","QUALOT BERRY","HONDEW BERRY","GREPA BERRY","TAMATO BERRY","CORNN BERRY","MAGOST BERRY","RABUTA BERRY","NOMEL BERRY","SPELON BERRY","PAMTRE BERRY","WATMEL BERRY","DURIN BERRY","BELUE BERRY","LIECHI BERRY","GANLON BERRY","SALAC BERRY","PETAYA BERRY","APICOT BERRY","LANSAT BERRY","STARF BERRY","ENIGMA BERRY","????????","????????","????????","BRIGHTPOWDER","WHITE HERB","MACHO BRACE","EXP. SHARE","QUICK CLAW","SOOTHE BELL","MENTAL HERB","CHOICE BAND","KING’S ROCK","SILVERPOWDER","AMULET COIN","CLEANSE TAG","SOUL DEW","DEEPSEATOOTH","DEEPSEASCALE","SMOKE BALL","EVERSTONE","FOCUS BAND","LUCKY EGG","SCOPE LENS","METAL COAT","LEFTOVERS","DRAGON SCALE","LIGHT BALL","SOFT SAND","HARD STONE","MIRACLE SEED","BLACKGLASSES","BLACK BELT","MAGNET","MYSTIC WATER","SHARP BEAK","POISON BARB","NEVERMELTICE","SPELL TAG","TWISTEDSPOON","CHARCOAL","DRAGON FANG","SILK SCARF","UP-GRADE","SHELL BELL","SEA INCENSE","LAX INCENSE","LUCKY PUNCH","METAL POWDER","THICK CLUB","STICK","????????","????????","????????","????????","????????","????????","????????","????????","????????","????????","????????","????????","????????","????????","????????","????????","????????","????????","????????","????????","????????","????????","????????","????????","????????","????????","????????","????????","RED SCARF","BLUE SCARF","PINK SCARF","GREEN SCARF","YELLOW SCARF","MACH BIKE","COIN CASE","ITEMFINDER","OLD ROD","GOOD ROD","SUPER ROD","S.S. TICKET","CONTEST PASS","????????","WAILMER PAIL","DEVON GOODS","SOOT SACK","BASEMENT KEY","ACRO BIKE","オカキクケ CASE","LETTER","EON TICKET","RED ORB","BLUE ORB","SCANNER","GO-GOGGLES","METEORITE","RM. 1 KEY","RM. 2 KEY","RM. 4 KEY","RM. 6 KEY","STORAGE KEY","ROOT FOSSIL","CLAW FOSSIL","DEVON SCOPE","TM01","TM02","TM03","TM04","TM05","TM06","TM07","TM08","TM09","TM10","TM11","TM12","TM13","TM14","TM15","TM16","TM17","TM18","TM19","TM20","TM21","TM22","TM23","TM24","TM25","TM26","TM27","TM28","TM29","TM30","TM31","TM32","TM33","TM34","TM35","TM36","TM37","TM38","TM39","TM40","TM41","TM42","TM43","TM44","TM45","TM46","TM47","TM48","TM49","TM50","HM01","HM02","HM03","HM04","HM05","HM06","HM07","HM08","????????","????????","OAK’S PARCEL","POKé FLUTE","SECRET KEY","BIKE VOUCHER","GOLD TEETH","OLD AMBER","CARD KEY","LIFT KEY","HELIX FOSSIL","DOME FOSSIL","SILPH SCOPE","BICYCLE","TOWN MAP","VS SEEKER","FAME CHECKER","TM CASE","BERRY POUCH","TEACHY TV","TRI-PASS","RAINBOW PASS","TEA","MYSTICTICKET","AURORATICKET","POWDER JAR","RUBY","SAPPHIRE"],"abilities":["-------","STENCH","DRIZZLE","SPEED BOOST","BATTLE ARMOR","STURDY","DAMP","LIMBER","SAND VEIL","STATIC","VOLT ABSORB","WATER ABSORB","OBLIVIOUS","CLOUD NINE","COMPOUNDEYES","INSOMNIA","COLOR CHANGE","IMMUNITY","FLASH FIRE","SHIELD DUST","OWN TEMPO","SUCTION CUPS","INTIMIDATE","SHADOW TAG","ROUGH SKIN","WONDER GUARD","LEVITATE","EFFECT SPORE","SYNCHRONIZE","CLEAR BODY","NATURAL CURE","LIGHTNINGROD","SERENE GRACE","SWIFT SWIM","CHLOROPHYLL","ILLUMINATE","TRACE","HUGE POWER","POISON POINT","INNER FOCUS","MAGMA ARMOR","WATER VEIL","MAGNET PULL","SOUNDPROOF","RAIN DISH","SAND STREAM","PRESSURE","THICK FAT","EARLY BIRD","FLAME BODY","RUN AWAY","KEEN EYE","HYPER CUTTER","PICKUP","TRUANT","HUSTLE","CUTE CHARM","PLUS","MINUS","FORECAST","STICKY HOLD","SHED SKIN","GUTS","MARVEL SCALE","LIQUID OOZE","OVERGROW","BLAZE","TORRENT","SWARM","ROCK HEAD","DROUGHT","ARENA TRAP","VITAL SPIRIT","WHITE SMOKE","PURE POWER","SHELL ARMOR","CACOPHONY","AIR LOCK"],"types":["NORMAL","FIGHT","FLYING","POISON","GROUND","ROCK","BUG","GHOST","STEEL","???","FIRE","WATER","GRASS","ELECTR","PSYCHC","ICE","DRAGON","DARK"]};

const TYPE_LABEL = ["NORMAL","FIGHTING","FLYING","POISON","GROUND","ROCK","BUG","GHOST","STEEL","???","FIRE","WATER","GRASS","ELECTRIC","PSYCHIC","ICE","DRAGON","DARK"];
const TYPE_COLOR = ["#a8a878","#c03028","#a890f0","#a040a0","#e0c068","#b8a038","#a8b820","#705898","#b8b8d0","#68a090","#f08030","#6890f0","#78c850","#f8d030","#f85888","#98d8d8","#7038f8","#705848"];
// Gen 3 type chart: [attacker][defender] = multiplier (exceptions only)
const CHART = (() => {
  const N=0,FI=1,FL=2,PO=3,GR=4,RO=5,BU=6,GH=7,ST=8,FR=10,WA=11,GS=12,EL=13,PS=14,IC=15,DR=16,DA=17;
  const t = {};
  const set = (a, list) => { t[a] = {}; for (const [d, m] of list) t[a][d] = m; };
  set(N, [[RO,.5],[GH,0],[ST,.5]]);
  set(FI, [[N,2],[FL,.5],[PO,.5],[RO,2],[BU,.5],[GH,0],[ST,2],[PS,.5],[IC,2],[DA,2]]);
  set(FL, [[FI,2],[RO,.5],[BU,2],[ST,.5],[GS,2],[EL,.5]]);
  set(PO, [[PO,.5],[GR,.5],[RO,.5],[GH,.5],[ST,0],[GS,2]]);
  set(GR, [[FL,0],[PO,2],[RO,2],[BU,.5],[ST,2],[FR,2],[GS,.5],[EL,2]]);
  set(RO, [[FI,.5],[FL,2],[GR,.5],[BU,2],[ST,.5],[FR,2],[IC,2]]);
  set(BU, [[FI,.5],[FL,.5],[PO,.5],[GH,.5],[ST,.5],[FR,.5],[GS,2],[PS,2],[DA,2]]);
  set(GH, [[N,0],[GH,2],[ST,.5],[PS,2],[DA,.5]]);
  set(ST, [[RO,2],[ST,.5],[FR,.5],[WA,.5],[EL,.5],[IC,2]]);
  set(FR, [[RO,.5],[BU,2],[ST,2],[FR,.5],[WA,.5],[GS,2],[IC,2],[DR,.5]]);
  set(WA, [[GR,2],[RO,2],[FR,2],[WA,.5],[GS,.5],[DR,.5]]);
  set(GS, [[FL,.5],[PO,.5],[GR,2],[RO,2],[BU,.5],[ST,.5],[FR,.5],[WA,2],[GS,.5],[DR,.5]]);
  set(EL, [[FL,2],[GR,0],[WA,2],[GS,.5],[EL,.5],[DR,.5]]);
  set(PS, [[FI,2],[PO,2],[ST,.5],[PS,.5],[DA,0]]);
  set(IC, [[FL,2],[GR,2],[ST,.5],[FR,.5],[WA,.5],[GS,2],[IC,.5],[DR,2]]);
  set(DR, [[ST,.5],[DR,2]]);
  set(DA, [[FI,.5],[GH,2],[ST,.5],[PS,2],[DA,.5]]);
  return t;
})();
const STAT_NAMES = ["ATK","DEF","SPE","SPA","SPD","ACC","EVA"];
const ERRORS = {
  1: "That choice is not allowed right now.",
  2: "Invalid move.",
  3: "That move can't be used right now (no PP left or blocked).",
  4: "That item can't be used right now.",
  5: "That Pokémon can't be sent out.",
  6: "The Pokémon is trapped and can't be switched out."
};
const TARGET_SELECTED = 0, TARGET_USER_OR_SEL = 2, TARGET_BOTH = 8, TARGET_USER = 16, TARGET_FOES_ALLY = 32, TARGET_FIELD = 64;

let code = "";
let state = null, lastJson = "", lastSeq = -1, lastReqKey = "";
let sel = null;          // {kind:'move'|'item'|'switch'|'ai', a1, a2, label}
let tab = "moves";
let sending = false, failCount = 0, notified = -1;

const $ = (id) => document.getElementById(id);
const esc = (s) => String(s ?? "").replace(/[&<>"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
const speciesName = (id) => (GAME.species[id] || "???");
const moveData = (id) => GAME.moves[id] || {n:"???",p:0,t:0,a:0,pp:0,tg:0};
const itemName = (id) => GAME.items[id] || "???";

function typeChip(t) { return `<span class="type" style="background:${TYPE_COLOR[t]||'#666'}">${TYPE_LABEL[t]||'?'}</span>`; }
function typesChips(types) {
  if (!types) return "";
  const a = types[0], b = types[1];
  return typeChip(a) + (b !== a ? typeChip(b) : "");
}
function statusChips(s1, s2, s3, fainted) {
  const out = [];
  if (fainted) return `<span class="st fnt">FNT</span>`;
  if (s1 & 7) out.push(`<span class="st slp">SLP</span>`);
  if (s1 & 0x80) out.push(`<span class="st tox">TOX</span>`);
  else if (s1 & 0x8) out.push(`<span class="st psn">PSN</span>`);
  if (s1 & 0x10) out.push(`<span class="st brn">BRN</span>`);
  if (s1 & 0x20) out.push(`<span class="st frz">FRZ</span>`);
  if (s1 & 0x40) out.push(`<span class="st par">PAR</span>`);
  if (s2 & 7) out.push(`<span class="st misc">Confused</span>`);
  if (s2 & 0xF0000) out.push(`<span class="st misc">Infatuated</span>`);
  if (s2 & 0x1000000) out.push(`<span class="st misc">Substitute</span>`);
  if (s3 & 4) out.push(`<span class="st misc">Leech Seed</span>`);
  return out.join("");
}
function stageChips(stages) {
  if (!stages) return "";
  const out = [];
  for (let i = 1; i <= 7; i++) {
    const v = stages[i] - 6;
    if (v) out.push(`<span class="stage ${v < 0 ? "neg" : ""}">${STAT_NAMES[i-1]} ${v > 0 ? "+" : ""}${v}</span>`);
  }
  return out.join("");
}
function hpBar(pct) {
  const cls = pct <= 20 ? "low" : pct <= 50 ? "mid" : "";
  return `<div class="hp"><i class="${cls}" style="width:${Math.max(0, Math.min(100, pct))}%"></i></div>`;
}
function effectiveness(moveId, defTypes) {
  const m = moveData(moveId);
  if (!m.p || !defTypes) return null;
  let mult = 1;
  const seen = new Set();
  for (const d of defTypes) {
    if (seen.has(d)) continue;
    seen.add(d);
    const row = CHART[m.t];
    if (row && row[d] !== undefined) mult *= row[d];
  }
  return mult;
}
function effChip(mult) {
  if (mult === null || mult === 1) return "";
  if (mult === 0) return `<span class="eff zero">x0</span>`;
  if (mult >= 4) return `<span class="eff x4">x4</span>`;
  if (mult >= 2) return `<span class="eff x2">x2</span>`;
  return `<span class="eff half">x${mult === .25 ? "¼" : "½"}</span>`;
}
function battlerLabel(b, st) {
  if (st.battlersCount < 4) return "";
  return b.id === 0 ? "left" : b.id === 2 ? "right" : b.id === 1 ? "left" : "right";
}

// ------------------------------------------------------------ network
async function api(path, body) {
  const url = `api/${path}?k=${encodeURIComponent(code)}&t=${Date.now()}`;
  const opt = body ? { method: "POST", headers: {"Content-Type":"application/x-www-form-urlencoded"}, body } : {};
  const r = await fetch(url, opt);
  const j = await r.json();
  if (r.status === 401) throw Object.assign(new Error("code"), { code: true });
  return j;
}

async function poll() {
  try {
    const st = await api("state");
    failCount = 0;
    $("dot").className = "dot on";
    const json = JSON.stringify(st);
    if (json !== lastJson) { lastJson = json; onState(st); }
  } catch (e) {
    if (e.code) { logout("Wrong code, or the code has changed."); return; }
    failCount++;
    $("dot").className = "dot off";
    if (failCount >= 3) renderBanner("err", "📡", "Connection lost", "Retrying... Check that player 1 has mGBA and the tunnel running.");
  }
  setTimeout(poll, document.hidden ? 1500 : 700);
}

function onState(st) {
  const prevKey = lastReqKey;
  state = st;
  lastReqKey = st.reqType ? `${st.reqSeq}:${st.reqType}:${st.reqBattler}` : "";
  if (lastReqKey !== prevKey) {
    // new request: clear the selection if it is a different decision
    const sameDecision = prevKey && lastReqKey && prevKey.split(":").slice(1).join(":") === lastReqKey.split(":").slice(1).join(":");
    if (!sameDecision) { sel = null; tab = st.reqType === 3 ? "switch" : "moves"; }
    if (st.reqType && st.lastError) { showToast(ERRORS[st.lastError] || "Invalid choice."); sel = null; }
    if (st.reqType && notified !== st.reqSeq) { notified = st.reqSeq; notifyTurn(); }
  }
  $("autoAi").checked = !!st.auto;
  render();
}

async function send() {
  if (!sel || !state || !state.reqType || sending) return;
  sending = true;
  $("sendBtn").disabled = true;
  const types = { move: 1, item: 2, switch: 3, ai: 4 };
  const body = `seq=${state.reqSeq}&type=${types[sel.kind]}&a1=${sel.a1 ?? 0}&a2=${sel.a2 ?? 0}`;
  try {
    const r = await api("choose", body);
    if (!r.ok) showToast(r.error || "Error");
    else { sel = null; state.reqType = 0; lastJson = ""; render(); }
  } catch (e) { showToast("Sending failed, please try again."); }
  sending = false;
  $("sendBtn").disabled = false;
}

// ------------------------------------------------------------ interface
function renderBanner(kind, icon, big, small) {
  $("banner").innerHTML = `<div class="banner ${kind}"><div class="icon">${icon}</div><div><div class="big">${esc(big)}</div><div class="small">${esc(small || "")}</div></div></div>`;
}

function render() {
  const st = state;
  if (!st) return;
  if (st.game === "none") { renderBanner("", "🎮", "Game not running", "Player 1 needs to open the ROM in mGBA."); clearBattle(); return; }
  if (st.game === "wrong") { renderBanner("err", "⚠️", "Unpatched ROM", "The ROM open in mGBA doesn't have the Rival at the Wheel patch."); clearBattle(); return; }
  if (!st.inBattle) { renderBanner("", "🌿", "No battle right now", "When player 1 battles a trainer, it'll be your turn."); clearBattle(); hideConfirm(); return; }

  const me = st.battlers.find(b => b.id === st.reqBattler);
  const who = st.trainerName ? `${st.trainerClass} ${st.trainerName}` : st.trainerClass;
  if (st.reqType) {
    const what = st.reqType === 3 ? "Choose the next Pokémon" : `What will ${me ? speciesName(me.species) : ""} do?`;
    renderBanner("turn", "🔥", "Your turn!", `${what}${who ? " · you are " + who : ""}`);
  } else {
    renderBanner("", "⏳", "Player 1's turn", `${who ? "You are " + who + " · " : ""}turn ${st.turn + 1}`);
  }
  renderAction(st, me);
  renderField(st);
  renderParty(st);
  updateConfirm();
}

function clearBattle() { $("action").innerHTML = ""; $("field").innerHTML = ""; $("partyBox").innerHTML = ""; }

function renderAction(st, me) {
  const box = $("action");
  if (!st.reqType || !me) { box.innerHTML = ""; hideConfirm(); return; }
  const tabs = [];
  if (st.reqType !== 3) tabs.push(["moves", "Moves"]);
  if (st.reqType === 1) tabs.push(["items", "Items"]);
  if (st.reqType !== 2) tabs.push(["switch", st.reqType === 3 ? "Party" : "Switch"]);
  if (!tabs.find(t => t[0] === tab)) tab = tabs[0][0];
  let html = `<h2>${st.reqType === 3 ? "Who goes in next?" : "Your choice" + (battlerLabel(me, st) ? " · " + battlerLabel(me, st) + " Pokémon" : "")}</h2>`;
  if (tabs.length > 1) html += `<div class="tabs">${tabs.map(([k, l]) => `<button data-tab="${k}" class="${k === tab ? "on" : ""}">${l}</button>`).join("")}</div>`;
  html += `<div class="choices">`;
  if (tab === "moves") html += movesHtml(st, me);
  if (tab === "items") html += itemsHtml(st);
  if (tab === "switch") html += switchHtml(st);
  html += `</div>`;
  html += `<button class="ai-btn ${sel && sel.kind === "ai" ? "sel" : ""}" data-ai="1">🤖 Let the game's AI decide</button>`;
  box.innerHTML = html;
}

function foesOf(st) { return st.battlers.filter(b => !b.foe && b.present); }

function movesHtml(st, me) {
  const unusable = st.unusableMoves;
  if ((unusable & 15) === 15) {
    const s = sel && sel.kind === "move";
    return `<button class="choice wide ${s ? "sel" : ""}" data-move="0" data-struggle="1"><div class="t">STRUGGLE</div><div class="s">No usable moves: it will use Struggle</div></button>`;
  }
  const foes = foesOf(st);
  let html = "";
  for (let i = 0; i < 4; i++) {
    const id = me.moves[i];
    if (!id) { html += `<button class="choice" disabled><div class="t">—</div></button>`; continue; }
    const m = moveData(id);
    const blocked = (unusable >> i) & 1;
    const effs = foes.length === 1 ? effChip(effectiveness(id, foes[0].types)) :
      foes.map(f => effChip(effectiveness(id, f.types))).filter(Boolean).join("");
    const isSel = sel && sel.kind === "move" && sel.a1 === i;
    html += `<button class="choice ${isSel ? "sel" : ""}" data-move="${i}" ${blocked ? "disabled" : ""}>
      <div class="t">${esc(m.n)}</div>
      <div class="s">${typeChip(m.t)} PP ${me.pp[i]}/${me.maxPp[i]} ${m.p ? "· POW " + (m.p === 1 ? "var." : m.p) : "· status"} ${m.a ? "· ACC " + m.a : ""} ${effs}</div>
    </button>`;
  }
  return html;
}

function itemsHtml(st) {
  let html = "", any = false;
  st.trainerItems.forEach((id, i) => {
    if (!id) return;
    any = true;
    const ok = (st.itemUsable >> i) & 1;
    const isSel = sel && sel.kind === "item" && sel.a1 === i;
    html += `<button class="choice ${isSel ? "sel" : ""}" data-item="${i}" ${ok ? "" : "disabled"}>
      <div class="t">${esc(itemName(id))}</div><div class="s">${ok ? "Use on the active Pokémon" : "Not useful right now"}</div></button>`;
  });
  if (!any) html = `<div class="note wide" style="grid-column:1/-1">This trainer has no items (left).</div>`;
  return html;
}

function switchHtml(st) {
  let html = "";
  if (st.reqType === 1 && !st.canSwitch) html += `<div class="note" style="grid-column:1/-1">⛓️ The Pokémon is trapped and can't be switched out.</div>`;
  let any = false;
  for (const p of st.party) {
    if (p.onField) continue;
    any = true;
    const ok = p.canSend && (st.reqType === 3 || st.canSwitch);
    const pct = p.maxHP ? Math.round(p.hp * 100 / p.maxHP) : 0;
    const isSel = sel && sel.kind === "switch" && sel.a1 === p.slot;
    html += `<button class="choice ${isSel ? "sel" : ""}" data-switch="${p.slot}" ${ok ? "" : "disabled"}>
      <div class="t">${esc(p.egg ? "EGG" : speciesName(p.species))} <span class="lv">Lv${p.level}</span></div>
      ${hpBar(pct)}
      <div class="s">${p.hp}/${p.maxHP} HP ${typesChips(GAME.speciesTypes[p.species])} ${statusChips(p.status, 0, 0, p.hp === 0)}</div></button>`;
  }
  if (!any) html += `<div class="note" style="grid-column:1/-1">No other Pokémon in the party.</div>`;
  return html;
}

function renderField(st) {
  const foes = st.battlers.filter(b => b.foe);
  const players = st.battlers.filter(b => !b.foe);
  let html = `<h2>Your Pokémon in battle</h2><div class="grid2">`;
  for (const b of foes) {
    const pct = b.maxHP ? Math.round(b.hp * 100 / b.maxHP) : 0;
    const side = battlerLabel(b, st);
    html += `<div class="card mon ${b.present ? "" : "dim"}">
      <div class="top"><span class="name">${esc(speciesName(b.species))}</span><span class="lv">Lv${b.level}</span>${side ? `<span class="tag">${side}</span>` : ""}${b.id === st.reqBattler && st.reqType ? `<span class="tag" style="color:var(--accent);border-color:var(--accent)">choosing</span>` : ""}</div>
      ${hpBar(pct)}
      <div class="hptext"><span>${b.hp}/${b.maxHP} HP</span><span>${b.ability ? esc(GAME.abilities[b.ability]) : ""}${b.item ? " · " + esc(itemName(b.item)) : ""}</span></div>
      <div class="chips">${typesChips(b.types)}${statusChips(b.status1, b.status2, b.status3, b.hp === 0)}${stageChips(b.stages)}</div>
    </div>`;
  }
  html += `</div><h2>Opponent: player 1</h2><div class="grid2">`;
  for (const b of players) {
    const side = battlerLabel(b, st);
    html += `<div class="card mon ${b.present ? "" : "dim"}">
      <div class="top"><span class="name">${esc(speciesName(b.species))}</span><span class="lv">Lv${b.level}</span>${side ? `<span class="tag">${side}</span>` : ""}</div>
      ${hpBar(b.hpPct)}
      <div class="hptext"><span>${b.hpPct}% HP</span><span>${b.lastMove ? "last move: " + esc(moveData(b.lastMove).n) : ""}</span></div>
      <div class="chips">${typesChips(b.types)}${statusChips(b.status1, b.status2, b.status3, b.hpPct === 0)}${stageChips(b.stages)}</div>
    </div>`;
  }
  html += `</div>`;
  const pp = st.playerParty || [];
  html += `<div class="note" style="display:flex;align-items:center;gap:10px;margin-top:10px">Player 1's party <div class="balls">${pp.map(v => `<span class="ball ${["", "ok", "stat", "fnt"][v]}"></span>`).join("")}</div></div>`;
  const w = st.weather;
  const weather = (w & 7) ? "Rain" : (w & 0x18) ? "Sandstorm" : (w & 0x60) ? "Sun" : (w & 0x80) ? "Hail" : "";
  const sideNames = (v) => [v & 1 ? "Reflect" : "", v & 2 ? "Light Screen" : "", v & 0x10 ? "Spikes" : "", v & 0x20 ? "Safeguard" : "", v & 0x100 ? "Mist" : ""].filter(Boolean).join(", ");
  const extra = [weather && "Weather: " + weather, st.sides && sideNames(st.sides[1]) && "Your side: " + sideNames(st.sides[1]), st.sides && sideNames(st.sides[0]) && "Opponent's side: " + sideNames(st.sides[0])].filter(Boolean);
  if (extra.length) html += `<div class="note">${extra.join(" · ")}</div>`;
  $("field").innerHTML = html;
}

function renderParty(st) {
  let html = `<h2>Your party</h2><div class="party">`;
  for (const p of st.party) {
    const pct = p.maxHP ? Math.round(p.hp * 100 / p.maxHP) : 0;
    const moves = p.moves.map((m, i) => m ? `<span class="mv">${esc(moveData(m).n)} ${p.pp[i]}/${p.maxPp[i]}</span>` : "").join("");
    html += `<div class="prow ${p.onField ? "field" : ""}">
      <div><b>${esc(p.egg ? "EGG" : speciesName(p.species))}</b> <span class="lv">Lv${p.level}</span> ${p.onField ? `<span class="tag">active</span>` : ""}</div>
      <div class="meta">${p.hp}/${p.maxHP} HP</div>
      <div style="grid-column:1/-1">${hpBar(pct)}</div>
      <div class="chips" style="grid-column:1/-1">${typesChips(GAME.speciesTypes[p.species])}${statusChips(p.status, 0, 0, p.hp === 0)}${p.item ? `<span class="mv">🎒 ${esc(itemName(p.item))}</span>` : ""}</div>
      <div class="moves">${moves}</div></div>`;
  }
  html += `</div>`;
  $("partyBox").innerHTML = html;
}

function selectionLabel() {
  if (!sel || !state) return "";
  const me = state.battlers.find(b => b.id === state.reqBattler);
  if (sel.kind === "ai") return "Let <b>the AI</b> decide";
  if (sel.kind === "move") {
    if (sel.struggle) return "Use <b>Struggle</b>";
    const m = moveData(me.moves[sel.a1]);
    const t = state.battlers.find(b => b.id === sel.a2);
    const target = state.battlersCount === 4 && sel.pickedTarget && t ? ` on <b>${esc(speciesName(t.species))}</b>` : "";
    return `Use <b>${esc(m.n)}</b>${target}`;
  }
  if (sel.kind === "item") return `Use <b>${esc(itemName(state.trainerItems[sel.a1]))}</b>`;
  if (sel.kind === "switch") {
    const p = state.party.find(x => x.slot === sel.a1);
    return `Send out <b>${esc(speciesName(p.species))}</b>`;
  }
  return "";
}
function updateConfirm() {
  if (sel && state && state.reqType) {
    $("confirmWhat").innerHTML = selectionLabel();
    $("confirm").classList.add("show");
  } else hideConfirm();
}
function hideConfirm() { $("confirm").classList.remove("show"); }

function chooseTarget(moveSlot) {
  const st = state, me = st.battlers.find(b => b.id === st.reqBattler);
  const m = moveData(me.moves[moveSlot]);
  const options = st.battlers.filter(b => b.present && b.id !== me.id);
  const root = $("modalRoot");
  root.innerHTML = `<div class="modal-bg" id="mbg"><div class="modal"><h3>Use ${esc(m.n)} on whom?</h3><div class="choices">
    ${options.map(b => `<button class="choice" data-target="${b.id}"><div class="t">${esc(speciesName(b.species))}</div>
      <div class="s">${b.foe ? "your partner" : "opponent, " + battlerLabel(b, st)} ${effChip(effectiveness(me.moves[moveSlot], b.types))}</div></button>`).join("")}
    </div><button class="ai-btn" id="mclose">Cancel</button></div></div>`;
  $("mbg").onclick = (e) => {
    const t = e.target.closest("[data-target]");
    if (t) { sel = { kind: "move", a1: moveSlot, a2: +t.dataset.target, pickedTarget: true }; root.innerHTML = ""; render(); }
    else if (e.target.id === "mbg" || e.target.id === "mclose") root.innerHTML = "";
  };
}

document.addEventListener("click", (e) => {
  const b = e.target.closest("button");
  if (!b || b.disabled || !state) return;
  if (b.dataset.tab) { tab = b.dataset.tab; render(); return; }
  if (b.dataset.ai) { sel = { kind: "ai" }; render(); return; }
  if (b.dataset.move !== undefined) {
    const slot = +b.dataset.move;
    if (b.dataset.struggle) { sel = { kind: "move", a1: 0, a2: 0, struggle: true }; render(); return; }
    const me = state.battlers.find(x => x.id === state.reqBattler);
    const m = moveData(me.moves[slot]);
    const needsTarget = state.battlersCount === 4 && m.tg === TARGET_SELECTED &&
      state.battlers.filter(x => x.present && x.id !== me.id).length > 1;
    if (needsTarget) { chooseTarget(slot); return; }
    const foe = state.battlers.find(x => !x.foe && x.present);
    sel = { kind: "move", a1: slot, a2: foe ? foe.id : 0 };
    render(); return;
  }
  if (b.dataset.item !== undefined) { sel = { kind: "item", a1: +b.dataset.item }; render(); return; }
  if (b.dataset.switch !== undefined) { sel = { kind: "switch", a1: +b.dataset.switch }; render(); return; }
});
$("sendBtn").onclick = send;
$("cancelBtn").onclick = () => { sel = null; render(); };
$("autoAi").onchange = async (e) => {
  try { await api("auto", "on=" + (e.target.checked ? 1 : 0)); } catch (err) { showToast("Failed"); }
};

let toastTimer = null;
function showToast(msg) {
  const t = $("toast");
  t.textContent = msg;
  t.classList.remove("hidden");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.add("hidden"), 3500);
}

let audioCtx = null;
function notifyTurn() {
  if (navigator.vibrate) navigator.vibrate([120, 60, 120]);
  try {
    audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
    const o = audioCtx.createOscillator(), g = audioCtx.createGain();
    o.type = "square"; o.frequency.value = 880;
    g.gain.setValueAtTime(.05, audioCtx.currentTime);
    g.gain.exponentialRampToValueAtTime(.0001, audioCtx.currentTime + .25);
    o.connect(g); g.connect(audioCtx.destination); o.start(); o.stop(audioCtx.currentTime + .26);
  } catch (e) {}
  if (document.hidden) document.title = "⚡ Your turn! · Rival at the Wheel";
}
document.addEventListener("visibilitychange", () => { if (!document.hidden) document.title = "Rival at the Wheel"; });

// ------------------------------------------------------------ login
function store(k, v) { try { v === null ? localStorage.removeItem(k) : localStorage.setItem(k, v); } catch (e) {} }
function load(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }

async function tryLogin(c) {
  code = (c || "").trim().toUpperCase();
  if (!code) return false;
  try {
    const r = await fetch(`api/state?k=${encodeURIComponent(code)}&t=${Date.now()}`);
    if (r.status === 401) return false;
    store("rt_code", code);
    $("login").classList.add("hidden");
    $("app").classList.remove("hidden");
    onState(await r.json());
    poll();
    return true;
  } catch (e) {
    $("loginErr").textContent = "The server isn't responding. Does player 1 have mGBA and the tunnel running?";
    return false;
  }
}
function logout(msg) {
  store("rt_code", null);
  $("app").classList.add("hidden");
  $("login").classList.remove("hidden");
  $("loginErr").textContent = msg || "";
}
$("codeBtn").onclick = async () => { if (!(await tryLogin($("codeInput").value)) && !$("loginErr").textContent) $("loginErr").textContent = "Wrong code."; };
$("codeInput").addEventListener("keydown", (e) => { if (e.key === "Enter") $("codeBtn").click(); });

(async () => {
  const fromUrl = new URLSearchParams(location.search).get("k");
  const saved = fromUrl || load("rt_code");
  if (saved && await tryLogin(saved)) return;
  $("login").classList.remove("hidden");
  if (saved && !$("loginErr").textContent) $("loginErr").textContent = "The saved code is no longer valid.";
})();
</script>
</body>
</html>

]==========]

-- ---------------------------------------------------------------------------
local build = nil
local server = nil
local clients = {}
local autoAI = AUTO_AI
local lastSeq = -1
local lastP2Seen = 0
local p2Announced = false
local nextClientId = 1

local function log(msg) console:log("[Rival at the Wheel] " .. msg) end
local function logError(msg) console:error("[Rival at the Wheel] " .. msg) end

local function randomCode()
  local chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
  math.randomseed(os.time() + math.floor(os.clock() * 100000))
  local out = {}
  for i = 1, 6 do
    local n = math.random(1, #chars)
    out[i] = chars:sub(n, n)
  end
  return table.concat(out)
end

if CODE == nil or CODE == "" then CODE = randomCode() end
CODE = string.upper(CODE)

-- ------------------------------ JSON ---------------------------------------
local ARRAY = {}
local function arr(t) return setmetatable(t or {}, ARRAY) end

local function jsonString(s)
  s = s:gsub('[%c"\\]', function(c)
    if c == '"' then return '\\"' end
    if c == '\\' then return '\\\\' end
    if c == '\n' then return '\\n' end
    return string.format('\\u%04x', c:byte())
  end)
  return '"' .. s .. '"'
end

local function toJson(v)
  local t = type(v)
  if t == "nil" then return "null" end
  if t == "boolean" then return v and "true" or "false" end
  if t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return "null" end
    if math.type(v) == "integer" then return tostring(v) end
    return string.format("%.4f", v)
  end
  if t == "string" then return jsonString(v) end
  if t == "table" then
    local parts = {}
    if getmetatable(v) == ARRAY or v[1] ~= nil then
      for i = 1, #v do parts[#parts + 1] = toJson(v[i]) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    for k, val in pairs(v) do
      parts[#parts + 1] = jsonString(tostring(k)) .. ":" .. toJson(val)
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "null"
end

-- ------------------------------ GAME MEMORY --------------------------------
local function detectBuild()
  if not emu then return nil end
  for _, b in ipairs(BUILDS) do
    local ok, s = pcall(function() return emu:readRange(b.sig, #SIGNATURE) end)
    if ok and s == SIGNATURE then return b end
  end
  return nil
end

local function u8(s, o) return s:byte(o + 1) end
local function u16(s, o) return (string.unpack("<I2", s, o + 1)) end
local function u32(s, o) return (string.unpack("<I4", s, o + 1)) end
local function s8(s, o) return (string.unpack("<i1", s, o + 1)) end

local function decodeText(s, o, n)
  local out = {}
  for i = 0, n - 1 do
    local b = s:byte(o + i + 1)
    if b == nil or b == 0xFF then break end
    out[#out + 1] = CHARMAP[b] or "?"
  end
  return (table.concat(out):gsub("%s+$", ""))
end

local function readMailbox()
  if not build then return nil end
  local ok, s = pcall(function() return emu:readRange(build.rc, MAILBOX_SIZE) end)
  if not ok or not s or #s < MAILBOX_SIZE then return nil end
  if u32(s, 0) ~= REMOTE_MAGIC then return nil end
  return s
end

local function list4(s, o, size, reader)
  local t = arr()
  for i = 0, 3 do t[#t + 1] = reader(s, o + i * size) end
  return t
end

local function parseState(s)
  local st = {}
  st.reqSeq = u8(s, 0x04)
  st.reqType = u8(s, 0x05)
  st.reqBattler = u8(s, 0x06)
  st.respSeq = u8(s, 0x07)
  st.lastError = u8(s, 0x0B)
  st.battleType = u32(s, 0x0C)
  st.trainerId = u16(s, 0x10)
  st.battlersCount = u8(s, 0x12)
  st.inBattle = u8(s, 0x13) ~= 0
  st.trainerItems = list4(s, 0x14, 2, u16)
  st.trainerClass = decodeText(s, 0x1C, 14)
  st.trainerName = decodeText(s, 0x2A, 14)
  st.unusableMoves = u8(s, 0x38)
  st.canSwitch = u8(s, 0x39) ~= 0
  st.itemUsable = u8(s, 0x3A)
  st.switchable = u8(s, 0x3B)
  st.turn = u8(s, 0x3C)
  st.absent = u8(s, 0x3D)
  st.weather = u16(s, 0x3E)
  st.sides = arr({ u16(s, 0x40), u16(s, 0x42) })

  st.battlers = arr()
  for i = 0, 3 do
    local o = 0x48 + i * 0x40
    local species = u16(s, o)
    if i < st.battlersCount and species ~= 0 then
      local isFoe = (i % 2) == 1
      local b = {
        id = i,
        foe = isFoe,
        species = species,
        nickname = decodeText(s, o + 0x30, 12),
        level = u8(s, o + 0x28),
        present = u8(s, o + 0x29) ~= 0,
        types = arr({ u8(s, o + 0x2A), u8(s, o + 0x2B) }),
        status1 = u32(s, o + 0x08),
        status2 = u32(s, o + 0x0C),
        status3 = u32(s, o + 0x3C),
        lastMove = u16(s, o + 0x2E),
        stages = arr(),
      }
      for k = 0, 7 do b.stages[#b.stages + 1] = s8(s, o + 0x20 + k) end
      local hp, maxHP = u16(s, o + 0x02), u16(s, o + 0x04)
      if isFoe then
        b.hp = hp
        b.maxHP = maxHP
        b.item = u16(s, o + 0x06)
        b.ability = u8(s, o + 0x2C)
        b.partyIndex = u8(s, o + 0x2D)
        b.moves = list4(s, o + 0x10, 2, u16)
        b.pp = list4(s, o + 0x18, 1, u8)
        b.maxPp = list4(s, o + 0x1C, 1, u8)
      else
        -- For player 1, only what the game itself would show
        b.hpPct = maxHP > 0 and math.floor(hp * 100 / maxHP + 0.5) or 0
        if hp > 0 and b.hpPct == 0 then b.hpPct = 1 end
      end
      st.battlers[#st.battlers + 1] = b
    end
  end

  st.party = arr()
  for i = 0, 5 do
    local o = 0x148 + i * 0x2C
    local flags = u8(s, o + 0x19)
    if (flags & 1) ~= 0 then
      st.party[#st.party + 1] = {
        slot = i,
        species = u16(s, o),
        nickname = decodeText(s, o + 0x1A, 12),
        hp = u16(s, o + 0x02),
        maxHP = u16(s, o + 0x04),
        item = u16(s, o + 0x06),
        status = u32(s, o + 0x08),
        moves = list4(s, o + 0x0C, 2, u16),
        pp = list4(s, o + 0x14, 1, u8),
        maxPp = list4(s, o + 0x26, 1, u8),
        level = u8(s, o + 0x18),
        onField = (flags & 2) ~= 0,
        canSend = (flags & 4) ~= 0,
        egg = (flags & 8) ~= 0,
      }
    end
  end

  st.playerParty = arr()
  for i = 0, 5 do st.playerParty[#st.playerParty + 1] = u8(s, 0x250 + i) end
  return st
end

local function writeResponse(seq, rtype, a1, a2)
  local s = readMailbox()
  if not s then return false, "No battle in progress" end
  local reqSeq, reqType = u8(s, 0x04), u8(s, 0x05)
  if reqType == 0 then return false, "It's not your turn" end
  if reqSeq ~= seq then return false, "Request expired, try again" end
  if u8(s, 0x07) == reqSeq then return false, "Choice already sent" end
  emu:write8(build.rc + 0x08, rtype)
  emu:write8(build.rc + 0x09, a1 & 0xFF)
  emu:write8(build.rc + 0x0A, a2 & 0xFF)
  emu:write8(build.rc + 0x07, reqSeq)
  return true
end

-- ------------------------------- WEB SERVER ---------------------------------
local STATUS_TEXT = { [200] = "OK", [400] = "Bad Request", [401] = "Unauthorized", [404] = "Not Found" }

local function httpResponse(code, ctype, body)
  return table.concat({
    "HTTP/1.1 ", code, " ", STATUS_TEXT[code] or "OK", "\r\n",
    "Content-Type: ", ctype, "\r\n",
    "Content-Length: ", #body, "\r\n",
    "Cache-Control: no-store\r\n",
    "Connection: close\r\n\r\n",
    body,
  })
end

local function jsonResponse(code, t) return httpResponse(code, "application/json; charset=utf-8", toJson(t)) end

local function parseQuery(q)
  local t = {}
  for k, v in string.gmatch(q or "", "([^&=]+)=([^&]*)") do
    v = v:gsub("+", " "):gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
    t[k] = v
  end
  return t
end

local function buildState()
  local st = { ok = true, auto = autoAI, version = 1 }
  if not emu then
    st.game = "none"
    return st
  end
  if not build then build = detectBuild() end
  if not build then
    st.game = "wrong"
    return st
  end
  st.game = build.name
  local s = readMailbox()
  if not s then
    st.inBattle = false
    return st
  end
  local parsed = parseState(s)
  for k, v in pairs(parsed) do st[k] = v end
  if parsed.reqType ~= 0 and parsed.respSeq == parsed.reqSeq then
    st.reqType = 0 -- answer already sent, being processed
  end
  return st
end

local function handleRequest(method, path, body)
  local route, query = path:match("^([^?]*)%??(.*)$")
  local q = parseQuery(query)
  if route == "/" or route == "/index.html" then
    return httpResponse(200, "text/html; charset=utf-8", HTML)
  end
  if route == "/favicon.ico" then
    return httpResponse(404, "text/plain", "")
  end
  if route:sub(1, 5) == "/api/" then
    local key = string.upper(q.k or "")
    if key ~= CODE then
      return jsonResponse(401, { ok = false, error = "Wrong code" })
    end
    lastP2Seen = os.time()
    if not p2Announced then
      p2Announced = true
      log("Player 2 has connected!")
    end
    if route == "/api/state" then
      return jsonResponse(200, buildState())
    end
    if route == "/api/choose" and method == "POST" then
      local f = parseQuery(body)
      local seq, rtype = tonumber(f.seq), tonumber(f.type)
      local a1, a2 = tonumber(f.a1) or 0, tonumber(f.a2) or 0
      if not seq or not rtype or rtype < 1 or rtype > 4 then
        return jsonResponse(400, { ok = false, error = "Invalid request" })
      end
      if not build then return jsonResponse(200, { ok = false, error = "Game not ready" }) end
      local ok, err = writeResponse(seq, rtype, a1, a2)
      return jsonResponse(200, { ok = ok, error = err })
    end
    if route == "/api/auto" and method == "POST" then
      local f = parseQuery(body)
      autoAI = f.on == "1"
      log(autoAI and "Auto AI turned ON by player 2" or "Auto AI turned off: player 2 decides")
      return jsonResponse(200, { ok = true, auto = autoAI })
    end
  end
  return httpResponse(404, "text/plain; charset=utf-8", "Page not found")
end

local function closeClient(c)
  if clients[c.id] then
    clients[c.id] = nil
    pcall(function() c.sock:close() end)
  end
end

local function tryHandle(c)
  if c.out then return end
  local headerEnd = c.buf:find("\r\n\r\n", 1, true)
  if not headerEnd then
    if #c.buf > 16384 then closeClient(c) end
    return
  end
  local header = c.buf:sub(1, headerEnd - 1)
  local method, path = header:match("^(%u+)%s+(%S+)")
  if not method then closeClient(c); return end
  local len = tonumber(header:match("[Cc]ontent%-[Ll]ength:%s*(%d+)")) or 0
  if len > 4096 then closeClient(c); return end
  local body = c.buf:sub(headerEnd + 4)
  if #body < len then return end
  body = body:sub(1, len)
  local ok, resp = pcall(handleRequest, method, path, body)
  if not ok then
    logError("internal error: " .. tostring(resp))
    resp = httpResponse(400, "text/plain", "Error")
  end
  c.out = resp
end

local function onClientData(c)
  while clients[c.id] do
    local data, err = c.sock:receive(4096)
    if data then
      c.buf = c.buf .. data
      c.last = os.time()
    else
      if err ~= socket.ERRORS.AGAIN then
        if not c.out then closeClient(c) end
      end
      break
    end
  end
  if clients[c.id] then tryHandle(c) end
end

local function flushClients()
  local now = os.time()
  for _, c in pairs(clients) do
    if c.out then
      if #c.out == 0 then
        closeClient(c)
      else
        local n, err = c.sock:send(c.out)
        if n and n > 0 then
          c.out = c.out:sub(n + 1)
          c.last = now
          if #c.out == 0 then closeClient(c) end
        elseif err and err ~= socket.ERRORS.AGAIN then
          closeClient(c)
        end
      end
    end
    if clients[c.id] and now - c.last > 15 then closeClient(c) end
  end
end

local function onAccept()
  while true do
    local sock, err = server:accept()
    if not sock then return end
    local c = { id = nextClientId, sock = sock, buf = "", last = os.time() }
    nextClientId = nextClientId + 1
    clients[c.id] = c
    sock:add("received", function() onClientData(c) end)
    sock:add("error", function() closeClient(c) end)
  end
end

local function startServer()
  local port = PORT
  for attempt = 0, 10 do
    local s, err = socket.bind(LOCAL_ONLY and "127.0.0.1" or nil, port + attempt)
    if s then
      local ok, lerr = s:listen(16)
      if ok then
        server = s
        server:add("received", onAccept)
        return port + attempt
      end
      s:close()
      logError("listen failed on port " .. (port + attempt) .. ": " .. tostring(lerr))
    elseif err ~= socket.ERRORS.ADDRESS_IN_USE then
      logError("cannot open port " .. (port + attempt) .. ": " .. tostring(err))
      return nil
    end
  end
  return nil
end

-- ------------------------------- MAIN LOOP ----------------------------------
local REQ_NAMES = { [1] = "choosing an action", [2] = "choosing a move", [3] = "choosing the next Pokemon" }

local function onFrame()
  flushClients()
  if not emu then return end
  if not build then
    build = detectBuild()
    if build then log("Patch detected: " .. build.name) end
    return
  end
  local s = readMailbox()
  if not s then return end
  local reqSeq, reqType, respSeq = u8(s, 0x04), u8(s, 0x05), u8(s, 0x07)
  if reqType ~= 0 and respSeq ~= reqSeq then
    if autoAI then
      writeResponse(reqSeq, 4, 0, 0)
      return
    end
    if reqSeq ~= lastSeq then
      lastSeq = reqSeq
      local err = u8(s, 0x0B)
      if err ~= 0 then
        log("Invalid choice, player 2 must try again (" .. (REQ_NAMES[reqType] or "?") .. ")")
      else
        log("Waiting for player 2: " .. (REQ_NAMES[reqType] or "?"))
      end
    end
  end
end

local function onStart()
  build = detectBuild()
  if build then
    log("Patch detected: " .. build.name)
  elseif emu then
    logError("This ROM doesn't have the Rival at the Wheel patch (or it's a different build).")
  end
end

local port = startServer()
console:log("==============================================")
console:log("           RIVAL AT THE WHEEL - mGBA")
console:log("==============================================")
if port then
  log("Server started on port " .. port)
  log("CODE for player 2:  " .. CODE)
  log("Test locally:  http://127.0.0.1:" .. port .. "/?k=" .. CODE)
  log("For internet play, run the tunnel (start_tunnel.bat) and send player 2")
  log("the https://....trycloudflare.com link together with the code.")
else
  logError("Couldn't start the web server. Change PORT at the top of the script.")
end

callbacks:add("frame", onFrame)
callbacks:add("start", onStart)
if emu then onStart() end
