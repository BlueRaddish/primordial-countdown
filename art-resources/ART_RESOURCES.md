# Open-source art & audio resources for Primordial Countdown

Eleven downloaded packs, chosen against what this game actually is: a **640×360 2D pixel
sidescroller roguelike in Godot 4** with an animated player, three enemy movement patterns,
a 2×-size stage boss, ~15 skills that need icons and VFX, seven traits with three stages
each, and an arena of generated tiles.

Every pack in this folder was downloaded from its original source, verified to open, and
its contents listed below are what is actually inside the archive — not what the store page
claims. Total: **112 MB** (99 MB of that is the music in pack 11).

Nothing here has been added to the project's own `assets/` tree and no existing file was
touched. This folder is a staging area — copy out only what you use.

---

## The gaps these fill

The project currently ships Kenney Pixel Platformer tiles plus eight untouched player
tiles. These directories are **empty**: `assets/sprites/enemies/`, `assets/sprites/bosses/`,
`assets/sprites/ui/`, `assets/fonts/`, `assets/audio/sfx/`, `assets/audio/music/`.

| Need | Pack |
| --- | --- |
| Animated player (idle/run/hit) | 1, 2 |
| Walker / Lunger / Hopper enemies | 1, 2 |
| Stage boss at 2× minion size | 1 (`big_demon` is literally 32×36 vs 16×16), 2 |
| Arena tiles beyond the current set | 3, 4 |
| Parallax background | 2, 4 |
| Skill VFX (13 skills fire an AoE or a dash) | 5 |
| HUD panels, bars, buttons | 6 |
| Trait + skill icons (7 traits × 3 stages, ~18 skills) | 8, 6 |
| Pixel font for the year counter / HUD | 7 |
| Hit, swing, damage, UI SFX | 9 |
| Devolution / skill-unlock / death stingers | 10 |
| Background music | 11 |

---

## Summary

| # | Pack | Author | License | Size | Best for |
| --- | --- | --- | --- | --- | --- |
| 1 | 16×16 DungeonTileset II v1.7 | 0x72 | CC0 | 408 KB | Enemies, boss, player |
| 2 | Gothicvania Patreon Collection | Luis Zuno (ansimuz) | Public domain / CC0 | 3.9 MB | Hero, monsters, parallax, tilesets |
| 3 | Pixel Platformer — Industrial Expansion | Kenney | CC0 | 164 KB | Arena tiles (style-matched) |
| 4 | 2D Platformer Volcano Pack 1.1 | Tio Aimar | CC0 | 820 KB | Primordial/volcanic theme |
| 5 | Free Pixel Effects Pack + sword slash | CodeManu, tbbk | see note | 1.5 MB | Skill VFX, impacts |
| 6 | UI Pack — Pixel Adventure | Kenney | CC0 | 312 KB | HUD frames, bars, buttons |
| 7 | Kenney Fonts | Kenney | CC0 | 60 KB | HUD / counter typography |
| 8 | game-icons.net (4180 SVG) | 36 artists | CC BY 3.0 | 4.0 MB | Trait + skill icons |
| 9 | Impact / RPG / UI Audio | Kenney | CC0 | 2.1 MB | SFX |
| 10 | Music Jingles | Kenney | CC0 | 1.2 MB | Event stingers |
| 11 | Fantasy Ambience + Drum Loops | North Fantasy Music | CC BY 4.0 | 99 MB | Music |

Nine of eleven are CC0 or public domain — no attribution obligation at all. Only packs 8
and 11 (and arguably 5) legally require credit.

---

## 1. `01_0x72_dungeon_tileset_ii/` — the single best fit here

**0x72_DungeonTilesetII_v1.7.zip** · 408 KB · 754 files · CC0 ·
<https://0x72.itch.io/dungeontileset-ii>

The strongest match in this whole set. 16×16 side-view characters, every one with **idle and
run animations already split into individual frames** (`frames/` directory) *and* packed into
one atlas with a `tile_list_v1.7` coordinate file — so you can either load loose frames into
`AnimatedSprite2D` or slice the atlas programmatically.

Playable/humanoid bodies: knight, elf, wizard, lizard, dwarf (each m/f, each with a **hit**
frame as well as idle/run). Monsters: goblin, imp, chort, skeleton, orc warrior, orc shaman,
masked orc, necromancer, wogol, swampy, muddy, zombie (tiny/normal/big/ice), slug, tiny slug,
angel, pumpkin dude. Plus **ogre** and **big demon**.

Why it lines up with your systems:

- **`big_demon` is 32×36 against the 16×16 minions** — the README's "stage boss: twice the
  size" is satisfiable without scaling a sprite up and blurring it.
- Three visually distinct silhouette classes map cleanly onto Walker / Lunger / Hopper —
  e.g. orc warrior walks, chort lunges, imp/slug hops.
