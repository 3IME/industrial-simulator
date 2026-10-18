extends SceneTree
## Etape 1 ZAI_PROMPT : les FIO_* se chargent, les .tres portent textures.

func _initialize() -> void:
	var manifeste = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/imported/manifest.json"))
	if manifeste == null:
		print("FIO ECHEC : manifest illisible"); quit(1); return
	var texturés := 0
	var prem := ""
	for entree in manifeste["assets"]:
		if entree.get("statut", "") == "texturé":
			texturés += 1
			if prem == "":
				prem = entree["obj"]
	print("FIO manifeste : ", manifeste["stats"], " total=", len(manifeste["assets"]))
	var mesh := load("res://" + prem)
	if mesh == null:
		print("FIO ECHEC : OBJ introuvable ", prem); quit(1); return
	var nb_surfaces := 0
	if mesh is Mesh:
		nb_surfaces = mesh.get_surface_count()
	print("FIO premier texturé : ", prem, " type=", mesh.get_class(),
		" surfaces=", nb_surfaces)
	var tres := load("res://assets/imported/FIO_BeltConveyor2M__BeltConveyor2M.tres")
	print("FIO materiau .tres : ", tres != null,
		" albedo=", tres.albedo_texture != null if tres != null else false)
	print("FIO OK")
	quit(0)
