# Primordial Countdown: Design

Engine: Godot 4.x
Genre: 2D pixel sidescroller, roguelike run structure
Reference feel: Super Smash Bros. stage combat, not top-down horde survivor

**This is the design doc — what the game is and why.** Two neighbours divide the rest:

| Doc | Holds |
| --- | --- |
| `README.md` | What is built, in mechanical detail — every trait number, every skill, every cooldown. The source of truth for *current behaviour*. |
| `ideate.md` | The forward backlog, tiered by build order. The source of truth for *what is next*. |
| `PLANNING_DECISIONS.md` | Why the design is this and not something else — the record of forks already resolved. Read it before reopening one. |

This file keeps its section numbering stable: `README.md`, `ideate.md`, and several
source files cite it by section (`PLANNING1 section 6`, and so on). Renumber nothing.

> **Status:** milestone 3 complete and then some — the loop exists, both devolution
> and the evolved-trait layer are built, and the art pass has landed. The one large
> piece still unbuilt is world evolution (section 3).

---

## 1. Concept

**You devolve. The world around you evolves.**

The two do not happen together. They are separate systems on separate triggers, and
the gap between them is the run.

Half of that is real today. You devolve, on a clock you spend yourself. The world does
not yet evolve — see section 3.

---

## 2. Settled

| Decision | Detail |
| --- | --- |
| Devolution is a cost | It removes capability. Nothing about it is a reward. |
| Full devolution ends the run | The objective is to survive, not to arrive. |
| The counter *is* the devolution track | One number, counting down, spent by acting. There is no second bar. |
| Degradation is chosen | Each step offers 3 still-degradable traits; the player picks which one falls. |
| Traits are the capability record | The single source of truth for what the player can currently do. |
| Health is a separate track | Never merged with the countdown. |
| Buffs soften the fall | They never reverse it, and never restore what was lost. |
| Loss can open a door | Specific *combinations* of loss grow an evolved trait. Still a fall, different shape. |

---

## 3. The two systems

### Devolution: player-driven

Fed by what the player spends. Every attack and every skill costs years off the
countdown, so how fast you fall depends on how you fight. Two players at the same wave
can be in very different states.

### Evolution: progression-driven — **not built**

`scripts/systems/evolution_system.gd` is a five-line stub and is not in any scene. The
world currently does not gain capability; enemy mix shifts by wave and a boss arrives
every third, but nothing escalates on a schedule of its own.

This is the largest known gap between the design and the build. `ideate.md` 3.2 carries
it. Until it exists, the premise's second half is unearned, and the geological era
readout is flavour rather than a second clock the player can feel.

### Why they stay decoupled

Because the world's schedule is fixed and the player's is not, skill shows up as **how
much capability you still have when the world's next step arrives.** Play efficiently
and you meet an evolved world mostly intact. Play sloppily and you meet the same world
already stripped down.

Link them one-to-one and that variance disappears — the run plays identically every
time. Keep them fully separate in code: `devolution_system.gd` and
`evolution_system.gd` must never read each other's state. This rule survived a full
redesign that proposed collapsing both into a single kill counter; see
`PLANNING_DECISIONS.md`.

---

## 4. Core loop

1. Fight enemies in a side-view arena
2. Attacking and using skills spends years off the countdown
3. At fixed thresholds the run stops and offers a choice of 3 traits — one degrades
4. Certain combinations of loss offer an evolved trait, accept or decline
5. The run ends when the counter reaches 0, which is exactly when you are fully devolved

**End condition:** the counter hitting 0 and full devolution are the same event by
construction, not by coincidence — the 14 degradation steps are derived from the
starting year total so they land together. Section 5 covers the arithmetic.

Death also ends a run. It is a failure state, not the designed ending.

---

## 5. Countdown system

### Settled

- **The year counter is the devolution counter.** One number on the HUD. There is no
  hidden bar behind it and no separate progress meter.
- A run starts at **2000 years** (`starting_years` on the DevolutionSystem node). That
  single figure is the only knob for run length.
- The **14 devolution steps are derived from it**, spread along a growth curve and
  normalised to sum to exactly the starting total. At the shipped growth of 2.0 the
  last step costs 3× the first: `71, 82, 93, ... 203, 214 = 2000`. Devolution starts
  slow and accelerates.
- Alongside the raw number the HUD shows a **logarithmic geological readout**
  (3.50B → 1000). It is a display layer over the same counter, never a second source
  of truth.

### Decided: what the clock spends

