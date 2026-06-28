extends CharacterBody2D

signal player_died(player_node)
signal hit_landed(is_finisher) # ponytail: stage listens for hitstop + shake

@export var is_player_2: bool = false
@export var health_bar : ProgressBar
var proyektil_scene : PackedScene
@onready var cooldown_tembak = $CooldownTembak
@onready var cooldown_pukul  = $CooldownPukul
@onready var sprite           = $AnimatedSprite2D
@onready var punch_box_shape  = $PunchBox/CollisionShape2D

var damage_pukul : int = 10
var input_shoot  = "p1_shoot"
var input_left   = "p1_left"
var input_right  = "p1_right"
var input_jump   = "p1_jump"
var input_crouch = "p1_crouch"
var input_punch  = "p1_punch"
var input_kick   = "p1_kick"

const SPEED         = 300.0
const JUMP_VELOCITY = -600.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var hp                       = 100
var is_punching              = false
var is_stunned               = false
var is_hit                   = false
var is_invincible            = false
var is_dead                  = false
var combo_count              = 0  # 1, 2, 3
var jump_count               = 0
var is_slide_kicking         = false
var is_dash_attacking        = false

# ponytail: projectile stock and reload variables
var shoot_charges            = 3
const MAX_SHOOT_CHARGES      = 3
var is_reloading_shoot       = false
var shoot_cooldown_timer     = 0.0
var reload_timer             = 0.0
const SINGLE_SHOT_COOLDOWN   = 0.5
const FULL_RELOAD_COOLDOWN   = 10.0

var ui_stock_container       : HBoxContainer
var ui_reload_bar            : ProgressBar

func _ready():
	if is_player_2:
		input_left   = "p2_left"
		input_right  = "p2_right"
		input_jump   = "p2_jump"
		input_crouch = "p2_crouch"
		input_punch  = "p2_punch"
		input_shoot  = "p2_shoot"
		input_kick   = "p2_kick"

	punch_box_shape.disabled = true
	# ponytail: size & position hitbox to be horizontal & symmetric
	punch_box_shape.shape = punch_box_shape.shape.duplicate()
	punch_box_shape.shape.size = Vector2(90, 50)
	punch_box_shape.position = Vector2(0, -10)

	if health_bar:
		health_bar.max_value = hp
		health_bar.value     = hp

	var karakter = Global.p2_pilihan if is_player_2 else Global.p1_pilihan
	if karakter == "tesla":
		sprite.sprite_frames = load("res://resources/animasi_tesla.tres")
		damage_pukul         = 5
		proyektil_scene      = load("res://scenes/proyektil_petir.tscn")
	elif karakter == "edison":
		sprite.sprite_frames = load("res://resources/animasi_edison.tres")
		damage_pukul         = 25
		proyektil_scene      = load("res://scenes/proyektil_lampu.tscn")
		
	_setup_projectile_ui()

func _process(delta):
	if is_dead: return
	
	# ponytail: update projectile timers and reload state
	if shoot_cooldown_timer > 0.0:
		shoot_cooldown_timer -= delta
		
	if is_reloading_shoot:
		reload_timer -= delta
		if reload_timer <= 0.0:
			shoot_charges = MAX_SHOOT_CHARGES
			is_reloading_shoot = false
			
	_update_projectile_ui()
	
	var karakter = Global.p2_pilihan if is_player_2 else Global.p1_pilihan

	# Tesla: Crouch + Punch = Slide Kick
	if karakter == "tesla" and Input.is_action_pressed(input_crouch) and Input.is_action_just_pressed(input_punch):
		if not is_punching and not is_stunned and not is_slide_kicking and not is_dash_attacking and cooldown_pukul.is_stopped():
			combo_count = 0 # reset combo agar slide kick tidak trigger smash
			await attack_slide_kick()
			return

	# Tesla: Crouch + Shoot = Dash Attack
	if karakter == "tesla" and Input.is_action_pressed(input_crouch) and Input.is_action_just_pressed(input_shoot):
		if not is_punching and not is_stunned and not is_slide_kicking and not is_dash_attacking and cooldown_pukul.is_stopped():
			combo_count = 0
			await attack_dash()
			return

	if Input.is_action_just_pressed(input_shoot) and not is_punching:
		# ponytail: check projectile stock charges instead of cooldown_tembak
		if shoot_charges > 0 and shoot_cooldown_timer <= 0.0 and not is_reloading_shoot:
			shoot_charges -= 1
			shoot_cooldown_timer = SINGLE_SHOT_COOLDOWN
			
			if shoot_charges == 0:
				is_reloading_shoot = true
				reload_timer = FULL_RELOAD_COOLDOWN
				
			tembak_proyektil()

