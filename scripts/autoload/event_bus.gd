# event_bus.gd — Autoload
# Global signals. Cross-system signals go through here rather than direct node references.
extends Node

# ---- Player signals ----
signal player_died
signal player_hit(damage: float, knockback_dir: Vector2)
signal player_health_changed(current: float, maximum: float)

# ---- Enemy signals ----
signal enemy_died(enemy: Node)
signal enemy_hit(enemy: Node, damage: float, knockback_dir: Vector2)

# ---- Combat signals ----
signal attack_landed(hit_count: int)

# ---- Trait signals ----
signal trait_changed(trait_name: String, new_stage: int)
signal trait_extinct(trait_name: String)

# ---- Skill signals ----
signal skill_unlocked(skill_data: Resource)
signal skill_assigned(slot_index: int, skill_data: Resource)

# ---- Progression signals ----
signal devolution_milestone_reached(kill_count: int)
signal wave_cleared(wave_number: int)
signal wave_started(wave_number: int, enemy_count: int)

# ---- UI signals ----
signal character_screen_toggled(is_open: bool)

# ---- Navigation signals ----
signal scene_change_requested(scene_path: String)
