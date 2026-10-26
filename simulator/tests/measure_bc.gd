extends SceneTree
func _initialize() -> void:
	for chemin in ["BeltConveyor4M.glb", "StackableBox.glb"]:
		var res = load("res://assets/imported/" + chemin)
		var noeud: Node3D = res.instantiate()
		var racine := Node3D.new()
		racine.add_child(noeud)
		get_root().add_child(racine)
		await process_frame
		var acc := AABB()
		var premier := true
		for m in noeud.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = m.global_transform * m.mesh.get_aabb()
			if premier:
				acc = b; premier = false
			else:
				acc = acc.merge(b)
		print(chemin, " taille=", acc.size, " min=", acc.position)
		racine.queue_free()
	quit(0)