func _physics_process(delta):
	if is_dead: return
	if not is_on_floor():
		velocity.y += gravity * delta
		if not is_punching and not is_stunned:
			sprite.play("aw")
	else:
		jump_count = 0

	if not is_stunned:
		var karakter_char = Global.p2_pilihan if is_player_2 else Global.p1_pilihan
		# Block normal punch when crouch is held for Tesla (special moves handled in _process)
		var crouch_held = Input.is_action_pressed(input_crouch) and is_on_floor() and karakter_char == "tesla"
		if Input.is_action_just_pressed(input_punch) and not is_punching and not crouch_held:
			if cooldown_pukul.is_stopped():
				attack_punch()
		elif Input.is_action_just_pressed(input_kick) and not is_punching and not crouch_held:
			if cooldown_pukul.is_stopped():
				attack_kick()

	if is_stunned:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 2)
	elif is_punching or is_slide_kicking or is_dash_attacking:
		if is_punching:
			velocity.x = move_toward(velocity.x, 0, SPEED * delta * 5)
		elif is_slide_kicking:
			# Luncuran berkurang perlahan agar terasa berbobot
			velocity.x = move_toward(velocity.x, 0, SPEED * delta * 1.5)
		elif is_dash_attacking:
			velocity.x = move_toward(velocity.x, 0, SPEED * delta * 3)
	else:
		if Input.is_action_pressed(input_crouch) and is_on_floor():
			velocity.x = 0
			if sprite.sprite_frames.has_animation("crouch"):
				if sprite.animation != "crouch":
					sprite.sprite_frames.set_animation_loop("crouch", false)
					sprite.play("crouch")
			else:
				if sprite.animation != "idle":
					sprite.play("idle")
		else:
			var direction = Input.get_axis(input_left, input_right)
			if direction:
				velocity.x = direction * SPEED
				sprite.play("walk")
				sprite.flip_h = direction < 0
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)
				if is_on_floor():
					sprite.play("idle")

		if Input.is_action_just_pressed(input_jump) and (is_on_floor() or jump_count < 2): # ponytail: hardcoded 2 jumps
			velocity.y = JUMP_VELOCITY
			jump_count = 1 if is_on_floor() else jump_count + 1
			if jump_count > 1:
				_spawn_jump_particles()
				_apply_jump_squash()

	$PunchBox.position.x = -55 if sprite.flip_h else 55
	move_and_slide()

# ─── COMBO PUNCH ─────────────────────────────────────────────────────────────

func attack_punch():
	is_punching = true
	combo_count += 1

	# Hit terakhir = finisher (hit ke-3)
	var is_finisher = combo_count >= 3

	# Forward dash — makin kuat tiap hit
	var arah = -1 if sprite.flip_h else 1
	velocity.x = arah * (450.0 + combo_count * 80.0)

	# Finisher (hit ke-3) = Overhead Smash dengan animasi baru
	if is_finisher and sprite.sprite_frames.has_animation("smash"):
		sprite.play("smash")
		# Smash: loncat sedikit ke atas lalu hantam bawah
		velocity.y = -250.0
		
		# Smash Finisher Phases: Wind-up (0.3s), Active (0.2s), Recovery (0.4s)
		await get_tree().create_timer(0.3).timeout
		punch_box_shape.disabled = false
		_spawn_ground_dust()
		await get_tree().create_timer(0.2).timeout
		punch_box_shape.disabled = true
		await get_tree().create_timer(0.4).timeout
		is_punching = false
		
		cooldown_pukul.wait_time = 0.9
		cooldown_pukul.start()
		combo_count = 0
	else:
		if sprite.sprite_frames.has_animation("punch"):
			sprite.play("punch")
			# Standard squish-stretch
			if is_finisher:
				var tw = create_tween()
				tw.tween_property(sprite, "scale", Vector2(1.4, 0.7), 0.06)
				tw.tween_property(sprite, "scale", Vector2(0.7, 1.4), 0.06)
				tw.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)

		punch_box_shape.disabled = false
		await get_tree().create_timer(0.2).timeout
		punch_box_shape.disabled = true
		is_punching = false

		if is_finisher:
			cooldown_pukul.wait_time = 0.9
			cooldown_pukul.start()
			combo_count = 0
		else:
			cooldown_pukul.wait_time = 0.15
			cooldown_pukul.start()

