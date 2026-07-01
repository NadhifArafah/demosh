extends Area2D

const SPEED = 1000.0
var direction = 1
var cooldown_duration = 1.5
var damage = 33
var penembak = null # Tempat menyimpan referensi player yang menembak

func _physics_process(delta):
	position.x += SPEED * direction * delta

func _on_body_entered(body):
	# JIKA yang ditabrak adalah si penembak itu sendiri, ABAIKAN!
	if body == penembak:
		return
		
	# Baru jalankan damage jika mengenai objek lain (musuh)
	if body.has_method("terkena_pukul"):
		body.terkena_pukul(damage, global_position, false, Color(1.0, 0.8, 0.1))
		queue_free() # Hapus peluru setelah kena
