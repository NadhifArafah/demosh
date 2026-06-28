extends Area2D

const SPEED = 500.0
var direction = 1
var cooldown_duration = 1.5
var damage = 15
var penembak = null # Tempat menyimpan referensi player yang menembak

func _physics_process(delta):
	position.x += SPEED * direction * delta

func _on_body_entered(body):
	# JIKA yang ditabrak adalah si penembak itu sendiri, ABAIKAN!
	if body == penembak:
		return
		
	# Baru jalankan damage jika mengenai objek lain (musuh)
	if body.has_method("terkena_pukul"):
		# Kirim damage proyektil DAN global_position milik proyektil saat ini
		body.terkena_pukul(damage, global_position)
		queue_free() # Hapus peluru setelah kena
