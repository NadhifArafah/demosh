extends CharacterBody2D

signal player_died(player_node)
signal hit_landed(is_finisher) # ponytail: stage listens for hitstop + shake

@export var is_player_2: bool = false
@export var health_bar : ProgressBar

#ulti
var ui_ulti_bar              : ProgressBar
var ulti_charge              : float = 0.0
const MAX_ULTI_CHARGE        : float = 100.0
var ulti_scene               : PackedScene
var input_ulti               = "p1_ulti"
#dash
var is_dashing              = false
const DASH_SPEED            = 800.0
const DURASI_DASH           = 0.2

# Node Pendukung Skill & Cooldown (Universal)
@onready var cooldown_skill = $CooldownSkill
@export var cooldown_bar : TextureProgressBar # atau ProgressBar, sesuaikan dengan UI-mu jika ada

var ui_skill_cooldown_bar    : ProgressBar
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
var input_skill  = "p1_skill" # Input skill universal

const SPEED         = 300.0
const JUMP_VELOCITY = -600.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var hp                       = 100
var is_punching              = false
var is_stunned               = false
var is_hit                   = false
var is_invincible            = false
var is_dead                  = false
var is_crouching             = false
var _base_scale : float      = 1.5
var combo_count              = 0  # 1, 2, 3
var jump_count               = 0
var is_slide_kicking         = false
var is_dash_attacking        = false

# Status Universal untuk Skill Luar
var is_casting_skill         = false 

# Data Skill per Karakter
var skill_scene              : PackedScene

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
		input_skill  = "p2_skill"
		input_ulti   = "p2_ulti" # Daftarkan p1_ulti dan p2_ulti di Input Map Editor kamu

	punch_box_shape.disabled = true
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
		skill_scene          = load("res://scenes/skill_petir_tesla.tscn") 
		ulti_scene           = load("res://scenes/ulti_tesla.tscn")
	elif karakter == "edison":
		sprite.sprite_frames = load("res://resources/animasi_edison.tres")
		damage_pukul         = 25
		proyektil_scene      = load("res://scenes/proyektil_lampu.tscn")
		skill_scene          = load("res://scenes/skill_aura_edison.tscn") 
		ulti_scene           = load("res://scenes/ulti_edison.tscn")
		
	_setup_projectile_ui()
	sprite.animation_finished.connect(_on_sprite_animation_finished)

	# Setup Cooldown Timer jika belum diatur di editor
	if not cooldown_skill:
		cooldown_skill = Timer.new()
		cooldown_skill.name = "CooldownSkill"
		cooldown_skill.one_shot = true
		add_child(cooldown_skill)

func _on_sprite_animation_finished() -> void:
	if sprite.animation == "crouch" and sprite.speed_scale < 0.0:
		sprite.speed_scale = 1.0
		_play_anim("idle")

