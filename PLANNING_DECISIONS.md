# Decision record

Why the design is what it is. This exists so a settled question stays settled — and so
that reopening one is a deliberate act with the original reasoning in front of you,
rather than an accident.

It replaces two documents that are now folded in here: a full alternative design
(`PLANNING2.md`) and the merge analysis written against it (`PLANNING_CONFLICT.md`).
Both are in git history if the raw text is ever wanted.

For what the game *is*, see `PLANNING1.md`. For what it *does*, `README.md`. For what
is *next*, `ideate.md`.

---

## The history in one paragraph

The project started from a design doc built around two decoupled clocks — you degrade on
your own schedule, the world escalates on its own, and the run is the gap between them.
Partway in, a second document arrived: a complete rewrite framing the project as a
20-minute hackathon build, replacing sections 1–8 wholesale. It proposed a kill-driven
timeline across four named historical eras, six degradation stages per trait, and
"Titan Buffs" as explicitly game-breaking rewards. A third document was then written to
compare the two and name the contradictions. **The build resolved almost every fork in
favour of the original**, with two large exceptions where the rewrite was right.

---

## Where the rewrite won

**Player-chosen degradation.** The original filed this under "possible later, not
scoped." The rewrite made a selection menu core. Shipped: every devolution offers 3
still-degradable traits and the player picks. This turned out to be the single most
important decision in the game — it is what makes the evolved-trait combinations
steerable rather than random, and it converts devolution from something that happens to
you into a decision you own.

**Waves over continuous spawning.** The original left the spawn model open and asked for
both to be built configurable and chosen on feel. The rewrite committed to strict waves.
Shipped as waves, boss every third.

---

## Where the rewrite was rejected

| Fork | Rewrite proposed | Shipped | Why |
| --- | --- | --- | --- |
| **What drives the clock** | Kills, exclusively — no passive decay, no progress without killing | Player action: attacks and skill costs | Kill count per stage is close to fixed, so a kill clock is a fixed schedule with no skill expression. Spending years to *act* makes every skill use a real decision. |
| **System coupling** | One kill counter drives devolution, eras, and everything else | Devolution and evolution kept strictly separate | Coupling them removes all run-to-run variance — the gap between the two schedules *is* the game. `evolution_system.gd` still exists as a stub for exactly this reason. |
| **Stages per trait** | 6 (intact, four linear −20/40/60/80% steps, extinct) | 3 (intact, partial, lost) | Four intermediate percentage steps is a lot of authoring for changes the player cannot feel individually. Three stages make each transition legible. |
| **Buff strength** | "Titan Buffs": 3× global damage, guaranteed 100% crits, immunity to all hitstun, extra lives | Temporary, cooldown-gated skills that soften the fall | The premise dies if devolution becomes a power-up path with a cost attached. Loss has to stay loss. `status_effects.gd` still carries this note where the ceiling is enforced. |
| **Run objective** | Reach 3.5B B.C. and trigger a victory sequence | Survive; the run ends when you are fully devolved | Two incompatible framings. Survival keeps the countdown a threat rather than a goal. |
| **The four eras as content** | Four eras with named bosses, enemy rosters, per-era wave counts and year-per-kill rates | Kept only as the logarithmic era *readout* on the HUD | The era table and the rewrite's own balancing matrix disagreed by roughly 5×, and none of the roster content existed. The readout keeps the feel at none of the cost. |
| **Ice / ranged subsystem** | Deep Freeze, Splinter Spike, Sub-Zero Wave, Glacial Orbit, a scalable upgrade card pool | Not built | Arrived attached to no milestone, and several entries assumed a projectile system nobody had planned. Unrelated to devolution. |
| **Code conventions** | `PascalCase.gd`, a `src/` tree, direct autoload calls, no event bus | `lowercase_underscore.gd`, `scripts/`, `event_bus.gd` | Cheap to settle, expensive to churn. The original convention was already in the tree. |
| **HUD removal at terminal Head** | Hide the entire HUD CanvasLayer | Head degrades precision only (`~25`, then `??`); bars always stay | Hiding the HUD takes the countdown with it. That makes the run unreadable, not harder. |
| **Terminal Eyes** | Screen fully black; one of the two offered buffs did not restore any way to see | Eyes dim the world (55%, then 22%); Echo Sense is the answer to the dark | A choice where one branch ends your ability to play is a trap, not a decision. |

---

## Contradictions the analysis caught

Recorded because they are the kind of error worth recognising a second time, not because
they are still live. All of these were in the rewrite; none survive in the build.

- **The era table and the balancing matrix disagreed by ~5×.** Era 1 spanned ~120 kills
  by the year math and 25 by the pacing table. Every era had the mismatch, and the
  20-minute target depended on which was right.
- **Full devolution was unreachable.** Seven traits at five stages is 35 steps; the run
  granted 20. The original end condition was dead on arrival under the new numbers. The
  build fixes this structurally: 14 steps derived from the 2000-year total, so the
  counter and full devolution land on the same event by construction.
- **The devolution count contradicted its own milestone rule.** One devolution per 5
  kills against the matrix's kill totals gives 29, not the stated 20.
- **The design said the player chooses; the code called `pick_random()`.** Shipped as a
  real choice of 3.
- **The sample `PlayerController.gd` had lost all indentation** and would not compile.

The general lesson, and the reason this file exists: the rewrite's problems were almost
all *internal inconsistency* rather than bad ideas. Content authored against numbers
nobody had reconciled is the work most likely to be thrown away.

---

## Still open

Carried forward as genuinely undecided. The first is the big one.

- **Does the world evolve, or only change?** `evolution_system.gd` is still a stub, so
  today the answer is "neither." Everything about the difficulty curve depends on this,
  and it is the last unbuilt half of the premise. `ideate.md` 3.2.
- **Is the devolution fork balanced?** Choice-of-3 is live, but it is a menu rather than
  a decision if one branch is always right. Needs playtesting, not building.
  `ideate.md` 2.2.
- **Does anything show a trait that is *missing*?** `body_marks.gd` draws what grew
  back; nothing yet draws absence, so "no arms" reads the same as intact.
- **Meta progression.** `save_manager.gd` is scaffolded and unused.
- **Regained-trait scaling.** Whether Claws should sharpen as the clock runs down —
  deliberately deferred to `ideate.md` 3.1.
