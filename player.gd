extends CharacterBody2D

@export var is_player_2: bool = false
@export var health_bar : ProgressBar
var proyektil_scene : PackedScene
@onready var cooldown_tembak = $CooldownTembak
@onready var cooldown_pukul = $CooldownPukul
var is_stunned = false # Menandai apakah player sedang kaku/tidak bisa menyerang
var pukulan_berturut_turut = 0 # Untuk sistem combo/cooldown per beberapa pukulan

var damage_pukul : int = 10 
var input_shoot = "p1_shoot"
var input_left = "p1_left"
var input_right = "p1_right"
var input_jump = "p1_jump"
var input_crouch = "p1_crouch"
var input_punch = "p1_punch"

const SPEED = 300.0
const JUMP_VELOCITY = -600.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_punching = false
var hp = 100
var is_hit = false

# Ambil node sejak awal di atas biar seragam
@onready var sprite = $AnimatedSprite2D
@onready var punch_box_shape = $PunchBox/CollisionShape2D 

func _ready():
	# 1. Atur Input Map Player 1 atau 2
	if is_player_2:
		input_left = "p2_left"
		input_right = "p2_right"
		input_jump = "p2_jump"
		input_crouch = "p2_crouch"
		input_punch = "p2_punch"
		input_shoot = "p2_shoot"
	
	if punch_box_shape:
		punch_box_shape.disabled = true

	# 2. Set nilai awal bar darah
	if health_bar:
		health_bar.max_value = hp
		health_bar.value = hp
		
	# 3. Cek pilihan karakter dari Global
	var karakter_terpilih = ""
	if is_player_2:
		karakter_terpilih = Global.p2_pilihan
	else:
		karakter_terpilih = Global.p1_pilihan

	# 4. Ganti gambar animasi & proyektil secara otomatis
	print("Nama Node: ", name, " | Karakter Terpilih dari Global: ", karakter_terpilih)

	if karakter_terpilih == "tesla":
		sprite.sprite_frames = load("res://animasi_tesla.tres") 
		damage_pukul = 5
		proyektil_scene = load("res://proyektil_petir.tscn") 
		print(name, " sukses load proyektil_petir.tscn") # <-- TAMBAHKAN INI
		
	elif karakter_terpilih == "edison":
		sprite.sprite_frames = load("res://animasi_edison.tres") 
		damage_pukul = 25
		proyektil_scene = load("res://proyektil_lampu.tscn")
		print(name, " sukses load proyektil_lampu.tscn") #
	

func _process(_delta):
	if Input.is_action_just_pressed(input_shoot) and not is_punching:
		print("--- TOMBOL TEMBAK DITEKAN ---")
		print("Status Timer Berhenti? ", cooldown_tembak.is_stopped())
		
		if cooldown_tembak.is_stopped():
			print("Timer aman, peluru ditembakkan!")
			
			if proyektil_scene:
				var proyektil_temp = proyektil_scene.instantiate()
				var waktu_tunggu = 0.5
				if "cooldown_duration" in proyektil_temp:
					waktu_tunggu = proyektil_temp.cooldown_duration
				proyektil_temp.queue_free()
				
				cooldown_tembak.wait_time = waktu_tunggu
				cooldown_tembak.start()
				print("Timer dinyalakan selama: ", waktu_tunggu, " detik.")
				
				tembak_proyektil()
		else:
			print("Tembakan ditolak karena masih cooldown!")

func _physics_process(delta):
	# 1. Efek Gravitasi (Selalu jalan)
	if not is_on_floor():
		velocity.y += gravity * delta
		sprite.play("aw")

	# 2. Logika Menyerang (Hanya bisa dipicu jika tidak sedang kaku/stunned)
	if not is_stunned:
		if Input.is_action_just_pressed(input_punch) and not is_punching:
			if cooldown_pukul.is_stopped():
				attack_punch()

	# 3. KONTROL PERGERAKAN UTAMA (Kunci agar bisa geser)
	if is_stunned:
		# Jika sedang kena hit/stunned, biarkan velocity.x hasil knockback bekerja.
		# Kita kurangi kecepatannya perlahan (efek gesek lantai) agar tidak meluncur selamanya.
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 2)
		
	elif is_punching:
		# Jika sedang memukul, biarkan velocity.x hasil forward dash bekerja.
		# Rem perlahan saat pukulan mau selesai.
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 5)
		
	else:
		# JIKA SEDANG NORMAL (Tidak dipukul & Tidak mukul), BARU INPUT JALAN BEKERJA
		if Input.is_action_pressed(input_crouch) and is_on_floor():
			velocity.x = 0
			sprite.play("crouch")
		else:
			var direction = Input.get_axis(input_left, input_right)
			if direction:
				velocity.x = direction * SPEED
				sprite.play("walk")
				if direction > 0:
					sprite.flip_h = false
					$PunchBox.position.x = 0 
				elif direction < 0:
					sprite.flip_h = true
					$PunchBox.position.x = -80 
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)
				if is_on_floor():
					sprite.play("idle")

		# Logika Melompat
		if Input.is_action_just_pressed(input_jump) and is_on_floor():
			velocity.y = JUMP_VELOCITY
			
	# Menjalankan semua kalkulasi velocity di atas
	move_and_slide()