func _process(delta):
	if is_dead: return
	
	# INPUT ULTIMATE (Hanya bisa ditekan jika bar penuh = 100)
	if Input.is_action_just_pressed(input_ulti) and ulti_charge >= MAX_ULTI_CHARGE and not is_stunned and not is_casting_skill:
		_gunakan_ultimate()
	
	# 1. INPUT SKILL YANG SUDAH DIPERBAIKI (SANGAT SENSITIF & RESPONSIF)
	if Input.is_action_just_pressed(input_skill):
		if cooldown_skill.is_stopped() and skill_scene:
			var karakter_saat_ini = Global.p2_pilihan if is_player_2 else Global.p1_pilihan
			
			# Jika Tesla: Wajib diam, tidak boleh sedang dipukul / menyerang
			if karakter_saat_ini == "tesla":
				if not is_punching and not is_stunned and not is_casting_skill:
					_gunakan_skill()
			
			# Jika Edison: LANGSUNG KELUARKAN! Tidak peduli sedang jalan/lompat, yang penting cooldown selesai!
			elif karakter_saat_ini == "edison":
				if not is_stunned: # Hanya mengunci jika Edison sedang pingsan/terkena hit keras
					_gunakan_skill()
	
	if shoot_cooldown_timer > 0.0:
		shoot_cooldown_timer -= delta
		
	if is_reloading_shoot:
		reload_timer -= delta
		if reload_timer <= 0.0:
			shoot_charges = MAX_SHOOT_CHARGES
			is_reloading_shoot = false
			
	_update_projectile_ui()
	_update_cooldown_bar_ui()
	
	var karakter = Global.p2_pilihan if is_player_2 else Global.p1_pilihan

	# Tombol Pemicu Skill (Universal)
	if Input.is_action_just_pressed(input_skill) and not is_punching and not is_stunned and not is_casting_skill:
		if cooldown_skill.is_stopped() and skill_scene:
			_gunakan_skill()

	# Tesla Actions
	if Input.is_action_pressed(input_crouch) and Input.is_action_just_pressed(input_punch):
		if not is_punching and not is_stunned and not is_slide_kicking and not is_dash_attacking and not is_casting_skill and cooldown_pukul.is_stopped():
			combo_count = 0 
			await attack_slide_kick()
			return

	if Input.is_action_pressed(input_crouch) and Input.is_action_just_pressed(input_shoot):
		if not is_punching and not is_stunned and not is_slide_kicking and not is_dash_attacking and not is_casting_skill and cooldown_pukul.is_stopped():
			combo_count = 0
			await attack_dash()
			return

	if Input.is_action_just_pressed(input_shoot) and not is_punching and not is_casting_skill:
		if shoot_charges > 0 and shoot_cooldown_timer <= 0.0 and not is_reloading_shoot:
			shoot_charges -= 1
			shoot_cooldown_timer = SINGLE_SHOT_COOLDOWN
			if shoot_charges == 0:
				is_reloading_shoot = true
				reload_timer = FULL_RELOAD_COOLDOWN
			
			tembak_proyektil()

func _play_anim(anim: StringName) -> void:
	var karakter = Global.p2_pilihan if is_player_2 else Global.p1_pilihan
	
	if karakter=="edison":
		sprite.offset.y = -25.0
	# ─── PROTEKSI SKILL & ULTI TESLA ───
	# Izinkan animasi "skill" DAN "smash" untuk berputar saat casting! 
	# Selain kedua animasi ini (seperti idle/walk), langsung tolak (return).
	if karakter == "tesla" and is_casting_skill and anim != "skill" and anim != "smash":
		return

	if sprite.speed_scale < 0.0: return
	if sprite.animation == anim and sprite.is_playing(): return
	
	sprite.speed_scale = 1.0
	sprite.play(anim)
	
	if not karakter =="edison":sprite.offset.y = 0.0
	sprite.scale    = Vector2(_base_scale, _base_scale)

