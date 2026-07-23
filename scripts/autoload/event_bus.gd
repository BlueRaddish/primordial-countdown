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

# ---- Navigation signals ----
signal scene_change_requested(scene_path: String)
