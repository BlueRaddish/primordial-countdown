# audio_manager.gd — Autoload
# Music and SFX playback, driven entirely off EventBus.
#
# Nothing in the game calls this directly: it listens to the same signals the HUD and
# the systems already emit, so adding a sound never means editing gameplay code. If a
# thing is worth hearing, it already has a signal.
#
# BUSES: Master -> {Music, SFX} (default_bus_layout.tres). The settings panel drives
# those three bus volumes by name, which is why they exist rather than every player
# carrying its own volume.
#
# ASSETS: the curated picks from art-resources/15_selected_devolution_assets/audio,
# copied into assets/audio. Licensing is CC0 (Kenney impact sounds + jingles, ansimuz's
# town/cyberpunk era tracks) except MUSIC_BASE, which is North Fantasy Music under
# CC BY 4.0 and is credited in the README — see ART_RESOURCES.md.
#
# FORMAT: everything is OGG Vorbis, as ART_RESOURCES.md asks for. The music started as
# 16-bit WAV (30MB) and was converted with libsndfile via Python's soundfile — there is
# no ffmpeg on this machine. 30MB -> 1.8MB with identical duration, channels and rate.
# Note for anyone repeating it: libsndfile's Vorbis encoder crashes outright on a whole
# 72-second buffer, so the conversion has to be written in blocks.
extends Node

# --- SFX ---
const SFX: Dictionary = {
	"attack": preload("res://assets/audio/sfx/sfx_blade_slice.ogg"),
	"enemy_hit": preload("res://assets/audio/sfx/sfx_punch_flesh_hit.ogg"),
	"boss_slam": preload("res://assets/audio/sfx/sfx_boss_slam_impact.ogg"),
	# The player's own hit sound changes with what is left of their skin — armour
	# state is audible before you look at the health bar.
	"hurt_armored": preload("res://assets/audio/sfx/sfx_plate_hit.ogg"),
	"hurt_skin": preload("res://assets/audio/sfx/sfx_metal_hit.ogg"),
	"hurt_raw": preload("res://assets/audio/sfx/sfx_soft_hit_skin_lost.ogg"),
	# Event stingers.
	"devolution": preload("res://assets/audio/sfx/jingle_devolution_step.ogg"),
	"skill_unlock": preload("res://assets/audio/sfx/jingle_skill_unlock.ogg"),
	"evolved": preload("res://assets/audio/sfx/jingle_evolved_trait_grown.ogg"),
	"death": preload("res://assets/audio/sfx/jingle_full_devolution_death.ogg"),
}

# --- Music ---
# One base track per era (prehistoric/industrial/cyberpunk), keyed by stage_manager.gd's
# StageManager.Era — see its advance_to_era().
const MUSIC_BASE: AudioStream = preload("res://assets/audio/music/music_swamp_era.ogg")
const MUSIC_TOWN: AudioStream = preload("res://assets/audio/music/music_town_era.ogg")
const MUSIC_CYBERPUNK: AudioStream = preload("res://assets/audio/music/music_cyberpunk_era.ogg")
const MUSIC_BOSS: AudioStream = preload("res://assets/audio/music/music_boss_tension.ogg")
# Layered on top rather than replacing the base: the run getting late should sound
# like something added to the world, not like a different track.
const MUSIC_LATE_LAYER: AudioStream = preload(
	"res://assets/audio/music/music_late_run_tension_layer.ogg"
)

# Years-remaining fraction below which the tension layer fades in.
const LATE_RUN_THRESHOLD: float = 0.45
const MUSIC_DB: float = -8.0
const LAYER_DB: float = -14.0
const FADE_SPEED: float = 1.5

# A small pool, so overlapping hits do not cut each other off.
const SFX_VOICES: int = 8

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _music: AudioStreamPlayer
var _layer: AudioStreamPlayer

var _boss_active: bool = false
var _layer_target_db: float = -80.0
var _devolution_system: Node

# What to return to once a boss dies — whichever era track was last playing, so a boss
# fought in the industrial or cyberpunk era doesn't fall back to the prehistoric one.
var _current_era_music: AudioStream = MUSIC_BASE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i: int in range(SFX_VOICES):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sfx_players.append(p)

	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = MUSIC_DB
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	_music.finished.connect(_on_music_finished)
	add_child(_music)

	_layer = AudioStreamPlayer.new()
	_layer.bus = "Music"
	_layer.volume_db = -80.0
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_layer.finished.connect(_on_layer_finished)
	add_child(_layer)

	EventBus.attack_made.connect(_on_attack_made)
	EventBus.enemy_hit.connect(_on_enemy_hit)
	EventBus.player_hit.connect(_on_player_hit)
	EventBus.player_died.connect(_on_player_died)
	EventBus.devolution_applied.connect(_on_devolution_applied)
	EventBus.skill_unlocked.connect(_on_skill_unlocked)
	EventBus.evolved_trait_grown.connect(_on_evolved_grown)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_defeated.connect(_on_boss_defeated)

	call_deferred("_find_systems")