func _physics_process(delta):
	if is_dead: return
	if not is_on_floor():
		velocity.y += gravity * delta
		if not is_punching and not is_stunned and not is_casting_skill:
			if abs(velocity.x) > 10.0:
				_play_anim("aw")
			else:
				_play_anim("jump")
	else:
		jump_count = 0

	if not is_stunned and not is_casting_skill:
		var karakter_char = Global.p2_pilihan if is_player_2 else Global.p1_pilihan
		var crouch_held = Input.is_action_pressed(input_crouch) and is_on_floor()
		if Input.is_action_just_pressed(input_punch) and not is_punching and not crouch_held:
			if cooldown_pukul.is_stopped():
				attack_punch()
		elif Input.is_action_just_pressed(input_kick) and not is_punching and not crouch_held:
			if cooldown_pukul.is_stopped():
				attack_kick()

	if is_stunned:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 2)
	elif is_punching or is_slide_kicking or is_dash_attacking or is_casting_skill:
		if is_punching:
			velocity.x = move_toward(velocity.x, 0, SPEED * delta * 5)
		elif is_slide_kicking:
			velocity.x = move_toward(velocity.x, 0, SPEED * delta * 1.5)
		elif is_dash_attacking:
			velocity.x = move_toward(velocity.x, 0, SPEED * delta * 3)
		elif is_casting_skill:
			# Skill mengunci pergerakan horizontal total secara universal
			velocity.x = move_toward(velocity.x, 0, SPEED * delta * 10)
	else:
		if Input.is_action_pressed(input_crouch) and is_on_floor():
			# (Bagian logika jongkokmu yang lama tetap biarkan utuh di sini...)
			velocity.x = 0
			if sprite.sprite_frames.has_animation("crouch"):
				if not is_crouching:
					is_crouching = true
					sprite.sprite_frames.set_animation_loop("crouch", false)
					sprite.speed_scale = 1.0
					_play_anim("crouch")
			else:
				_play_anim("idle")
		elif is_crouching and is_on_floor():
			# (Bagian logika berdiri dari jongkokmu yang lama...)
			is_crouching = false
			sprite.speed_scale = -1.0
			sprite.play("crouch")
			sprite.frame = sprite.sprite_frames.get_frame_count("crouch") - 1
			var karakter = Global.p2_pilihan if is_player_2 else Global.p1_pilihan
			
		else:
			# ─── LOGIKA BARU: DASH SAAT TEKAN & JALAN SAAT HOLD ───
			var direction = Input.get_axis(input_left, input_right)
			
			# 1. DETEKSI TEKANAN PERTAMA (JUST PRESSED) -> LANGSUNG DASH!
			if (Input.is_action_just_pressed(input_left) or Input.is_action_just_pressed(input_right)) and not is_dashing:
				# Tentukan arah dash berdasarkan tombol yang baru ditekan
				var arah_dash = -1.0 if Input.is_action_just_pressed(input_left) else 1.0
				_mulai_dash_arah(arah_dash)

			# 2. LOGIKA PERGERAKAN JALAN / IDLE NORMAL (AKAN OTOMATIS AMBIL ALIH PAS HOLD)
			if not is_dashing: 
				if direction:
					velocity.x = direction * SPEED
					# KUNCI: Hanya mainkan walk jika tidak sedang punching, dash attack, atau casting skill/shoot
					if is_on_floor() and not is_punching and not is_dash_attacking and not is_casting_skill:
						_play_anim("walk")
					sprite.flip_h = direction < 0
				else:
					velocity.x = move_toward(velocity.x, 0, SPEED)
					# KUNCI: Hanya mainkan idle jika tidak sedang punching, dash attack, atau casting skill/shoot
					if is_on_floor() and not is_punching and not is_dash_attacking and not is_casting_skill:
						_play_anim("idle")

		if Input.is_action_just_pressed(input_jump) and (is_on_floor() or jump_count < 2):
			velocity.y = JUMP_VELOCITY
			jump_count = 1 if is_on_floor() else jump_count + 1
			if jump_count > 1:
				_spawn_jump_particles()
				_apply_jump_squash()

	$PunchBox.position.x = -55 if sprite.flip_h else 55
	move_and_slide()

# ─── UNIVERSAL SKILL INSTANTIATOR ─────────────────────────────────────────────
func _gunakan_skill():
	var waktu_cooldown = 10.0 if (Global.p2_pilihan if is_player_2 else Global.p1_pilihan) == "tesla" else 10.0
	var karakter = Global.p2_pilihan if is_player_2 else Global.p1_pilihan
	
	if cooldown_skill:
		cooldown_skill.wait_time = waktu_cooldown
		cooldown_skill.start()
		
	if ui_skill_cooldown_bar:
		ui_skill_cooldown_bar.max_value = waktu_cooldown
		ui_skill_cooldown_bar.value = waktu_cooldown

	z_index = 1
	
	# --- PERBAIKAN STATE KHUSUS ---
	if karakter == "tesla":
		is_casting_skill = true # Hanya Tesla yang mengunci pergerakan & animasi jalan
		velocity = Vector2.ZERO 
		
		# Memaksa animasi "skill" berputar dari frame 0
		sprite.stop()
		_play_anim("skill") 
	elif karakter == "edison":
		is_casting_skill = false # Edison TIDAK mengunci gerakan jalan/idle
		# Mainkan animasi menghentak sekali. Jika player jalan, nanti otomatis ter-override animasi walk
		sprite.stop()
		_play_anim("punch") 
	
	var skill_instance = skill_scene.instantiate()
	skill_instance.pemilik = self
	get_parent().add_child(skill_instance)
	skill_instance.global_position = global_position
	
	var waktu_durasi_skill = 2.0
	if "durasi_skill" in skill_instance:
		waktu_durasi_skill = skill_instance.durasi_skill
		
	await get_tree().create_timer(waktu_durasi_skill).timeout
	
	# Reset status khusus Tesla
	if karakter == "tesla":
		is_casting_skill = false 
	z_index = 0

