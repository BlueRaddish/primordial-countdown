# Ideate — where Primordial Countdown goes next

A working backlog of ideas to make the game deeper, more dynamic, and more tightly
bound to its two pillars: **you devolve** and **the clock counts down**. Ordered by
*when they should be built*, not by how exciting they are — each tier assumes the one
above it is in place. Every idea notes why it serves the theme, because anything that
does not is scope we should cut.

The north star: **the run should read as a body coming apart and improvising around
the wreckage, against a clock that never stops.** Devolution is loss; the only power
you gain is power that grows out of loss.

---

## Tier 0 — just shipped (context for what follows)

- Fullscreen / clean scaling, F11 toggle.
- Mid-air skills refresh the jump → aerial skill chains.
- Trait roster reworked: **Lungs** (swing recovery), **Skin** (passive armor);
  Throat and Speech retired.
- **Evolved traits** — hidden combo unlocks, offered as accept/decline, that grow
  over a lost trait: **Wings** (arms lost), **Hide** (skin + lungs lost).
- New mobility skills: Scramble, Wing Dash, Updraft; plus Curl (Hide).

Everything below builds on this.

---

## Tier 1 — finish the systems we just started

These make the new mechanics feel complete rather than bolted on. Do them first.

### 1.1 Fill out the evolved-trait roster
PLANNING1 section 6 already lists "traits regained": **Tail, Claws, Plates, Gills**.
Turn each into an `EvolvedTraitData` with a hidden loss-combo:

| Evolved | Suggested combo | Role it takes over | Effect sketch |
| --- | --- | --- | --- |
| **Tail** | Legs partial + Head lost | balance/air | Mid-air horizontal correction, a tail-whip attack, better coyote time. |
| **Claws** | Arms lost + Skin lost | the melee arms couldn't give | A natural weapon that *scales with the countdown* — see 3.1. |
| **Plates** | Skin lost + Gut lost | Skin | Flat damage reduction that stacks with knockback resistance. |
| **Gills** | Lungs lost + Eyes lost | Lungs | Pays off only once there's water/hazard terrain (Tier 3). |

**Why:** the design doc already promised these; they turn evolved traits from a
two-item novelty into a real branch of the run. **Depends on:** nothing — the system
exists, this is data + a few stat hooks.

### 1.2 Mutually-exclusive evolved paths
Growing Wings should lock out Claws (both grow from the arm slot). Make
`EvolvedTraitData.replaces_trait` enforce one evolved trait per slot, so choosing one
closes another. **Why:** the theme is a body forced down *one* path; a run where you
grow everything is a power fantasy, not a devolution. **Depends on:** 1.1.

### 1.3 Visible bodies
The player sprite never changes as traits are lost or evolved. At minimum, tint/overlay
per major state (no arms, wings out, hide plated). **Why:** the whole fantasy is
watching your body change; right now it is invisible. **Depends on:** an art pass (can
start with palette swaps and simple attached sprites).

### 1.4 Head's missing skill
Head is the only trait with no full-loss buff (PLANNING1 leaves it undecided). Idea:
**"Instinct"** — with the head's readouts gone, the HUD is dark, but enemies about to
attack flash a tell. You trade *information* for *reflex*. **Why:** closes the last gap
in the trait→skill mapping and leans into the head being about perception.

---

## Tier 2 — make the countdown a decision, not a meter

The year counter is currently something that happens *to* you. Make spending it a
live tactical choice.

### 2.1 Countdown-priced risk/reward moments
Occasional "spend years to change the fight" beats: a shrine that heals for 40 years,
a door that skips a wave for 60. **Why:** the clock is the game's central currency;
let players *choose* to burn it, not just watch it drain. **Depends on:** nothing.

### 2.2 Devolution as a fork (expand player-choice mode)
Player-chosen degradation already exists behind a dev toggle. Promote it: at each step,
choose which of two offered traits degrades. **Why:** turns the fall into a series of
real decisions — "keep my arms one more wave, or my eyes?" **Depends on:** the popup
already supports choice buttons; needs balancing so no order is strictly best.

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
