

# 🛠️ GAME DESIGN DOCUMENT: PROJECT DEVOLUTION**Core Tagline:** *The closer you get to the beginning, the less you have to survive.*  
**Genre:** 2D Side-Scrolling Arena Fighter / Roguelike (Smash Bros Physics + Time Countdown)  
**Target Engine:** Godot 4 (GDScript)  
**Target Match Length:** 20 Minutes (Continuous Survival across 4 Eras)
---## 🎯 HACKATHON STATUS & COMPLETED MILESTONES### ✅ Milestone 1: It Moves (COMPLETED)Project scaffolding and basic player movement in a flat arena. No combat, no enemies, no devolution.*   **Status Indicators Met:**
    *   Project directory matches Section 8 structure.
    *   Autoloads are completely registered and loading.
    *   Player character renders with placeholder art, moves left/right, jumps, and lands on a solid floor.
    *   Camera smoothly tracks and follows the player.
    *   One flat test arena exists with a visible ground plane.
### ✅ Milestone 2: It Fights (COMPLETED)One enemy type, basic melee combat, health as a separate track.*   **Status Indicators Met:**
    *   One enemy type spawns in the arena and executes basic AI loops (patrol/chase).
    *   Player executes a basic melee attack linked to an active collision hitbox.
    *   Enemies take damage, track state variables, and die.
    *   Player registers damage from enemy contacts.
    *   Health bar is fully operational and visible on the active HUD layer.
    *   Smash-style knockback physics function perfectly on both player and enemy characters.
### 🕒 Milestone 3: The Clock Triggers (NEXT UP)Integrating the reverse historical timeline, wave mechanics, and the 5-stage structural degradation loop.
---## 🕒 1. SYSTEM ARCHITECTURE: THE REVERSE TIME ENGINE
The game features no traditional XP. Instead, a **Time Progression Bar** tracks your travel backward into Prehistory. You start in the present day and fight down to the dawn of life.
### 📉 The B.C. Scale & Era TriggersThe 20-minute run is strictly partitioned into 4 distinct historical eras. To survive, you must clear enemy waves to force the timeline backward. 


[Start: 2026 A.D.] ➔ [Ice Age: 10,000 B.C.] ➔ [Mesozoic: 2.5M B.C.] ➔ [Primordial: 250M B.C.] ➔ [Win: 3.5B B.C.]


*   **Total Match Duration:** 1,200 Seconds (20 Minutes).
*   **Time Calculation:** Every second alive automatically subtracts time from the current era. Every enemy kill drops large chunk-modifiers of time.
*   **Devolution Pacing:** A Devolution Selection Menu triggers automatically at fixed historical intervals within each era (5 Devolutions per Era = 20 Total Choices per run).

| Era | Timeline Window | Duration in Run | Waves Config | Era Boss |
| :--- | :--- | :--- | :--- | :--- |
| **1. Modern Holocene** | 2026 A.D. to 10,000 B.C. | Minutes 0:00 – 4:00 | 5 Waves (Hounds/Drones) | **The Industrial Mech** |
| **2. Pleistocene Ice Age** | 10,000 B.C. to 2.5M B.C. | Minutes 4:00 – 9:00 | 6 Waves (Neanderthals/Mammoths) | **The Mammoth King** |
| **3. Mesozoic Era** | 2.5M B.C. to 250M B.C. | Minutes 9:00 – 15:00 | 8 Waves (Raptors/Pterodactyls) | **The Apex Carnivore** |
| **4. Archean Primordial** | 250M B.C. to 3.5B B.C. | Minutes 15:00 – 20:00 | 10 Waves (Trilobites/Anomalocaris) | **The Core Sentient Ooze** |

---

## 🧬 2. DATA DATABASE: THE 5-STAGE DEVOLUTION ARCHITECTURE

Every devolution choice degrades a trait by 1 stage. The debuff effects remain identical across stages 1 to 4, scaling downwards in mechanical performance. When a trait clicks to **Stage 5 (Extinct)**, the base capability is stripped completely, and a **Big Upgrade (Titan Buff)** is unlocked.


