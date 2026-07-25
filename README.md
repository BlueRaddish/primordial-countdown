# Primordial Countdown

A 2D pixel sidescroller roguelike built in Godot 4.x.

**You devolve. The world around you evolves.** See `PLANNING1.md` for the design.

Current state: milestone 3 — *the loop exists*.

---

## Controls

| Input | Action |
| --- | --- |
| `A` / `D` or arrows | Move |
| `Space` / `W` | Jump — press again in mid-air to double jump. With wings, hold while falling to glide. |
| Left mouse / `J` | Melee attack, aimed at the cursor |
| `Q` / `E` / `R` | Skill slots |
| `C` | Character screen (freezes game time) |
| `F11` / `Alt`+`Enter` | Toggle fullscreen |
| `Esc` | Pause |

Firing **any skill while in mid-air refreshes your jump** (not a double jump — the
ground jump itself is handed back), so weaving a skill into a jump keeps you
airborne. Aerial skill chains are a real mobility option.

## Display

The game renders at a fixed 640×360 and scales up to fill any window or screen
(`canvas_items` stretch, `expand` aspect), so it is fully resizable and
fullscreen-able. `F11` or `Alt`+`Enter` toggles borderless fullscreen; the window
manager lives in `scripts/autoload/window_manager.gd`.

---

## Traits

Traits are the single source of truth for what the player can currently do. Each moves
through three stages, per `PLANNING1.md` section 6:

| Stage | Meaning |
| --- | --- |
| **Intact** | Full capability. |
| **Partial** | A scaling penalty, and nothing in return. |
| **Lost** | The trait's function is removed entirely, and one buff is granted. |

The buff softens the fall. It does not reverse it — every one is temporary and on a
cooldown, and none of them restores the capability that was lost.

Every trait has a real, applied effect at **both** stages. Nothing here is decorative — if
a number is in `trait_manager.gd`, some system reads it.

| Trait | Intact | Partial | Lost |
| --- | --- | --- | --- |
| **Arms** | 25 dmg, 40px reach | 17.5 dmg, 26px reach | No attack at all |
| **Legs** | 120 speed, 68px jump, **double jump** | 78 speed, 44px jump, **no double jump** | No walking, no jump |
| **Gut** | 1.5 hp/s regen | 0.5 hp/s regen | No regen |
| **Lungs** | Normal swing recovery | Swing recovery ×1.5 | Swing recovery ×2.2 |
| **Eyes** | Full brightness | World dims to 55% | World dims to 22% |
| **Skin** | Take 20% less damage | Take 10% less | No protection (take full) |
| **Head** | Exact HUD numbers | Numbers rounded, shown as `~25` | Numbers shown as `??` |

> **Note:** Throat and Speech were retired — they never made much physical sense.
> **Lungs** took over the throat's job (breath paces how fast you can swing again),
> and **Skin** is a passive layer of protection that thins as it degrades. Both feed
> the new evolved traits below.

Two of these interact with the arena and the skills in ways worth knowing:

- **Partial legs cannot reach the high route.** Intact legs jump 68px and double-jump to a
  123px climb; partial legs peak at 44px with no double jump, which does not clear the 45px
  steps above the summit. Losing legs closes off part of the arena before it stops you
  walking.
- **Lungs degrade your baseline swing speed, and their own full-loss skill fixes it.**
  Lost lungs leave you swinging at ×2.2, but Second Wind cuts it to ×0.25 in bursts.
  Same shape for eyes: the world goes dark, and Echo Sense is how you find things in it.
- **Skin is a flat damage sponge.** Intact skin turns aside a fifth of every hit; once it
  is gone the raw body takes hits in full — but grows Thornskin, and, in the right
  combination, either a Hide or a set of Plates (see Evolved traits).

Head never hides the bars, only the numbers — hiding the whole HUD would make the run
unreadable rather than harder. Losing it entirely grants **Hindbrain**, which replaces
the readouts with a reflex: anything about to hit you lights up.

