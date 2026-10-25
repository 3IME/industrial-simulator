# -*- coding: utf-8 -*-
p = "simulator/ui/asset_browser.gd"
s = open(p, encoding="utf-8").read()

# 1. la liste devient une grille 2 colonnes
old = """	_liste = VBoxContainer.new()
	_liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defilement.add_child(_liste)
	_remplir()"""
assert old in s, "liste vbox"
s = s.replace(old, """	_liste = GridContainer.new()
	_liste.columns = 2
	_liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_liste.add_theme_constant_override("h_separation", 8)
	_liste.add_theme_constant_override("v_separation", 8)
	defilement.add_child(_liste)
	_remplir()""")

# 2. vignettes : cartes carrees (icone au-dessus, nom dessous)
old2 = """		var vignette := VignetteAsset.new()
		vignette.pressed.connect(func() -> void:
			_attrapeur.demarrer_manuel(entree))
		vignette.set_meta("fio", entree)
		_liste.add_child(vignette)"""
assert old2 in s, "vignettes"
s = s.replace(old2, """		var carte := VignetteAsset.new()
		carte.custom_minimum_size = Vector2(130, 132)
		carte.text = entree["nom"]
		carte.add_theme_font_size_override("font_size", 10)
		carte.expand_icon = true
		carte.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		carte.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		carte.add_theme_constant_override("icon_max_width", 110)
		var donnee: Dictionary = entree
		carte.pressed.connect(func() -> void:
			_attrapeur.demarrer_manuel(donnee))
		carte.set_meta("fio", entree)
		_liste.add_child(carte)""")

# 3. la file d'apercus vise la carte
s = s.replace("""		_file_apercus.append({"vignette": vignette, "entree": entree})""",
"""		_file_apercus.append({"vignette": carte, "entree": entree})""")

# 4. classe VignetteAsset : reglages carte carree
old4 = """	func _ready() -> void:
		clip_text = true
		icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		expand_icon = true
		custom_minimum_size = Vector2(280, 38)
		add_theme_font_size_override("font_size", 12)"""
assert old4 in s, "classe ready"
s = s.replace(old4, """	func _ready() -> void:
		clip_text = true
		text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		custom_minimum_size = Vector2(130, 132)
		add_theme_font_size_override("font_size", 10)
		icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		expand_icon = true
		add_theme_constant_override("icon_max_width", 110)""")

open(p, "w", encoding="utf-8", newline="\n").write(s)
print("OK grille 2 colonnes")
