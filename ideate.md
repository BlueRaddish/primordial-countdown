# Ideate — where Primordial Countdown goes next

A working backlog of ideas to make the game deeper, more dynamic, and more tightly
bound to its two pillars: **you devolve** and **the clock counts down**. Ordered by
*when they should be built*, not by how exciting they are — each tier assumes the one
above it is in place. Every idea notes why it serves the theme, because anything that
does not is scope we should cut.

The north star: **the run should read as a body coming apart and improvising around
the wreckage, against a clock that never stops.** Devolution is loss; the only power
you gain is power that grows out of loss.

**Next up: clear the known issues, then the art/audio pass, then Tier 2.** Tiers 0 and 1
are shipped. The devolution *systems* are now complete — what is still missing is making
the countdown itself a decision. But three bugs, one open fiction question, and an entire
unbuilt art/audio layer turned up in a review pass over the shipped systems, and they
should be settled first rather than built on top of.

---

## Tier 0 — just shipped (context for what follows)

- Fullscreen / clean scaling, F11 toggle.
- Mid-air skills refresh the jump → aerial skill chains.
- Trait roster reworked: **Lungs** (swing recovery), **Skin** (passive armor);
  Throat and Speech retired.
- **Evolved traits** — hidden combo unlocks, offered as accept/decline, that grow
  over a trait slot: **Wings** (arms lost + lungs intact + legs partial/lost) and
  **Hide** (skin intact + lungs lost + gut lost).
- **Devolution is a choice of 3** — each step offers 3 random still-degradable traits
  with their consequences, so you steer toward the evolved combos yourself. Total is
  still 14 degradations, so the countdown lands exactly on full devolution.
- New mobility skills: Scramble, Wing Dash, Updraft; plus Curl (Hide).
- Attack+movement hybrids (`impulse_reverse` added to SkillData): Lunge Strike,
  Backstep Slash, Wing Slam.

Everything below builds on this.

---

## Tier 1 — finish the systems we just started ✅ shipped

These made the new mechanics feel complete rather than bolted on. Kept here as the
record of what was built and where it deviated from the sketch.

### 1.1 Fill out the evolved-trait roster ✅
All six of PLANNING1 section 6's "traits regained" now exist as `EvolvedTraitData`,
each with a hidden loss-combo and a real effect:

| Evolved | Combo | Slot | Effect as built |
| --- | --- | --- | --- |
| **Tail** | Legs partial + Head lost | Legs | ×1.9 air control that survives losing the legs entirely, +0.12s coyote, Tail Whip. |
| **Claws** | Arms lost + Skin lost | Arms | Restores the attack at ×1.15 damage and half reach. Grants Rend. |
| **Plates** | Skin lost + Gut lost | Skin | 30% damage reduction + 65% knockback resistance. Grants Ram. |
| **Gills** | Lungs lost + Eyes lost | Lungs | Cancels the lungs' ×2.2 swing penalty outright. No skill — see 3.3. |

**Deviation:** Claws do *not* scale with the countdown yet. That was the sketch above,
but it belongs to 3.1 and was deliberately left there.

### 1.2 Mutually-exclusive evolved paths ✅
`replaces_trait` is now the exclusivity key: one evolved trait per slot, permanently.
Wings closes off Claws, Hide closes off Plates. The offer popup names what you give up
before you accept, and a closed-off form stays greyed out on the character screen so the
choice remains visible for the rest of the run.

### 1.3 Visible bodies ✅
`scripts/player/body_marks.gd` draws wings, tail, claws, gills and a plated rim, and the
sprite drains toward grey as total degradation rises (partial stages included, so it
slides rather than steps). Procedural rather than authored, so it cannot go stale when a
trait is retuned — real art replaces that one node.

**Still open:** nothing shows a trait that is *missing*. The marks only draw what grew
back, so "no arms" and "no legs" still read the same as intact. Worth a pass with art.