---

## Evolved traits

Some devolutions do not only strip you down — a few *combinations* of losses reopen an
older shape the lineage once had. These are the **evolved traits**: hidden options that
surface only when a specific combination of devolutions is reached, offered once as an
accept/decline popup (game time frozen). Accepting grows the trait, which **permanently
takes over the slot of the trait it grows from**. Declining resumes normal degradation and
leaves the option claimable later from the character screen.

| Evolved trait | Grows when | Slot | Effect |
| --- | --- | --- | --- |
| **Wings** | Arms **lost** + Lungs **intact** + Legs **partial/lost** | Arms | An extra mid-air flap, a glide (hold jump while falling), and the wing skills (Wing Dash, Updraft, Wing Slam). Wings keep the jump alive even after the legs are also gone. |
| **Claws** | Arms **lost** + Skin **lost** | Arms | Your melee attack works again at **×1.15 damage but half the reach** — nothing left to protect, so the limb becomes the weapon. Grants Rend. |
| **Hide** | Skin **intact** + Lungs **lost** + Gut **lost** | Skin | The still-whole skin thickens into a plated hide: heavy **40% flat damage reduction**, far past what intact skin ever gave, plus the Curl skill. |
| **Plates** | Skin **lost** + Gut **lost** | Skin | Bone pushes out through bare flesh: **30% damage reduction** and **65% knockback resistance**. Weaker than a Hide — this is salvage, not growth. Grants Ram. |
| **Tail** | Legs **partial** + Head **lost** | Legs | Real mid-air steering (**×1.9 air control**) that *survives losing the legs entirely*, plus **+0.12s coyote time**. Grants Tail Whip. |
| **Gills** | Lungs **lost** + Eyes **lost** | Lungs | Breathing moves off the ruined lungs, cancelling their **×2.2 swing penalty** outright. No skill — the rest of it waits on water terrain (`ideate.md` 3.3). |

**One evolved trait per slot, permanently.** Wings and Claws both grow from the arms;
Hide and Plates both grow from the skin. Taking one closes the other off for the rest of
the run, and the offer popup names what you are giving up before you accept. The theme is
a body forced down *one* path — a run where you grow everything would be a power fantasy,
not a devolution. A closed-off form stays listed on the character screen, greyed out, so
the choice remains visible.

Because these read *combinations* — some traits lost, others deliberately kept —
they are things you **steer toward** through the devolution choices (below), not
accidents.

They still count as part of the fall — you reach them by losing things — but they change
what the fall *feels* like. Defined in `scripts/systems/evolved_trait_definitions.gd`;
tracked per-player by `scripts/player/evolved_trait_manager.gd`.

---

## The body is visible

The run is about watching a body come apart, so it has to be legible on the body itself,
not only in the HUD. Two channels, both driven from the same trait recalculation:

- **The sprite drains.** It lerps toward a bloodless grey as total degradation rises,
  counting partial stages too — so the colour slides gradually rather than stepping only
  on full losses.
- **Grown parts are drawn.** `scripts/player/body_marks.gd` renders wings (beating faster
  in the air), a tail (swaying against your direction of travel), claws (stubby hooks, to
  say *no reach*), gills, and a plated rim in the Hide's or Plates' colour.

These are procedural shapes, not art, for the same reason the AoE indicators are: they
follow trait state exactly and never go stale when a trait is retuned. Real art replaces
that one node and nothing else. The node stops processing entirely when nothing has grown.

---

## Skills

Skills are the buffs granted at full loss. They are never bought or found — each one
appears and disappears purely as a function of trait state, and each is derived from the
core idea of the trait it comes from.

Every skill costs **years** off the countdown when it fires, on top of its cooldown. A
normal attack costs 1 year for comparison.

### Single-trait skills

