extends Area2D

var damage_awal = 15          
var damage_selama_di_area = 5 
var damage_dot_per_detik = 2  
var durasi_dot_mark = 4.0     
var durasi_skill = 2.0       

var persentase_heal = 0.5    
var cooldown_skill_ini = 5.0 

var pemilik = null           
var musuh_yang_pernah_kena = [] 

@onready var dot_timer = $DotTimer

func _ready():
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("default") # Ganti "default" dengan nama animasimu di editor
	
	if not dot_timer.timeout.is_connected(_on_dot_timer_timeout):
		dot_timer.timeout.connect(_on_dot_timer_timeout)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		
	dot_timer.wait_time = 0.2
	dot_timer.start()
	
	# Amankan pergerakan & animasi player dari sini
	if pemilik and is_instance_valid(pemilik):
		pemilik.is_casting_skill = true
		pemilik.velocity.x = 0
		
		# Tetap mempertahankan arah flip_h player asli saat memutar idle
		if pemilik.sprite:
			var current_flip = pemilik.sprite.flip_h
			pemilik._play_anim("idle")
			pemilik.sprite.flip_h = current_flip
			
			# ─── PERBAIKAN UTAMA: COCOKKAN ARAH AURA DENGAN ARAH TESLA ───
			# Jika Tesla menghadap kiri (flip_h = true), balikkan seluruh area skill ke kiri (-1)
			if current_flip:
				scale.x = -abs(scale.x)
			else:
				scale.x = abs(scale.x)
				
			# Jika kamu pakai AnimatedSprite2D di dalam skill ini, ikut di-flip juga
			if has_node("AnimatedSprite2D"):
				$AnimatedSprite2D.flip_h = current_flip
			elif has_node("Sprite2D"):
				$Sprite2D.flip_h = current_flip
	
	await get_tree().create_timer(durasi_skill).timeout
	
	# Buka kembali pengunci gerakan player saat durasi habis
	if pemilik and is_instance_valid(pemilik):
		pemilik.is_casting_skill = false
				
	queue_free()

func _process(delta):
	# Aura menempel pada posisi Tesla
	if pemilik and is_instance_valid(pemilik):
		global_position = pemilik.global_position

func _on_body_entered(body):
	if body and is_instance_valid(body) and body != pemilik and body.has_method("terkena_pukul"):
		if not body in musuh_yang_pernah_kena:
			musuh_yang_pernah_kena.append(body)
			body.terkena_pukul(damage_awal, global_position)
			_aplikasikan_dot_mark_mandiri(body)

func _on_dot_timer_timeout():
	var target_di_dalam_area = get_overlapping_bodies()
	for body in target_di_dalam_area:
		if body and is_instance_valid(body) and body != pemilik and body.has_method("terkena_pukul"):
			if not body in musuh_yang_pernah_kena:
				musuh_yang_pernah_kena.append(body)
				body.terkena_pukul(damage_awal, global_position)
				_aplikasikan_dot_mark_mandiri(body)
				continue
				
			body.terkena_pukul(damage_selama_di_area, global_position)
			
			if pemilik and is_instance_valid(pemilik):
				var jumlah_heal = damage_selama_di_area * persentase_heal
				var max_hp_sebenarnya = 100.0
				if pemilik.health_bar:
					max_hp_sebenarnya = pemilik.health_bar.max_value
				
				pemilik.hp = min(pemilik.hp + jumlah_heal, max_hp_sebenarnya)
				if pemilik.health_bar:
					pemilik.health_bar.value = pemilik.hp

func _aplikasikan_dot_mark_mandiri(target_musuh):
	var sisa_durasi = durasi_dot_mark
	while sisa_durasi > 0 and is_instance_valid(target_musuh) and target_musuh.hp > 0:
		await get_tree().create_timer(1.0).timeout
		sisa_durasi -= 1.0
		
		if is_instance_valid(target_musuh) and target_musuh.hp > 0:
			var damage_akhir_dot = damage_dot_per_detik
			if pemilik and is_instance_valid(pemilik):
				var max_hp = 100.0
				if pemilik.health_bar:
					max_hp = pemilik.health_bar.max_value
				var rasio_hp = pemilik.hp / max_hp
				var bonus_damage = (1.0 - rasio_hp) * 20.0
				damage_akhir_dot += floor(bonus_damage)
				
			target_musuh.terkena_pukul(damage_akhir_dot, global_position, false, Color(0.2, 0.6, 1.0))
				
			if pemilik and is_instance_valid(pemilik):
				var jumlah_heal = damage_akhir_dot * persentase_heal
				var max_hp_sebenarnya = 100.0
				if pemilik.health_bar:
					max_hp_sebenarnya = pemilik.health_bar.max_value
				pemilik.hp = min(pemilik.hp + jumlah_heal, max_hp_sebenarnya)
				if pemilik.health_bar:
					pemilik.health_bar.value = pemilik.hp