Everything routes through one entry point, `spend_years()`. The shipped driver is
**player action** — a normal attack costs 1 year, each skill costs its own amount.
Leaning on skills burns the run faster, which is the intended tension: a 15-year
Apex Instinct is fifteen swings you will never take.

Other drivers remain as exports on `devolution_system.gd` and can be toggled without
rewriting anything: damage dealt, time survived, wave clears, and kills.

**Kills are deliberately off.** Kill count per stage is close to fixed, so a
kill-driven clock is a schedule wearing a costume — no skill expression. A full
redesign once proposed making kills the *only* driver; that was rejected for this
reason (`PLANNING_DECISIONS.md`).

Because devolution is a cost, the player minimises whatever the driver measures. Choose
drivers by asking what behaviour that minimisation produces.

---

## 6. Devolution system

### Settled: traits as capability state

`trait_manager.gd` holds the current stage of every trait and is the single source of
truth. Combat, movement, and UI query it rather than tracking capability themselves.

Each trait moves through **three** stages — `intact`, `partial`, `fully_lost`:

- **Partial** applies a scaling penalty and gives nothing back
- **Full loss** removes the trait's function entirely and grants one skill

Every trait has a real applied effect at *both* stages. Nothing is decorative — if a
number is in `trait_manager.gd`, some system reads it.

The buff softens the fall. It does not reverse it: every one is temporary, on a
cooldown, and none restores the capability that was lost. A redesign proposed
"game-breaking" replacement powers (3× damage, guaranteed crits, extra lives) — this
rule is what rejected them.

### Settled: the player chooses

Each devolution offers **3 randomly drawn traits** that still have room to degrade, and
the player picks which one loses a stage. The order is yours: you decide what to protect
and what to spend, which is also how you steer toward the evolved forms below. The total
is 14 degradations however you order it, so the countdown still lands exactly.

This was "possible later, not scoped" in the original plan. It is now core.

### The seven traits

**Arms, Legs, Gut, Lungs, Eyes, Skin, Head.** Exact numbers live in `README.md`.

Throat and Speech were retired — neither made much physical sense. **Lungs** took over
the throat's job (breath paces how fast you can swing again) and **Skin** is a passive
layer of protection that thins as it degrades. Both feed the evolved forms.

Every one of the seven now has a full-loss skill. Head was the last gap and closed with
**Hindbrain**.

Two constraints learned the hard way, both from rejected proposals:

- **Never remove the player's ability to read the run.** Head degrades *precision*
  (`~25`, then `??`) but never hides the bars themselves. A proposal to strip the whole
  HUD at terminal Head would have taken the countdown with it, making the run
  unreadable rather than harder.
- **Never leave a choice that is strictly a trap.** A proposed terminal Eyes stage
  blacked out the screen and offered a buff that did not restore any way to see.

### Traits regained → evolved traits

Older forms had features modern ones lost, so some devolutions grant rather than remove.
These still count as part of the fall and still cost the same years. They change what
the fall *feels* like, not its direction.

This concept shipped as **evolved traits**: hidden options that surface only when a
specific *combination* of losses is reached, offered once as accept/decline with game
time frozen. Accepting permanently takes over the slot of the trait it grows from, which
closes off the other form that shares that slot.

| Evolved | Grows from | Origin |
| --- | --- | --- |
| **Tail** | Legs | original "traits regained" list |
| **Claws** | Arms | original list |
| **Plates** | Skin | original list |
| **Gills** | Lungs | original list |
| **Wings** | Arms | added later |
| **Hide** | Skin | added later |

All six exist as `EvolvedTraitData` with real effects. Because they read combinations —
some traits lost, others deliberately kept — they are steered toward, not stumbled into.

---

## 7. Combat

### Settled

- 2D side view, knockback matters
- Health is a separate track from the countdown
- **One boss per stage** — every 3rd wave. Twice the size, twice the contact damage,
  420 health, a telegraphed ground slam. Boss waves spawn half the usual minions so the
  boss is the fight.
- **Waves**, not continuous. Decided on feel during milestone 3; continuous spawn is
  dropped.

### Enemies

Three movement patterns, mixed per wave and weighted toward walkers early: **Walker**
(patrols, chases, turns at ledges), **Lunger** (stands off, telegraphs, lunges),
**Hopper** (chases in hops, uses the platforms).

Each wears its own sprite so the pattern is readable before it acts, not only once it
moves.

### Arena

