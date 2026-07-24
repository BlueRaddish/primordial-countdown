# Primordial Countdown

A 2D pixel sidescroller roguelike built in Godot 4.x.

**You devolve. The world around you evolves.** See `PLANNING1.md` for the design.

Current state: milestone 3 — *the loop exists*.

---

## Controls

| Input | Action |
| --- | --- |
| `A` / `D` or arrows | Move |
| `Space` / `W` | Jump |
| Left mouse / `J` | Melee attack, aimed at the cursor |
| `Q` / `E` / `R` | Skill slots |
| `C` | Character screen (freezes game time) |
| `Esc` | Pause |

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
| **Legs** | 120 speed, 68px jump | 78 speed, 44px jump | No walking, no jump |
| **Gut** | 1.5 hp/s regen | 0.5 hp/s regen | No regen |
| **Throat** | Normal swing recovery | Swing recovery ×1.5 | Swing recovery ×2.2 |
| **Eyes** | Full brightness | World dims to 55% | World dims to 22% |
| **Speech** | Enemies within 92px chase 35% slower | 46px, 18% slower | No aura |
| **Head** | Exact HUD numbers | Numbers rounded, shown as `~25` | Numbers shown as `??` |

Two of these interact with the arena and the skills in ways worth knowing:

- **Partial legs cannot reach the high route.** A 44px peak rise does not clear the 45px
  steps above the summit. Losing legs closes off part of the arena before it stops you
  walking.
- **Throat degrades your baseline swing speed, and its own full-loss skill fixes it.**
  Lost throat leaves you swinging at ×2.2, but Second Wind cuts it to ×0.25 in bursts.
  Same shape for eyes: the world goes dark, and Echo Sense is how you find things in it.

Head never hides the bars, only the numbers — hiding the whole HUD would make the run
unreadable rather than harder.

---

## Skills

Skills are the buffs granted at full loss. They are never bought or found — each one
appears and disappears purely as a function of trait state, and each is derived from the
core idea of the trait it comes from.

### Single-trait skills

| Skill | Trait | Kind | CD | Effect |
| --- | --- | --- | --- | --- |
| **Gorge** | Gut lost | Buff | 14s | For 6s, 45% of all damage dealt returns as health (omnivamp). The gut can no longer draw nourishment from food, so it draws it from the strike. |
| **Threat Aura** | Speech lost | Buff | 16s | For 8s, take 45% less damage and burn anything that touches you. No voice left to warn with, so the body radiates threat instead. |
| **Adrenal Surge** | Arms lost | Buff | 15s | For 5s, everything deals double damage. PLANNING1 gives arms a damage multiplier at full loss. |
| **Echo Sense** | Eyes lost | Buff | 13s | For 6s, pulse every 0.7s for damage in a 72px radius. Vibration sense: blind, but the ground reports back. |
| **Second Wind** | Throat lost | Buff | 14s | For 5s, attack cooldown drops to a quarter. Free burst attacks — nothing left to pace. |
| **Pounce** | Legs lost | Movement | 3s | Leap toward the cursor. Untouchable for the leap, and it hurts on contact. Alternative movement: it no longer walks anywhere, it arrives. |

### Multi-trait skills

These read a *combination* of capability rather than a single loss, so they can require a
trait to still be working.

| Skill | Requires | Kind | CD | Effect |
| --- | --- | --- | --- | --- |
| **Devastating Kick** | Arms **lost** + Legs intact/partial | Attack | 2.5s | Heavy directional kick, 60 damage in a 32px arc. With the arms gone, the kick becomes the whole moveset. |
| **Apex Instinct** | Gut **lost** + Speech **lost** | Buff | 24s | For 7s: +50% damage, 35% less damage taken, 30% omnivamp. Two silences at once; what remains is entirely appetite. |
| **Blind Fury** | Eyes partial/lost + Arms intact/partial | Attack | 4s | Wide 44px arc sweep, 38 damage. It cannot see what it is hitting. It hits anyway. |

**Head** has no skill yet — `PLANNING1.md` marks its full-loss buff as undecided.

Buffs do not stack multiplicatively into absurdity: the strongest source of omnivamp and
retaliation wins rather than summing, and the shortest attack-cooldown multiplier wins.

Skills are defined in `scripts/systems/skill_definitions.gd`. Add one by appending to
`get_all_skills()` — a skill can carry any combination of an offensive AoE, a timed buff,
and a movement impulse, and applies whichever components are non-zero.

---

## Devolution clock

One hidden `devolution_points` value, one entry point — `add_devolution_points()` — and a
set of driver toggles, per `PLANNING1.md` section 5. Swapping the driver means flipping an
export in `scripts/systems/devolution_system.gd`, not rewriting the system.

**Current driver: attacks made.** Every swing counts, landed or whiffed, including
offensive skill casts. Kills are deliberately off — kill count per stage is close to fixed,
which would make the clock a schedule with no skill expression.

Also available as exports: kills, damage dealt, time survived, wave clears.

Degradation order is **fixed** (milestone 3): the trait list is walked once taking
everything to partial, then again taking everything to lost, so the crippling losses (arms,
legs) land late. Player-chosen degradation is `PLANNING1.md` section 6's "possible later" —
it exists behind a toggle in the character screen's testing panel.

The HUD readout is logarithmic and derived from actual trait state, never stored
separately. It counts down from 3.50B years to 1000 as the player devolves.

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
- **Devolution order: FIXED / PLAYER CHOICE** — flip between milestone 3's fixed order and
  the player-chosen variant.
- **Reset all traits to intact.**

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
A boss health bar appears at the top of the HUD.

---

## Credits

| Asset | Author | License | Link |
| --- | --- | --- | --- |
| Pixel Platformer (1.2) | Kenney | CC0 1.0 | https://kenney.nl/assets/pixel-platformer |
