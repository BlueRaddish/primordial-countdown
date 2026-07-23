# Devolution Roguelike: Planning

Engine: Godot 4.x
Genre: 2D pixel sidescroller, roguelike run structure
Reference feel: Super Smash Bros. stage combat, not top down horde survivor

---

## 1. Concept

**You devolve. The world around you evolves.**

The two do not happen together. They are separate systems on separate triggers, and the gap between them is the run.

---

## 2. Settled

| Decision | Detail |
| --- | --- |
| Devolution is a cost | It removes capability. Nothing about it is a reward. |
| Full devolution ends the run | The objective is to survive. |
| Devolution is driven by the bar | Combat performance fills it. Timing varies by player. |
| Evolution is driven by progression | Triggered by clearing waves and beating bosses. Timing is fixed. |
| The two systems are independent | No one to one relationship. They never reference each other. |
| Traits are the capability record | The single source of truth for what the player can currently do. |
| Health is a separate track | Never merged with the devolution bar. |

---

## 3. The two systems

### Devolution: player driven

Fed by combat performance through the devolution bar. How fast it advances depends on how the player plays, so two players reaching the same point in a run can be in very different states.

### Evolution: progression driven

Triggered by clearing waves and beating bosses. It happens on schedule regardless of how the player is doing.

### Why they stay decoupled

Because the world's schedule is fixed and the player's is not, skill shows up as **how much capability you still have when the world's next step arrives.** Play efficiently and you meet an evolved world mostly intact. Play sloppily and you meet the same world already stripped down.

If the two were linked one to one, that variance disappears and the run plays identically every time. Keep them fully separate in code. `devolution_system.gd` and `evolution_system.gd` should never read each other's state.

---

## 4. Core loop

1. Fight enemies in a side view arena
2. Combat performance advances the devolution bar
3. A full bar triggers a devolution: the player loses capability
4. Clearing waves and bosses triggers world evolution: enemies gain capability
5. Run ends when the player is fully devolved

---

## 5. Countdown system

### Settled

- Displayed as a progress bar plus a readout at the top of the screen
- The hidden bar is what actually drives devolution. The readout is a display layer.
- The readout is **logarithmic**, and visibly accelerates as the run progresses

### Undecided: what advances the bar

Not blocking. Build the driver swappable: keep one hidden `devolution_points` integer, and have every candidate source call the same `add_devolution_points()` function. Changing the driver later means toggling which callers are active, not rewriting the system.

Because devolution is a cost, the player will minimize whatever the driver measures.

| Driver | Player minimizes it by | Result |
| --- | --- | --- |
| Kills | Killing less | Kill count per stage is close to fixed, so this becomes a schedule with no skill expression |
| Damage dealt | Not wasting damage on overkill, whiffs, and armor | Rewards precision and target priority |
| Hits landed | Landing fewer, bigger hits | Pushes hard toward heavy slow weapons |
| Time survived | Fighting faster | Pushes aggression, makes defensive play strictly losing |
| Stage clears | Nothing, it is fixed | Fully predictable pacing, zero player agency |

Decide during milestone 3.

---

## 6. Devolution system

### Settled: traits as capability state

Traits are the record of what the player can and cannot do at the current level. `trait_manager` holds the current stage of every trait and is the single source of truth. Combat, movement, and UI all query it rather than tracking capability themselves.

Each trait moves through `intact`, `partial`, `fully_lost`.

- **Partial** applies a scaling penalty with no reward
- **Full loss** removes the trait's function entirely and grants one buff

The buff softens the fall. It does not reverse it.

### Possible later: player chosen degradation

Degradation order is fixed for now. If the animation budget allows, the player could instead choose which trait degrades at each step. That is the same `trait_manager` and the same trait resources with a selection menu in front of it, so it is an addition rather than a rebuild. Not scoped yet.

### Traits lost

| Trait | Partial effect | Full loss effect | Full loss buff |
| --- | --- | --- | --- |
| Arms | Shorter reach | No arm attacks | Damage multiplier |
| Legs | Slower, shorter dash | No walking | Alternative movement |
| Gut | Worse health regen | No regen, no health pickups | Extra life |
| Throat | Slower stamina regen | No stamina regen | Free burst attacks |
| Eyes | Vision dims | See only moving things | Vibration sense |
| Head | Readouts get vaguer | Numbers hidden | Undecided |
| Speech | Weaker battle cry | No battle cry | Permanent aura |

### Traits regained

Older forms had features modern ones lost, so some devolutions grant rather than remove. These still count as devolutions and still advance the bar. They change what the fall feels like, not the direction.

| Trait | Partial gain | Full gain |
| --- | --- | --- |
| Tail | Improved balance, mid air correction | Extra attack |
| Claws | Small natural attack | Natural weapon that scales instead of a held weapon |
| Plates | Minor damage reduction | Flat damage reduction |
| Gills | Extended breath capacity | Full capability in any submerged environment |

---

## 7. Combat

### Settled

