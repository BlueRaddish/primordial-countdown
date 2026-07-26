# Parallel work plan — final push

Disposable coordination doc. Delete it when the push is done.

Four instances, **zero shared files in wave 1**. The split is by file ownership, not by
task, because that is what actually collides.

---

## Read this first: two findings that change the work

**1. The devolution-card font diagnosis is wrong.** `project.godot:37` already sets
`theme/custom_font="res://assets/fonts/Kenney Pixel.ttf"` **project-wide**. Every `Label`
in `devolution_popup.gd` sets only `add_theme_font_size_override("font_size", …)`, which
overrides the *size* and leaves the font as the theme default — so the cards are already
rendering in Kenney Pixel. Adding explicit font overrides is a no-op that will look like
a fix and change nothing.

The likelier cause of "ugly": Kenney Pixel is a pixel font with a native size, and the
cards ask for **9, 10, 11 and 12 px**. Off-native sizes in a pixel font render mushy and
inconsistently weighted. Test that first — snap the sizes to the font's native size or a
clean multiple, then judge. The depth/shadow work is still worth doing.

**2. Item 4 is almost certainly not a bug.** `player.gd::_update_body_appearance()` does
`Color.WHITE.lerp(Color(0.58, 0.55, 0.62), decay)`, where `decay` is
`_get_devolution_fraction()` = summed trait stages / 14. So the tint is *linear in total
devolution*: at 3 of 14 steps it is a 21% shift toward grey — invisible mid-fight. Only
near total loss does it read. The system works; the curve is the problem. Confirm with
the 1-minute test, then treat it as a numbers change, not a bug hunt.

---

## Ownership table — wave 1 (all four run at once)

| # | Job | Writes ONLY | Reads |
|---|---|---|---|
| **A** | Ending screen | `scripts/ui/death_screen.gd`, `scenes/ui/death_screen.tscn` | GameState, StageManager, TraitManager |
| **B** | Era transition + tint curve | `scripts/systems/era_door.gd`, `scripts/player/player.gd` | StageManager, Vfx |
| **C** | Devolution card polish | `scripts/ui/devolution_popup.gd` | — |
| **D** | Asset sourcing, no code | `art-resources/2x_*/**` only | — |

No file appears twice. A, B and C never touch each other's scripts, and D writes no code
at all.

### Wave 2 — only after wave 1 has merged

These are held back **because they collide with C**, not because they are low value:

- **UI-kit integration** → `devolution_popup.gd` + `stage_manager.gd`. Same file as C.
- **VFX pack integration** → `scripts/vfx/vfx.gd`. Additive; give it one owner.
- **Doc merge** → one instance folds D's per-pack notes into `ART_RESOURCES.md` and the
  README credits table.

---

## The rule that keeps this from breaking

**Nobody edits `ART_RESOURCES.md`, `README.md` or `project.godot` in wave 1.**

Those three are append-magnets — every asset task wants a row in them, and four instances
appending to the same table is a guaranteed conflict. Instead: D writes a `README.txt`
*inside each pack folder* recording source URL, licence and contents (there is already a
precedent at `art-resources/16_luizmelo_monsters/README.txt`), and a single wave-2 pass
merges them.

---

## Running Godot from more than one instance

This is the real constraint, not the code. All instances share one `.godot/` import
cache, and two engine runs against it will race.

**Use a worktree per code instance:**

```
git worktree add ../pc-A -b work/ending-screen
git worktree add ../pc-B -b work/era-transition
git worktree add ../pc-C -b work/devo-cards
```

Each gets its own working dir and its own `.godot/`, so they can run and test
simultaneously. `.godot/` is gitignored, so each worktree builds its own on first open.
That import is now cheap — `art-resources/.gdignore` keeps the 45M staging tree out of
it, leaving only the ~5M of real `assets/`.

**D needs no worktree** — it only downloads into `art-resources/` and never runs the
engine. Point it at the main checkout.

Merge order does not matter for A/B/C: disjoint files, no semantic overlap.

---

## Shared briefing — paste this into every instance