func _on_punch_box_body_entered(body):
	if body == self or not body.has_method("terkena_pukul"):
		return
	var is_finisher: bool
	var dmg: int
	if is_slide_kicking:
		# Slide kick: damage sedang, bukan finisher
		is_finisher = false
		dmg = int(damage_pukul * 2.0)
	elif is_dash_attacking:
		# Dash attack: damage besar, punya hitstop
		is_finisher = true
		dmg = int(damage_pukul * 3.5)
	elif sprite.animation == "kick":
		# Kick biasa: damage 1.5x dari punch biasa
		is_finisher = false
		dmg = int(damage_pukul * 1.5)
	else:
		is_finisher = combo_count >= 3
		dmg = damage_pukul * (3 if is_finisher else max(combo_count, 1))
	body.terkena_pukul(dmg, global_position, is_finisher)
	hit_landed.emit(is_finisher)

# ─── NORMAL KICK (Tombol Kick) ──────────────────────────────────────────────

func attack_kick():
	is_punching = true # Block pergerakan & input pukul lainnya
	var arah = -1 if sprite.flip_h else 1
	velocity.x = arah * 200.0 # melangkah sedikit maju

	if sprite.sprite_frames.has_animation("kick"):
		sprite.play("kick")

	# Kick Phases: Startup (0.1s), Active (0.2s), Recovery (0.2s)
	await get_tree().create_timer(0.1).timeout

	# Aktifkan hitbox tendangan — jangkauan agak lebih jauh dari punch biasa
	punch_box_shape.shape.size = Vector2(100, 55)
	punch_box_shape.position = Vector2(0, 5) # agak ke bawah
	punch_box_shape.disabled = false
	await get_tree().create_timer(0.2).timeout
	punch_box_shape.disabled = true
	
	# Kembalikan hitbox ke ukuran normal
	punch_box_shape.shape.size = Vector2(90, 50)
	punch_box_shape.position = Vector2(0, -10)

	await get_tree().create_timer(0.2).timeout
	is_punching = false
	cooldown_pukul.wait_time = 0.3
	cooldown_pukul.start()

# ─── SLIDE KICK (Crouch + Punch) ────────────────────────────────────────────

func attack_slide_kick():
	is_slide_kicking = true
	var arah = -1 if sprite.flip_h else 1

	if sprite.sprite_frames.has_animation("slide_kick"):
		sprite.play("slide_kick")

	# Luncur ke depan seperti Shadow Fight slide
	velocity.x = arah * 700.0
	velocity.y = 60.0  # mendorong ke tanah agar tidak melayang

	# Slide Kick Phases: Startup (0.2s), Active (0.2s), Recovery (0.2s)
	await get_tree().create_timer(0.2).timeout

	# Aktifkan hitbox — hantam setinggi pinggang kebawah (hit rendah)
	punch_box_shape.shape.size = Vector2(100, 35)
	punch_box_shape.position = Vector2(0, 25) # sedikit ke bawah dari center
	punch_box_shape.disabled = false
	await get_tree().create_timer(0.2).timeout
	punch_box_shape.disabled = true
	
	# Kembalikan hitbox ke ukuran normal
	punch_box_shape.shape.size = Vector2(90, 50)
	punch_box_shape.position = Vector2(0, -10)

	await get_tree().create_timer(0.2).timeout
	is_slide_kicking = false
	cooldown_pukul.wait_time = 0.5
	cooldown_pukul.start()

func _on_punch_box_body_entered_slide(_body):
	# ponytail: slide kick pakai hitbox damage dari _on_punch_box_body_entered yang sudah ada
	pass

# ─── DASH ATTACK (Crouch + Shoot) ────────────────────────────────────────────

func attack_dash():
	is_dash_attacking = true
	var arah = -1 if sprite.flip_h else 1

	if sprite.sprite_frames.has_animation("dash_attack"):
		sprite.play("dash_attack")

	# Dash cepat dan keras seperti Tekken shoulder charge
	velocity.x = arah * 900.0

	# Dash Attack Phases: Startup (0.25s), Active (0.25s), Recovery (0.33s)
	await get_tree().create_timer(0.25).timeout

	# Aktifkan hitbox — hitbox besar, cocok untuk tabrak lari
	punch_box_shape.shape.size = Vector2(120, 70)
	punch_box_shape.position = Vector2(0, -10)
	punch_box_shape.disabled = false
	await get_tree().create_timer(0.25).timeout
	punch_box_shape.disabled = true
	
	# Kembalikan hitbox ke ukuran normal
	punch_box_shape.shape.size = Vector2(90, 50)
	punch_box_shape.position = Vector2(0, -10)

	await get_tree().create_timer(0.33).timeout
	is_dash_attacking = false
	cooldown_pukul.wait_time = 0.7
	cooldown_pukul.start()

