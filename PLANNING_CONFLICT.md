# Devolution Roguelike: Merge Analysis

Comparing the previous planning doc against the revised version.

---

## Part 1: What actually changed

The revision is not an edit pass. Sections 1 through 8 of the old doc were replaced wholesale. Below are the core ideas behind the changes, not the line by line differences.

### 1. The project became a hackathon build

Target match length is now 20 minutes. Milestones 1 and 2 are marked complete. The code samples are explicitly written to skip architecture in favor of speed. This reframes every other decision: things that were "build it swappable and decide later" are now "pick one and ship."

### 2. Devolution and evolution were re-coupled

This is the largest change. In the revised doc there is one variable driving everything: **kill count**.

Kills subtract years. Years cross era boundaries. Kill milestones trigger devolution. There is no separate evolution system, no `evolution_system.gd`, and the world does not gain capability. Eras simply swap the enemy roster.

The previous doc's central claim, that the two systems run on independent triggers and the gap between them is the run, is gone.

### 3. The clock driver was decided as kills

Flat years per kill, scaled per era. No passive time decay. The doc is explicit that the game does not progress without kills.

### 4. Devolution went from 3 stages to 6

Old: `intact`, `partial`, `fully_lost`.
New: Stage 0 intact, Stages 1 through 4 as linear percentage degradation, Stage 5 extinct.

Each trait now has authored numbers per stage, mostly 20/40/60/80 percent penalties.

### 5. Buffs became net positive, not softening

Old rule: the buff softens the fall, it does not reverse it.

New: "Titan Buffs" are described as game breaking. Examples include 3.0x global damage, guaranteed 100 percent critical hits, total immunity to hitstun and knockback, and an extra life. Each extinction offers a choice between two of them.

Devolution is now a power up path with a cost attached, rather than a cost with a consolation attached.

### 6. A win condition replaced survival

Old: the run ends when you are fully devolved. Objective is to survive.

New: reaching 3.5 Billion B.C. triggers a victory sequence. Objective is to reach the beginning.

Note that these are not compatible framings, and the new one makes full devolution unreachable anyway. See Part 5.

### 7. Player chosen degradation was promoted from "later" to core

Old: fixed order, with player choice as an unscoped maybe.

New: a Devolution Selection Menu pauses the game at fixed kill milestones, 5 per era, 20 per run. Plus a two option Titan Buff choice at each extinction.

### 8. Historical eras returned, fully specified

Four eras with names, year boundaries, wave counts, enemy types, and named bosses. Modern Holocene, Pleistocene Ice Age, Mesozoic, Archean Primordial.

### 9. Spawn model decided as waves

Strict wave clear. The next wave instances only when the arena is empty. Continuous spawn is dropped.

### 10. An ice and ranged weapon subsystem appeared

Deep Freeze, Splinter Spike, Sub-Zero Wave, Glacial Orbit, plus a basic upgrade pool of scalable cards. The Recoil Jet buff assumes a ranged weapon exists. None of this was in the previous doc and none of it appears in the milestone plan.

### 11. Trait list changed

Throat and Gills merged into one trait. Tail, Claws, and Plates are gone, so the "traits regained" concept is removed entirely. Seven traits remain.

### 12. Code conventions were reversed

Old: `lowercase_underscore.gd`, `scripts/`, all cross system signals through `event_bus.gd`.

New: `PascalCase.gd`, `src/`, no event bus, direct autoload calls. `WaveSpawner` calls `TimeManager` directly, `TimeManager` calls `DevolutionManager` directly.

---

## Part 2: Direct contradictions to resolve

These are not merge conflicts in the file. They are two people currently believing opposite things.

| Topic | Previous doc | Revised doc |
| --- | --- | --- |
| System coupling | Devolution and evolution independent | One kill counter drives everything |
| World evolution | Enemies gain capability over the run | Does not exist |
| Buff strength | Softens the fall, never reverses it | Explicitly game breaking |
| Run objective | Survive as long as possible | Reach 3.5B B.C. and win |
| End of run | Full devolution ends it | Victory sequence ends it |
| Trait choice | Fixed order for now | Player chooses, 20 times per run |
| Eras | Removed as undecided | Four, fully specified |
| Naming | lowercase_underscore | PascalCase |
| Signals | Through event_bus | Direct calls between autoloads |

The first four are design disagreements and need a conversation. The last two are cheap to settle and should be settled before anyone writes more code.

---

## Part 3: Decided

Things both docs agree on, or that the revision settles and nothing contradicts.

- Godot 4, GDScript, 2D side view, pixel art
- Smash style knockback matters
- Health is a numeric bar, separate from devolution
- Melee combat with an activatable hitbox
- Wave based spawning, next wave on full clear
- Devolution is triggered at thresholds, not continuously
- Traits are the single source of truth for player capability
- Traits degrade in stages, with a terminal stage that strips the capability entirely
- Reaching the terminal stage grants a replacement ability
- Seven traits: arms, legs, gut, throat, eyes, head, speech
- Each trait's penalty scales by percentage across intermediate stages
- The devolution menu pauses the game
- Player base stats are stored separately from current stats so modifiers can recalculate
- HUD shows era, timeline position, and health
- Milestones 1 and 2 are complete

