extends Player

# Last direction faced — persists when velocity drops to zero.
var _facing := &"down"

# AnimatedSprite2D replacing the Sprite2D "Character" node from player.tscn.
var _anim_sprite: AnimatedSprite2D
var _shadow_sprite: AnimatedSprite2D

# Stored pre-_ready so PlayerManager can set frames before add_child.
var _pending_frames: SpriteFrames = null


func _ready() -> void:
	_anim_sprite = get_node("Character") as AnimatedSprite2D
	_shadow_sprite = get_node("Shadow") as AnimatedSprite2D
	# Do not call super._ready() — it would try to cast AnimatedSprite2D to
	# the Sprite2D-typed spriteNode and fail. Replicate what super does instead.
	# Base class has `shadowNode: Sprite2D`; we don't assign it (would type-error).
	# Base's _process flip_h logic uses shadowNode but we override _process anyway.
	healthNode = get_node("HealthComponent")
	if stat_budget != null:
		speed = stat_budget.get_speed()
		pushback_strength = stat_budget.get_pushback_strength()
		current_weapon_damage_scale = stat_budget.get_damage_scale()
		if healthNode != null:
			healthNode.max_health = stat_budget.get_max_health()
			healthNode.health = healthNode.max_health
	SignalBus.freeze_game_time.connect(on_freeze_game_time)
	SceneSwitcher.on_map_close_functions.append(hide_player_from_map)
	SignalBus.start_pregame.connect(on_pregame)
	SignalBus.start_ingame.connect(on_ingame)
	if healthNode != null:
		healthNode.health_update.connect(health_update)
		healthNode.entity_died.connect(player_died)
	# Shadow mirrors the character's frames in lockstep — keeps walk anims in sync.
	_anim_sprite.frame_changed.connect(_sync_shadow_frame)
	_anim_sprite.animation_changed.connect(_sync_shadow_animation)
	# Apply frames that were set before add_child
	if _pending_frames != null:
		_set_frames_both(_pending_frames)
		_pending_frames = null
	if _anim_sprite.sprite_frames != null:
		_anim_sprite.play(&"idle_down")


## Called by PlayerManager before or after add_child — safe either way.
func set_sprite_frames(sf: SpriteFrames) -> void:
	if _anim_sprite != null:
		_set_frames_both(sf)
		_anim_sprite.play(&"idle_down")
	else:
		_pending_frames = sf


func _set_frames_both(sf: SpriteFrames) -> void:
	_anim_sprite.sprite_frames = sf
	if _shadow_sprite != null:
		_shadow_sprite.sprite_frames = sf


func _sync_shadow_animation() -> void:
	if _shadow_sprite == null or _shadow_sprite.sprite_frames == null:
		return
	if _shadow_sprite.animation != _anim_sprite.animation:
		_shadow_sprite.play(_anim_sprite.animation)


func _sync_shadow_frame() -> void:
	if _shadow_sprite == null:
		return
	_shadow_sprite.frame = _anim_sprite.frame


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_animation()


func _process(delta: float) -> void:
	if healthNode == null:
		return
	if healthNode.is_dead:
		if _anim_sprite != null:
			_anim_sprite.rotation = 1.5708  # 90 deg in radians
		return
	if _anim_sprite != null:
		_anim_sprite.rotation = 0.0


func _update_animation() -> void:
	if _anim_sprite == null or _anim_sprite.sprite_frames == null:
		return
	if state == States.DEAD:
		return

	var v := velocity
	var moving := v.length_squared() > 0.01

	if moving:
		if absf(v.x) >= absf(v.y):
			_facing = &"right" if v.x > 0 else &"left"
		else:
			_facing = &"down" if v.y > 0 else &"up"
		_play_if_not_current(&"walk_" + _facing)
	else:
		_play_if_not_current(&"idle_" + _facing)


func _play_if_not_current(anim: StringName) -> void:
	if _anim_sprite.animation != anim:
		_anim_sprite.play(anim)