func _update_cooldown_bar_ui():
	# Update Bar Cooldown Ungu yang baru kita buat dari kode
	if ui_skill_cooldown_bar and cooldown_skill:
		if not cooldown_skill.is_stopped():
			ui_skill_cooldown_bar.visible = true
			ui_skill_cooldown_bar.value = cooldown_skill.time_left
		else:
			# Jika cooldown beres, sembunyikan bar atau kosongkan nilainya
			ui_skill_cooldown_bar.value = 0
			ui_skill_cooldown_bar.visible = false # opsional, hapus baris ini jika ingin bar tetap kelihatan saat kosong

# ─── COMBO PUNCH & ATTACKS (Sama seperti backup asli) ─────────────────────────

func attack_punch():
	is_punching = true
	combo_count += 1
	var is_finisher = combo_count >= 3
	var arah = -1 if sprite.flip_h else 1
	velocity.x = arah * (450.0 + combo_count * 80.0)

	if is_finisher and sprite.sprite_frames.has_animation("smash"):
		_play_anim("smash")
		velocity.y = -250.0
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
			_play_anim("punch")
			if is_finisher:
				var tw = create_tween()
				var bs = _base_scale
				tw.tween_property(sprite, "scale", Vector2(bs * 1.4, bs * 0.7), 0.06)
				tw.tween_property(sprite, "scale", Vector2(bs * 0.7, bs * 1.4), 0.06)
				tw.tween_property(sprite, "scale", Vector2(bs, bs), 0.08)

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
	# Tambah Bar Ulti saat berhasil mendaratkan serangan (+5)
	ulti_charge = min(ulti_charge + 5.0, MAX_ULTI_CHARGE)
	if ui_ulti_bar: ui_ulti_bar.value = ulti_charge
	
	if body == self or not body.has_method("terkena_pukul"):
		return
	var is_finisher: bool
	var dmg: int
	if is_slide_kicking:
		is_finisher = false
		dmg = int(damage_pukul * 2.0)
	elif is_dash_attacking:
		is_finisher = true
		dmg = int(damage_pukul * 3.5)
	elif sprite.animation == "kick":
		is_finisher = false
		dmg = int(damage_pukul * 1.5)
	else:
		is_finisher = combo_count >= 3
		dmg = damage_pukul * (3 if is_finisher else max(combo_count, 1))
	body.terkena_pukul(dmg, global_position, is_finisher)
	hit_landed.emit(is_finisher)

func attack_kick():
	is_punching = true
	var arah = -1 if sprite.flip_h else 1
	velocity.x = arah * 200.0
	if sprite.sprite_frames.has_animation("kick"):
		_play_anim("kick")
	await get_tree().create_timer(0.1).timeout
	punch_box_shape.shape.size = Vector2(100, 55)
	punch_box_shape.position = Vector2(0, 5)
	punch_box_shape.disabled = false
	await get_tree().create_timer(0.2).timeout
	punch_box_shape.disabled = true
	punch_box_shape.shape.size = Vector2(90, 50)
	punch_box_shape.position = Vector2(0, -10)
	await get_tree().create_timer(0.2).timeout
	is_punching = false
	cooldown_pukul.wait_time = 0.3
	cooldown_pukul.start()