---

## Part 4: Undecided

Genuinely open, and the ones marked blocking should be answered this week.

### Blocking

- **Does the world evolve, or only change?** Everything about difficulty curve depends on this. If enemies never gain capability, the only source of rising difficulty is the era roster swap, and the run gets easier every time you take a strong Titan Buff.
- **Is the run survival or a race to the end?** Determines whether the timeline is a threat or a goal.
- **Are buffs net positive or net negative?** These two docs are 180 degrees apart. Pick one before tuning anything.
- **Does the player choose the trait, or is it random?** The doc says the player chooses. The code calls `pick_random()`. One of them is wrong.

### Non blocking

- Number of stages per trait, 3 or 6
- Whether the intermediate stage penalties stay at flat 20/40/60/80 or get hand tuned
- Whether regained traits (tail, claws, plates) come back
- Naming convention and whether an event bus is used
- Whether the ice ability set and basic upgrade pool are in scope at all
- Meta progression between runs

---

## Part 5: Problems found in the revised doc

Not opinions. These are internal contradictions that will surface as bugs.

**The era table and the balancing matrix disagree by roughly 5x.**
Era 1 spans 2026 A.D. to 10,000 B.C. at 100 years per kill, which is about 120 kills. The balancing matrix says 25 kills. Era 2 spans 2.49M years at 15,000 per kill, which is about 166 kills. The matrix says 30. Every era has this mismatch. Either the years per kill values or the kill targets need recalculating, and the 20 minute target depends on which.

**Full devolution is unreachable.**
Seven traits at five stages each is 35 devolution steps. The run grants 20. You cannot fully devolve, so the previous doc's end condition is dead on arrival and the victory condition is the only real ending.

**Devolution count does not match the milestone rule.**
The rule is one devolution per 5 kills. Under the balancing matrix's 145 total kills that gives 29 devolutions, not the stated 20.

**Eyes Stage 5 has a trap option.**
Stage 5 turns the screen fully black. Option A renders geometry as neon outlines. Option B grants critical hits. Picking B means you cannot see the level at all for the rest of the run.

**Head Stage 5 removes the HUD, which removes the clock.**
If the entire HUD CanvasLayer is hidden, the player loses the timeline bar and era readout. Since kills are the only progression mechanism and the timeline is the only feedback on it, this makes the run unreadable rather than harder.

**The code picks a random trait.**
`TimeManager.subtract_years()` calls `DevolutionManager.traits.keys().pick_random()`. The design doc describes a selection menu. The menu does not exist in the code.

**`PlayerController.gd` will not compile as written.**
The `_physics_process` body has lost all indentation. Likely a paste artifact, but worth fixing before anyone copies it.

**The ice and ranged systems have no milestone.**
Splinter Spike, Sub-Zero Wave, and Recoil Jet all assume projectiles exist. No milestone includes building a projectile system.

---

## Part 6: Capabilities required either way

This is the actual build list. Every item here is needed no matter how Part 4 resolves, so none of it is blocked by the disagreements. Start here.

### Player

- `CharacterBody2D` with gravity, floor detection, horizontal movement, jump
- Base constants stored separately from live values, so modifiers can be reapplied from scratch
- A single `recalculate_modifiers()` that rebuilds every live stat from trait state, rather than applying deltas
- Melee attack with a hitbox that activates and deactivates on animation frames
- Health track with damage intake and death
- Knockback intake
- Boolean capability gates read by input handling: can_jump, movement_enabled, arms_blocked
- An alternate movement hook, so a replacement ability can take over when normal movement is disabled

### Enemy

- Base enemy with health, contact damage, and a death signal
- Patrol and chase state machine
- Hitbox and hurtbox on correct collision layers
- Knockback intake

### Combat

- Damage system with a single entry point both player and enemies route through
- Hit registration that emits a signal on kill

### Spawning

- Spawner with configurable spawn point markers
- Enemy scene array assignable in the inspector
- Live enemy tracking with cleanup on death
- Wave clear detection and next wave trigger

### Progression

- One counter advanced by a single function, whatever ends up calling it
- Threshold checks that emit a signal at fixed intervals
- A stage index that increments at boundaries and emits on change
- A numeric readout derived from the counter, not stored separately

### Devolution

- Trait state as a dictionary of name to integer stage
- `devolve_trait(name)` that increments, clamps at max, and triggers recalculation
- Per trait modifier lookup arrays indexed by stage
- Terminal stage detection that fires a separate signal
- Ability grant that flips a flag on the player

### UI

- HUD with health, progress readout, and current stage label
- A pause on trigger selection popup
- Choice cards that display text and return a selection
- A way to hide individual HUD elements independently, since several trait effects target the UI

### Notes on building these

The capability gates and the recalculate function are the load bearing pieces. If every stat is rebuilt from trait state on every change, then any of the Part 4 disagreements can be resolved later by editing lookup tables rather than by editing logic.

Do not build the era table, the buff list, or the ability pool until Part 4 is answered. Those are content, and content written against the wrong framing is the work most likely to be thrown away.