### 1.4 Head's missing skill ✅
Shipped as **Hindbrain** — renamed from "Instinct" because "Apex Instinct" already
existed and two near-identical names in one list is a UI problem. For 8s every enemy
about to hit you lights up and you take 25% less damage. Every trait now has a full-loss
skill, closing the last gap PLANNING1 left undecided.

---

## Known issues — fix before Tier 2

Found while reviewing the shipped systems. Not new features — bugs and rough edges in
what already exists. Listed most-important first; worth clearing before Tier 2 builds
more on top of the same code.

### 2.0.1 Double jump doesn't work on certain platforms
The one-way platforms (`arena_renderer.gd`'s `one_way_platforms` list — the shelves with
the teal top-line, meant to be jumped up through from below) can be fallen straight
through instead of landed on, most often right after a double jump arcs back down onto
one. **Likely cause:** their collider is deliberately thin (`ONE_WAY_THICKNESS = 8`) with
a small margin (`ONE_WAY_MARGIN = 6`) meant to stop fast falls tunnelling through — but
the player's fall speed can reach `max_fall_speed = 400` px/s, which at the project's 60
physics-ticks/second default covers ~6.7 px in a single frame. That's already past the 6
px margin, so any fall at or near terminal velocity onto one of these platforms is likely
to tunnel through rather than land. The risk is even flagged in `arena_renderer.gd`'s own
comment — the margin just isn't large enough for the numbers actually in play. **Possible
fix:** raise `ONE_WAY_MARGIN` past the worst-case per-frame fall distance (something like
12–16, with headroom for a dropped frame) so a landing is caught reliably no matter how
the platform was reached.