```
Project: Primordial Countdown, Godot 4.7.1, C:\Users\there\Downloads\Projects\primordial-countdown
Godot binary: C:/Users/there/Downloads/Godot_v4.7.1-stable_win64_console.exe

Engine gotchas, all learned the hard way:
- ui_smoke_test ONLY works windowed. Under --headless it prints nothing and hangs.
  Run: GODOT --path . --resolution 640x360 tests/ui_smoke_test.tscn
- gameplay_smoke_test does run headless:
  GODOT --headless --path . tests/gameplay_smoke_test.tscn
- `--headless --path . --import` hangs (never exits) while the Godot editor is open.
  The import itself still completes; kill it after, or close the editor first.
- Control.size is (0,0) during _ready(). Use get_viewport_rect().size.
  This silently made the off-screen enemy markers invisible for a whole session.
- New `class_name` types are invisible to headless test runs. Use preload() instead.
- Kenney Pixel is ALREADY the project-wide theme font (project.godot:37).

Visual changes need a rendered check, not just green tests. tests/wing_preview.gd is a
working example: it loads the real game scene, forces state, and screenshots. Both a
2x-height character and mis-anchored wings shipped green through the smoke tests.

Hard rules:
- DO NOT generate images. Download open-source art or reuse what is on disk. Nothing else.
- DO NOT open or edit ideate.md — the user is editing it.
- DO NOT edit ART_RESOURCES.md, README.md or project.godot this wave.
- Stay inside the files your brief assigns you. Another instance owns the rest.
- Run BOTH suites before reporting done.
```

---

## Instance briefs

### A — Ending screen *(the long pole; start it first)*

`death_screen.gd` is 29 lines: a blank panel and a menu button. Everything it needs is
already on autoloads, so this is assembly, not plumbing.

Confirmed available at death time:
- `GameState.current_wave`, `GameState.kill_count` — **`end_run()` only flips
  `is_run_active`; it does not reset these.** Reset happens in `start_new_run()`. You can
  read them freely after `end_run()`.
- `StageManager.current_era` — the era enum the player reached.
- `TraitManager.is_intact(name)` over `TraitManager.ALL_TRAITS` (7 traits) — for "which
  trait, if any, is still Intact".
- The game scene stays loaded behind the panel (only `return_to_menu()` changes scene),
  so the era backdrop and the player sprite are still there to frame against.

Build: frozen player sprite against the current backdrop, one line of real numbers, one
closing line ("Everything got older. So did you."). **No victory branch.**

### B — Era transition couplet, then the tint curve

`era_door.gd::_on_body_entered()` already fires a flare and a buff burst — you are adding
a held beat, not a system. Add a `Label` with the couplet ("The doorway is newer than the
ground. / You are older than you look."), fading in and out over ~2-3s. No game-time
pause.

Then item 4 — **run the test before editing anything**: open the character screen (C),
max every trait with dev +, watch the sprite. Per the finding above it will go visibly
grey-purple, which means the fix is the curve, not the code: make `decay` non-linear in
`_get_devolution_fraction()` or push the tint target further, so mid-run devolution
actually reads. If the sprite does *not* change at full devolution, that is a real bug —
say so and dig into `_update_body_appearance()`.

### C — Devolution card polish

Read the "font diagnosis is wrong" finding first. `devolution_popup.gd` is already a
considered design (per-trait accents, colour stripe, harsher tint on full loss, hover
states) — this is depth and legibility, not a rewrite.

Do: test the font sizes against Kenney Pixel's native size; add `shadow_size` /
`shadow_color` to the existing `_card_style()` StyleBoxFlat. Keep `_card_style()` as the
single place card appearance is decided — wave 2 swaps its `StyleBoxFlat` for a
`StyleBoxTexture` and needs that seam intact.

### D — Asset sourcing only, no code

Safest-licence-first. Each pack goes in its own folder with a `README.txt` (source URL,
licence, contents, why). **Do not integrate anything and do not touch ART_RESOURCES.md.**

1. `21_pixel_parchment_ui/` — Pixel Parchment UI Kit. Explicitly commercial-OK. Best fit,
   do it first; it doubles as the era-transition text container.
2. `22_soulofkiran_wooden_gui/` — Pixel Art Wooden GUI v1, CC0.
3. `23_ansimuz_warped_shooting_fx/` — CC0, same artist as the backdrops. Zero risk.
4. `24_craftpix_explosions/` — craftpix.net terms. Note the licence exactly as pack 18 is
   noted.
5. **Medieval slash: do not download.** It shipped once already —
   `git log --diff-filter=D -- '*05_vfx_extras*'` to find the deleting commit, then
   `git checkout <sha>^ -- <path>`. Free.
6. **Cyberpunk UI kit — last, and only if the user verifies the licence at the original
   source.** Unstated licence on a repost is the worst thing to put in a HUD. If it
   cannot be pinned down, skip it; the flat cyberpunk card look is a fine fallback.

Note: `.zip` is now gitignored and archives are not kept — store packs extracted.

---

## If you only get two instances

A alone (it is the biggest and highest payoff), and B+C together — they are small and
touch different files. Drop D entirely; the asset work is polish on top of systems and
should not compete with the three confirmed functional gaps.