Stage 0 (Intact) ➔ Stages 1-4 (Performance Degrades) ➔ Stage 5 (Extinction & Titan Buff)


### 🥩 Gut
*   **The Penalty:** Health regeneration systems degrade; recovery item drops lose efficacy.
    *   *Stage 1:* Health regen speed -20%. Potions heal for 10% less.
    *   *Stage 2:* Health regen speed -40%. Potions heal for 30% less.
    *   *Stage 3:* Health regen speed -60%. Potions heal for 50% less.
    *   *Stage 4:* Health regen speed -80%. Potions heal for 70% less.
*   **Stage 5 (Extinct):** Natural health regeneration drops to 0. Health potion items no longer spawn on the map.
*   **💥 Titan Buff Options:**
    *   *Option A (Primal Carapace):* Global damage output is multiplied by **3.0x**.
    *   *Option B (Metabolic Spike):* Incoming damage is reduced by a flat 50%; lower health scaling adds up to +50% knockback resistance.

### 🫁 Throat & Gills
*   **The Penalty:** Stamina pool capacity shrinks; stamina recovery speeds suffer.
    *   *Stage 1:* Stamina regen speed -20%. Max stamina -10%.
    *   *Stage 2:* Stamina regen speed -40%. Max stamina -20%.
    *   *Stage 3:* Stamina regen speed -60%. Max stamina -45%.
    *   *Stage 4:* Stamina regen speed -80%. Max stamina -60%.
*   **Stage 5 (Extinct):** Stamina recovery ceases entirely. A continuous **Suffocation Meter** appears. You must deal damage to enemies to keep the meter full; dropping to zero inflicts high passive damage over time.
*   **💥 Titan Buff Options:**
    *   *Option A (Anaerobic Rage):* All abilities bypass cooldown timers entirely when your Suffocation Meter drops below 30%.
    *   *Option B (Vortex Respiration):* Emits a toxic cloud aura that drains health from nearby enemies, filling your life bar.

### 🗣️ Speech
*   **The Penalty:** The knockback radius and stun duration of your Battle Cry ability scale down.
    *   *Stage 1:* Battle Cry range -20%. Cooldown +15%.
    *   *Stage 2:* Battle Cry range -40%. Cooldown +30%.
    *   *Stage 3:* Battle Cry no longer stuns targets (only knocks back).
    *   *Stage 4:* Battle Cry range -80%. Damage -50%.
*   **Stage 5 (Extinct):** **The Battle Cry action is locked out.** All alternative magical or spell-based subsystems are permanently disabled.
*   **💥 Titan Buff Options:**
    *   *Option A (Voodoo Scream):* Taking damage automatically emits a full-screen shockwave that stuns all active targets for 2.5 seconds.
    *   *Option B (Rebirth Echo):* Grants an Extra Life. Upon taking fatal damage, explode in an area-of-effect blast, resetting your health to 100%.

### 🦾 Arms
*   **The Penalty:** Physical arm reach shrinks, rendering close-quarters combat shorter.
    *   *Stage 1:* Melee attack range -20%.
    *   *Stage 2:* Melee attack range -40%.
    *   *Stage 3:* Melee attack range -60%. Cannot interact with environmental stage items or throw blocks.
    *   *Stage 4:* Melee attack range -80%. Ledge-grabbing functionality is disabled.
*   **Stage 5 (Extinct):** **All physical arm or hand-based inputs are disabled.**
*   **💥 Titan Buff Options:**
    *   *Option A (Glacial Orbit):* A permanent protective ring of ice spikes orbits your character model, dealing automated physical damage and applying a freeze status to adjacent targets.
    *   *Option B (Kinetic Repulsion):* Converts 50% of incoming physical damage into a reflective force, snapping it back at attackers.

### 🦿 Legs
*   **The Penalty:** Ground movement acceleration drops; horizontal dash range is penalized.
    *   *Stage 1:* Movement speed and dash distance -20%.
    *   *Stage 2:* Movement speed and dash distance -40%.
    *   *Stage 3:* Movement speed -60%. Jump vertical height is cut in half.
    *   *Stage 4:* Movement speed -80%. Dashing and standard jumping choices are disabled.
