# Open-source art & audio resources for Primordial Countdown

Chosen against what this game actually is: a **640×360 2D pixel sidescroller
roguelike in Godot 4** with an animated player, three enemy movement patterns, a
2×-size stage boss, ~15 skills that need icons and VFX, seven traits with three
stages each, and an arena of generated tiles. The run is themed as three
**time-period backdrops** the world scrolls through while the player devolves.

Every pack in this folder was downloaded from its original source, verified to
open, and its contents listed below are what is actually inside the archive —
not what the store page claims.

Nothing here has been added to the project's own `assets/` tree and no existing
file was touched, **except** the volcano layers from the now-removed pack 4,
which were already copied into `assets/sprites/backgrounds/volcano/` and
`assets/fonts/` before this pass — see "Currently wired into the game" below.
This folder is a staging area — copy out only what you use.

**Two rules added in the 2026-07-26 cleanup:**

- **No .zip archives are kept.** Packs are stored extracted; the archive is a second
  copy of the same bytes. `.gitignore` has a `*.zip` rule so one cannot drift back in.
  Every download URL is in the attribution table at the bottom, so any pack can be
  re-fetched.
- **`.gdignore` makes Godot skip this whole tree.** Without it Godot imported all of
  these packs as game assets — 969 `.import` files, and a `.godot/` cache several times
  the size of the game's real `assets/`, re-scanned on every editor start. Nothing here
  loads through `res://`; the scripts in `tools/` read these files from disk with Python,
  which `.gdignore` does not affect. If you copy a pack file into `assets/`, it imports
  normally there — that is the intended path.

---

## Currently wired into the game

- `assets/sprites/vfx/*.png` — 22 textures from the **Kenney Particle Pack** (CC0),
  downloaded 2026-07-25 and driving every combat effect through
  `scripts/vfx/vfx.gd`: sparks, slashes, muzzle flashes, smoke, dirt, scorch, flares,
  traces, twirls. This replaced the pack-4-era gap left when CodeManu's VFX pack was
  culled — the game had no effect art at all, so every hit, buff, dash and boss slam
  spawned the same drawn circle. Source:
  https://kenney.nl/assets/particle-pack
- `assets/audio/` — the curated SFX/jingles plus four music tracks, converted from
  WAV to OGG Vorbis (30MB -> 1.8MB).

- `assets/sprites/player/wings_bat.png` — the **Wings evolved trait**, cut out of
  `02_ansimuz_gothicvania_collection`'s `demon-idle.png` by `tools/build_wings.py`.
  Replaces the five-point polygon `body_marks.gd` used to draw, which looked like the
  placeholder it was on what is meant to be a reward for losing a limb.

  Wings had to be side-on (this is a sidescroller), genuinely animated, and by ansimuz —
  the player wears his Gothic hero, and a wing from another artist sits on it at the
  wrong outline weight. The demon's 6-frame idle is one full wing beat and satisfies all
  three, without adding a pack.

  The build script masks the three palette entries the membrane owns, keeps the largest
  connected component (the near wing — the demon is drawn in 3/4, so its far wing is a
  stunted fragment that vanishes on the up-stroke), and flattens the three colours to
  three levels of grey so `wing_color` still tints the result. `body_marks.gd` mirrors
  the one wing about the body's centre line to make the pair, which is also why the
  wings need no flip when the player turns around. Re-run the script to change any of
  this; nothing was hand-edited, and the pack is untouched.