func attack_punch():
	is_punching = true
	pukulan_berturut_turut += 1
	
	# 1. Efek Maju ke Depan (Forward Dash) saat mukul
	var arah_mukul = -1 if sprite.flip_h else 1
	velocity.x = arah_mukul * 450.0 # Angka 450 bisa kamu naikkan kalau kurang maju
	
	if sprite.sprite_frames.has_animation("punch"):
		sprite.play("punch")
	
	punch_box_shape.disabled = false 
	await get_tree().create_timer(0.2).timeout
	punch_box_shape.disabled = true 
	is_punching = false
	
	# 2. Sistem Cooldown: Jika sudah 3 kali pukul, beri jeda lama
	if pukulan_berturut_turut >= 3:
		cooldown_pukul.wait_time = 0.8 # Jeda 0.8 detik setelah kombo 3 pukulan
		cooldown_pukul.start()
		pukulan_berturut_turut = 0 # Reset hitungan kombo
	else:
		# Jeda tipis antar pukulan biasa (biar ga bisa dispam super brutal)
		cooldown_pukul.wait_time = 0.15
		cooldown_pukul.start()

# Tambahkan parameter posisi_penyerang
# Ganti baris teratas fungsinya menjadi seperti ini saja:
func terkena_pukul(damage_amount, posisi_penyerang):
	if not is_hit:
		hp -= damage_amount
		if health_bar:
			health_bar.value = hp
		is_hit = true
		is_stunned = true
		print(name, " terkena pukul! Sisa HP: ", hp)
		
		# Ganti nama variabelnya menjadi arah_pental agar tidak bentrok
		var arah_pental = 1.0
		if posisi_penyerang.x > global_position.x:
			arah_pental = -1.0
		else:
			arah_pental = 1.0
			
		velocity.x = arah_pental * 500.0 # Gunakan nama baru di sini
		velocity.y = -250.0
		sprite.play("aw")
		await get_tree().create_timer(0.4).timeout
		
		is_hit = false
		is_stunned = false
		print(name, " terkena pukul! Sisa HP: ", hp)
		
		# HITUNG ARAH KNOCKBACK BERDASARKAN POSISI SERANGAN:
		# Jika posisi penyerang lebih besar dari posisi saya, berarti penyerang di KANAN. Maka saya mental ke KIRI (-).
		# Sebaliknya, jika penyerang di KIRI, saya mental ke KANAN (+).
		var arah_knockback = 1.0
		if posisi_penyerang.x > global_position.x:
			arah_knockback = -1.0
		else:
			arah_knockback = 1.0
			
		velocity.x = arah_knockback * 500.0 # Kekuatan knockback horizontal
		velocity.y = -250.0                # Kekuatan knockback vertikal (sedikit membal)
		
		await get_tree().create_timer(0.4).timeout
		
		is_hit = false
		is_stunned = false

func _on_punch_box_body_entered(body):
	if body != self and body.has_method("terkena_pukul"):
		# Kirim damage DAN global_position Player yang memukul
		body.terkena_pukul(damage_pukul, global_position)

func tembak_proyektil():
	if proyektil_scene:
		var peluru = proyektil_scene.instantiate()
		
		if "penembak" in peluru:
			peluru.penembak = self
		
		# Gunakan global_position di KEDUA BELAH PIHAK
		peluru.global_position = global_position
		
		if sprite and sprite.flip_h:
			peluru.global_position.x -= 50
			if "direction" in peluru:
				peluru.direction = -1 
		else:
			peluru.global_position.x += 50
			if "direction" in peluru:
				peluru.direction = 1 
			
		get_parent().add_child(peluru)