| Skill | Trait | Kind | CD | Cost | Effect |
| --- | --- | --- | --- | --- | --- |
| **Gorge** | Gut lost | Buff | 14s | 8 yr | For 6s, 45% of all damage dealt returns as health (omnivamp). The gut can no longer draw nourishment from food, so it draws it from the strike. |
| **Thornskin** | Skin lost | Buff | 16s | 8 yr | For 8s, take 45% less damage and burn anything that touches you. Nothing left to protect the raw flesh, so it answers every touch. |
| **Adrenal Surge** | Arms lost | Buff | 15s | 10 yr | For 5s, everything deals double damage. PLANNING1 gives arms a damage multiplier at full loss. |
| **Echo Sense** | Eyes lost | Buff | 13s | 8 yr | For 6s, pulse every 0.7s for damage in a 72px radius. Vibration sense: blind, but the ground reports back. |
| **Second Wind** | Lungs lost | Buff | 14s | 8 yr | For 5s, attack cooldown drops to a quarter. Free burst attacks — no breath left to pace. |
| **Pounce** | Legs lost | Movement | 3s | **free** | Leap toward the cursor. Untouchable for the leap, and it hurts on contact. Free because with the legs gone it *is* the player's movement — charging for it would charge for walking. |
| **Hindbrain** | Head lost | Buff | 15s | 8 yr | For 8s, every enemy about to hit you lights up, and you take 25% less damage. The readouts are gone for good; this replaces knowing with noticing. |

Every trait now has a full-loss skill — Head was the last gap PLANNING1 left undecided.
Hindbrain restores no information: it marks lungers winding up *and* anything close enough
to land a contact hit, which is the part walkers and hoppers never telegraphed at all.

### Mobility skills

More movement expression, per the redesign. Every one of these — like all skills — also
**refreshes your jump when fired in mid-air**, so they chain into and out of jumps.

| Skill | Source | Kind | CD | Cost | Effect |
| --- | --- | --- | --- | --- | --- |
| **Scramble** | Legs **partial** | Movement | 4s | 1 yr | A short i-frame evasive dash toward the cursor. Appears once the legs start failing; gives way to Pounce at full loss. |
| **Wing Dash** | Wings grown | Movement | 2.5s | **free** | A long horizontal air-dash toward the cursor, untouchable during it. Free — with the arms gone it is core wing mobility, like Pounce. |
| **Updraft** | Wings grown | Movement | 5s | 1 yr | Launch straight up on a burst of air. Hold jump after to glide, reaching the high route from below. |

### Attack + movement skills

Skills that move you *and* hit — the "commit to a strike" verbs. Each carries both an
offensive AoE and an impulse, so it reads as a dash-through, a hit-and-retreat, a dive. All
grant i-frames for their motion, and (like every skill) refresh the jump in mid-air.

| Skill | Source | Kind | CD | Cost | Effect |
| --- | --- | --- | --- | --- | --- |
| **Lunge Strike** | Arms intact/partial + Legs **partial/lost** | Attack | 5s | 2 yr | Dash to the cursor and strike on arrival (42 dmg), untouchable through the lunge. Legs failing → explosive committed lunges. |
| **Backstep Slash** | Arms **partial** | Attack | 5s | 2 yr | Strike toward the cursor (34 dmg), then leap the opposite way. Hit-and-run as the arms weaken. |
| **Wing Slam** | Wings grown | Attack | 4s | 1 yr | Dive toward the cursor and slam down (52 dmg). Best entered from a jump or glide — turns height into damage. |

### Evolved trait skills

The deepest branch in the game: each needs its evolved trait grown, which means a specific
combination of losses, accepted permanently.