func attack_slide_kick():
	is_slide_kicking = true
	var arah = -1 if sprite.flip_h else 1
	if sprite.sprite_frames.has_animation("slide_kick"):
		_play_anim("slide_kick")
	velocity.x = arah * 700.0
	velocity.y = 60.0
	await get_tree().create_timer(0.2).timeout
	punch_box_shape.shape.size = Vector2(100, 35)
	punch_box_shape.position = Vector2(0, 25)
	punch_box_shape.disabled = false
	await get_tree().create_timer(0.2).timeout
	punch_box_shape.disabled = true
	punch_box_shape.shape.size = Vector2(90, 50)
	punch_box_shape.position = Vector2(0, -10)
	await get_tree().create_timer(0.2).timeout
	is_slide_kicking = false
	cooldown_pukul.wait_time = 0.5
	cooldown_pukul.start()

func _on_punch_box_body_entered_slide(_body):
	pass

func attack_dash():
	is_dash_attacking = true
	var arah = -1 if sprite.flip_h else 1
	if sprite.sprite_frames.has_animation("dash_attack"):
		_play_anim("dash_attack")
	velocity.x = arah * 900.0
	await get_tree().create_timer(0.25).timeout
	punch_box_shape.shape.size = Vector2(120, 70)
	punch_box_shape.position = Vector2(0, -10)
	punch_box_shape.disabled = false
	await get_tree().create_timer(0.25).timeout
	punch_box_shape.disabled = true
	punch_box_shape.shape.size = Vector2(90, 50)
	punch_box_shape.position = Vector2(0, -10)
	await get_tree().create_timer(0.33).timeout
	is_dash_attacking = false
	cooldown_pukul.wait_time = 0.7
	cooldown_pukul.start()

func _spawn_ground_dust():
	var p = CPUParticles2D.new()
	get_parent().add_child(p)
	p.global_position = global_position
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
	# Tambah Bar Ulti saat menerima damage sebagai mekanisme comeback (+8)
	ulti_charge = min(ulti_charge + 8.0, MAX_ULTI_CHARGE)
	if ui_ulti_bar: ui_ulti_bar.value = ulti_charge
	
	if is_invincible or is_dead: return

	# KUNCI ANTI-KNOCKBACK SAAT CASTING SKILL TESLA
	if is_casting_skill and (Global.p2_pilihan if is_player_2 else Global.p1_pilihan) == "tesla":
		hp -= damage_amount
		if health_bar: health_bar.value = hp
		if hp <= 0: die()
		return

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
	_play_anim("aw")

	_spawn_hit_particles(is_finisher, custom_color)

	var stun_dur = 0.5 if is_finisher else 0.35
	await get_tree().create_timer(stun_dur).timeout

	is_hit     = false
	is_stunned = false

	if hp <= 0:
		die()
		return

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

	if custom_color != null:
		p.color = custom_color
	else:
		var karakter = Global.p2_pilihan if is_player_2 else Global.p1_pilihan
		p.color = Color(1.0, 0.9, 0.2) if karakter == "edison" else Color(0.2, 0.6, 1.0)

	p.emitting = true
	await get_tree().create_timer(0.6).timeout
	p.queue_free()

func _spawn_jump_particles():
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
	var tw = create_tween()
	var bs = _base_scale
	tw.tween_property(sprite, "scale", Vector2(bs * 0.8, bs * 1.3), 0.05)
	tw.tween_property(sprite, "scale", Vector2(bs, bs), 0.1)

func die():
	if is_dead: return
	is_dead    = true
	is_stunned = true
	set_physics_process(false)
	set_process(false)

	var tw = create_tween()
	tw.tween_property(sprite, "rotation_degrees", 90.0 * (-1 if sprite.flip_h else 1), 0.4)
	tw.parallel().tween_property(sprite, "modulate:a", 0.0, 1.2)

	player_died.emit(self)

func tembak_proyektil():
	if not proyektil_scene: return
	
	is_punching = true
	_play_anim("projectile")
	
	var peluru = proyektil_scene.instantiate()
	if "penembak" in peluru: peluru.penembak = self
	peluru.global_position = global_position + Vector2(-50 if sprite.flip_h else 50, 0)
	if "direction" in peluru: peluru.direction = -1 if sprite.flip_h else 1
	get_parent().add_child(peluru)
	
	await get_tree().create_timer(0.25).timeout
	is_punching = false

