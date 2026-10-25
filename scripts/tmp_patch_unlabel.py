# -*- coding: utf-8 -*-
# 1. main.gd : le voile n'a plus d'etiquette (les textes vivent dans
#    le splash, plus aucun doublon)
p = "simulator/scenes/main.gd"
s = open(p, encoding="utf-8").read()

old = """    _etiquette_charge = Label.new()
    etiquette_charge.text = "Construction de l'usine..."
    _etiquette_charge.set_anchors_preset(Control.PRESET_CENTER)"""
if old not in s:
    # variante si le patch precedent avait laisse un seul style
    old = """    _etiquette_charge = Label.new()
    _etiquette_charge.set_anchors_preset(Control.PRESET_CENTER)"""
assert old in s, "label create"
s = s.replace(old, "")
for ligne in [
    "    _etiquette_charge.add_theme_font_size_override(\"font_size\", 26)\n",
    "    _etiquette_charge.add_theme_color_override(\"font_color\", Color(0.85, 0.9, 1.0))\n",
    "    rideau.add_child(_etiquette_charge)\n",
]:
    assert ligne in s, ligne[:40]
    s = s.replace(ligne, "")

old2 = "var _etiquette_charge: Label = null"
assert old2 in s
s = s.replace(old2 + "\n", "")

old3 = """	if _etiquette_charge != null:
		_etiquette_charge.text = texte"""
assert old3 in s
s = s.replace(old3, "")
open(p, "w", encoding="utf-8", newline="\n").write(s)
print("OK main sans etiquette")

# 2. splash : ne pas reecrire 'Construction de l'usine...' (le texte
#    'Chargement de l'usine...' reste jusqu'au premier meta)
p2 = "simulator/ui/splash.gd"
s2 = open(p2, encoding="utf-8").read()
old4 = '\t_label_etape.text = "Construction de l\'usine..."\n\t_phase_construction = true'
assert old4 in s2
s2 = s2.replace(old4, "\t_phase_construction = true")
open(p2, "w", encoding="utf-8", newline="\n").write(s2)
print("OK splash unicite")
