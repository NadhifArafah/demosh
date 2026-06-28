extends Area2D

const SPEED = 500.0
var direction = 1
var damage = 15
var cooldown_duration = 0.3
var penembak = null # Tempat menyimpan referensi player yang menembak

var is_hitting = false

func _physics_process(delta):
	if is_hitting:
		return
	position.x += SPEED * direction * delta
	
	# Loop frame 0 and 1 for flying animation
	if $AnimatedSprite2D.frame >= 2:
		$AnimatedSprite2D.frame = 0

func _on_body_entered(body):
	# JIKA yang ditabrak adalah si penembak itu sendiri, atau sedang hitting,ignore ajah
	if body == penembak or is_hitting:
		return
		
	is_hitting = true
	$AnimatedSprite2D.stop()
	$AnimatedSprite2D.frame = 2 # Play impact frame
		
	# Baru jalankan damage jika mengenai objek lain (musuh)
	if body.has_method("terkena_pukul"):
		body.terkena_pukul(damage, global_position, false, Color(0.2, 0.6, 1.0))
		
	# Tunggu sebentar agar animasi impact sempat terputar sebelum peluru dihapus
	await get_tree().create_timer(0.15).timeout
	queue_free()