func _setup_projectile_ui():
	if not health_bar: return
	
	# 1. SETUP UI PELURU (Bawaan aslimu yang sudah stabil)
	ui_stock_container = HBoxContainer.new()
	health_bar.get_parent().add_child(ui_stock_container)
	ui_stock_container.add_theme_constant_override("separation", 6)
	
	ui_stock_container.anchor_left = health_bar.anchor_left
	ui_stock_container.anchor_right = health_bar.anchor_right
	ui_stock_container.anchor_top = health_bar.anchor_bottom
	ui_stock_container.anchor_bottom = health_bar.anchor_bottom
	ui_stock_container.offset_left = health_bar.offset_left
	ui_stock_container.offset_right = health_bar.offset_right
	ui_stock_container.offset_top = health_bar.offset_bottom + 4
	ui_stock_container.offset_bottom = health_bar.offset_bottom + 19
	
	if is_player_2:
		ui_stock_container.alignment = BoxContainer.ALIGNMENT_END
	else:
		ui_stock_container.alignment = BoxContainer.ALIGNMENT_BEGIN
		
	for i in range(MAX_SHOOT_CHARGES):
		var rect = ColorRect.new()
		rect.custom_minimum_size = Vector2(18, 8)
		var karakter = Global.p2_pilihan if is_player_2 else Global.p1_pilihan
		rect.color = Color(0.2, 0.7, 1.0) if karakter == "tesla" else Color(1.0, 0.8, 0.1)
		ui_stock_container.add_child(rect)
		
	# 2. SETUP UI RELOAD PELURU (Bawaan aslimu yang sudah stabil)
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
	
	var sb = StyleBoxFlat.new()
	var karakter = Global.p2_pilihan if is_player_2 else Global.p1_pilihan
	sb.bg_color = Color(0.2, 0.7, 1.0, 0.6) if karakter == "tesla" else Color(1.0, 0.8, 0.1, 0.6)
	ui_reload_bar.add_theme_stylebox_override("fill", sb)

	# 3. ─── BUAT BAR COOLDOWN SKILL BARU (DIBUAT DARI NOL DI SINI) ───
	ui_skill_cooldown_bar = ProgressBar.new()
	health_bar.get_parent().add_child(ui_skill_cooldown_bar)
	ui_skill_cooldown_bar.show_percentage = false
	
	# Ukuran Bar Cooldown Skill (Lebar disamakan dengan reload bar)
	ui_skill_cooldown_bar.custom_minimum_size = Vector2(120, 6)
	
	# Posisikan tepat di bawah susunan UI peluru agar rapi
	ui_skill_cooldown_bar.anchor_left = health_bar.anchor_left
	ui_skill_cooldown_bar.anchor_right = health_bar.anchor_right
	ui_skill_cooldown_bar.anchor_top = health_bar.anchor_bottom
	ui_skill_cooldown_bar.anchor_bottom = health_bar.anchor_bottom
	ui_skill_cooldown_bar.offset_left = health_bar.offset_left
	ui_skill_cooldown_bar.offset_right = health_bar.offset_right
	ui_skill_cooldown_bar.offset_top = health_bar.offset_bottom + 28 # Diberi jarak ke bawah
	ui_skill_cooldown_bar.offset_bottom = health_bar.offset_bottom + 34
	
	# Berikan warna ungu estetik khusus untuk menandakan Skill Utama
	var sb_skill = StyleBoxFlat.new()
	sb_skill.bg_color = Color(0.6, 0.2, 0.9, 0.8) # Ungu Terang
	sb_skill.set_corner_radius_all(2) # Membuat ujungnya sedikit melengkung halus
	ui_skill_cooldown_bar.add_theme_stylebox_override("fill", sb_skill)
	
	# Warna background bar saat kosong (Hitam transparan)
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.1, 0.1, 0.1, 0.4)
	sb_bg.set_corner_radius_all(2)
	ui_skill_cooldown_bar.add_theme_stylebox_override("background", sb_bg)
	
	# Set nilai awal (kosong/siap pakai)
	ui_skill_cooldown_bar.max_value = 1.0
	ui_skill_cooldown_bar.value = 0
	
	#ultimate
	# 4. BUAT BAR ULTIMATE OTOMATIS (Warna Emas/Oranye)
	ui_ulti_bar = ProgressBar.new()
	health_bar.get_parent().add_child(ui_ulti_bar)
	ui_ulti_bar.show_percentage = false
	ui_ulti_bar.custom_minimum_size = Vector2(120, 8) # Sedikit lebih tebal dari bar skill
	
	ui_ulti_bar.anchor_left = health_bar.anchor_left
	ui_ulti_bar.anchor_right = health_bar.anchor_right
	ui_ulti_bar.anchor_top = health_bar.anchor_bottom
	ui_ulti_bar.anchor_bottom = health_bar.anchor_bottom
	ui_ulti_bar.offset_left = health_bar.offset_left
	ui_ulti_bar.offset_right = health_bar.offset_right
	ui_ulti_bar.offset_top = health_bar.offset_bottom + 38 # Di bawah bar skill
	ui_ulti_bar.offset_bottom = health_bar.offset_bottom + 46
	
	var sb_ulti = StyleBoxFlat.new()
	sb_ulti.bg_color = Color(1.0, 0.65, 0.0, 0.9) # Warna Emas / Oranye Terang
	sb_ulti.set_corner_radius_all(2)
	ui_ulti_bar.add_theme_stylebox_override("fill", sb_ulti)
	
	var sb_ulti_bg = StyleBoxFlat.new()
	sb_ulti_bg.bg_color = Color(0.1, 0.1, 0.1, 0.5)
	sb_ulti_bg.set_corner_radius_all(2)
	ui_ulti_bar.add_theme_stylebox_override("background", sb_ulti_bg)
	
	ui_ulti_bar.max_value = MAX_ULTI_CHARGE
	ui_ulti_bar.value = 0

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

