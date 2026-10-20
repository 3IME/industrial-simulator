# -*- coding: utf-8 -*-
p = "simulator/ui/asset_browser.gd"
s = open(p, encoding="utf-8").read()

# 1. declarations : Node3D (la cause de TOUT)
assert "var _rendu: SubViewport = null" in s
s = s.replace("var _maquette: MeshInstance3D = null", "var _maquette: Node3D = null")
s = s.replace("var _fantome: MeshInstance3D = null", "var _fantome: Node3D = null")
s = s.replace("var _grille: MeshInstance3D = null",
              "var _grille: MeshInstance3D = null\nvar _grille_ok := false")

# 2. cadre jaune : suit la rotation et la position de l'objet selectionne
old = """			elif _selection >= 0:
				var sel_r: Dictionary = _deposes[_selection]
				sel_r["mesh"].rotation.y += PI / 12.0   # 15 degres
				sel_r["corps"].rotation.y = sel_r["mesh"].rotation.y"""
assert old in s, "rotation selection"
s = s.replace(old, """			elif _selection >= 0:
				var sel_r: Dictionary = _deposes[_selection]
				sel_r["mesh"].rotation.y += PI / 12.0   # 15 degres
				sel_r["corps"].rotation.y = sel_r["mesh"].rotation.y
				_cadrer_selection()"""
)

# 3. deplacement horizontal : fleches (pas d'un carreau, 20 cm),
#    uniquement quand un objet est selectionne (cles consommees)
old2 = """	elif event is InputEventKey and event.pressed \\
			and event.keycode == KEY_DELETE and _selection >= 0:
		supprimer_selection()
		get_viewport().set_input_as_handled()"""
assert old2 in s, "suppr ancre"
s = s.replace(old2, """	elif event is InputEventKey and event.pressed \\
			and event.keycode == KEY_DELETE and _selection >= 0:
		supprimer_selection()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and _selection >= 0 \\
			and [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN].has(event.keycode):
		var sel_d: Dictionary = _deposes[_selection]
		var deplacement := Vector3.ZERO
		match event.keycode:
			KEY_LEFT:
				deplacement.x = -PAS_AIMANT
			KEY_RIGHT:
				deplacement.x = PAS_AIMANT
			KEY_UP:
				deplacement.z = -PAS_AIMANT
			KEY_DOWN:
				deplacement.z = PAS_AIMANT
		for cible_d in ["mesh", "corps", "surbrillance"]:
			sel_d[cible_d].position += deplacement
		_cadrer_selection()
		get_viewport().set_input_as_handled()"""
)

# 4. helper : recadre la surbrillance sur l'objet (rotation comprise)
old3 = "func deselectionner() -> void:"
assert old3 in s
s = s.replace(old3, """## Recalcule la surbrillance apres rotation/deplacement : boite
## reelle + meme assiette que l'objet.
func _cadrer_selection() -> void:
	if _selection < 0 or _selection >= _deposes.size() \\
			or _deposes[_selection].is_empty():
		return
	var sel_c: Dictionary = _deposes[_selection]
	var noeud_c: Node3D = sel_c["mesh"]
	var boite_c := _boite_de(noeud_c)
	var cadre_c: MeshInstance3D = sel_c["surbrillance"]
	cadre_c.position = noeud_c.position + boite_c.get_center()
	cadre_c.rotation.y = noeud_c.rotation.y


func deselectionner() -> void:""")

# 5. molette : recadre aussi la surbrillance
old4 = """		sel_m["surbrillance"].position.y = sel_m["mesh"].position.y
		get_viewport().set_input_as_handled()"""
assert old4 in s
s = s.replace(old4, """		_cadrer_selection()
		get_viewport().set_input_as_handled()""")

# 6. terminer : ne recapture la souris que si le panneau est ferme
old5 = """	(navire as Node).masquer_references()
	if not (navire as Node).drag_gui_actif():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED"""
assert old5 in s, "terminer"
s = s.replace(old5, """	(navire as Node).masquer_references()
	if not (navire as Node).drag_gui_actif() \\
			and not (navire as Node).panneau_ouvert():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED""")

old6 = "func sur_panneau(position_ecran: Vector2) -> bool:"
assert old6 in s
s = s.replace(old6, """func panneau_ouvert() -> bool:
	return _panneau != null and _panneau.visible


func sur_panneau(position_ecran: Vector2) -> bool:""")

open(p, "w", encoding="utf-8", newline="\n").write(s)
print("OK types + cadre + fleches + souris")