### 2.0.2 Boss ground slam hits softer than just touching the boss
`BossEnemy.slam_damage` is 22, but the boss inherits `BaseEnemy`'s plain contact damage
(30 — already double a normal enemy's 15, per the "twice the contact damage" design) and
a connecting lunge hits for 45 (contact damage × the lunger behavior's 1.5 multiplier).
So the one attack that is telegraphed and dodgeable currently deals the *least* damage of
the three ways the boss can hurt you — backwards from the usual telegraph/dodge contract,
where the big obvious attack should be the one that punishes hardest for eating it.
**Possible fix:** raise `slam_damage` above both contact and lunge damage (or give it its
own multiplier the way lunges get one), so dodging the slam is worth visibly more than
dodging a bump.

### 2.0.3 Devolution ("degrade") screen needs individual cards, not a stacked list
Each offered trait in the devolution popup (`devolution_popup.gd`, shown from
`devolution_screen.tscn`) is currently one full-width `Button` in a plain vertical stack —
same background, same border, nothing separating one option from the next but its text.
Functionally fine, but it reads like a settings list rather than a moment where the
player is choosing what to lose. **Possible fix:** give each option its own bordered
panel/card — its own background, a color accent per trait, the "X → Y — consequence"
text laid out inside instead of squeezed into one button label — so the choice reads as
picking between distinct things, not clicking down a menu.

---

## Rethink the aging fiction (open design question)

The devolution system's current framing: a run starts at "2000 years old"
(`starting_years` in `devolution_system.gd`), every normal attack subtracts exactly 1
year, skills subtract their own cost, and hitting 0 means fully devolved. Mechanically
this works — it's a clean, tunable countdown, and `README.md`'s "The year counter"
section explains why it's one number instead of a hidden bar. But the fiction under it
doesn't hold up: a 2000-year-old body doesn't lose a whole calendar year of pre-existing
life every time it throws a punch, and "years" as a unit implies a chronology that a
single melee swing doesn't plausibly represent. Worth settling before Tier 2 leans on it
further — 2.1's "spend years to change the fight" beats only feel earned if what a "year"
means survives contact with the idea.

Two draft alternatives. The *mechanics* don't need to change — one countdown number,
spent through `spend_years()`, ending the run at zero — only what it represents:

**A. Aging debt, not banked years.** Reframe the number as accumulated biological
stress rather than a stockpile being spent down. The character starts at a normal age;
every attack, skill, and hit taken adds "wear" that compounds toward a hard cap — the run
ends when the body hits a terminal age, not when a bank of years empties. This is the
more biologically honest version of what's already happening (exertion and injury really
do accelerate aging — cortisol, oxidative stress, telomere attrition), and it flips the
HUD from "counting down a stockpile" to "counting up toward how old the fight has made
you," which reads better than "swinging a sword makes you younger." Numerically this can
be the *same* countdown inverted (years_remaining becomes years_aged, counting up to
starting_years instead of down from it) — closer to a display and copy change than a
systems one.

**B. Drop "years" as the unit entirely.** Keep the number and the countdown exactly as
built, but stop calling it years — something like "vitality" or "spark" sidesteps the
realism complaint outright, since the objection is specifically that *years* implies a
literal chronology attacks can't plausibly consume. Cheaper to ship than A, but loses the
geological-era contrast the HUD already draws between "your countdown" and "the world's
age" (3.5B → 1000) — that contrast depends on both readouts being time in some sense.

Leaning toward A: it keeps the years-vs-eras contrast intact, and "the fight itself is
aging you" is a stronger version of the loss theme than a mysterious pre-existing
stockpile. Needs a decision before Tier 2.1 is built, since that tier's shrines/doors are
priced in whatever unit this becomes.

---

## Tier 1.5 — Give the body, the fights, and the world a voice (art + audio pass)

An animation/audio review turned up real, ready-to-use candidates already sitting in
`art-resources/15_selected_devolution_assets/` (avatars, trait/skill references, curated
audio) — copied out of packs already on disk, nothing new downloaded, see
`art-resources/ART_RESOURCES.md` for the full inventory and licenses. Ordered by
payoff-per-effort: the body swap is the single biggest visible win Tier 1.3 already asked
for; audio starts from literal zero, so even rough wiring beats silence; the VFX trail is
one small code change; the wings crop is polish on something that already works.

### 1.5.1 Body-stage avatars — make devolution visible at the whole-body level
Four frame sets are ready in `avatars/`: `stage1_unarmored_elf_m`, `stage2_rotting_
big_zombie`, `stage3_skeleton_skelet` (each with full idle + run, and a hit frame where
the source pack shipped one), plus `stage4_dead/skull.png`. Stage 0 (Knight) is already
`assets/sprites/player/knight`. **Why:** Tier 1.3 shipped procedural marks for what a
trait *grew back*, but flagged its own gap — "nothing shows a trait that is missing." A
whole-body stage swap solves that at the level the north star actually asks for: watching
your own silhouette fail, not reading a HUD row. **Depends on:** nothing new —
`devolution_system.gd`'s `total_devolutions` (0-14) is already the exact signal to drive
it, matching how this pass agreed the trigger should work (whole-body total, not any one
trait maxing out).

Implementation: build 3 new `SpriteFrames` resources mirroring
`resources/sprite_frames/player_knight.tres`'s shape — idle, run, `jump` (reuse a run
frame, the same trick the knight's own jump animation already is), `attack` (elf_m has a
real hit frame to reuse; big_zombie and skelet don't ship one, so reuse one of their own
idle frames the same way `jump` already reuses a run frame — zero new art either way).
`skull.png` is not a live gameplay stage; it's what `death_screen.gd` shows, since hitting
devolution step 14 already fires `player_died` on its own — there's no "stage 4 while
still playing" to build. Add a small stage-index function alongside
`recalculate_from_traits` that swaps `_sprite.sprite_frames` when `total_devolutions`
crosses a threshold. Starting thresholds to tune from (not final — check them against
`devolution_curve_growth`'s existing pacing so stages don't all cluster at the end): 0 =
Knight, 1–4 = unarmored, 5–9 = rotting, 10–13 = skeleton, 14 = run already over.

