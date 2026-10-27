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
	print("CARTES=", nav._liste.get_child_count())
	for i in range(mini(5, nav._liste.get_child_count())):
		print("  carte: ", (nav._liste.get_child(i) as Button).text)
	quit(0)
	return true