*   **Stage 5 (Extinct):** **Standard directional walking inputs and jumping are completely disabled.** The character is rooted to the ground plane.
*   **💥 Titan Buff Options:**
    *   *Option A (Quantum Blink):* Replaces directional movement keys with an instantaneous, infinite-use short-range **Teleport Dash** that moves through solid physics layers.
    *   *Option B (Recoil Jet):* The character hovers above ground blocks with zero friction, navigating platforms purely through the kinetic backward recoil of fired ranged weaponry.

### 👁️ Eyes
*   **The Penalty:** The viewport visibility space undergoes restrictions and heavy blur filters.
    *   *Stage 1:* Screen borders darken with an aggressive vignette layout.
    *   *Stage 2:* Background details, decorations, and non-essential scenery blur out.
    *   *Stage 3:* A thick fog-of-war layer cuts off visibility past a medium ring.
    *   *Stage 4:* Visibility shrinks down into a tight spotlight track directly centered on the player.
*   **Stage 5 (Extinct):** **The game viewport turns completely pitch black.**
*   **💥 Titan Buff Options:**
    *   *Option A (Sonar Matrix):* Platforms, hazardous projectiles, and enemy collision boxes render through neon vector stroke lines against the black screen space.
    *   *Option B (Blindsight Focus):* Blind strikes increase precision accuracy. Every attack that impacts an enemy hitbox lands as a guaranteed **100% Critical Hit**.

### 🧠 Head
*   **The Penalty:** Stat feedback and textual information on future upgrade choices vanish.
    *   *Stage 1:* Numerical values on upgrade panels display as generalized statements (e.g., `+10% Speed` turns to `+More Speed`).
    *   *Stage 2:* The UI clock engine glitched out, spinning characters wildly.
    *   *Stage 3:* Upgrade choice card headers turn to garbled characters, revealing only basic descriptive flavor text blocks.
    *   *Stage 4:* The master screen Health Bar vanishes. Player damage feedback relies entirely on how bright red the character model flashes.
*   **Stage 5 (Extinct):** **The entire HUD layer is stripped from view.** Future choice cards display as blind click selections showing a single `?` icon block.
*   **💥 Titan Buff Options:**
    *   *Option A (Primal Automation):* Total immunity to hit-stun, interrupts, freeze states, and knockback forces.
    *   *Option B (Magnetic Alignment):* All projectile options gain homing behaviors, automatically snapping vectors toward the nearest active enemy target.

---

## 🔮 3. THE SCALABLE BASIC UPGRADE POOL

These standard, scalable cards populate choices alongside the major devolutions. They feature simple numerical scaling designed to offset your current physical penalties.

*   **Deep Freeze (Ice Ability Upgrade):** Extends target frozen frames by +0.5 seconds per level.
*   **Splinter Spike (Ice Ability Upgrade):** Adds +1 additional projectile needle to standard firing trajectories.
*   **Sub-Zero Wave (Ice Ability Upgrade):** Fired projectiles penetrate through an extra target before fracturing.
*   **Density Matrix (Passive Mod):** Cuts incoming enemy smash knockback distance by 15%.
*   **Calloused Involute (Passive Mod):** Flat damage reduction value protection to cushion low health bars.

---

## 🛠️ 4. GODOT 4 PRODUCTION CODE BLUEPRINT (GDSCRIPT)

This clean, centralized state machine tracks your 5-stage devolution progression vectors. It scales physics variables dynamically, bypassing complex multi-file calculations during a rapid hackathon development cycle.

