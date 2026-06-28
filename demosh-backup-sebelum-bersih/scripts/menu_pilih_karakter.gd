extends Control

func _on_tombol_tesla_gui_input(event: InputEvent):
	# Cek apakah ada klik mouse
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			Global.p1_pilihan = "tesla"
			print("Pemain 1 memilih TESLA! (Klik Kiri)")
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			Global.p2_pilihan = "tesla"
			print("Pemain 2 memilih TESLA! (Klik Kanan)")

func _on_tombol_edison_gui_input(event: InputEvent):
	# Cek apakah ada klik mouse
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			Global.p1_pilihan = "edison"
			print("Pemain 1 memilih EDISON! (Klik Kiri)")
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			Global.p2_pilihan = "edison"
			print("Pemain 2 memilih EDISON! (Klik Kanan)")

func _on_tombol_mulai_pressed():
	get_tree().change_scene_to_file("res://scenes/mainstage.tscn")