- Separate `hit` frames exist for the humanoids, useful for the damage flash.
- Also ships weapons, chests, coins, floor spikes, and full floor/wall atlases
  (`atlas_floor-16x16.png`, `atlas_walls_low-16x16.png`, `atlas_walls_high-16x32.png`).

The one caveat: it is a *dungeon* set, so the palette reads stone-and-torch rather than
primordial. Pack 4's volcanic background and Godot's `CanvasModulate` (which you already use
for the Eyes trait dimming) go a long way toward re-tinting it.

## 2. `02_ansimuz_gothicvania_collection/` — the volume pick

**gothicvania_patreon_collection.zip** · 3.9 MB · 421 files · public domain, credit
appreciated · <https://opengameart.org/content/gothicvania-patreons-collection>

Thirteen of Luis Zuno's 2016–17 packs in one archive, each with PNG spritesheets, individual
PNG frames, animated GIF previews (handy for judging timing before you import), and layered
PSDs:

`Gothic-hero-Files` · `Gothic-hero-p2-Files` (adds climb, crouch, crouch-slash, hurt and
**jump-attack** sprite folders — jump-attack is close to your Wing Slam) · `demon-Files` ·
`Hell-Beast-Files` (with and without outline stroke) · `Hell-Hound-Files` · `Ghost-Files` ·
`Fire-Skull-Files` · `Nightmare-Files` · `wolf-runing-cycle` · `Gothic-Horror-Files` ·
`Gothic-Castle-Files` · `Old-dark-Castle-tileset-Files` · `night-town-background-files`
(seamless parallax layers).

These are larger and more detailed than 16×16 — a hero of roughly 32–48 px. At 640×360 that
is still a sensible player size, but **do not mix these with pack 1 at the same on-screen
scale**; pick one as your character language. The wolf run cycle and hell hound are excellent
Walker/Lunger candidates; the fire skull and ghost float, which suits a Hopper variant.

Licence text bundled as `public-license.txt`: *"Public domain and free to use on whatever you
want, personal or commercial. Credit is not required but appreciated."*

## 3. `03_kenney_pixel_platformer_industrial/` — the safe, style-matched tiles

**kenney_pixel-platformer-industrial-expansion.zip** · 164 KB · 125 files · CC0 ·
<https://kenney.nl/assets/pixel-platformer-industrial-expansion>

A direct expansion of the **Pixel Platformer pack the project already uses**, so it drops in
with zero style clash — same 18×18 grid, same palette. Ships loose `Tiles/`, a packed
`Tilemap/` sheet, `Tilesheet.txt`, and a preview. This is the lowest-risk way to give
`arena_renderer.gd` more tile variety (pipes, girders, machinery, hazard stripes) without
re-arting the arena.

Kenney's sibling expansions (farm, blocks) use the same URL pattern if you want more later.

## 4. `04_volcano_platformer_tioaimar/` — the thematic one

**2D Platformer Volcano Pack 1.1.zip** · 820 KB · 70 files · CC0, credit optional ·
<https://opengameart.org/content/2d-platformer-volcano-pack-11>

The closest thing here to *primordial*: molten ground, ash, lava. Contains
`PNG/bg_volcano.png` plus **six separated parallax layers** in `bg_volcano_layers/`
(`bg_volcano_1..6.png`) and ~30 ground/prop tiles. Version 1.1 added a grey-ash ground
variant specifically so walkable surfaces read differently from decorative lava — exactly the
readability problem a platformer arena has.

Six discrete layers is more than enough for a convincing depth effect behind the arena, and a
lava-lit backdrop gives the Eyes-trait dimming something dramatic to dim.

## 5. `05_vfx_extras/` — skill VFX

**codemanu_free_pixel_effects_pack.zip** · 1.5 MB · 20 spritesheets ·
<https://codemanu.itch.io/pixelart-effect-pack>
**pixel_art_sword_slash_sprites.png** · 4 KB · CC0 · by tbbk ·
<https://opengameart.org/content/pixel-art-sword-slash-effect>

Twenty 100×100 px effect spritesheets made with Pixel FX Designer, and the names map
remarkably well onto your skill list:

| Sheet | Suggested use |
| --- | --- |
| `10_weaponhit` | normal melee impact, Lunge Strike arrival |
| `6_flamelash`, `11_fire`, `9_brightfire` | Thornskin, Adrenal Surge |
| `13_vortex`, `7_firespin` | Echo Sense pulse, Wing Slam landing |
| `8_protectioncircle` | Curl, Hide damage reduction |
| `19_freezing`, `18_midnight` | Blind Fury, Apex Instinct |
| `4_casting`, `1_magicspell`, `17_felspell` | generic skill cast tell |
| `3_bluefire`, `12_nebula`, `14_phantom` | buff auras |