### `DevolutionManager.gd`
```gdscript
extends Node

# Player Trait Arrays: 0 = Intact, 5 = Extinct
var traits = {
	"arms": 0,
	"legs": 0,
	"throat": 0,
	"eyes": 0,
	"head": 0,
	"gut": 0,
	"speech": 0
}

# Stat Modifier Lookup Scales (Indices 0 to 5)
var leg_speed_modifiers: Array[float] = [1.0, 0.8, 0.6, 0.4, 0.2, 0.0]
var leg_jump_modifiers: Array[float]  = [1.0, 1.0, 1.0, 0.5, 0.0, 0.0]
var arm_range_modifiers: Array[float] = [1.0, 0.8, 0.6, 0.4, 0.2, 0.0]

@onready var player: CharacterBody2D = get_tree().get_first_node_in_group("Player")

# Increments a specific trait level and evaluates breaking point states
func devolve_trait(trait_name: String) -> void:
	if traits.has(trait_name) and traits[trait_name] < 5:
		traits[trait_name] += 1
		print_debug("Trait Devolution Advanced: ", trait_name, " Level: ", traits[trait_name])
		recalculate_player_modifiers()
		
		if traits[trait_name] == 5:
			trigger_titan_upgrade_sequence(trait_name)

# Recalculates base player structural variables across mechanics
func recalculate_player_modifiers() -> void:
	if not player: return
	
	# 1. Update Lower Movement Systems via Leg Configuration
	var current_leg_stage = traits["legs"]
	player.SPEED = player.BASE_SPEED * leg_speed_modifiers[current_leg_stage]
	player.JUMP_VELOCITY = player.BASE_JUMP_VELOCITY * leg_jump_modifiers[current_leg_stage]
	
	if current_leg_stage >= 4:
		player.can_jump = false
	if current_leg_stage == 5:
		player.normal_movement_enabled = false
		
	# 2. Update Attack System Range via Arm Configuration
	var current_arm_stage = traits["arms"]
	player.melee_range = player.BASE_MELEE_RANGE * arm_range_modifiers[current_arm_stage]
	
	if current_arm_stage == 5:
		player.arms_actions_blocked = true

	# 3. Process Environmental Shaders via Vision Systems
	if traits["eyes"] == 5:
		player.activate_blind_render_shader()

# Fires UI overlays to switch active inputs to alternative mechanics
func trigger_titan_upgrade_sequence(trait_key: String) -> void:
	get_tree().paused = true
	# Reference your local instantiation of the UI Selection Scene here
	print_all_titan_choices_to_console(trait_key)

func print_all_titan_choices_to_console(key: String) -> void:
	match key:
		"legs":
			print("TITAN UNLOCKED: Choose [A] Quantum Displacement (Blink) or [B] Recoil Jet Physics")
		"arms":
			print("TITAN UNLOCKED: Choose [A] Glacial Orbit Spikes or [B] Kinetic Repulsion Shield")
```

### `PlayerController.gd` (Movement Snippet)
```gdscript
extends CharacterBody2D

class_name Player

const BASE_SPEED = 300.0
const BASE_JUMP_VELOCITY = -400.0
const BASE_MELEE_RANGE = 50.0

var SPEED = 300.0
var JUMP_VELOCITY = -400.0
var melee_range = 50.0

var can_jump: bool = true

var normal_movement_enabled: bool = true
var arms_actions_blocked: bool = false
var teleport_unlocked: bool = false
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
func _physics_process(delta):
# Apply standard physics gravity if falling
if not is_on_floor():
velocity.y += gravity * delta
# Process jump mechanics conditionally based on leg devolution stage
if Input.is_action_just_pressed("ui_accept") and is_on_floor() and can_jump:
velocity.y = JUMP_VELOCITY
# Fetch ground input vectors
var direction = Input.get_axis("ui_left", "ui_right")
if normal_movement_enabled:
if direction:
velocity.x = direction * SPEED
else:
velocity.x = move_toward(velocity.x, 0, SPEED)
else:
# Alternate movement calculations (Titan Teleport / Recoil)
handle_alternate_movement_input(direction)
move_and_slide()
func handle_alternate_movement_input(dir: float) -> void:
if teleport_unlocked and Input.is_action_just_pressed("dash") and dir != 0:
# Leap coordinates instantly along directional vectors
global_position.x += dir * 150.0
spawn_ice_burst_at_footing()
func spawn_ice_burst_at_footing() -> void:
pass # Hook instanced ice asset here for hackathon juice
func activate_blind_render_shader() -> void:
# Access screen space canvas material to enable outlines
pass
```
------------------------------
## 🌊 5. THE HACKATHON WAVE SPAWNING TEMPLATE
This script coordinates your wave structures on a 2D side-scrolling platform map. It stops continuous drops while ensuring an immediate horde surge lands the moment an entire wave is cleared.
## WaveSpawner.gd
```gdscript
extends Node2D
@export var enemy_scenes: Array[PackedScene] # Drop enemy variants into this array via Inspector
@export var spawn_points: Array[Marker2D] # Mark positions on the platform edges
var current_wave: int = 0
var alive_enemies: Array[Node] = []
func _ready() -> void:
start_next_wave()
func start_next_wave() -> void:
current_wave += 1
var spawn_count = 5 + (current_wave * 3) # Scaled multiplier configuration
print_string_wave_log(spawn_count)
for i in range(spawn_count):
spawn_random_enemy()
await get_tree().create_timer(0.2).timeout # Minor staggered offset to avoid overlapping frame lag
func spawn_random_enemy() -> void:
if enemy_scenes.is_empty() || spawn_points.is_empty(): return
var random_enemy_type = enemy_scenes.pick_random().instantiate()
var random_marker = spawn_points.pick_random()
random_enemy_type.global_position = random_marker.global_position
random_enemy_type.connect("tree_exited", Callable(self, "_on_enemy_killed").bind(random_enemy_type))
get_parent().add_child(random_enemy_type)
alive_enemies.append(random_enemy_type)
func _on_enemy_killed(enemy_reference: Node) -> void:
if alive_enemies.has(enemy_reference):
alive_enemies.erase(enemy_reference)
# Insert Reverse Time Engine trigger updates here
# TimeManager.subtract_years(500)
# Strict structural clear verification: triggers the next wave layout instantly
if alive_enemies.is_empty():
print("Wave Cleared completely! Pushing next era surge.")
start_next_wave()
func print_string_wave_log(count: int) -> void:
print("Spawning Wave: ", current_wave, " | Count: ", count)
```
------------------------------
## 🎨 6. USER INTERFACE LAYOUT SPECIFICATION

