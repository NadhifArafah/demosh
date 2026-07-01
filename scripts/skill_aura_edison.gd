extends Area2D

var damage_aura = 3          
var jumlah_heal_diri = 0.67     
var durasi_skill = 5.0       
var cooldown_skill_ini = 10.0

var pemilik = null           

@onready var dot_timer = $DotTimer

func _ready():
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("default") # Ganti "default" dengan nama animasimu di editor
		
	dot_timer.wait_time = 0.2
	dot_timer.one_shot = false
	dot_timer.start()
	
	if not dot_timer.timeout.is_connected(_on_dot_timer_timeout):
		dot_timer.timeout.connect(_on_dot_timer_timeout)

	# Aktifkan cooldown di sisi Player Edison semenjak dinyalakan
	#if pemilik and is_instance_valid(pemilik):
	#	if pemilik.cooldown_skill:
	#		pemilik.cooldown_skill.wait_time = cooldown_skill_ini
	#		pemilik.cooldown_skill.start()
	#	if pemilik.cooldown_bar:
	#		pemilik.cooldown_bar.max_value = cooldown_skill_ini

	await get_tree().create_timer(durasi_skill).timeout
	queue_free()

func _process(delta):
	if pemilik and is_instance_valid(pemilik):
		global_position = pemilik.global_position

func _on_dot_timer_timeout():
	# 1. HEAL MURNI UNTUK EDISON
	if pemilik and is_instance_valid(pemilik):
		var max_hp_edison = 100.0
		if pemilik.health_bar:
			max_hp_edison = pemilik.health_bar.max_value
		
		pemilik.hp = min(pemilik.hp + jumlah_heal_diri, max_hp_edison)
		if pemilik.health_bar:
			pemilik.health_bar.value = pemilik.hp

	# 2. DAMAGE DPS AREA KE SEMUA MUSUH
	var target_di_dalam_aura = get_overlapping_bodies()
	for body in target_di_dalam_aura:
		if body and is_instance_valid(body) and body != pemilik:
			if body.has_method("terkena_pukul"):
				body.terkena_pukul(damage_aura, global_position, false, Color(1.0, 1.0, 0.0))