| Skill | Source | Kind | CD | Cost | Effect |
| --- | --- | --- | --- | --- | --- |
| **Rend** | Claws grown | Attack | 5s | 2 yr | Tear apart everything at arm's length (58 dmg in a tight 26px radius) and gain 35% omnivamp for 3s. Deliberately short-ranged — claws trade reach for everything else. |
| **Tail Whip** | Tail grown | Attack | 4s | 1 yr | A full 360° sweep, 30 damage in a 48px radius. The one skill that ignores the cursor: a tail does not aim, it clears the ground you are standing on. Spacing, not damage. |
| **Ram** | Plates grown | Attack | 5s | 2 yr | Charge the cursor, bowling over anything in the way (46 dmg). **No i-frames** — ×0.35 damage taken instead. You are armored, not absent. |
| **Curl** | Hide grown | Buff | 18s | 6 yr | For 4s, pull into the hide: take almost no damage (×0.15) and grind anything touching you. |

### Multi-trait skills

These read a *combination* of capability rather than a single loss, so they can require a
trait to still be working.

| Skill | Requires | Kind | CD | Cost | Effect |
| --- | --- | --- | --- | --- | --- |
| **Devastating Kick** | Arms **lost** + Legs intact/partial | Attack | 2.5s | 1 yr | Heavy directional kick, 60 damage in a 32px arc. With the arms gone, the kick becomes the whole moveset — so it is priced as a normal attack. |
| **Apex Instinct** | Gut **lost** + Skin **lost** | Buff | 24s | 15 yr | For 7s: +50% damage, 35% less damage taken, 30% omnivamp. Bare and starving at once; what remains is entirely appetite. |
| **Blind Fury** | Eyes partial/lost + Arms intact/partial | Attack | 4s | 2 yr | Wide 44px arc sweep, 38 damage. It cannot see what it is hitting. It hits anyway. |

All directional skills aim at the **cursor**, recomputed at the moment of firing rather
than inherited from the last melee swing.

**Head** has no skill yet — `PLANNING1.md` marks its full-loss buff as undecided.

Buffs do not stack multiplicatively into absurdity: the strongest source of omnivamp and
retaliation wins rather than summing, and the shortest attack-cooldown multiplier wins.

Skills are defined in `scripts/systems/skill_definitions.gd`. Add one by appending to
`get_all_skills()` — a skill can carry any combination of an offensive AoE, a timed buff,
and a movement impulse, and applies whichever components are non-zero.

---

## The year counter

There is no devolution bar. **The year counter is the devolution counter** — one number,
counting down, shown on the HUD.

| Action | Cost |
| --- | --- |
| Normal attack | 1 year |
| Skill | the skill's own `year_cost` (see the tables above) |
| Pounce | free |

A run starts at **2000 years**. That figure is the single knob for run length:
`starting_years` on the DevolutionSystem node. The 14 devolution steps are *derived* from
it, spread along a growth curve and normalised to sum to exactly `starting_years`, so
raising or lowering it lengthens or shortens the run without desynchronising anything.

At the shipped settings (`devolution_curve_growth = 2.0`, so the last step costs 3× the
first) the schedule works out to:

```
71, 82, 93, 104, 115, 126, 137, 148, 159, 170, 181, 192, 203, 214   = 2000
```

So the first devolution takes ~71 attacks and the last takes ~214: devolution starts slow
and accelerates. Spending your last year lands exactly on your last devolution, so
**reaching 0 means fully devolved**, which is `PLANNING1.md` section 4's end condition.

Because skills are paid for in the same currency, leaning on them burns the run faster.
That is the intended tension — a 15-year Apex Instinct is fifteen swings you will never
take.

Everything routes through one entry point, `spend_years()`, with driver toggles as
`PLANNING1.md` section 5 asks. Swapping what drives the clock means flipping an export in
`scripts/systems/devolution_system.gd`, not rewriting the system. Also available: kills,
damage dealt, time survived, wave clears. Kills are deliberately off — kill count per stage
is close to fixed, which would make the clock a schedule with no skill expression.