=======================================================================================
[ ⏳ ERA: MESOZOIC ]    [ 🧬 TIME TRAVELING BAR: 150,000,000 B.C. ]    [ ❤️ HP: 100/100 ]
=======================================================================================

|                                                                                     |
|       (Platform Entry)                                         (Platform Entry)     |
|       [Spawn Node 1] ---------                        --------- [Spawn Node 2]      |
|                                |                      |                             |
|                                |                      |                             |
|                                ------------------------                             |
|                                     [ Main Arena ]                                  |
|                                                                                     |
|   👾 Swarmer                                                               👾 Swarmer|
|                                      🧍 PLAYER                                      |
=======================================================================================

## 🧠 UI Script Adaptation for Head Phase 1–5

   1. Stage 1: In your Card Choice UI item text labels, run a simple regex replacement filter that swaps specific text blocks (like +25% Melee Attack Range) with ambiguous strings (Increases reach slightly).
   2. Stage 2: Access your main UI control nodes using get_node() paths and attach a randomized rotator script to make the text frame jitter or bounce around.
   3. Stage 3: Utilize an alternate font file filled with ancient glyph scripts or randomized symbol layouts to replace the main headers.
   4. Stage 4: Set .visible = false on the root node handling your Health Bar and Shield assets.
   5. Stage 5: Set .visible = false directly onto your root HUD CanvasLayer to drop the player into total immersion.

------------------------------
## 📂 8. PROJECT DIRECTORY ARCHITECTURE
text res:// ├── .godot/ ├── assets/ │ ├── audio/ │ │ ├── music/ │ │ └── sfx/ │ └── textures/ │ ├── enemies/ │ ├── environment/ │ ├── player/ │ └── ui/ ├── src/ │ ├── autoloads/ │ │ ├── DevolutionManager.gd │ │ └── TimeManager.gd │ ├── enemies/ │ │ ├── base_enemy.gd │ │ └── base_enemy.tscn │ ├── environment/ │ │ ├── base_arena.gd │ │ └── base_arena.tscn │ ├── player/ │ │ ├── PlayerController.gd │ │ └── player.tscn │ └── ui/ │ ├── HUD.gd │ ├── hud.tscn │ ├── DevolutionMenu.gd │ └── devolution_menu.tscn ├── icon.svg └── project.godot 






