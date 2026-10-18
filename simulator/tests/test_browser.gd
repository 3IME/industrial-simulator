extends SceneTree
var frames := 0
var nav = null

func _initialize() -> void:
	nav = preload("res://ui/asset_browser.gd").new()
	get_root().add_child(nav)

func _process(_d: float) -> bool:
	frames += 1
	if frames < 10:
		return false
	print("MANIFESTE=", nav._manifeste.size())
	print("BOUTONS=", nav._liste.get_child_count())
	if nav._liste.get_child_count() > 0:
		var b: Control = nav._liste.get_child(0)
		print("PREMIER taille=", b.size, " visible=", b.visible)
	print("PANNEAU=", nav._panneau.size)
	quit(0)
	return true
