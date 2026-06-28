extends Area2D

const SPEED = 500.0
var direction = 1
var damage    = 15
var penembak  = null

func _physics_process(delta):
	position.x += SPEED * direction * delta

func _on_body_entered(body):
	if body == penembak: return
	if body.has_method("terkena_pukul"):
		body.terkena_pukul(damage, global_position)
		queue_free()