### 1.5.2 Audio — currently: total silence
16 curated files are ready in `audio/` — impact hits per armor state, 4 event stingers,
6 background/tension music tracks. **Why:** `audio_manager.gd` is a bare autoload stub
today and `assets/audio/` is empty — every attack, hit, devolution step, and death in the
current build is silent. This is the single biggest gap in the whole review, bigger than
any visual one, because a silent build reads as unfinished even when everything else
works. **Depends on:** `audio_manager.gd` needs real `play_sfx()`/`play_music()` methods
first — there's no partial version to extend, this starts from zero.

The triggers already exist and fire today; only the sound is missing. Straight mapping to
`event_bus.gd` signals: `sfx_metal_hit` / `sfx_punch_flesh_hit` / `sfx_blade_slice` /
`sfx_plate_hit` / `sfx_soft_hit_skin_lost` → `player_hit`/`enemy_hit`, picked by current
Arms/Skin trait stage rather than one fixed sound; `sfx_boss_slam_impact` →
`BossEnemy._do_slam()`; `jingle_devolution_step` → `devolution_applied`;
`jingle_skill_unlock` → `skill_unlocked`; `jingle_evolved_trait_grown` →
`evolved_trait_grown`; `jingle_full_devolution_death` → `player_died`. The 4
background/tension tracks (`music_swamp_era`, `_town_era`, `_town_era_alt_darker`,
`_boss_tension`) and 2 drum loops (`_late_run_tension_layer`, `_active_combat_layer`)
route through `stage_manager.gd` — already an empty stub per `ART_RESOURCES.md`'s own
notes on the parallax-tiling rework it's waiting on. The drum loops are built to fade in
under whichever era track is already playing (low `years_fraction`, or a boss engaged)
rather than replace it outright. **Still open:** no cyberpunk-flavored track exists for
pack 14's era — flagged during the review, needs a separate CC0/CC-BY synthwave source
before that era ships with music that actually fits.

### 1.5.3 Skill VFX trail — the one real code gap the review found
Everything about how skill effects render turned out to already work (`AoEIndicator` is
pure procedural geometry, no texture, so it never cared what body was under it) — except
one thing: it draws a single static arc at a fixed point, not a shape that follows the
player through an impulse-based skill (Lunge Strike, Backstep Slash, Wing Dash, Wing
Slam). **Why:** this is the actual, concrete version of what the Gothic-hero/demon
reference clips were standing in for — not new art, a trail that follows the lunge.
**Implementation:** sample `player.global_position` each frame during the
`impulse_speed`/`impulse_upward_bias` window (`ability_manager.gd::_execute_skill`
already knows exactly when this starts), draw a tapering, fading polygon strip between
the sampled points, colored by `skill.aoe_color`, self-clearing the same way
`AoEIndicator` already does. **Depends on:** nothing new — extends an existing, shipped,
already style-agnostic system.

### 1.5.4 Evolved-trait wings — optional real-art polish
The angel's full idle+run frame set in `powerup_reference/` is the one asset out of the
whole review that's actually croppable — same rig scale/style as the body-stage sprites,
and the wings sit on the back as a separable shape. Everything else in that folder
(chort, ogre, demon, gothic-hero, wolf, ghost) stays reference-only — a different rig or
style, useful for an artist's eye, not for extraction. **Why this is optional:** Tier 1.3
already shipped a working wing mark (`body_marks.gd::_draw_wings()`, a drawn polygon) —
this is a polish pass on something that already works, not a gap. **Implementation:**
crop just the wing shape (transparent elsewhere) from each frame, swap the polygon for a
textured `Sprite2D` positioned/rotated by the same `_phase`-driven beat math already
there. **Depends on:** someone actually doing the crop; lowest priority in this tier since
the procedural version is already shipped and working.

---

## Tier 2 — make the countdown a decision, not a meter

The year counter is currently something that happens *to* you. Make spending it a
live tactical choice.

### 2.1 Countdown-priced risk/reward moments
Occasional "spend years to change the fight" beats: a shrine that heals for 40 years,
a door that skips a wave for 60. **Why:** the clock is the game's central currency;
let players *choose* to burn it, not just watch it drain. **Depends on:** nothing.