- 2D side view
- Knockback matters
- Health is a separate track from devolution
- One boss per stage

### Undecided: spawn model

| Model | For | Against |
| --- | --- | --- |
| Waves | Clear beats, breathing room between waves, suits a fixed arena | Pacing can feel stop and start |
| Continuous | Constant pressure, better sense of being overwhelmed | Harder to place devolution moments cleanly |

Build the spawner so both are configurable from the same resource. Test both in milestone 2 and pick from feel.

---

## 8. Godot project structure

```
res://
├── project.godot
├── docs/
│   └── planning.md
│
├── assets/
│   ├── sprites/
│   │   ├── player/
│   │   ├── enemies/
│   │   ├── bosses/
│   │   ├── arenas/
│   │   └── ui/
│   ├── audio/
│   │   ├── music/
│   │   └── sfx/
│   └── fonts/
│
├── scenes/
│   ├── main/
│   │   ├── main.tscn
│   │   └── game.tscn
│   ├── player/
│   │   └── player.tscn
│   ├── enemies/
│   │   ├── base_enemy.tscn
│   │   └── stage_01/
│   ├── bosses/
│   ├── arenas/
│   │   ├── base_arena.tscn
│   │   └── arena_stage_01.tscn
│   ├── ui/
│   │   ├── hud.tscn
│   │   ├── devolution_screen.tscn
│   │   ├── main_menu.tscn
│   │   └── pause_menu.tscn
│   └── vfx/
│
├── scripts/
│   ├── autoload/
│   │   ├── game_state.gd
│   │   ├── event_bus.gd
│   │   ├── audio_manager.gd
│   │   └── save_manager.gd
│   ├── player/
│   │   ├── player.gd
│   │   ├── player_states/
│   │   ├── trait_manager.gd
│   │   └── ability_manager.gd
│   ├── systems/
│   │   ├── devolution_system.gd
│   │   ├── evolution_system.gd
│   │   ├── timeline_clock.gd
│   │   ├── spawner.gd
│   │   ├── stage_manager.gd
│   │   └── damage_system.gd
│   ├── enemies/
│   │   ├── base_enemy.gd
│   │   └── enemy_states/
│   ├── ui/
│   └── utils/
│
├── resources/
│   ├── traits/
│   ├── abilities/
│   ├── enemies/
│   ├── spawn_patterns/
│   └── stages/
│
└── addons/
```

`devolution_system.gd` and `evolution_system.gd` are deliberately separate scripts with no shared state. Keeping them apart in the codebase is what enforces the decoupling described in section 3.

### Conventions

- Files and folders: lowercase with underscores
- Node names inside scenes: PascalCase
- Cross system signals go through `event_bus.gd` rather than direct node references

### Data driven content

Traits, abilities, spawn patterns, and stages should all be custom `Resource` types saved as `.tres` files in `resources/`. Adding a new trait or spawn pattern is then filling out a form in the inspector, not writing code.

```gdscript
# scripts/systems/trait_data.gd
class_name TraitData
extends Resource

@export var trait_name: String
@export var max_stages: int = 3
@export var partial_stage_effects: Array[String]
@export var full_loss_effect: String
@export var full_loss_buff: String
```

### Autoloads

| Autoload | Purpose |
| --- | --- |
| `game_state` | Current stage, run stats, active traits, world evolution level |
| `event_bus` | Global signals |
| `audio_manager` | Music and sfx playback |
| `save_manager` | Meta progression between runs |

---

## 9. Build order

**Milestone 1: it moves**
Project scaffolding and basic player movement in a flat arena. No combat, no enemies, no devolution.

Done when:
- Project directory matches section 8
- Autoloads registered and loading
- Player character renders with placeholder art, moves left/right, jumps, and lands on a solid floor
- Camera follows the player
- One flat test arena exists with visible ground

**Milestone 2: it fights**
One enemy type, basic melee combat, health as a separate track.

Done when:
- One enemy type spawns in the arena and has basic AI (patrol/chase)
- Player has a basic melee attack with hitbox
- Enemies take damage and die
- Player takes damage from enemies
- Health bar visible on HUD
- Knockback works on both player and enemies

**Milestone 3: the loop exists**
Spawner supporting both waves and continuous, devolution bar, traits with a fixed degradation order. Test both spawn models and pick one.

Done when:
- Spawner runs and populates the arena
- Devolution bar fills from combat performance
- A full bar triggers a devolution step (fixed order)
- At least three traits degrade visibly
- Both spawn models tested, one chosen

**Milestone 4: both systems run**
Evolution system running independently against the player. Full trait list. One boss. Tune the clock driver here, once there is something to tune against.

Done when:
- Evolution system advances on wave/boss clear
- Enemies gain capability at each evolution step
- Full trait list implemented
- One boss with a unique pattern
- Clock driver decided and tuned

**Milestone 5: content**
Stage content, art pass, audio.

**Milestone 6: expand, if time allows**
Scope to be decided with the team.

Do not start milestone 4 until milestone 3 is fun without any art.