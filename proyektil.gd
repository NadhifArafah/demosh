extends Area2D

const SPEED = 500.0
var direction = 1
var damage = 15
var penembak = null # Tempat menyimpan referensi player yang menembak

func _physics_process(delta):
	position.x += SPEED * direction * delta

func _on_body_entered(body):
	# Trik deteksi: Cetak nama objek apa pun yang ditabrak peluru di panel bawah!
	print("Peluru nabrak sesuatu namanya: ", body.name, " | Tipenya: ", body.get_class())

	if body == penembak:
		return
		
	if body.has_method("terkena_pukul"):
		body.terkena_pukul(damage)
		queue_free()
