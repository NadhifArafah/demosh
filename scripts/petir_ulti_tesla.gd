extends Area2D

var penembak = null
var damage_ulti = 12 
var durasi_tampil = 0.2 # Durasi petir nongol di layar sebelum menghilang otomatis

func _ready():
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("default") # Ganti "default" dengan nama animasimu di editor
	body_entered.connect(_on_body_entered)
	
	if $AnimatedSprite2D:
		$AnimatedSprite2D.play("default") # Ganti dengan nama animasi petirmu
	
	# --- SOLUSI ANTI-NYANGKUT: Pakai Timer Otomatis ---
	# Begitu petir lahir, tunggu selama 0.2 detik lalu hapus dari layar, 
	# jadi tidak akan pernah nyangkut lagi meskipun animasinya looping!
	await get_tree().create_timer(durasi_tampil).timeout
	queue_free()

func _on_body_entered(body):
	if body == penembak:
		return
		
	if body.has_method("terkena_pukul"):
		body.terkena_pukul(damage_ulti, global_position, true, Color(0.2, 0.6, 1.0))
		# Kita hapus queue_free() di sini agar jika ada 2 musuh berdekatan, 
		# keduanya bisa sekaligus tersambar petir sebelum petirnya hilang dalam 0.2 detik.
