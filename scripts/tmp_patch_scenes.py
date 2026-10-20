# -*- coding: utf-8 -*-
p = "simulator/ui/asset_browser.gd"
s = open(p, encoding="utf-8").read()

# 1. fantome Node3D avec enfant recharge selon la ressource
old = """	var point := _position_sol(position_ecran)
	_fantome.position = point
	_grille.visible = true
	_fantome.visible = true"""
assert old in s, "maj fantome"
s = s.replace(old, """	var point := _position_sol(position_ecran)
	var boite_f := _boite_de(_fantome)
	_fantome.position = Vector3(point.x,
		point.y - boite_f.position.y, point.z)
	_grille.visible = true
	_fantome.visible = true""")

old2 = """func montrer_references(entree: Dictionary, position_ecran: Vector2) -> void:
	_entree_courante = entree
	var mesh = load("res://" + entree["obj"])
	if mesh is Mesh:
		_fantome.mesh = mesh
	_maj_fantome(position_ecran)"""
assert old2 in s, "montrer"
s = s.replace(old2, """func montrer_references(entree: Dictionary, position_ecran: Vector2) -> void:
	_entree_courante = entree
	 charger_fantome(entree)
	_maj_fantome(position_ecran)


## Charge la ressource du fantome (Mesh ou PackedScene) une seule
## fois par objet (cle = chemin).
func _charger_fantome(entree: Dictionary) -> void:
	var chemin: String = entree["obj"]
	if _fantome_cle == chemin:
		return
	_fantome_cle = chemin
	for enfant in _fantome.get_children():
		enfant.queue_free()
	var ressource = load("res://" + chemin)
	if ressource is PackedScene:
		var scene_f: Node3D = ressource.instantiate()
		_fantome.add_child(scene_f)
	elif ressource is Mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = ressource
		_fantome.add_child(mi)


## AABB monde relative d'un noeud (ses meshes, transformation incluse).
func _boite_de(noeud: Node3D) -> AABB:
	var acc := AABB()
	var premier := true
	for m in noeud.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null:
			continue
		var b: AABB = m.global_transform * m.mesh.get_aabb()
		if premier:
			acc = b
			premier = false
		else:
			acc = acc.merge(b)
	if premier:
		return AABB(Vector3(-0.25, -0.25, -0.25), Vector3(0.5, 0.5, 0.5))
	# ramener en coordonnees locales du noeud (position/rotation y)
	var origine := noeud.global_transform.origin
	acc.position -= origine
	return acc""")

s = s.replace("""var _angle_fantome := 0.0            # rotation du fantome (R, pas 45)""",
"""var _angle_fantome := 0.0            # rotation du fantome (R, pas 45)
var _fantome_cle := ""               # chemin du fantome charge""")

# 2. fantome : Node3D au lieu de MeshInstance3D
old3 = """	_fantome = MeshInstance3D.new()
	var mat_f := StandardMaterial3D.new()
	mat_f.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_f.albedo_color = Color(0.85, 0.9, 1.0, 0.5)
	_fantome.material_override = mat_f
	_fantome.visible = false"""
assert old3 in s, "construire fantome"
s = s.replace(old3, """	_fantome = Node3D.new()
	_fantome.visible = false""")

# 3. deposer : Mesh OU PackedScene, calage AABB au sol
old4 = """		var mesh = load("res://" + _entree_courante["obj"])
		if mesh is Mesh:"""
assert old4 in s, "deposer tete"
s = s.replace(old4, """		var ressource = load("res://" + _entree_courante["obj"])
		var instance: Node3D = null
		if ressource is PackedScene:
			instance = ressource.instantiate()
		if instance != null:""")
old5 = """		if mesh is Mesh:
			var instance := MeshInstance3D.new()
			instance.mesh = mesh
			if _entree_courante.has("tres"):
				var mat = load("res://" + _entree_courante["tres"])
				if mat is Material:
					instance.material_override = mat
			instance.position = point_dep"""
# deja remplace ci-dessus partiellement : gerer le bloc complet
s = s.replace("""		if instance != null:
			var instance := MeshInstance3D.new()
			instance.mesh = mesh
			if _entree_courante.has("tres"):
				var mat = load("res://" + _entree_courante["tres"])
				if mat is Material:
					instance.material_override = mat
			instance.position = point_dep""", """		if instance != null:
			instance.position = point_dep""")
s = s.replace("""			instance.position = point_dep
			instance.rotation.y = _angle_fantome
			_monde.add_child(instance)
			# collision solide : box statique alignee sur l'AABB reelle
			var boite: AABB = mesh.get_aabb()""", """			var boite: AABB = _boite_de(instance)
			instance.position = Vector3(point_dep.x,
				point_dep.y - boite.position.y, point_dep.z)
			instance.rotation.y = _angle_fantome
			_monde.add_child(instance)
			# collision solide : box statique alignee sur l'AABB reelle""")
s = s.replace("""			corps.position = point_dep + boite.get_center()""",
"""			corps.position = instance.position + boite.get_center()""")
s = s.replace("""			cadre.position = point_dep + boite.get_center()""",
"""			cadre.position = instance.position + boite.get_center()""")

# 4. annuler : vide aussi le fantome
s = s.replace("""func annuler() -> void:
	_entree_courante = {}
	_angle_fantome = 0.0
	_fantome.rotation.y = 0.0""",
"""func annuler() -> void:
	_entree_courante = {}
	_angle_fantome = 0.0
	_fantome.rotation.y = 0.0
	_fantome_cle = ""
	for enfant in _fantome.get_children():
		enfant.queue_free()""")

# 5. miniatures : GLB en scene instanciee dans le viewport
old6 = """		var mesh = load("res://" + chemin_obj)
		if mesh is Mesh:
			_maquette.mesh = mesh
			if entree.has("tres"):
				var mat = load("res://" + entree["tres"])
				if mat is Material:
					_maquette.material_override = mat
			# recadrer la camera sur la boite reelle du mesh
			var boite: AABB = mesh.get_aabb()
			var rayon := boite.size.length() * 0.5
			var echelle := 1.4 / maxf(rayon, 0.001)
			_maquette.scale = Vector3.ONE * echelle
			_maquette.position = -boite.get_center() * echelle"""
assert old6 in s, "miniatures"
s = s.replace(old6, """		for enfant_p in _maquette.get_children():
			enfant_p.queue_free()
		var ressource_p = load("res://" + chemin_obj)
		var echantillon: Node3D = null
		if ressource_p is PackedScene:
			echantillon = ressource_p.instantiate()
			_maquette.add_child(echantillon)
		elif ressource_p is Mesh:
			_maquette.mesh = ressource_p
			echantillon = _maquette
		if echantillon != null:
			var boite: AABB = _boite_de(echantillon)
			var rayon := boite.size.length() * 0.5
			var echelle := 1.4 / maxf(rayon, 0.001)
			_maquette.scale = Vector3.ONE * echelle
			_maquette.position = -boite.get_center() * echelle""")
s = s.replace("""		_maquette.mesh = null""", """		if _maquette.get_child_count() == 0:
			_maquette.mesh = null""")

# _maquette devient Node3D porteur
s = s.replace("""	_maquette = MeshInstance3D.new()
	_rendu.add_child(_maquette)""", """	_maquette = Node3D.new()
	_rendu.add_child(_maquette)""")

open(p, "w", encoding="utf-8", newline="\n").write(s)
print("OK navigateur PackedScene")
