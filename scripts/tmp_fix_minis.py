# -*- coding: utf-8 -*-
p = "simulator/ui/asset_browser.gd"
s = open(p, encoding="utf-8").read()

# 1. _process : lance la generation serialisee, jamais en parallele
old = """	if not _panneau.visible or _file_apercus.is_empty() or _rendu == null:
		return
	for _i in range(2):
		if _file_apercus.is_empty():
			return
		var travail: Dictionary = _file_apercus.pop_front()
		var vignette: Button = travail["vignette"]
		var entree: Dictionary = travail["entree"]
		if not is_instance_valid(vignette):
			continue
		var chemin_obj: String = entree["obj"]
		if _cache_apercus.has(chemin_obj):
			vignette.icon = _cache_apercus[chemin_obj]
			continue
		# detacher IMMEDIATEMENT (queue_free est differe : l'objet
		# resterait rendu une frame de plus)
		for enfant_p in _maquette.get_children():
			_maquette.remove_child(enfant_p)
			enfant_p.queue_free()
		var ressource_p = load("res://" + chemin_obj)
		var echantillon: Node3D = null
		if ressource_p is PackedScene:
			echantillon = ressource_p.instantiate()
			_maquette.add_child(echantillon)
		elif ressource_p is Mesh:
			var mi_p := MeshInstance3D.new()
			mi_p.mesh = ressource_p
			_maquette.add_child(mi_p)
			echantillon = mi_p
		if echantillon != null:
			var boite: AABB = _boite_de(echantillon)
			var rayon := boite.size.length() * 0.5
			# plafond de zoom : un petit objet (capteur) reste petit dans
			# l'icone au lieu d'etre gonfle pour la remplir
			var echelle := clampf(1.4 / maxf(rayon, 0.001), 0.25, 1.5)
			_maquette.scale = Vector3.ONE * echelle
			_maquette.position = -boite.get_center() * echelle
			await RenderingServer.frame_post_draw
			if is_instance_valid(vignette):
				var texture := ImageTexture.create_from_image(
					_rendu.get_texture().get_image())
				_cache_apercus[chemin_obj] = texture
				vignette.icon = texture
		# detacher APRES le rendu : rien ne traîne dans le monde
		for enfant_p in _maquette.get_children():
			_maquette.remove_child(enfant_p)
			enfant_p.queue_free()"""
assert old in s, "bloc miniatures"
s = s.replace(old, """	if _apercu_en_cours:
		return
	if not _panneau.visible or _file_apercus.is_empty() or _rendu == null:
		return
	_apercu_en_cours = true
	_generer_apercus()""")

# 2. fonction async serialisee (une seule chaine, 2 frames/objet)
old2 = "func _construire_references_3d() -> void:"
assert old2 in s, "ancre refs"
s = s.replace(old2, """## Genere les miniatures SEQUENTIELLEMENT (une seule chaine d'await :
## _process etant rappele chaque frame, deux boucles paralleles
## capturaient la maquette d'un AUTRE objet — icones melangees/grises).
func _generer_apercus() -> void:
	while _panneau.visible and not _file_apercus.is_empty():
		var travail: Dictionary = _file_apercus.pop_front()
		var vignette: Button = travail["vignette"]
		var entree: Dictionary = travail["entree"]
		if not is_instance_valid(vignette):
			continue
		var chemin_obj: String = entree["obj"]
		if _cache_apercus.has(chemin_obj):
			vignette.icon = _cache_apercus[chemin_obj]
			continue
		# detacher IMMEDIATEMENT (queue_free est differe)
		for enfant_p in _maquette.get_children():
			_maquette.remove_child(enfant_p)
			enfant_p.queue_free()
		var ressource_p = load("res://" + chemin_obj)
		var echantillon: Node3D = null
		if ressource_p is PackedScene:
			echantillon = ressource_p.instantiate()
			_maquette.add_child(echantillon)
		elif ressource_p is Mesh:
			var mi_p := MeshInstance3D.new()
			mi_p.mesh = ressource_p
			_maquette.add_child(mi_p)
			echantillon = mi_p
		if echantillon != null:
			var boite: AABB = _boite_de(echantillon)
			var rayon := boite.size.length() * 0.5
			# plafond de zoom : un petit objet reste petit dans l'icone
			var echelle := clampf(1.4 / maxf(rayon, 0.001), 0.25, 1.5)
			_maquette.scale = Vector3.ONE * echelle
			_maquette.position = -boite.get_center() * echelle
			# 2 frames de rendu avant capture (materiaux + draw reels)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			if is_instance_valid(vignette):
				var texture := ImageTexture.create_from_image(
					_rendu.get_texture().get_image())
				_cache_apercus[chemin_obj] = texture
				vignette.icon = texture
		for enfant_p in _maquette.get_children():
			_maquette.remove_child(enfant_p)
			enfant_p.queue_free()
		await get_tree().process_frame
	_apercu_en_cours = false


func _construire_references_3d() -> void:""")

# 3. membre du flag
old3 = "var _fantome_cle := \"\""
assert old3 in s
s = s.replace(old3, old3 + "\nvar _apercu_en_cours := false     # generation serialisee")

open(p, "w", encoding="utf-8", newline="\n").write(s)
print("OK generation serialisee")