func _find_systems() -> void:
	_devolution_system = get_tree().get_first_node_in_group("devolution_system")


func _process(delta: float) -> void:
	# The late-run layer fades in once the countdown is far enough along, and back out
	# if a run resets. Driven from the countdown rather than from a timer, so it tracks
	# how devolved the player actually is.
	if not _devolution_system:
		_find_systems()
	var want_layer: bool = false
	if _devolution_system and GameState.is_run_active:
		var frac: float = _devolution_system.call("get_years_fraction")
		want_layer = frac <= LATE_RUN_THRESHOLD
	_layer_target_db = LAYER_DB if want_layer else -80.0

	if want_layer and not _layer.playing:
		_play_music_stream(_layer, MUSIC_LATE_LAYER, -80.0)
	_layer.volume_db = move_toward(
		_layer.volume_db, _layer_target_db, FADE_SPEED * 60.0 * delta
	)
	if _layer.volume_db <= -79.0 and _layer.playing and not want_layer:
		_layer.stop()


# ---- Public API ----

func play_sfx(id: String, pitch_variance: float = 0.08) -> void:
	"""Fire a one-shot. Round-robins the voice pool so rapid hits overlap instead of
	cutting each other off."""
	if not SFX.has(id):
		return
	var p: AudioStreamPlayer = _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stream = SFX[id]
	# A little pitch scatter stops a repeated swing sound turning into a machine gun.
	p.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	p.play()


func play_music(stream: AudioStream) -> void:
	if stream != MUSIC_BOSS:
		_current_era_music = stream
	if _music.stream == stream and _music.playing:
		return
	_play_music_stream(_music, stream, MUSIC_DB)


func start_run_music() -> void:
	_boss_active = false
	play_music(MUSIC_BASE)


func stop_music() -> void:
	_music.stop()
	_layer.stop()


# ---- Internals ----

func _play_music_stream(player: AudioStreamPlayer, stream: AudioStream, db: float) -> void:
	# The importer does not mark these as looping, so set it on the resource — a music
	# bed that stops dead after one pass is worse than no music.
	var ogg: AudioStreamOggVorbis = stream as AudioStreamOggVorbis
	if ogg:
		ogg.loop = true
	var wav: AudioStreamWAV = stream as AudioStreamWAV
	if wav and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	player.stream = stream
	player.volume_db = db
	player.play()


func _on_music_finished() -> void:
	# Belt and braces for any stream that will not loop itself.
	if _music.stream:
		_music.play()


func _on_layer_finished() -> void:
	if _layer.stream and _layer_target_db > -79.0:
		_layer.play()


# ---- Event handlers ----

func _on_attack_made() -> void:
	play_sfx("attack")


func _on_enemy_hit(_enemy: Node, _damage: float, _knockback: Vector2) -> void:
	play_sfx("enemy_hit")


func _on_player_hit(_damage: float, _knockback_dir: Vector2) -> void:
	play_sfx(_hurt_sound_for_armor(), 0.05)


func _hurt_sound_for_armor() -> String:
	"""What the player is wearing decides what a hit sounds like: plate over a grown
	Hide, a duller metal over intact skin, wet and soft once the skin is gone."""
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return "hurt_skin"
	var player: Node = players[0]

	if player.has_node("EvolvedTraitManager"):
		var evo: Node = player.get_node("EvolvedTraitManager")
		if evo.call("has_trait", "hide") or evo.call("has_trait", "plates"):
			return "hurt_armored"

	if player.has_node("TraitManager"):
		var tm: TraitManager = player.get_node("TraitManager") as TraitManager
		if tm and tm.get_trait_stage("skin") >= TraitManager.STAGE_LOST:
			return "hurt_raw"
	return "hurt_skin"


func _on_player_died() -> void:
	play_sfx("death", 0.0)
	stop_music()


func _on_devolution_applied(_trait_name: String, _new_stage: int) -> void:
	play_sfx("devolution", 0.0)


func _on_skill_unlocked(_skill: Resource) -> void:
	play_sfx("skill_unlock", 0.0)


func _on_evolved_grown(_evolved_id: String) -> void:
	play_sfx("evolved", 0.0)


func _on_boss_spawned(_boss: Node, _max_health: float) -> void:
	_boss_active = true
	play_music(MUSIC_BOSS)


func _on_boss_defeated() -> void:
	if not _boss_active:
		return
	_boss_active = false
	play_music(_current_era_music)