func _mulai_dash_arah(arah: float):
	is_dashing = true
	
	velocity.x = arah * DASH_SPEED
	velocity.y = 0 # Kunci sumbu Y agar meluncur lurus
	
	_play_anim("aw")
	sprite.flip_h = (arah < 0)

	# Efek squash instan
	var tw = create_tween()
	var bs = _base_scale
	tw.tween_property(sprite, "scale", Vector2(bs * 1.3, bs * 0.8), 0.05)
	tw.tween_property(sprite, "scale", Vector2(bs, bs), 0.15)

	# Tunggu durasi dash selesai (0.2 detik)
	await get_tree().create_timer(DURASI_DASH).timeout
	
	is_dashing = false
	
	# Selesai dash, jika tombol masih DI-HOLD, velocity langsung menyesuaikan ke kecepatan jalan normal!
	var direction_sekarang = Input.get_axis(input_left, input_right)
	if direction_sekarang:
		velocity.x = direction_sekarang * SPEED
	else:
		velocity.x = 0

func _gunakan_ultimate():
	ulti_charge = 0.0 
	if ui_ulti_bar: ui_ulti_bar.value = 0
	
	var karakter = Global.p2_pilihan if is_player_2 else Global.p1_pilihan
	
	if karakter == "tesla":
		is_casting_skill = true
		velocity = Vector2.ZERO
		_play_anim("smash") 
		
		var ulti_obj = ulti_scene.instantiate()
		ulti_obj.pemilik = self
		get_parent().add_child(ulti_obj)
		
		# Tunggu durasi badai petir selesai
		await get_tree().create_timer(2.5).timeout
		
		# ─── RESET SETELAH ULTI BERES ───
		is_casting_skill = false
		_play_anim("idle") # Kembalikan ke posisi siap tempur
		
	elif karakter == "edison":
		# Edison melemparkan bola lampu raksasa secara instan ke depan
		_play_anim("punch") 
		var lampu_raksasa = ulti_scene.instantiate()
		lampu_raksasa.penembak = self
		lampu_raksasa.global_position = global_position + Vector2(-80 if sprite.flip_h else 80, -30)
		lampu_raksasa.direction = -1 if sprite.flip_h else 1
		get_parent().add_child(lampu_raksasa)
