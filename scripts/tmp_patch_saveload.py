# -*- coding: utf-8 -*-
p = "simulator/ui/asset_browser.gd"
s = open(p, encoding="utf-8").read()

# 1. boutons Sauvegarder / Charger a cote d'Actualiser
old = """	var bouton := Button.new()
	bouton.text = "Actualiser"
	bouton.pressed.connect(func() -> void:
		_charger_manifeste()
		_remplir())
	colonne.add_child(bouton)"""
assert old in s, "bouton actualiser"
s = s.replace(old, """	var boutons_fichier := HBoxContainer.new()
	boutons_fichier.add_theme_constant_override("separation", 8)
	colonne.add_child(boutons_fichier)

	var bouton := Button.new()
	bouton.text = "Actualiser"
	bouton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bouton.pressed.connect(func() -> void:
		_charger_manifeste()
		_remplir())
	boutons_fichier.add_child(bouton)

	var bouton_sauver := Button.new()
	bouton_sauver.text = "Sauvegarder"
	bouton_sauver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bouton_sauver.pressed.connect(_sauvegarder)
	boutons_fichier.add_child(bouton_sauver)

	var bouton_charger := Button.new()
	bouton_charger.text = "Charger"
	bouton_charger.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bouton_charger.pressed.connect(_charger)
	boutons_fichier.add_child(bouton_charger)""")

# 2. deposer : garder le chemin obj dans le registre + refactor creation
old2 = """			_deposes.append({"mesh": instance, "corps": corps,
				"surbrillance": cadre, "nom": _entree_courante["nom"]})"""
assert old2 in s, "deposes append"
s = s.replace(old2, """			_deposes.append({"mesh": instance, "corps": corps,
				"surbrillance": cadre, "nom": _entree_courante["nom"],
				"obj": _entree_courante["obj"]})""")

# 3. sauvegarde / chargement (JSON dans user://)
old3 = "func annuler() -> void:"
assert old3 in s, "annuler"
s = s.replace(old3, """## --- Sauvegarde / chargement de l'amenagement pose avec J ---------

const FICHIER_USINE := "user://usine_j.json"


func _sauvegarder() -> void:
	var objets: Array = []
	for depose in _deposes:
		if depose.is_empty():
			continue
		objets.append({
			"nom": depose["nom"],
			"obj": depose["obj"],
			"pos": [depose["mesh"].position.x, depose["mesh"].position.y,
				depose["mesh"].position.z],
			"rot_y": depose["mesh"].rotation.y,
		})
	var fichier := FileAccess.open(FICHIER_USINE, FileAccess.WRITE)
	if fichier == null:
		print("Sauvegarde IMPOSSIBLE : ", FICHIER_USINE)
		return
	fichier.store_string(JSON.stringify({"usine": objets}, "\\t"))
	print("Usine sauvegardee : ", objets.size(), " objets -> ",
		ProjectSettings.globalize_path(FICHIER_USINE))


func _charger() -> void:
	annuler()
	_attrapeur.terminer()
	deselectionner()
	# vider l'amenagement actuel
	for depose in _deposes:
		if depose.is_empty():
			continue
		depose["mesh"].queue_free()
		depose["corps"].queue_free()
		depose["surbrillance"].queue_free()
	_deposes.clear()
	# lire et reconstruire
	if not FileAccess.file_exists(FICHIER_USINE):
		print("Chargement : aucune sauvegarde (", FICHIER_USINE, ")")
		return
	var brut = JSON.parse_string(FileAccess.get_file_as_string(FICHIER_USINE))
	if brut == null or not brut.has("usine"):
		print("Chargement : fichier illisible")
		return
	var nb := 0
	for objet in brut["usine"]:
		for entree in _manifeste:
			if entree["nom"] == objet["nom"] and entree["obj"] == objet["obj"]:
				var p: Array = objet["pos"]
				_creer_objet(entree, Vector3(p[0], p[1], p[2]),
					float(objet["rot_y"]))
				nb += 1
				break
	print("Usine chargee : ", nb, " objets")


func _creer_objet(entree: Dictionary, position: Vector3, angle: float) -> void:
	var ressource = load("res://" + entree["obj"])
	var instance: Node3D = null
	if ressource is PackedScene:
		instance = ressource.instantiate()
	elif ressource is Mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = ressource
		instance = mi
	if instance == null or _monde == null:
		return
	_monde.add_child(instance)
	instance.rotation.y = angle
	var boite: AABB = _boite_de(instance)
	instance.position = Vector3(position.x,
		position.y - boite.position.y, position.z)
	var corps := StaticBody3D.new()
	corps.position = instance.position + boite.get_center()
	corps.rotation.y = angle
	var forme := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = boite.size
	forme.shape = cube
	corps.add_child(forme)
	corps.set_meta("fio_indice", _deposes.size())
	_monde.add_child(corps)
	var cadre := MeshInstance3D.new()
	var cube_sel := BoxMesh.new()
	cube_sel.size = boite.size + Vector3(0.06, 0.06, 0.06)
	var mat_sel := StandardMaterial3D.new()
	mat_sel.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_sel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_sel.albedo_color = Color(1.0, 0.85, 0.1, 0.35)
	cube_sel.material = mat_sel
	cadre.mesh = cube_sel
	cadre.position = instance.position + boite.get_center()
	cadre.rotation.y = angle
	cadre.visible = false
	_monde.add_child(cadre)
	_deposes.append({"mesh": instance, "corps": corps,
		"surbrillance": cadre, "nom": entree["nom"], "obj": entree["obj"]})


func annuler() -> void:""")

# 4. deposer : utiliser _creer_objet (le bloc d'instanciation existe
#    deja dans _creer_objet — deposer calcule le point et delegue)
debut = s.find("""		var ressource = load("res://" + _entree_courante["obj"])
		var instance: Node3D = null""")
fin = s.find("""			print("Asset depose : \"""", debut)
assert debut != -1 and fin != -1, "bornes deposer"
fin = s.find("\n", fin) + 1
nouveau = """		_creer_objet(_entree_courante, point_dep, _angle_fantome)
"""
s = s[:debut] + nouveau + s[fin:]

open(p, "w", encoding="utf-8", newline="\n").write(s)
print("OK sauvegarde/chargement")