func _spawn_ground_dust():
	# ponytail: inline dust cloud saat Overhead Smash mendarat
	var p = CPUParticles2D.new()
	get_parent().add_child(p)
	p.global_position = global_position + Vector2(0, 0)
	p.one_shot        = true
	p.explosiveness   = 0.9
	p.lifetime        = 0.4
	p.amount          = 15
	p.direction       = Vector2(0, -1)
	p.spread          = 80.0
	p.initial_velocity_min = 100.0
	p.initial_velocity_max = 220.0
	p.gravity         = Vector2(0, 300)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	p.color           = Color(0.85, 0.82, 0.75, 0.8)
	p.emitting        = true
	await get_tree().create_timer(0.5).timeout
	p.queue_free()

# ─── HIT REACTION ─────────────────────────────────────────────────────────────

func terkena_pukul(damage_amount, posisi_penyerang, is_finisher = false, custom_color = null):
	if is_invincible or is_dead: return

	# Blocking: kalau sedang crouch, reduksi damage & skip knockback
	if Input.is_action_pressed(input_crouch) and is_on_floor():
		hp -= int(damage_amount * 0.2)
		if health_bar: health_bar.value = hp
		if hp <= 0: die()
		return

	if is_hit: return
	is_hit    = true
	is_stunned = true

	hp -= damage_amount
	if health_bar: health_bar.value = hp

	var arah = -1.0 if posisi_penyerang.x > global_position.x else 1.0
	var kbx  = 800.0 if is_finisher else 500.0
	var kby  = -400.0 if is_finisher else -250.0
	velocity.x = arah * kbx
	velocity.y = kby
	sprite.play("aw")

	# Spawn partikel hit inline — ponytail: CPUParticles2D di sini, bukan scene terpisah
	_spawn_hit_particles(is_finisher, custom_color)

	var stun_dur = 0.5 if is_finisher else 0.35
	await get_tree().create_timer(stun_dur).timeout

	is_hit     = false
	is_stunned = false

	if hp <= 0:
		die()
		return

	# i-frame: berkedip selama 0.5 detik
	is_invincible = true
	var tw = create_tween().set_loops(5)
	tw.tween_property(sprite, "modulate:a", 0.2, 0.05)
	tw.tween_property(sprite, "modulate:a", 1.0, 0.05)
	await get_tree().create_timer(0.5).timeout
	is_invincible = false
	sprite.modulate.a = 1.0

func _spawn_hit_particles(is_finisher: bool, custom_color = null):
	var p = CPUParticles2D.new()
	get_parent().add_child(p)
	p.global_position = global_position + Vector2(0, -80)
	p.one_shot        = true
	p.explosiveness   = 0.95
	p.lifetime        = 0.4
	p.amount          = 20 if is_finisher else 8
	p.emission_shape  = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 10.0
	p.initial_velocity_min   = 150.0 if is_finisher else 80.0
	p.initial_velocity_max   = 300.0 if is_finisher else 150.0
	p.gravity         = Vector2(0, 200)
	p.scale_amount_min = 3.0 if is_finisher else 2.0
	p.scale_amount_max = 6.0 if is_finisher else 3.5

	# ponytail: warna hardcoded per karakter dari Global state, atau custom color jika dispesifikasikan
	if custom_color != null:
		p.color = custom_color
	else:
		var karakter = Global.p2_pilihan if is_player_2 else Global.p1_pilihan
		p.color = Color(1.0, 0.9, 0.2) if karakter == "edison" else Color(0.2, 0.6, 1.0)

	p.emitting = true
	await get_tree().create_timer(0.6).timeout
	p.queue_free()

func _spawn_jump_particles():
	# ponytail: simple inline white dust puff, no dynamic resources
	var p = CPUParticles2D.new()
	get_parent().add_child(p)
	p.global_position = global_position
	p.one_shot        = true
	p.explosiveness   = 0.95
	p.lifetime        = 0.3
	p.amount          = 10
	p.direction       = Vector2(0, 1)
	p.spread          = 90.0
	p.initial_velocity_min   = 60.0
	p.initial_velocity_max   = 120.0
	p.gravity         = Vector2(0, 0)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color           = Color(0.95, 0.95, 0.95, 0.6)
	p.emitting        = true
	await get_tree().create_timer(0.4).timeout
	p.queue_free()

func _apply_jump_squash():
	# ponytail: 2-step squash feedback
	var tw = create_tween()
	tw.tween_property(sprite, "scale", Vector2(0.8, 1.3), 0.05)
	tw.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)