Degradation is a **choice**. Each devolution offers a randomized set of **3** traits
that still have room to degrade, and you pick which one loses a stage (`PLANNING1.md`
section 6's player-chosen degradation, promoted from a dev toggle to the standard
flow). The order is now yours: you decide which capabilities to protect and which to
spend, which is also how you steer toward the evolved-trait combos above. The total is
still 14 degradations however you order them, so the countdown schedule lines up
exactly. A dev toggle widens the offer to *every* degradable trait for testing
(`devolution_choice_count` sets the normal count).

Alongside the raw counter the HUD shows a logarithmic geological readout (3.50B → 1000),
which `PLANNING1.md` section 5 settles on. It is a display layer over the same counter,
never a second source of truth.

---

## Time freezes on every screen

Opening the character screen, a devolution step, a skill unlock, or the death screen all
freeze game time, so no decision is made under time pressure. Pauses are refcounted in
`GameState`, so a devolution firing while the character screen is open does not unpause
everything when one of them closes.

---

## Testing tools

Press `C` for the character screen:

- **+ / −** per trait — move any trait to any stage to reach a skill immediately.
- **Take no damage** — the player stops taking damage entirely, and falling into the death
  zone respawns instead of ending the run. The HUD shows a loud green banner while it is on.
- **Zero skill cooldown** — every skill is instantly re-castable.
- **Freeze year counter** — the countdown stops entirely. Attacks and skills cost nothing
  and no devolution ever fires, so a single skill can be exercised for as long as you like
  without the run devolving out from under it. Pair with zero cooldown to hammer one skill
  indefinitely.
- **Devolution options: RANDOM 3 / SHOW ALL** — normal play offers a random 3 traits to
  choose from each step; SHOW ALL reveals every degradable trait so you can steer straight
  to a specific trait or evolved-trait combo.
- **Reset all traits to intact** — also clears any grown evolved traits.

While any of these are on, the HUD shows a loud green `TESTING — …` banner listing exactly
which, so a rigged run is never mistaken for a real one.

`scenes/main/game.tscn` can be launched directly (F6) — it starts a run itself rather than
requiring the menu.

---

## Arena

Ground, side walls, and eleven platforms in two routes. Four are one-way — marked with a
teal highlight, you can jump up through them.

Spacing is sized against the actual jump arc rather than guessed:

```
intact legs:   jump_force = -330  ->  peak rise 330² / (2 × 800) = 68 px
partial legs:  jump_force = -264  ->  peak rise 264² / (2 × 800) = 44 px
									  and move speed drops to 78 px/s
```

- **Main route** (P0–P7): 27px steps with 18px gaps, climbing left to right to the summit
  at y=153 and descending the right-hand side. Stays climbable on partial legs.
- **High route** (P8–P10): 45px steps above the summit. Partial legs peak at 44px, so this
  is intact-legs-only by design.

One-way platforms use a thin 8px collider pinned to the top surface rather than a
full-height one. A thick one-way box lets the player end up *inside* it on the way up and
pop out at the wrong edge — that was the source of the platforms feeling wrong.

Layout lives in `scripts/systems/arena_renderer.gd`, which generates both the tiles and the
colliders from one list.

---

## Enemies

Three movement patterns, mixed per wave and weighted toward walkers early:

| Pattern | Behaviour |
| --- | --- |
| **Walker** | Patrols, chases on sight, turns at ledges and walls rather than walking off. |
| **Lunger** | Closes to a stand-off distance, telegraphs with a visible pulse, then lunges hard. A connecting lunge hits 1.5× harder than a bump. |
| **Hopper** | Chases in hops and jumps when the player is above it, so it uses the platforms. |

**Stage boss** every 3rd wave: twice the size, twice the contact damage, 420 health, and a
telegraphed ground slam. Boss waves spawn half the usual minions so the boss is the fight.

Only the lunger telegraphs on its own. **Hindbrain** (Head lost) makes the rest legible for
its duration: `BaseEnemy.is_telegraphing()` marks a lunger winding up or mid-lunge, plus
any enemy close enough to land contact damage with its cooldown already spent. A hit flash
still overrides the highlight, because taking damage should always read first.
A boss health bar appears at the top of the HUD.