- `assets/sprites/backgrounds/cyberpunk/cyberpunk_{back,middle,foreground}.png` —
  the cyberpunk era backdrop, driving `parallax_backdrop.gd` (now a tiling parallax,
  see below), referenced by `scenes/main/game.tscn`. Replaces the volcano layers
  (deleted 2026-07-26, along with their `bg_volcano_1.png`…`_6.png` game-tscn
  references — see "Implementing these backgrounds" below for what changed in the
  script itself.
- `assets/sprites/enemies/{walker,lunger,hopper}/*.png` — re-skinned for the
  cyberpunk era from **Free 3 Cyberpunk Sprites Pixel Art** (a CraftPix.net freebie
  reposted on itch.io), by `tools/build_cyberpunk_enemies.py`. Biker → Walker
  (stockiest stance), Punk → Lunger (already leaning into the run in its idle pose),
  Cyborg → Hopper (most compact/agile silhouette). Only idle and run were used —
  `base_enemy.gd` only ever plays those two. Frames are cropped from the pack's
  48px-tall sheets to each character's own tight bounding box (not resized/redrawn)
  and rendered at 0.6x scale (reusing the player's own `SPRITE_SCALE`) so they read
  at roughly the footprint the old 0x72 sprites had. **This pack is NOT CC0** — see
  its own entry below for the actual license.
- `assets/fonts/Kenney Pixel.ttf`, `assets/fonts/Kenney Mini Square Mono.ttf` —
  independent copies, unaffected by anything below.

## Packs removed as not needed for this build

Downloaded, evaluated, and deleted (2026-07-25): Kenney Pixel Platformer
Industrial Expansion, the volcano platformer pack (superseded, see above),
CodeManu's VFX pack, Kenney UI Pack, Kenney Fonts (already copied into
`assets/fonts/` first, so no loss), and game-icons.net. None of these are
referenced anywhere in `scripts/` or `scenes/`, so removing them was safe.

---

## The three time-period backgrounds (this run's actual scope)

Picked 2026-07-25: **swamp → town → cyberpunk**, reading as the world
advancing through history while the player's own body devolves — the
"you devolve, the world evolves" contrast the design already leans on.
All three are from **ansimuz**, all three verified **CC0** (checked each
pack's own `public-license.pdf` directly — no attribution legally required,
though crediting him costs one line and he's earned it many times over in
the comments on every one of these pages).

### 12. `12_ansimuz_gothicvania_swamp/` — era 1

**Gothicvania Swamp files.zip** · 2.6 MB (6.1 MB unzipped) · CC0 ·
<https://ansimuz.itch.io/gothicvania-swamp>

```
Evironment/background.png     96 x 256   (sic — "Evironment" is the folder name in the zip)
Evironment/mid-layer-01.png  208 x 256
Evironment/mid-layer-02.png  208 x 256
Evironment/tileset.png       336 x 112
Evironment/props.png         176 x 43
Evironment/trees.png         288 x 208
```

Also ships a fully-animated hunter player character (stand/shoot/run/jump/
hurt/idle/crouch), 3 enemies (Spider, Swamp Thing, Ghost), and death/bullet FX
— usable later for enemy variety, not just backdrop.

### 13. `13_ansimuz_gothicvania_town/` — era 2

**GothicVania-town-files.zip** · 10.3 MB (25 MB unzipped) · CC0 ·
<https://ansimuz.itch.io/gothicvania-town>

```
PNG/environment/layers/background.png       384 x 288
PNG/environment/layers/middleground.png     384 x 288
PNG/environment/layers/tileset.png          592 x 192   (+ sliced-tileset/ pieces, mostly 16-48px)
PNG/environment/props/houses.png           1126 x 272
PNG/environment/props/props.png             352 x 192
```

Also ships 4 animated NPCs (idle + walk: bearded, hat-man, oldman, woman) and a
Phaser demo under `code/phaser-code/` (reference only — the game is Godot, the
JS code doesn't port over).

**Skipped as paid, not downloaded:** `GothicVania-Town-Plus_Files.zip` requires
$5+; the free tier above is everything used here.

### 14. `14_ansimuz_synth_cities_cyberpunk/` — era 3

**cyberpunk-street-files.zip** · 16.7 MB (33 MB unzipped) · CC0 ·
<https://ansimuz.itch.io/cyberpunk-street-environment>

Two parallax versions plus a standalone skyline set — pick one, don't mix:

```
Assets/Version 1/PNG/cyberpunk-street.png            608 x 192  (composed preview)
Assets/Version 1/PNG/layers/back-buildings.png       256 x 192
Assets/Version 1/PNG/layers/far-buildings.png        256 x 192
Assets/Version 1/PNG/layers/foreground.png           352 x 192

Assets/Version 2/Layers/back.png                     112 x 272
Assets/Version 2/Layers/middle.png                   256 x 272
Assets/Version 2/Layers/foreground.png               688 x 272
Assets/Version 2/Layers/foreground-empty.png         688 x 272  (no cars/props, if the busier one reads too noisy)

Assets/city skyline/Layers/back.png                  288 x 192
Assets/city skyline/Layers/buildings.png              288 x 192
Assets/city skyline/Layers/front.png                 288 x 192
```

Version 2 is the tallest (272px) and closest to matching the town pack's
288px, if visual weight across the three eras matters. Also includes a bonus
Godot demo project (`SynthCitiesGodot.zip`, not downloaded here — free to
grab from the same page if useful as a reference for wiring parallax in
Godot specifically, since everything else in this repo is hand-rolled GDScript).

**Skipped as paid, not downloaded:** `Synth Cities Skycraper/Pink/Blue Sky -
Background LITE` ($1.99 each) and the `Warped Synth Cities Backgrounds ADDON`
($5+) — the free `Synth Cities Environment` pack above covers the need.

---

## Implementing these backgrounds — done for the cyberpunk era (2026-07-26)

`parallax_backdrop.gd` was built entirely around the volcano pack's shape — one
1280×720 painting sliced into layers, each hung at a fixed `layer_offset_y`
recovered by matching it against that pack's own composed `bg_volcano.png`. It
positioned each layer once and scrolled it horizontally; it did **not** tile.

Every layer in packs 12–14 (and pack 2's `night-town-background-files`, already
on disk) is the opposite shape: a small **seamless-loop strip** (as narrow as
96px, as wide as 688px) meant to repeat edge-to-edge across whatever width the
camera sweeps, not one fixed composition.

**What shipped, in order:**

- [x] **Cyberpunk ships first**, one era at a time as planned — swamp and town
      are still just staged packs, not wired.
- [x] **`parallax_backdrop.gd` got a tiling mode.** Each layer now gets
      `ceil(640 / tile_width) + 3` `Sprite2D` copies, and every `_process()`
      call repositions *all* of them from scratch based on the camera's current
      x — no recycling/wraparound state to drift out of sync, just a fresh
      `base_index` computed each frame. The old single-sprite-per-layer path is
      gone; tiling is now the only mode (a layer wider than the viewport still
      works, it just needs 1-3 copies instead of many).
- [x] **Layer PNGs copied** into `assets/sprites/backgrounds/cyberpunk/` —
      Version 2's `back.png` / `middle.png` / `foreground-empty.png` (not
      Version 1, and not the busier `foreground.png` with cars/props — the
      empty variant reads cleaner behind combat, and this is the layer closest
      to the camera so it's also the most visually salient one).
- [x] **Reimport**: nothing extra needed. `project.godot` already sets
      `textures/canvas_textures/default_texture_filter=0` project-wide, and
      `parallax_backdrop.gd` additionally forces `TEXTURE_FILTER_NEAREST` on
      every tile it creates — pixel-art filtering was never a per-file import
      setting in this project, it's enforced at the project/node level.
- [x] **Wired into `game.tscn`** directly (`layer_textures` swapped, no
      `stage_manager.gd` era-switching — not in scope for this pass).
- [x] **`horizon_y` / `canvas_height` re-derived, not copied.** Each of these
      three layers is a complete, independent 272px-tall scene (sky down to
      street), not a slice of one shared painting — so `canvas_height = 272`
      (matching the layers' own height) makes every layer bottom-align by
      default, and `horizon_y = 288` was chosen to equal `ArenaRenderer.GROUND_Y`
      exactly, so each layer's own painted street sits flush with where the
      arena's real ground tiles begin. `base_x` lost its old meaning (it was
      solved against the volcano's 1280px canvas and the camera's sweep) and
      is now just a per-layer phase nudge, defaulted to 0.
- [x] **`assets/sprites/backgrounds/volcano/` deleted**, its `game.tscn`
      references replaced.
- [x] **ansimuz credited** in the README's credits table.

Swamp and town are unaffected — same tiling script will handle them whenever
one of those eras is wired in next, following this same pattern.

---

## Other packs already on disk (unaffected by the above)

### 1. `01_0x72_dungeon_tileset_ii/` — enemies, boss, player fallback

**0x72_DungeonTilesetII_v1.7.zip** · 408 KB · 754 files · CC0 ·
<https://0x72.itch.io/dungeontileset-ii>

16×16 side-view characters, every one with **idle and run animations already
split into individual frames** (`frames/` directory) *and* packed into one
atlas with a `tile_list_v1.7` coordinate file. Playable/humanoid bodies:
knight, elf, wizard, lizard, dwarf (each m/f, each with a **hit** frame).
Monsters: goblin, imp, chort, skeleton, orc warrior, orc shaman, masked orc,
necromancer, wogol, swampy, muddy, zombie (tiny/normal/big/ice), slug, tiny
slug, angel, pumpkin dude, plus **ogre** and **big demon** (32×36 vs the
16×16 minions — already the stage boss size, no scaling required). Currently
the source for `assets/sprites/player/knight`, `enemies/{walker,lunger,
hopper}`, and `bosses/big_demon`.

### 2. `02_ansimuz_gothicvania_collection/` — the volume pick

**gothicvania_patreon_collection.zip** · 3.9 MB · 421 files · public domain,
credit appreciated · <https://opengameart.org/content/gothicvania-patreons-collection>

Thirteen of Luis Zuno's 2016–17 packs in one archive: `Gothic-hero-Files`,
`Gothic-hero-p2-Files`, `demon-Files`, `Hell-Beast-Files`, `Hell-Hound-Files`,
`Ghost-Files`, `Fire-Skull-Files`, `Nightmare-Files`, `wolf-runing-cycle`,
`Gothic-Horror-Files`, `Gothic-Castle-Files`, `Old-dark-Castle-tileset-Files`,
`night-town-background-files` (seamless parallax layers — same tiling shape
as packs 12–14, see the implementation blocker above). Not currently wired
into anything; a candidate for enemy variety in the town/swamp eras.

### 9, 10, 11 — the audio source packs (REMOVED 2026-07-26)

`09_kenney_audio/`, `10_kenney_music_jingles/` and `11_fantasy_ambience_music/`
are gone. All three existed only as .zip archives — nothing was ever extracted
beside them — and together they were 101 MB, over half this folder.

Everything they supplied lives on downstream and nothing was lost:

- The SFX and stingers actually chosen are in `15_selected_devolution_assets/audio`
  as OGG, and shipped in `assets/audio/` (1.9 MB, wired through
  `scripts/autoload/audio_manager.gd`).
- The music is in `assets/audio/music/` as OGG. The two town-era tracks that had
  never been converted were converted during the cleanup rather than deleted
  (12.8 MB and 11.3 MB WAV -> 0.92 MB and 0.80 MB OGG) and sit in pack 15.
- The 6 source WAVs in pack 15 (53 MB) were deleted after verifying each one had
  an OGG counterpart in either staging or `assets/`.

**The CC BY 4.0 obligation did not go away.** North Fantasy Music's tracks are
still in the shipped game; deleting the source archive changes nothing about
that. The attribution rows in this file and in the project README stay.

To get any of it back: the download URLs are in the attribution table below, and
every deleted file is still in git history.

### 17. `17_kenney_pixel_platformer/` — ground tiles

**Pixel Platformer 1.2** · 1.6 MB · CC0 · <https://kenney.nl/assets/pixel-platformer>

Moved here on 2026-07-26. It had been sitting loose in the project root as
`kenney_pixel-platformer_extracted/` next to its own zip, outside this folder and
excluded from version control by name — so the source of tiles the game actually
ships was the one pack not recorded alongside the others. It is a normal staged
pack now.

Supplies the arena ground tiles in `assets/sprites/arenas/` that `arena_renderer.gd`
draws. Also contains Tiled and Construct 3 project files, which are reference only —
the arena is generated in GDScript, not authored in a tile editor.

### 18. `18_craftpix_cyberpunk_sprites/` — cyberpunk-era enemies

**Free 3 Cyberpunk Sprites Pixel Art.zip** · 71 kB ·
<https://free-game-assets.itch.io/free-3-cyberpunk-sprites-pixel-art>

```
1 Biker/  2 Punk/  3 Cyborg/
  {name}_idle.png        192x48  (4 frames, 48x48 each)
  {name}_run.png         288x48  (6 frames, 48x48 each)
  {name}_jump.png        192x48  (4 frames) — unused, no jump animation exists yet
  {name}_punch.png       288x48  (6 frames) — unused, no attack animation exists yet
  {name}_attack1/2/3.png 288-384 wide       — unused
  {name}_climb/death/doublejump/hurt.png    — unused
```

**Not CC0.** This is a free (name-your-own-price, $0 is a valid price) repost by
"Free Game Assets" of a **CraftPix.net** freebie — the original is
<https://craftpix.net/freebies/free-3-cyberpunk-characters-pixel-art/>, and
`license.txt` inside the zip points at CraftPix's own terms:
<https://craftpix.net/file-licenses/>. Summary: commercial use is explicitly
permitted, attribution is *not* required ("any credit will be highly
appreciated"), but — unlike every CC0 pack in this file — **redistributing the
source files themselves is prohibited** ("resell the art source files ... or a
slightly modified version"), and the assets may not be used to train AI models.
None of that blocks using the sprites in the shipped game; it blocks handing the
zip or the cropped PNGs out as a standalone asset pack.

Only `idle` and `run` were used, cropped and re-scaled by
`tools/build_cyberpunk_enemies.py` into `assets/sprites/enemies/{walker,lunger,
hopper}/` — see that script's docstring for the character-to-behavior mapping
and why each frame is cropped to a per-character (not per-frame) box.

### 15. `15_selected_devolution_assets/` — this pass's curated picks

Not a new download — every file here was copied out of packs 1, 2, 9, 10
and 11 (packs 9-11 have since been deleted, see above; same licenses: CC0
except the North Fantasy Music files, which stay CC BY 4.0 and need
attribution). Audio here is OGG only — the 53 MB of source WAVs was removed
on 2026-07-26 once every one had a converted counterpart. This folder exists
so the handful of files actually picked during the animation/audio review
don't stay buried inside the full packs.

```
avatars/                         — body-stage sprite candidates (idle+run+hit
                                    frame sets, full animation, not stills)
  stage1_unarmored_elf_m/         from pack 1's elf_m
  stage2_rotting_big_zombie/      from pack 1's big_zombie
  stage3_skeleton_skelet/         from pack 1's skelet
  stage4_dead/skull.png           from pack 1's skull.png (static, no anim)

powerup_reference/               — trait/skill visual references
  angel_idle/run_anim_f0-f3.png   from pack 1 — the one EXTRACTABLE asset
                                    (wings are a separable shape); everything
                                    else in this folder is REFERENCE ONLY, a
                                    different rig/style, not croppable —
                                    see filename suffixes for which trait/skill
                                    each maps to
  *_REFERENCE.png / .gif           chort (tail/claws), ogre (plates), demon
                                    (feral wings + wing dash), gothic-hero
                                    (aerial chain, lunge/backstep, hurt pose),
                                    wolf (feral tail/claws), ghost (gills)
  fire_skull_HINDBRAIN_SKILL_FX.gif  not body art — a HUD/enemy flash effect

audio/                            — curated SFX/music picks, renamed by role
                                     rather than source filename
  sfx_*.ogg                        impact sounds (pack 9) — metal/punch/plate/
                                     soft/bell hits per armor state
  jingle_*.ogg                     event stingers (pack 10) — devolution
                                     step, skill unlock, evolved trait grown,
                                     death
  music_*.wav                      background music + drum-loop tension
                                     layers (pack 11, CC BY 4.0 — North
                                     Fantasy Music)
```

Deliberately excluded: 3 of the 4 punch/flesh-hit sound candidates that were
being A/B compared (kept only `impactGeneric_light`, renamed
`sfx_punch_flesh_hit.ogg`), the knight (already the real player asset, not a
candidate), and the two non-chosen stage options (`doc` for stage 1,
`tiny_zombie` for stage 2) — narrowed down after review, not an oversight.

---

## Godot 4 import notes

- Pixel art: import tab → **Filter: Off**, **Mipmaps: Off**. The project
  renders at a fixed 640×360 with `canvas_items` stretch, so any filtering
  shows up immediately as mush.
- Fonts: **Antialiased: Disabled**, integer font sizes only.
- Pack 1's `frames/` folder loads straight into `SpriteFrames`; alternatively
  slice the atlas using the bundled `tile_list_v1.7`.
- Pack 2's PSDs are for editing only — import the PNGs, not the PSDs.
- Packs 12–14 ship PSDs too (`PSD/concepts.psd` etc.) — same rule, PNGs only.
- Convert pack 11's WAVs to OGG before import.
- `.import` files are generated per asset automatically once a file sits
  inside the project directory — this already happened to everything in
  `art-resources/`, which is expected and harmless; it doesn't mean the art
  is "in" the game until it's copied into `assets/` and referenced by a scene.

## Attribution

Credit isn't legally required for any CC0 pack (that's everything from
ansimuz and Kenney, packs 1, 2, 9, 10, 12, 13, 14), but pack 2 (Gothicvania)
asks for it loosely ("credit appreciated") and pack 11 (Fantasy Ambience)
*does* require it under CC BY 4.0 — and pack 15 pulled real files from both
of those, plus packs 1, 9, and 10, into material that's now earmarked for
actual use (see `ideate.md`'s Tier 1.5), not just staged. This table has
been pasted into the README's Credits table for that reason — it's the
project's actual homepage, not this file:

```markdown
| 16x16 DungeonTileset II | 0x72 | CC0 1.0 | https://0x72.itch.io/dungeontileset-ii |
| Gothicvania Patreon Collection | Luis Zuno (ansimuz) | Public domain, credit appreciated | https://opengameart.org/content/gothicvania-patreons-collection |
| Gothicvania Swamp | Luis Zuno (ansimuz) | CC0 1.0 | https://ansimuz.itch.io/gothicvania-swamp |
| GothicVania Town | Luis Zuno (ansimuz) | CC0 1.0 | https://ansimuz.itch.io/gothicvania-town |
| Synth Cities Environment | Luis Zuno (ansimuz) | CC0 1.0 | https://ansimuz.itch.io/cyberpunk-street-environment |
| Impact Sounds | Kenney | CC0 1.0 | https://kenney.nl/assets/impact-sounds |
| RPG Audio | Kenney | CC0 1.0 | https://kenney.nl/assets/rpg-audio |
| Music Jingles | Kenney | CC0 1.0 | https://kenney.nl/assets/music-jingles |
| Fantasy Ambience & Drum Loops | North Fantasy Music | CC BY 4.0 | https://opengameart.org/content/fantasy-music-and-drum-loops-pack |
| Free 3 Cyberpunk Sprites Pixel Art | CraftPix.net (reposted by Free Game Assets) | Free for commercial use, no attribution required, no redistribution of source files | https://free-game-assets.itch.io/free-3-cyberpunk-sprites-pixel-art |
```

Only pack 11 (and pack 2, loosely) actually asks for it — but everything
sourcing pack 15 is listed regardless, same "credit is deserved, not just
owed" reasoning the README's own Credits section already states. Pack 18
(CraftPix) is the one entry here that is **not** CC0 — see its own section
above for what its licence actually restricts.

## Version control

`.gitignore` does not currently exclude `/art-resources/` — another session
was mid-work here previously and this pass didn't touch that decision either.
Worth revisiting before the jam submission: the extracted, converted assets
actually used belong in `assets/` and get committed normally; the raw
archives in this folder don't need to ship.