Ground, side walls, eleven platforms in two routes, four of them one-way. Spacing is
sized against the actual jump arc rather than guessed, which makes it a design surface:
**partial legs cannot reach the high route.** Losing a trait closes off part of the
arena before it stops you walking.

### Time freezes on every decision

The character screen, every devolution step, every skill unlock, every evolved-trait
offer, and the death screen all freeze game time. No decision is made under time
pressure. Pauses are refcounted in `GameState` so overlapping screens cannot unpause
each other.

---

## 8. Godot project structure

```
res://
├── assets/          sprites (player, enemies, bosses, arenas, backgrounds, ui), audio, fonts
├── scenes/          main, player, enemies, arenas, ui, vfx
├── scripts/
│   ├── autoload/    game_state, event_bus, audio_manager, save_manager, window_manager
│   ├── player/      player, trait_manager, ability_manager, evolved_trait_manager,
│   │                status_effects, body_marks, slash_effect, aoe_indicator
│   ├── systems/     devolution_system, evolution_system (stub), timeline_clock,
│   │                wave_spawner, spawner, stage_manager, damage_system,
│   │                arena_renderer, parallax_backdrop, camera_follow, death_zone,
│   │                trait_data, skill_data, skill_definitions,
│   │                evolved_trait_data, evolved_trait_definitions
│   ├── enemies/     base_enemy, boss_enemy
│   ├── ui/          hud, character_screen, devolution_popup, evolved_trait_popup,
│   │                skill_unlock_popup, death_screen, main_menu, settings_panel,
│   │                skill_slot_hud, title_art
│   └── utils/
├── resources/
│   └── sprite_frames/   per-character SpriteFrames (.tres)
├── art-resources/   downloaded asset packs + ART_RESOURCES.md (staging, not shipped)
└── addons/
```

`devolution_system.gd` and `evolution_system.gd` are deliberately separate scripts with
no shared state. Keeping them apart in the codebase is what enforces section 3.

`game_state.gd` deliberately does **not** own the countdown. It holds run stats and the
refcounted pause state; the countdown belongs to `devolution_system.gd`.

### Conventions

- Files and folders: lowercase with underscores. Node names inside scenes: PascalCase.
- Cross-system signals go through `event_bus.gd` rather than direct node references.
- Content is data-driven: traits, skills, and evolved traits are `Resource` types, so
  adding one is filling out a definition rather than writing new logic.

A redesign proposed inverting all three — `PascalCase.gd`, a `src/` tree, and direct
autoload calls with no event bus. Not adopted; the tree above is what exists.

### Autoloads

| Autoload | Purpose |
| --- | --- |
| `game_state` | Run stats, refcounted pause state |
| `event_bus` | Global signals |
| `audio_manager` | Music and sfx playback |
| `save_manager` | Meta progression between runs — **exists but unused** |
| `window_manager` | Fullscreen and scaling |

---

## 9. Build order

**Milestone 1: it moves** ✅ — scaffolding, movement, camera, one flat arena.

**Milestone 2: it fights** ✅ — one enemy type, melee with a hitbox, health as a
separate track, knockback both ways.

**Milestone 3: the loop exists** ✅ — wave spawner, the countdown driving devolution,
traits degrading visibly. Exceeded the original bar: degradation is player-chosen rather
than fixed-order, all seven traits are in with both stages, every full loss grants a
skill, and the evolved-trait layer on top was never in the original plan.

**Art pass** ✅ *(unplanned, slotted after 3)* — per-character animated sprites, a
six-layer parallax backdrop, pixel fonts. See `README.md` § Art.

**Milestone 4: both systems run** ⬅ *next* — the honest remaining work:

- Build `evolution_system.gd` for real: enemies gain a capability per wave/boss cleared,
  on a fixed schedule independent of the player's losses (`ideate.md` 3.2)
- Make the era readout mean something — enemies reskin as it rolls over (`ideate.md` 2.3)
- Tune the devolution fork so no degradation order is strictly best (`ideate.md` 2.2)

**Milestone 5: content** — stage variety, terrain that reads traits, audio. The audio
folders are still empty; packs are staged in `art-resources/`.

**Milestone 6: meta and longevity** — `save_manager.gd` is scaffolded and unused.
Between-run unlocks, alternate lineages, seeded daily runs (`ideate.md` tier 4).

The original rule still stands and is why milestone 4 is not "more content":
**do not start milestone 4 until milestone 3 is fun without any art.** Art has since
landed, which makes this easier to fool yourself about. The test is still whether the
fall is interesting to play, not whether it looks good while playing.
