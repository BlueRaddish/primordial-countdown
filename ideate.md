# Ideate — where Primordial Countdown goes next

A working backlog of ideas to make the game deeper, more dynamic, and more tightly
bound to its two pillars: **you devolve** and **the clock counts down**. Ordered by
*when they should be built*, not by how exciting they are — each tier assumes the one
above it is in place. Every idea notes why it serves the theme, because anything that
does not is scope we should cut.

The north star: **the run should read as a body coming apart and improvising around
the wreckage, against a clock that never stops.** Devolution is loss; the only power
you gain is power that grows out of loss.

**Next up: the punch-list below, then Tier 1.5, then Tier 2.3 / Tier 3.**

> This document holds **open work only**. Tiers 0 and 1, the known-issues list, the
> playtest / UI / combat / pacing passes, Tier 2.1 and 2.2, and the punch-list's P0/P1
> items have all shipped and have been pruned out. Git history and
> `.claude/ACTIVE-SESSIONS.md` are the record of what was built and why.

---

## Playtest punch-list — remaining items

From an actual playtest session, each diagnosed against the code. Numbering is the
original playtest numbering, kept so the items stay traceable to that session; the
fixed items are gone, which is why it starts at 6. File/function references are exact;
line numbers drift, so search for the function name if one moved.

