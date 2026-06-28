extends Node2D

@onready var camera    = $Camera2D
@onready var gameover  = $CanvasLayer/GameOverPanel
@onready var label_win = $CanvasLayer/GameOverPanel/VBoxContainer/LabelWinner

var karakter_nama = {"tesla": "TESLA", "edison": "EDISON"}

func _ready():
	# Sambungkan sinyal player_died & hit_landed dari kedua player
	for node in [$Player, $Player2]:
		node.player_died.connect(_on_player_died)
		node.hit_landed.connect(_on_hit_landed)
	gameover.visible = false

func _on_hit_landed(is_finisher: bool):
	_hitstop(0.12 if is_finisher else 0.06)
	if is_finisher:
		_screen_shake(12.0, 0.35)
	else:
		_screen_shake(4.0, 0.15)

func _on_player_died(dead_player):
	await get_tree().create_timer(0.8).timeout
	# Siapa yang masih hidup = pemenang
	var winner_node = $Player2 if dead_player == $Player else $Player
	var karakter    = Global.p2_pilihan if winner_node == $Player2 else Global.p1_pilihan
	label_win.text  = karakter_nama.get(karakter, "PLAYER") + " MENANG!"
	gameover.visible = true

func _hitstop(dur: float):
	Engine.time_scale = 0.05
	await get_tree().create_timer(dur * 0.05).timeout  # waktu fisik, bukan game time
	Engine.time_scale = 1.0

func _screen_shake(strength: float, dur: float):
	var t = 0.0
	while t < dur:
		camera.offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		await get_tree().process_frame
		t += get_process_delta_time()
	camera.offset = Vector2.ZERO

func _on_btn_rematch_pressed():
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func _on_btn_menu_pressed():
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/menu_pilih_karakter.tscn")
