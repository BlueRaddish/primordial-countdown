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

---

## Currently wired into the game

- `assets/sprites/backgrounds/volcano/bg_volcano_1.png` … `_6.png` — driving
  `parallax_backdrop.gd`, referenced by `scenes/main/game.tscn`. **Scrapped**:
  the team decided against a volcanic look in favor of the three eras below.
  Nothing deletes these automatically — remove them once a replacement layer
  set is wired in, so the scene doesn't dangle a missing-texture reference.
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

## Implementing these backgrounds — the actual steps

This is the part that isn't just "drop in a PNG." Read `parallax_backdrop.gd`
before starting:

**The blocker:** `parallax_backdrop.gd` was built entirely around the volcano
pack's shape — one 1280×720 painting sliced into layers, each hung at a fixed
`layer_offset_y` recovered by matching it against that pack's own composed
`bg_volcano.png`. It positions each layer once and scrolls it horizontally;
it does **not** tile.

Every layer in packs 12–14 (and pack 2's `night-town-background-files`,
already on disk) is the opposite shape: a small **seamless-loop strip** (as
narrow as 96px, as wide as 688px) meant to repeat edge-to-edge across
whatever width the camera sweeps, not one fixed composition. Dropping these
into `layer_textures` as-is will leave gaps the moment the camera moves past
one copy's width — most of these are narrower than the 640px viewport itself.

**Steps, in order:**

- [ ] **Decide which era ships first.** Given the deadline, treat this as
      one background swap at a time, not three at once.
- [ ] **Give `parallax_backdrop.gd` a tiling mode.** Simplest version: for
      layers under a size threshold, instance N copies of the `Sprite2D`
      side by side (width × N ≥ camera sweep + one screen), and re-tile them
      in `_update_layers()` as the camera crosses each copy's edge — same
      pattern as an infinite scroller background. This is new code, not a
      config change; budget real time for it before touching the art.
- [ ] **Copy the chosen layer PNGs** into a new folder, matching the existing
      convention: `assets/sprites/backgrounds/<era_name>/`.
- [ ] **Reimport with pixel-art settings**: Godot import tab → **Filter:
      Off**, **Mipmaps: Off** (matches every other sprite in this project;
      skipping this is the #1 way new art shows up blurry against everything
      else).
- [ ] **Wire the new textures into `game.tscn`**, either by swapping
      `parallax_backdrop.gd`'s exported `layer_textures` directly for a single
      hardcoded era, or — if era-switching is actually in scope for the jam
      build — by giving `stage_manager.gd` (currently an empty stub) the job
      of swapping `layer_textures`/`layer_scroll`/`horizon_y` on era
      boundaries. Don't build the second option unless the first one is
      already working and there's time left; it's strictly more code.
- [ ] **Re-tune `horizon_y` and `base_x` per era.** These were solved
      specifically for the volcano pack's 720-tall canvas and camera sweep
      (see the comments in `parallax_backdrop.gd` — the math is: a layer
      must cover the 640px viewport at both ends of the camera's ~-30..1110
      sweep). A 288px-tall town layer or a 192px cyberpunk layer needs this
      re-derived, not copied — the volcano numbers will place them wrong.
- [ ] **Delete or replace `assets/sprites/backgrounds/volcano/`** once a real
      replacement is wired in, so nothing in the scene points at art the team
      already decided against.
- [ ] **Credit ansimuz** in the README's credits table (see below) — not
      legally required under CC0, but costs one line.

None of this is done yet. The packs are on disk and Godot has already
`.import`-cached them (they sit inside the project directory), but the game
still only renders the volcano layers until the steps above happen.

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

### 9. `09_kenney_audio/` — SFX

Three CC0 packs, 246 files total, OGG + WAV: `kenney_impact-sounds.zip`
(784 KB, 134 files), `kenney_rpg-audio.zip` (944 KB, 56 files),
`kenney_ui-audio.zip` (404 KB, 56 files). Not wired into `assets/audio/`
yet — that directory is still empty.

### 10. `10_kenney_music_jingles/` — event stingers

**kenney_music-jingles.zip** · 1.2 MB · 95 files · CC0. Short stings for
devolution steps, skill unlocks, boss spawn, death.

### 11. `11_fantasy_ambience_music/` — background music

**CC BY 4.0** · North Fantasy Music — this one *does* need attribution.
`fantasyambience.zip` (69 MB, 7 tracks) + `fantasyambience_drumloops.zip`
(30 MB, 5 loops), 44.1kHz 16-bit stereo WAV. **Convert to OGG before import**
— Godot will otherwise embed the raw WAV size, and this is 99 MB uncompressed.

### 15. `15_selected_devolution_assets/` — this pass's curated picks

Not a new download — every file here is copied out of packs 1, 2, 9, 10, and 11
above (same licenses: CC0 except the North Fantasy Music files, which stay
CC BY 4.0 and need attribution same as pack 11). This folder exists so the
handful of files actually picked during the animation/audio review don't stay
buried inside the full packs. Still staging, not `assets/` — nothing here is
wired into a scene yet.

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
```

Only pack 11 (and pack 2, loosely) actually asks for it — but everything
sourcing pack 15 is listed regardless, same "credit is deserved, not just
owed" reasoning the README's own Credits section already states.

## Version control

`.gitignore` does not currently exclude `/art-resources/` — another session
was mid-work here previously and this pass didn't touch that decision either.
Worth revisiting before the jam submission: the extracted, converted assets
actually used belong in `assets/` and get committed normally; the raw
archives in this folder don't need to ship.
