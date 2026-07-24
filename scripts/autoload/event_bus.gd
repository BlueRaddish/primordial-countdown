# event_bus.gd — Autoload
# Global signals. Cross-system signals go through here rather than direct node references.
extends Node

# ---- Player signals ----
signal player_died
signal player_hit(damage: float, knockback_dir: Vector2)
signal player_health_changed(current: float, maximum: float)
signal player_damage_dealt(amount: float)

# ---- Enemy signals ----
signal enemy_died(enemy: Node)
signal enemy_hit(enemy: Node, damage: float, knockback_dir: Vector2)
signal boss_spawned(boss: Node, max_health: float)
signal boss_health_changed(current: float, maximum: float)
signal boss_defeated

# ---- Combat signals ----
signal attack_made # Every swing, landed or whiffed. Drives the devolution clock.
signal attack_landed(hit_count: int)

# ---- Trait signals ----
signal trait_changed(trait_name: String, new_stage: int)
signal trait_extinct(trait_name: String)

# ---- Skill signals ----
signal skill_unlocked(skill_data: Resource)
signal skill_assigned(slot_index: int, skill_data: Resource)
signal skill_used(skill_data: Resource)
signal buff_applied(buff_id: String, duration: float, color: Color)
signal buff_expired(buff_id: String)

# ---- Progression signals ----
# devolution_pending fires first so UI can present the step; the trait only
# actually degrades once something calls TraitManager.devolve_trait().
signal devolution_pending(trait_name: String, step_index: int)
signal devolution_applied(trait_name: String, new_stage: int)
signal devolution_progress_changed(progress: float)
signal wave_cleared(wave_number: int)
signal wave_started(wave_number: int, enemy_count: int)

# ---- UI signals ----
signal character_screen_toggled(is_open: bool)
signal god_mode_changed(enabled: bool)

# ---- Navigation signals ----
signal scene_change_requested(scene_path: String)