### 2.2 Balance the devolution fork *(the fork itself shipped — see Tier 0)*
Choice-of-3 is live, so the remaining work is tuning, not building: make sure no
degradation order is strictly best, and that the 3 offered options are rarely all
equally painless. Candidate levers — weight the roll toward traits you've been
protecting, or make a *refused* trait cheaper to degrade next time. **Why:** a fork
where one branch always wins is a menu, not a decision. **Depends on:** playtesting.

### 2.3 Milestone bosses tied to era readout
The HUD already shows a geological era (3.50B → 1000). Have bosses/enemies reskin as the
era rolls over, so the *world evolving* is legible against your *devolving*. **Why:**
PLANNING1's core contrast is "you devolve, the world evolves" — right now only half of
that is visible. **Depends on:** evolution_system.gd (currently a stub) actually doing
something — see 3.2.

---

## Tier 3 — new content that the systems now support

Bigger swings. Each needs Tier 1–2 groundwork.

### 3.1 Countdown-scaling natural weapons
Claws (1.1) that get *stronger as the clock runs down* — the further devolved, the more
feral. **Why:** inverts the usual "you get weaker"; late-run you are a cornered animal,
which is exactly the mood. **Depends on:** 1.1, and a clean read of years-remaining
(devolution_system already exposes `get_years_fraction()`).

### 3.2 Real evolution system (the other half)
`evolution_system.gd` is an empty stub by design (kept decoupled from devolution).
Give it teeth: enemies gain a capability per wave/boss cleared — pack tactics, ranged
attacks, armor — on a fixed schedule independent of your losses. **Why:** the entire
premise is two clocks running against each other; only one is implemented. **Depends
on:** must never read devolution state (PLANNING1 section 3).

### 3.3 Terrain that reads traits
Water pools (Gills matter), dark caves (Eyes matter), high ledges (Wings/Legs matter),
crush hazards (Hide/Plates matter). **Why:** makes each trait's presence or absence a
spatial fact, not just a number. **Depends on:** 1.1 (Gills), arena_renderer extension.

### 3.4 Environmental mobility
Wall-cling, ledge-grab, ziplines — mobility that isn't a skill. **Why:** the user asked
for a more dynamic, engaging *feel*; traversal verbs do that even between fights.
**Depends on:** player controller work; pairs with Wings/Tail.

---

## Tier 4 — meta and longevity

Only once a single run is consistently fun (PLANNING1's rule: don't build milestone 4
until milestone 3 is fun without art).

### 4.1 Between-run meta progression
`save_manager.gd` exists but is unused. Unlock *starting conditions* — begin a run with
one trait already evolved, or a different degradation order. **Why:** the roguelike
loop needs a reason to replay; keep it about *how you fall*, not raw power creep.

### 4.2 Alternate lineages
Different starting trait sets (a swimmer, a flyer) that devolve down different trees.
**Why:** replay variety that stays on-theme. **Depends on:** data-driven traits (already
the architecture) + 4.1.

### 4.3 Seeded daily run
One shared seed per day: same waves, same degradation order, leaderboard by years
survived. **Why:** cheap longevity, and "years survived" is the perfect theme-native
score. **Depends on:** deterministic spawner + save_manager.

---

## Explicitly parked (don't build yet)

- **Multiplayer / co-op** — enormous scope, dilutes the intimate "your body, your
  clock" framing.
- **Crafting / inventory** — fights the premise; you don't *acquire*, you *lose and
  adapt*.
- **Story cutscenes** — the mechanics already tell the story; spend the budget on
  making the body visibly change (1.3) instead.

---

## Guiding tests for any new idea

Before adding anything, it should pass at least two:

1. **Does it deepen loss?** Devolution should feel like a cost even when it opens a door.
2. **Does it make the clock matter?** If it ignores the countdown, it belongs in a
   different game.
3. **Does it stay decoupled?** Devolution and evolution never read each other's state.
4. **Is it visible?** The player should be able to *see* their body and the world change.
