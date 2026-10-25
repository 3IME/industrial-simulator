# -*- coding: utf-8 -*-
# 1. main.gd : suppression de l'etiquette du voile (doublon du splash)
p = "simulator/scenes/main.gd"
s = open(p, encoding="utf-8").read()
old = """    _etiquette_charge = Label.new()
    _etiquette_charge.text = "Construction de l'usine..."
    _etiquette_charge.set_anchors_preset(Control.PRESET_CENTER)
    _etiquette_charge.add_theme_font_size_override("font_size", 26)
    _etiquette_charge.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
    rideau.add_child(_etiquette_charge)
"""
assert old in s, "bloc etiquette"
s = s.replace(old, "")
s = s.replace("var _etiquette_charge: Label = null\n", "")
old3 = """	if _etiquette_charge != null:
		_etiquette_charge.text = texte"""
assert old3 in s, "garde etiquette"
s = s.replace(old3, "")
open(p, "w", encoding="utf-8", newline="\n").write(s)
print("OK etiquette voile supprimee")

# 2. splash : ne pas reecrire 'Construction de l'usine...' au passage
#    en phase 2 (garder 'Chargement de l'usine...' jusqu'au 1er meta)
p2 = "simulator/ui/splash.gd"
s2 = open(p2, encoding="utf-8").read()
old4 = "\t_label_etape.text = \"Construction de l'usine...\"\n\t_phase_construction = true"
assert old4 in s2, "splash ligne"
s2 = s2.replace(old4, "\t_phase_construction = true")
open(p2, "w", encoding="utf-8", newline="\n").write(s2)
print("OK splash unicite")

# 3. miniatures : zoom plafonne (plus d'objets gonfles a remplir l'icone)
p3 = "simulator/ui/asset_browser.gd"
s3 = open(p3, encoding="utf-8").read()
old5 = """			var boite: AABB = _boite_de(echantillon)
			var rayon := boite.size.length() * 0.5
			var echelle := 1.4 / maxf(rayon, 0.001)
			_maquette.scale = Vector3.ONE * echelle"""
assert old5 in s3, "zoom miniatures"
s3 = s3.replace(old5, """			var boite: AABB = _boite_de(echantillon)
			var rayon := boite.size.length() * 0.5
			# plafond de zoom : un petit objet (capteur) reste petit dans
			# l'icone au lieu d'etre gonfle pour la remplir
			var echelle := clampf(1.4 / maxf(rayon, 0.001), 0.25, 1.5)
			_maquette.scale = Vector3.ONE * echelle""")
open(p3, "w", encoding="utf-8", newline="\n").write(s3)
print("OK zoom plafonne")