The separate 64×47 sword-slash sheet is the cheapest possible win for the basic attack arc.

**Licence note, read this one:** the itch.io page tags the pack **CC BY 4.0**, but the
bundled `README.txt` says *"This is a public domain asset… No credit required."* The two
disagree. Crediting CodeManu satisfies both readings, costs one line, and removes the
question — do that.

## 6. `06_kenney_ui_pack_pixel_adventure/` — HUD

**kenney_ui-pack-pixel-adventure.zip** · 312 KB · 533 files · CC0 ·
<https://kenney.nl/assets/ui-pack-pixel-adventure>

Pixel-native UI, which matters: Kenney's better-known vector UI packs look wrong at 640×360.
508 individual tiles in four variants — small/large tiles × thin/thick outline — plus packed
tilesheets for each. Panels, 9-slice frames, bars, buttons, checkboxes, sliders, cursors.

Directly useful for the character screen (`C`), the devolution choice popup, the accept/decline
evolved-trait prompt, the boss health bar, and the death screen — all of which are real
screens in the game today. Godot's `NinePatchRect` handles the frame tiles natively.

## 7. `07_kenney_fonts/` — typography

**kenney_kenney-fonts.zip** · 60 KB · 12 TTFs · CC0 ·
<https://kenney.nl/assets/kenney-fonts>

`Kenney Pixel`, `Kenney Pixel Square`, `Kenney Mini`, `Kenney Mini Square`,
`Kenney Mini Square Mono`, `Kenney Blocks`, `Kenney High`, `Kenney High Square`,
`Kenney Future`, `Kenney Future Narrow`, `Kenney Rocket`, `Kenney Rocket Square`.

**Kenney Mini Square Mono is the one to reach for on the year counter.** A monospaced font
stops the countdown from jittering horizontally as digits change — with a 2000→0 number
ticking down constantly on screen, a proportional font visibly wobbles. It also makes the
Head-trait states (`~25`, `??`) occupy stable width.

Set these to **Antialiased: Disabled** in the Godot import tab and use whole-number font
sizes or they will blur against your pixel art.

## 8. `08_game_icons_net/` — trait & skill icons

**game-icons.net.svg.zip** · 4.0 MB · **4180 SVGs** by 36 artists · **CC BY 3.0** ·
<https://game-icons.net/>

The standard answer for ability iconography, and this game needs a *lot* of it: 18-plus
skills, seven traits at three stages each, plus two evolved traits. Hand-drawing that is days
of work; this covers essentially all of it. There are direct hits for every trait — lungs,
eye, skin, stomach, arm, leg, brain — and for the skills (wing, thorns, fangs, dash, pounce,
kick, echo/sonar, adrenaline).

Downloaded as white-on-black 1×1 SVGs, organised `icons/<colour>/<colour>/1x1/<artist>/<name>.svg`.
Being vector, they rasterise crisply to whatever HUD size you want — export at your target
px size rather than scaling at runtime.

**This pack does require attribution**, per artist where practical. `icons/license.txt` is
included in the archive; the required form is *"Icons made by [author]. Available on
https://game-icons.net"*.

## 9. `09_kenney_audio/` — SFX

Three CC0 packs, 246 files total, all OGG + WAV:

- **kenney_impact-sounds.zip** (784 KB, 134 files) — the core combat layer. Impacts across
  materials and weights; the heavy variants suit the boss ground slam.
- **kenney_rpg-audio.zip** (944 KB, 56 files) — swings, hits, foot steps, creature noises,
  handle/inventory sounds.
- **kenney_ui-audio.zip** (404 KB, 56 files) — clicks, confirms, cancels, toggles for the
  character screen and devolution choices.

<https://kenney.nl/assets/impact-sounds> · <https://kenney.nl/assets/rpg-audio> ·
<https://kenney.nl/assets/ui-audio>

## 10. `10_kenney_music_jingles/` — event stingers

**kenney_music-jingles.zip** · 1.2 MB · 95 files · CC0 ·
<https://kenney.nl/assets/music-jingles>

Short musical stings, not loops. This game is unusually well suited to them because it has
so many discrete, time-freezing events: each of the 14 devolution steps, every skill unlock,
each evolved-trait offer, boss spawn, death. A distinct sting per event category makes the
fall legible by ear.

## 11. `11_fantasy_ambience_music/` — background music

**CC BY 4.0** · North Fantasy Music ·
<https://opengameart.org/content/fantasy-music-and-drum-loops-pack>

- `fantasyambience.zip` (69 MB, 7 tracks): `Dark_and_Mysterious`, `Nightwatch`,
  `Storm_Incoming`, `Sacred_Guardians`, `New_Dawn`, `Temple_of_Light`,
  `Soft_Strings_and_Flutes`.
