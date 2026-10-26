extends SceneTree
func _initialize() -> void:
	for chemin in ["BoxSquare.glb", "Claw.glb", "VisionSensor.glb", "BeltConveyor2M.glb"]:
		var res = load("res://assets/imported/" + chemin)
		if res == null:
			print(chemin, " ABSENT"); continue
		var noeud: Node3D = res.instantiate()
		var racine := Node3D.new()
		racine.add_child(noeud)
		get_root().add_child(racine)
		await process_frame
		var acc := AABB()
		var premier := true
		var nb := 0
		var has_lights := false
		for m in noeud.find_children("*", "MeshInstance3D", true, false):
			nb += 1
			if m.mesh == null:
				continue
			var b: AABB = m.global_transform * m.mesh.get_aabb()
			if premier:
				acc = b; premier = false
			else:
				acc = acc.merge(b)
		for l in noeud.find_children("*", "Light3D", true, false):
			has_lights = true
		print(chemin, " meshes=", nb, " tailles=", acc.size, " min=", acc.position, " lumieres=", has_lights)
		racine.queue_free()
	quit(0)
