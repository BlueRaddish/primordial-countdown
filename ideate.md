# Ideate — where Primordial Countdown goes next

A working backlog of ideas to make the game deeper, more dynamic, and more tightly
bound to its two pillars: **you devolve** and **the clock counts down**. Ordered by
*when they should be built*, not by how exciting they are — each tier assumes the one
above it is in place. Every idea notes why it serves the theme, because anything that
does not is scope we should cut.

The north star: **the run should read as a body coming apart and improvising around
the wreckage, against a clock that never stops.** Devolution is loss; the only power
you gain is power that grows out of loss.

**Next up: Tier 2.** Tiers 0 and 1 are shipped. The devolution *systems* are now
complete — what is still missing is making the countdown itself a decision.

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
