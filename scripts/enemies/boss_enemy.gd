# boss_enemy.gd
# Stage boss. PLANNING1 section 7: one boss per stage.
#
# For now it is deliberately cheap, as requested: twice the size of a normal enemy
# and twice the contact damage. The one thing it does beyond that is a telegraphed
# ground slam, so fighting it is not identical to fighting a big walker.
class_name BossEnemy
extends BaseEnemy

@export var slam_interval: float = 4.5
@export var slam_windup: float = 0.7
@export var slam_radius: float = 84.0
@export var slam_damage: float = 22.0
@export var slam_rise: float = -300.0

var _slam_timer: float = 0.0
var _slam_windup_timer: float = 0.0
var _slam_falling: bool = false


func _ready() -> void:
	super()
	_slam_timer = slam_interval
	EventBus.boss_spawned.emit(self, max_health)


func _physics_process(delta: float) -> void:
	super(delta)
	if _state == State.DEAD:
		return
	_process_slam(delta)


func _process_slam(delta: float) -> void:
	# Wind up in place, leap, then slam on landing.
	if _slam_windup_timer > 0.0:
		_slam_windup_timer -= delta
		velocity.x = 0.0
		var pulse: float = 0.5 + 0.5 * sin(_slam_windup_timer * 30.0)
		if _sprite:
			_sprite.modulate = Color(1.0, 0.35 + pulse * 0.5, 0.2)
		if _slam_windup_timer <= 0.0:
			velocity.y = slam_rise
			_slam_falling = true
		return

	if _slam_falling:
		if is_on_floor() and velocity.y >= 0.0:
			_slam_falling = false
			_do_slam()
		return

	# Only wind up when the player is actually in range to be threatened.
	_slam_timer -= delta
	if _slam_timer > 0.0:
		return

	var player: Node2D = _find_player()
	if not player:
		return
	if global_position.distance_to(player.global_position) > slam_radius * 1.6:
		return

	_slam_timer = slam_interval
	_slam_windup_timer = slam_windup


func _do_slam() -> void:
	var origin: Vector2 = global_position

	var indicator: AoEIndicator = AoEIndicator.new()
	indicator.aoe_center = origin
	indicator.aoe_radius = slam_radius
	indicator.aoe_color = Color("c0392b")
	indicator.is_directional = false
	get_parent().add_child(indicator)

	var player: Node2D = _find_player()
	if not player or not player.has_method("take_damage"):
		return
	if origin.distance_to(player.global_position) > slam_radius:
		return

	var dir: float = signf(player.global_position.x - origin.x)
	if dir == 0.0:
		dir = 1.0
	player.call("take_damage", slam_damage, Vector2(dir, -0.7).normalized())


func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	# Bosses shrug off knockback rather than being juggled across the arena.
	super(amount, knockback * 0.25)
	if _state != State.DEAD:
		EventBus.boss_health_changed.emit(get_health_fraction() * max_health, max_health)


func _die() -> void:
	super()
	EventBus.boss_defeated.emit()