# ─── KEMATIAN ─────────────────────────────────────────────────────────────────

func die():
	if is_dead: return
	is_dead    = true
	is_stunned = true
	set_physics_process(false)
	set_process(false)

	# Rubuhkan sprite
	var tw = create_tween()
	tw.tween_property(sprite, "rotation_degrees", 90.0 * (-1 if sprite.flip_h else 1), 0.4)
	tw.parallel().tween_property(sprite, "modulate:a", 0.0, 1.2)

	player_died.emit(self)

# ─── PROYEKTIL ─────────────────────────────────────────────────────────────────

func tembak_proyektil():
	if not proyektil_scene: return
	var peluru = proyektil_scene.instantiate()
	if "penembak" in peluru: peluru.penembak = self
	peluru.global_position = global_position + Vector2(-50 if sprite.flip_h else 50, 0)
	if "direction" in peluru: peluru.direction = -1 if sprite.flip_h else 1
	get_parent().add_child(peluru)

# (Electric Aura dihapus — diganti Slide Kick + Dash Attack di atas)

# ponytail: setup ammo indicators and reload bar next to player health bar
func _setup_projectile_ui():
	if not health_bar: return
	
	ui_stock_container = HBoxContainer.new()
	health_bar.get_parent().add_child(ui_stock_container)
	ui_stock_container.add_theme_constant_override("separation", 6)
	
	# Match position to the bottom of the player's health bar
	ui_stock_container.anchor_left = health_bar.anchor_left
	ui_stock_container.anchor_right = health_bar.anchor_right
	ui_stock_container.anchor_top = health_bar.anchor_bottom
	ui_stock_container.anchor_bottom = health_bar.anchor_bottom
	ui_stock_container.offset_left = health_bar.offset_left
	ui_stock_container.offset_right = health_bar.offset_right
	ui_stock_container.offset_top = health_bar.offset_bottom + 4
	ui_stock_container.offset_bottom = health_bar.offset_bottom + 19
	
	# Alignments: P2 on right, P1 on left
	if is_player_2:
		ui_stock_container.alignment = BoxContainer.ALIGNMENT_END
	else:
		ui_stock_container.alignment = BoxContainer.ALIGNMENT_BEGIN
		
	# Populate stock visual rectangles
	for i in range(MAX_SHOOT_CHARGES):
		var rect = ColorRect.new()
		rect.custom_minimum_size = Vector2(18, 8)
		var karakter = Global.p2_pilihan if is_player_2 else Global.p1_pilihan
		rect.color = Color(0.2, 0.7, 1.0) if karakter == "tesla" else Color(1.0, 0.8, 0.1)
		ui_stock_container.add_child(rect)
		
	# Create reload bar
	ui_reload_bar = ProgressBar.new()
	health_bar.get_parent().add_child(ui_reload_bar)
	ui_reload_bar.show_percentage = false
	ui_reload_bar.custom_minimum_size = Vector2(90, 4)
	ui_reload_bar.anchor_left = health_bar.anchor_left
	ui_reload_bar.anchor_right = health_bar.anchor_right
	ui_reload_bar.anchor_top = health_bar.anchor_bottom
	ui_reload_bar.anchor_bottom = health_bar.anchor_bottom
	ui_reload_bar.offset_left = health_bar.offset_left
	ui_reload_bar.offset_right = health_bar.offset_right
	ui_reload_bar.offset_top = health_bar.offset_bottom + 21
	ui_reload_bar.offset_bottom = health_bar.offset_bottom + 25
	
	ui_reload_bar.max_value = FULL_RELOAD_COOLDOWN
	ui_reload_bar.value = 0
	ui_reload_bar.visible = false
	
	# Color reload bar according to character color
	var sb = StyleBoxFlat.new()
	var karakter = Global.p2_pilihan if is_player_2 else Global.p1_pilihan
	sb.bg_color = Color(0.2, 0.7, 1.0, 0.6) if karakter == "tesla" else Color(1.0, 0.8, 0.1, 0.6)
	ui_reload_bar.add_theme_stylebox_override("fill", sb)

# ponytail: update visual elements according to ammunition state
func _update_projectile_ui():
	if not ui_stock_container: return
	
	for i in range(MAX_SHOOT_CHARGES):
		var rect = ui_stock_container.get_child(i)
		rect.visible = (shoot_charges > i)
		
	if is_reloading_shoot:
		ui_reload_bar.visible = true
		ui_reload_bar.value = FULL_RELOAD_COOLDOWN - reload_timer
	else:
		ui_reload_bar.visible = false
