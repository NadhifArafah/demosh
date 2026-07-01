extends Node2D

var pemilik = null
# --- SEKARANG ME-LOAD SCENE KHUSUS PETIR ULTI ---
var petir_scene = load("res://scenes/petir_ulti_tesla.tscn") 
var timer_petir : Timer
var durasi_total = 2.5
var jeda_spawn = 0.08 # Setiap 0.08 detik petir baru jatuh!
var durasi_skill = 5.0

func _ready():
	timer_petir = Timer.new()
	timer_petir.wait_time = jeda_spawn
	timer_petir.timeout.connect(_on_timer_petir_timeout)
	add_child(timer_petir)
	timer_petir.start()
	
	# Hancurkan generator badai ini setelah 2.5 detik selesai
	await get_tree().create_timer(durasi_total).timeout
	queue_free()

func _on_timer_petir_timeout():
	if not petir_scene or not pemilik: return
	
	var petir = petir_scene.instantiate()
	petir.penembak = pemilik 
	
	# Ambil lebar resolusi layar game
	var lebar_layar = get_viewport_rect().size.x
	
	# Pilih koordinat X acak dari ujung kiri ke ujung kanan layar
	var x_acak = randf_range(0.0, lebar_layar)
	
	# PERBAIKAN: Set koordinat Y sejajar dengan tinggi badan Tesla (alias langsung di atas tanah)
	var y_lantai = pemilik.global_position.y
	
	# Pasang posisi petir instan
	petir.global_position = Vector2(x_acak, y_lantai)
	
	# Sesuaikan offset sprite petirmu di inspector agar posisi bawah gambarnya pas menempel di Y lantai
	petir.scale = Vector2(2.5, 2.5)
	
	get_parent().add_child(petir)