- `fantasyambience_drumloops.zip` (30 MB, 5 loops): `Aggressive_Drum_Loop`, `Fast_Drum_Loop`,
  `Ominous_Drumbeat_Loop`, `Aftermath_Drumbeat_Loop`, `Dark…`.

44.1 kHz 16-bit stereo WAV, mostly dark and mysterious in tone. The **drum loops are the
interesting part for this game**: they are designed to layer independently over the ambience,
so you can raise the drums as the year counter falls and have the soundtrack itself devolve
toward percussion. `Dark_and_Mysterious` under `Ominous_Drumbeat_Loop` is a plausible default
bed; `Aggressive_Drum_Loop` for boss waves.

**These are raw WAV and account for 99 MB of this folder's 112 MB.** Convert whatever you keep
to OGG Vorbis before it goes anywhere near `assets/audio/music/` — expect roughly a 10× drop.
A third archive, `fantasyambience_extended.zip` (69 MB), exists at the same page; not
downloaded, since the base set plus loops already exceeds what one game needs.

---

## Recommended combination

Two coherent directions rather than a mix:

**A — tight and pixel-pure (recommended).** Pack 1 for every character and the boss, pack 3
for arena tiles, pack 4 for the parallax backdrop, 5 for VFX, 6/7/8 for UI. One 16×16
language throughout, reads perfectly at 640×360, and `big_demon` gives you the 2× boss for
free. Fastest route to a game that looks deliberate.

**B — larger, moodier characters.** Pack 2's hero and beasts as the character layer, still on
pack 3/4 environments. More frames per animation and a stronger silhouette, but the hero is
~3× the height of a pack-1 character, so the arena's 27 px steps and 68 px jump arc — both
tuned in `arena_renderer.gd` against the current sprite scale — would need revisiting. Worth
it only if you want the game to look like Gothicvania.

Either way, keep pack 8 for icons and packs 9–11 for audio; those are orthogonal to the
character choice.

## Godot 4 import notes

- Pixel art: import tab → **Filter: Off**, **Mipmaps: Off**. The project already renders at a
  fixed 640×360 with `canvas_items` stretch, so any filtering shows up immediately as mush.
- Fonts: **Antialiased: Disabled**, integer font sizes only.
- Pack 1's `frames/` folder loads straight into `SpriteFrames`; alternatively slice the atlas
  using the bundled `tile_list_v1.7` (name, x, y, w, h per line) if you prefer one texture.
- Pack 2's PSDs are for editing only — import the PNGs, not the PSDs, or Godot will choke.
- Convert pack 11's WAVs to OGG before import; Godot will happily embed 69 MB of WAV otherwise.
- `.import` files are generated per asset, so add assets in batches and let Godot settle
  between them.

## Attribution

Nine packs need nothing. For the ones that do, this is ready to paste into the README's
existing Credits table:

```markdown
| 16x16 DungeonTileset II | 0x72 | CC0 1.0 | https://0x72.itch.io/dungeontileset-ii |
| Gothicvania Collection | Luis Zuno (ansimuz) | Public domain | https://opengameart.org/content/gothicvania-patreons-collection |
| Pixel Platformer Industrial | Kenney | CC0 1.0 | https://kenney.nl/assets/pixel-platformer-industrial-expansion |
| 2D Platformer Volcano Pack | Tio Aimar | CC0 1.0 | https://opengameart.org/content/2d-platformer-volcano-pack-11 |
| Free Pixel Effects Pack | CodeManu | CC BY 4.0 | https://codemanu.itch.io/pixelart-effect-pack |
| Pixel art sword slash | tbbk | CC0 1.0 | https://opengameart.org/content/pixel-art-sword-slash-effect |
| UI Pack: Pixel Adventure | Kenney | CC0 1.0 | https://kenney.nl/assets/ui-pack-pixel-adventure |
| Kenney Fonts | Kenney | CC0 1.0 | https://kenney.nl/assets/kenney-fonts |
| Game icons | game-icons.net contributors | CC BY 3.0 | https://game-icons.net/ |
| Impact / RPG / UI Audio | Kenney | CC0 1.0 | https://kenney.nl/assets/impact-sounds |
| Fantasy Ambience & Drum Loops | North Fantasy Music | CC BY 4.0 | https://opengameart.org/content/fantasy-music-and-drum-loops-pack |
```

For pack 8, credit the individual artists of the icons you actually ship — the artist name is
the folder each SVG sits in, and `icons/license.txt` inside the archive has the full terms.

## Version control

`.gitignore` already keeps downloaded packs out of the repo
(`kenney_pixel-platformer.zip`, `kenney_pixel-platformer_extracted/`). This folder is 112 MB
of archives and follows the same pattern, so it wants the same treatment — adding

```
/art-resources/
```

to `.gitignore` keeps the originals local while the extracted, converted assets you actually
use go into `assets/` and get committed normally. I have not edited `.gitignore`, since
another session is working in this project.