**Needs verification, not diagnosis:** *fullscreen* (#4) was fixed by binding both F11
and F12 to `toggle_fullscreen`, but was only ever confirmed in the editor's embedded
window, where mode switches are a known rough edge. Re-test it in an actual export
before assuming it works.

### P2 — UX clarity

**6. More description of what the HUD means / what "years till upgrade" is.** The HUD
(`hud.gd`) shows raw numbers with a label but no explanation: `YEARS LEFT`, a countdown
readout, `Wave: N`, `Kills: N Atk: N` — someone who hasn't read the README has no way to
know years *are* the devolution counter, or that the small readout under it is a
log-scaled "era." There is no tooltip/legend system anywhere in the UI code. **Fix
direction:** this doesn't need new mechanics, just a one-time explainer — either a
first-run overlay, or hover tooltips added to the existing HUD labels.

**7. Remove/streamline the info at the top of the HUD (kill count, year, wave).** This is
in direct tension with item 6 — one asks for more explanation, the other for less
clutter. Both are right about different things: `hud.gd` currently places the year
counter, era readout, wave label, kill/attack counter, elapsed time, and buff list all in
the top-left 8–70px band. **Fix direction:** don't do both blindly — consolidate. Keep
years-left and health prominent (they're the two numbers that matter every second);
demote or move kill count / attack count / elapsed time into the character screen (`C`),
which already exists as the "read the details" surface, rather than trying to explain
seven simultaneous top-left labels in place.

**8. Add a screen describing the different powerups/abilities.** Confirmed missing —
there is no codex/tutorial/description screen anywhere in `scripts/ui/`. The closest
things that exist are `character_screen.gd` (shows current trait stages and grown evolved
traits, but only what you *have*, not what any of it means or what's still out there) and
`skill_unlock_popup.gd` (only shows a skill's own description at the moment it unlocks,
never again as a browsable reference). **Fix direction:** a new screen — could be as
simple as a scrollable list in the existing character-screen style, reusing
`evolved_trait_definitions.gd` and `skill_definitions.gd` as the data source, since both
already carry `description`/`flavor`/requirement text.

**9. Make it clearer skills are interchangeable / why you can't swap mid-game.** The
mid-run lock is intentional, not a bug — `ability_manager.gd`'s own comment explains it:
letting the character screen freely reassign skills mid-fight would drain the tension out
of every hard moment ("slot whatever counters the thing currently killing you, unpause").
Reassignment only opens in the `skill_unlock_popup.gd` window right after learning
something new, and that screen does label itself reasonably well (`"(click a slot to put
the selected skill in it)"`). The actual gap: nothing on the **character screen** (where a
player would go looking mid-fight to swap) explains *why* the slots are locked there or
*when* they'll open again — it just doesn't offer the option, silently. **Fix direction:**
a short, visible note on the character screen's skill panel ("loadout locks after the
unlock window — next chance: your next new skill") rather than a silent no-op.

### P3 — balance

**10. Losing legs is disproportionately punishing.** Grounded in `trait_manager.gd` and
`player.gd`: Legs at Lost sets `is_movement_blocked() = true` and `can_jump() = false`,
removing walking *and* jumping outright — the only trait whose full loss removes a core
verb rather than a secondary system. Its evolved fallback, Tail, only restores **mid-air**
steering (`player.gd::_handle_horizontal_movement`'s tail branch explicitly checks `not
is_on_floor()`) — unlike Claws, which fully restores Arms' actual attack. So even with
Tail grown, ground movement stays gone forever; only the free dash (unaffected by
`movement_enabled`, just shortened) and impulse-based skills still move the player at all.
This is deliberately harsh by design (the trait table says exactly this), but it's the one
trait whose full-loss compensation doesn't actually give back the lost capability, which
is probably why it reads as uniquely brutal rather than just "hard like the others."

**11. Too much life.** Player `max_health = 100` against current numbers: a regular
enemy's contact tick is 6 damage (`base_enemy.gd`), the boss's rebalanced slam/strike are
38/24. A single regular enemy needs ~16 unguarded contacts to kill the player, on top of
Gut's passive regen continuously topping health back up between hits. Worth a numbers
pass, but low-risk to tune since nothing else reads `max_health` structurally.

**12. Gills feel useless without water terrain.** Partly a legibility problem, partly a
real gap. The benefit is not actually gated behind terrain — `player.gd::
_apply_evolved_traits()` applies Gills' swing-penalty cancellation unconditionally the
moment it's grown (`cd_override = get_attack_cooldown_override(); if cd_override > 0.0:
attack_cooldown_mult = cd_override`), no map needed. But it's a passive stat correction
with no visual payoff or dedicated skill (deliberately — Gills is the one evolved trait
with no skill of its own), so it's easy to grow and never notice it did anything. The
water-terrain hook (Tier 3.3, "terrain that reads traits") is the piece that would make
Gills legible, and it's still unbuilt — that half of the complaint is accurate.

### P4 — audio polish

**13. Music sounds jank.** `audio_manager.gd::play_music()` swaps the base↔boss track
with a hard cut — `_play_music_stream()` just calls `.play()` on the new stream instantly,
no fade. The *only* thing that actually crossfades is the late-run tension layer
(`FADE_SPEED`-driven `move_toward` on `volume_db`). So a boss spawning or dying causes an
abrupt track switch while everything else in the audio system fades smoothly — the
inconsistency is likely what reads as "jank" rather than either track individually.
**Fix direction:** give `play_music()` the same fade treatment the tension layer already
has, rather than an instant stream swap.

**14. Tune down the sword noises.** `audio_manager.gd::play_sfx()` has no per-sound volume
calibration at all — every SFX plays at the `AudioStreamPlayer`'s base `volume_db` (0),
so if `sfx_blade_slice.ogg`'s source recording is simply louder than the others, there's
nothing in code compensating for it; the three volume sliders in Settings only scale
whole buses, not individual sounds. **Fix direction:** add a per-SFX `volume_db` offset to
the `SFX` dictionary (or a parallel one), and turn the blade slice down specifically —
cheap, since the plumbing (`play_sfx(id, pitch_variance)`) already takes an `id`.

### P5 — content gaps (bigger asks)

**15. "Teleportation to next level" doesn't work.** There is no level/stage-transition
system anywhere in the code to be broken — confirmed no `teleport`/`portal`/scene-change
logic exists outside `GameState`'s menu↔game transitions. The only thing that could read
as "going somewhere" is `year_shrine.gd`'s PASSAGE shrine, drawn as a doorway, which
*skips the next wave* (`wave_spawner.gd::skip_next_wave()`) rather than transitioning
anywhere — same arena, no scene change. `stage_manager.gd` (meant to eventually swap
era backgrounds — swamp/town/cyberpunk) is confirmed an empty stub per
`ART_RESOURCES.md`. This isn't a bug to patch; it's a feature that was never built. If a
PASSAGE shrine is what was interacted with, it's working as designed but has no dramatic
payoff (the wave just reports "cleared" instantly) — worth its own visual beat regardless
of whether real stage transitions ever get built.

**16. Use the wing skins that already exist.** Already the plan — see Tier 1.5.4 below:
the angel's full idle+run frame set sits in
`art-resources/15_selected_devolution_assets/powerup_reference/`, confirmed the one
genuinely croppable asset from the whole animation review. `body_marks.gd::_draw_wings()`
still draws a procedural polygon today, working but not using this art. No new
diagnosis needed here — it's queued, just not done yet.

---

## Loose ends left by shipped work

Small open items that outlived the passes that created them. None is a feature; each is
something a shipped system deliberately stopped short of.

- **Combat numbers are first-pass and were never feel-tuned.** The telegraph rework's
  interrupt window, the walker's 30px strike reach, and the status (Bleed/Mire/Reeling)
  durations are the three most likely to need adjusting against real play.
- **Settings are not persisted.** `save_manager.gd` still exists and is still unused, so
  every volume slider and accessibility toggle resets on launch. See also Tier 4.1, which
  is the bigger reason to finally wire it up.
- **Control rebinding is a static reference list**, not an actual rebinder.
- **The refused-trait-gets-cheaper lever was never built.** Tier 2.2 shipped the
  protection bias (an intact trait is 1.5× as likely to be offered as a partial one) but
  not the original sketch's idea that declining a trait makes it cheaper to lose later.
  Worth revisiting only if playtesting shows the weighting alone is not enough.

---

## Open: wings art, and the limits of form-swapping

**Wings still have no sourced art.** Searched OpenGameArt and itch.io for a CC0 pack of
*attachable, side-facing* wings and found none — every candidate (birds, bats, angels) is
a whole creature with the wings welded to a body, including the 0x72 angel this project
already staged as "the one EXTRACTABLE asset". At 16x16 with the wings fused to a torso,
cropping it would mean editing art, and the result would not match the 0.6-scaled Gothic
hero anyway. Wings currently remain the procedural pair in `body_marks.gd`, which do beat
faster airborne and mirror with facing (so they are already directional).

Three ways forward, in order of cost:
1. Keep procedural and tune them — free, already directional, but plainly drawn shapes.
2. Commission or hand-author a small 2-frame wing pair — cheapest real art fix.
3. Adopt a full winged character set and swap the whole rig when Wings grow.

**The limit of animation-set swapping.** Losing legs now switches the hero to `crouch` /
`crouch_slash`, which is a genuine visual read for a lost trait with no edited frames.
The same trick does NOT work for arms: there is no "one-armed" animation in the set, and
producing one means redrawing every frame. Currently arms-lost is expressed only through
gameplay (no attack) plus the decay tint. Options are a shader that masks an arm region
(crude on overlapping pixel art), an overlay that hides it, or accepting that some traits
read mechanically rather than visually.

---

## Open: the aging fiction

Not a blocker — the countdown shipped priced in years, and the shrines are one string
change away from any other unit. Recorded for whenever it is worth settling.

A run starts at `starting_years` (`devolution_system.gd`), every normal attack subtracts
exactly 1 year, skills subtract their own cost, and hitting 0 means fully devolved.
Mechanically this works — a clean, tunable countdown, and `README.md`'s "The year counter"
section explains why it's one number instead of a hidden bar. But the fiction under it
doesn't hold up: an ancient body doesn't lose a whole calendar year of pre-existing life
every time it throws a punch, and "years" as a unit implies a chronology that a single
melee swing doesn't plausibly represent.

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
stockpile.

---

## Tier 1.5 — Give the body, the fights, and the world a voice (art + audio pass)

An animation/audio review turned up real, ready-to-use candidates already sitting in
`art-resources/15_selected_devolution_assets/` (avatars, trait/skill references, curated
audio) — copied out of packs already on disk, nothing new downloaded, see
`art-resources/ART_RESOURCES.md` for the full inventory and licenses. Ordered by
payoff-per-effort: the body swap is the single biggest visible win; the VFX trail is
one small code change; the wings crop is polish on something that already works.

### 1.5.1 Body-stage avatars — make devolution visible at the whole-body level
Four frame sets are ready in `avatars/`: `stage1_unarmored_elf_m`, `stage2_rotting_
big_zombie`, `stage3_skeleton_skelet` (each with full idle + run, and a hit frame where
the source pack shipped one), plus `stage4_dead/skull.png`. Stage 0 (Knight) is already
`assets/sprites/player/knight`. **Why:** `body_marks.gd` draws procedural marks for what a
trait *grew back*, but nothing shows a trait that is **missing** — "no arms" and "no legs"
currently read the same as intact. A whole-body stage swap solves that at the level the
north star actually asks for: watching your own silhouette fail, not reading a HUD row.
**Depends on:** nothing new — `devolution_system.gd`'s `total_devolutions` (0-14) is
already the exact signal to drive it, and a whole-body total is the right trigger rather
than any one trait maxing out.

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

### 1.5.2 Audio — remaining gaps
The core wiring shipped: `audio_manager.gd` drives SFX, stingers and music off EventBus,
the player's hurt sound changes with armour state, and a tension layer fades in under 45%
years remaining. What is still open from the original curation:

- The 4 background/tension tracks (`music_swamp_era`, `_town_era`, `_town_era_alt_darker`,
  `_boss_tension`) and 2 drum loops (`_late_run_tension_layer`, `_active_combat_layer`)
  are meant to route through `stage_manager.gd` per era — but `stage_manager.gd` is still
  an empty stub waiting on the parallax-tiling rework (`ART_RESOURCES.md`). Until then
  there is no per-era music switching.
- **No cyberpunk-flavored track exists** for pack 14's era — needs a separate CC0/CC-BY
  synthwave source before that era ships with music that actually fits.
- The two audio-polish punch-list items (#13 music hard-cuts, #14 blade slice too loud)
  belong to this pass too.

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
style, useful for an artist's eye, not for extraction. **Why this is optional:** a working
wing mark already ships (`body_marks.gd::_draw_wings()`, a drawn polygon) — this is a
polish pass on something that works, not a gap. **Implementation:** crop just the wing
shape (transparent elsewhere) from each frame, swap the polygon for a textured `Sprite2D`
positioned/rotated by the same `_phase`-driven beat math already there. **Depends on:**
someone actually doing the crop; lowest priority in this tier.

---

## Tier 2 — make the countdown a decision, not a meter

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
Claws that get *stronger as the clock runs down* — the further devolved, the more feral.
Claws shipped at a flat ×1.15 damage deliberately, with the scaling left here. **Why:**
inverts the usual "you get weaker"; late-run you are a cornered animal, which is exactly
the mood. **Depends on:** a clean read of years-remaining (devolution_system already
exposes `get_years_fraction()`).

### 3.2 Real evolution system (the other half)
`evolution_system.gd` is an empty stub by design (kept decoupled from devolution).
Give it teeth: enemies gain a capability per wave/boss cleared — pack tactics, ranged
attacks, armor — on a fixed schedule independent of your losses. **Why:** the entire
premise is two clocks running against each other; only one is implemented. **Depends
on:** must never read devolution state (PLANNING1 section 3).

### 3.3 Terrain that reads traits
Water pools (Gills matter), dark caves (Eyes matter), high ledges (Wings/Legs matter),
crush hazards (Hide/Plates matter). **Why:** makes each trait's presence or absence a
spatial fact, not just a number. **Depends on:** arena_renderer extension. Also the fix
for punch-list #12 (Gills feel useless).

### 3.4 Environmental mobility
Wall-cling, ledge-grab, ziplines — mobility that isn't a skill. **Why:** the user asked
for a more dynamic, engaging *feel*; traversal verbs do that even between fights.
**Depends on:** player controller work; pairs with Wings/Tail.

### 3.5 Aerial boss phases
A phase where the boss leaves the floor entirely — hovering, diving, or holding a
position only reachable from the high route — so the fight moves into the air rather
than staying a ground brawl with a bigger sprite.

**Why:** the arena is now built for this. The side walls are gone, there are outboard
platforms over open air, and the kit already has Wings, Updraft, Wing Slam and a dash.
Right now every boss phase is fought standing on the floor, which spends none of that.
An aerial phase is also the natural place to make Wings feel like the reward they are
meant to be — and, inverted, to make *lacking* Wings a real problem, which is the
devolution premise doing its job.

**Depends on:** the phase system already exists (66%/33% thresholds in `boss_enemy.gd`),
so this is a new phase behaviour rather than new machinery. Worth pairing with 2.3, the
era-tied boss reskins.

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
  making the body visibly change (1.5.1) instead.

---

## Guiding tests for any new idea

Before adding anything, it should pass at least two:

1. **Does it deepen loss?** Devolution should feel like a cost even when it opens a door.
2. **Does it make the clock matter?** If it ignores the countdown, it belongs in a
   different game.
3. **Does it stay decoupled?** Devolution and evolution never read each other's state.
4. **Is it visible?** The player should be able to *see* their body and the world change.