---

## Art

Every character is its own animated sprite from 0x72's DungeonTileset II, at four frames
per idle and run cycle. The three enemy patterns are deliberately given three different
bodies, so a pattern is readable before it acts rather than only once it moves:

| On screen | Sprite | Size |
| --- | --- | --- |
| Player | `knight_m` | 16×28 |
| Walker | `orc_warrior` | 16×23 |
| Lunger | `chort` | 16×23 |
| Hopper | `imp` | 16×16 |
| Stage boss | `big_demon` | 32×36 |

The boss sprite is drawn at native size and needs no scaling: at 32×36 against a 16px
minion it is already the "twice the size" the boss is specified as, which is also why its
collider is 28×40 against a normal enemy's 14×20.

Frames live in `assets/sprites/`, and each pattern's animation set is a `SpriteFrames`
resource in `resources/sprite_frames/`. `base_enemy.gd` picks the set in `_ready()` from
its `behavior`, which the spawner assigns before `add_child()`, so it resolves once per
enemy. The boss brings its own frames and opts out via `use_behavior_sprite = false`.

Behind the arena is a six-layer parallax backdrop (`scripts/systems/parallax_backdrop.gd`).
It is a plain `Node2D` under `Arena` rather than a `ParallaxBackground`, because a
`CanvasModulate` only tints its own canvas layer — a `ParallaxBackground` makes its own, so
the Eyes trait would have dimmed the world and left the sky bright. Keeping the layers in
`Arena` means they darken with everything else.

The layers are pieces of one 1280×720 painting, so each has a fixed place on that canvas —
five bottom-aligned, the cloud band anchored to the top — recorded in `layer_offset_y`. The
canvas hangs by its bottom edge at y=470, well below the ground line, because the painting
puts its peaks mid-frame and the game only shows 360px at a time; anchoring at the ground
left everything worth seeing above the top of the screen.

UI uses Kenney Pixel as the project-wide default font. The year counter overrides it with
Kenney Mini Square Mono: it is the one number that changes constantly, and in a
proportional face the digits are different widths, so counting 2000 down to 0 makes the
readout twitch sideways. Monospace holds it still and keeps the Head trait's degraded
readouts (`~25`, `??`) the same width as the real thing.

---

## Credits

| Asset | Author | License | Link |
| --- | --- | --- | --- |
| Pixel Platformer (1.2) | Kenney | CC0 1.0 | https://kenney.nl/assets/pixel-platformer |
| 16x16 DungeonTileset II (1.7) — player, enemies, boss | 0x72 | CC0 1.0 | https://0x72.itch.io/dungeontileset-ii |
| 2D Platformer Volcano Pack 1.1 — parallax backdrop | Tio Aimar | CC0 1.0 | https://opengameart.org/content/2d-platformer-volcano-pack-11 |
| Pixel Platformer Industrial Expansion — ground tile | Kenney | CC0 1.0 | https://kenney.nl/assets/pixel-platformer-industrial-expansion |
| Kenney Fonts — Kenney Pixel, Kenney Mini Square Mono | Kenney | CC0 1.0 | https://kenney.nl/assets/kenney-fonts |

Every asset above is CC0, so none of this requires attribution — it is here because the
work deserves the credit, not because a licence demands it.

Further packs are staged but not yet used, with a written comparison, in `art-resources/`
(see `art-resources/ART_RESOURCES.md`): Gothicvania sprites, VFX sheets, pixel UI, ~4200
skill icons, SFX and music. Two of those do carry attribution requirements — game-icons.net
is CC BY 3.0 and the Fantasy Ambience music is CC BY 4.0 — so credit them here if they get
used. The staged archives are ~112 MB of originals and are not meant for version control;
add `/art-resources/` to `.gitignore` alongside the existing entries.
