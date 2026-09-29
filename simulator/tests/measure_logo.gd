extends SceneTree
## Outil de mesure : bbox de l'artwork du logo tel que GODOT le rastérise.
## Usage : godot --headless --path simulator --script res://tests/measure_logo.gd

func _init() -> void:
	var tex: Texture2D = load("res://assets/branding/logo2.svg")
	if tex == null:
		push_error("logo introuvable")
		quit(1)
		return
	var img: Image = tex.get_image()
	print("texture_size=", tex.get_size(), " image_size=", Vector2i(img.get_width(), img.get_height()))
	var x0 := 999999
	var y0 := 999999
	var x1 := -1
	var y1 := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.05:
				if x < x0:
					x0 = x
				if x > x1:
					x1 = x
				if y < y0:
					y0 = y
				if y > y1:
					y1 = y
	if x1 < 0:
		print("bbox=vide")
	else:
		print("bbox=", Vector4i(x0, y0, x1, y1))
		var c := Vector2((x0 + x1) / 2.0, (y0 + y1) / 2.0)
		print("centre=", c, " taille=", Vector2(x1 - x0 + 1, y1 - y0 + 1))
		print("fractions_centre=", Vector2(c.x / img.get_width(), c.y / img.get_height()))
		print("fractions_taille=", Vector2(float(x1 - x0 + 1) / img.get_width(), float(y1 - y0 + 1) / img.get_height()))
	quit(0)
