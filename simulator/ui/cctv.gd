extends Node3D
## Systeme de videosurveillance 4 cameras 3D.
## Les 4 flux sont rendus dans des SubViewport basse resolution
## puis assembles en grille 2x2 dans un viewport composite.
##
## Usage :
## var cctv = preload("res://ui/cctv.gd").new()
## cctv.setup([...])
## add_child(cctv)
##
## La texture composite est accessible via :
## cctv.texture

const FLUX_SHADER := preload("res://ui/cctv_flux.gdshader")

const LARGEUR_FLUX := 320
const HAUTEUR_FLUX := 180

const LARGEUR_COMPOSITE := LARGEUR_FLUX * 2
const HAUTEUR_COMPOSITE := HAUTEUR_FLUX * 2

var texture: ViewportTexture = null
var _composite: SubViewport = null

var _cams: Array[Camera3D] = []
var _originales: Array[Vector3] = []
var _recs: Array[ColorRect] = []
var _alarmes: Array[bool] = []
var _materiaux: Array[ShaderMaterial] = []
var _no_signal: Array[Label] = []

var _temps := 0.0
var _textures_a_poser: Array = []
var _posees := false


func setup(flux: Array) -> void:
	_composite = SubViewport.new()
	_composite.size = Vector2i(LARGEUR_COMPOSITE, HAUTEUR_COMPOSITE)
	_composite.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_composite.transparent_bg = false
	add_child(_composite)

	# Fond noir du composite
	var fond := ColorRect.new()
	fond.position = Vector2.ZERO
	fond.size = Vector2(LARGEUR_COMPOSITE, HAUTEUR_COMPOSITE)
	fond.color = Color(0.005, 0.008, 0.008, 1.0)
	_composite.add_child(fond)

	for i in range(min(flux.size(), 4)):
		var conf: Dictionary = flux[i]

		# SubViewport de la camera
		var vp := SubViewport.new()
		vp.size = Vector2i(LARGEUR_FLUX, HAUTEUR_FLUX)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.transparent_bg = false
		add_child(vp)

		# Camera 3D
		var cam := Camera3D.new()
		cam.fov = 72.0
		vp.add_child(cam)
		cam.position = conf.get("pos", Vector3.ZERO)
		cam.look_at(conf.get("visee", Vector3.ZERO), Vector3.UP)
		cam.current = true
		_cams.append(cam)
		_originales.append(cam.rotation)
		_alarmes.append(false)

		# Position du quadrant
		var colonne := i % 2
		var ligne := i / 2
		var coin := Vector2(colonne * LARGEUR_FLUX, ligne * HAUTEUR_FLUX)

		# Texture du flux (assignation differree : cf fin de setup)
		var tx := TextureRect.new()
		tx.position = coin
		tx.size = Vector2(LARGEUR_FLUX, HAUTEUR_FLUX)
		_textures_a_poser.append([tx, vp])
		tx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tx.stretch_mode = TextureRect.STRETCH_SCALE
		tx.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var mat := ShaderMaterial.new()
		mat.shader = FLUX_SHADER
		mat.set_shader_parameter("intensite", conf.get("intensite", 0.3))
		mat.set_shader_parameter("teinte", conf.get("teinte", Color(0.9, 1.0, 0.95)))
		tx.material = mat
		_materiaux.append(mat)
		_composite.add_child(tx)

		# Nom de camera
		var nom := Label.new()
		nom.text = conf.get("nom", "CAM %02d" % (i + 1))
		nom.position = coin + Vector2(8, 5)
		nom.add_theme_font_size_override("font_size", 16)
		nom.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
		nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_composite.add_child(nom)

		# Point rouge REC
		var rec := ColorRect.new()
		rec.color = Color(1.0, 0.05, 0.03, 1.0)
		rec.size = Vector2(8, 8)
		rec.position = coin + Vector2(LARGEUR_FLUX - 45, 9)
		rec.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_composite.add_child(rec)
		_recs.append(rec)

		# Texte REC
		var texte_rec := Label.new()
		texte_rec.text = "REC"
		texte_rec.position = coin + Vector2(LARGEUR_FLUX - 35, 1)
		texte_rec.add_theme_font_size_override("font_size", 15)
		texte_rec.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		texte_rec.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_composite.add_child(texte_rec)

		# Horodatage
		var horloge := Label.new()
		horloge.name = "Horloge_%02d" % i
		horloge.text = "00:00:00"
		horloge.position = coin + Vector2(8, HAUTEUR_FLUX - 25)
		horloge.add_theme_font_size_override("font_size", 14)
		horloge.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8))
		horloge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_composite.add_child(horloge)

		# Perte de signal
		var perte := Label.new()
		perte.text = "PERTE DE SIGNAL"
		perte.position = coin + Vector2(60, HAUTEUR_FLUX * 0.5 - 12)
		perte.add_theme_font_size_override("font_size", 18)
		perte.add_theme_color_override("font_color", Color(1.0, 0.2, 0.15))
		perte.visible = false
		perte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_composite.add_child(perte)
		_no_signal.append(perte)

	texture = _composite.get_texture()


func _process(delta: float) -> void:
	if not _posees:
		_posees = true
		# Une frame apres la creation : les viewports ont rendu une image,
		# leurs textures sont alors fiables (le viewport #2 restait noir
		# quand la texture etait liee trop tot).
		for paire in _textures_a_poser:
			paire[0].texture = paire[1].get_texture()
		_textures_a_poser = []
	_temps += delta

	# Balayage lent des cameras
	for i in range(_cams.size()):
		var vitesse := 0.3 + 0.05 * i
		var amplitude := 0.06
		_cams[i].rotation.y = _originales[i].y + sin(_temps * vitesse) * amplitude
		_cams[i].rotation.x = _originales[i].x \
				+ sin(_temps * vitesse * 0.7) * amplitude * 0.3

	# REC clignotant
	var allume := fmod(_temps, 1.0) < 0.6
	for rec in _recs:
		rec.visible = allume

	# Horloges
	var heure := Time.get_time_string_from_system()
	for enfant in _composite.get_children():
		if enfant is Label and enfant.name.begins_with("Horloge_"):
			enfant.text = heure


## Active/desactive le mode alarme d'une camera.
func set_alarme(index: int, actif: bool) -> void:
	if index < 0 or index >= _cams.size():
		return
	_alarmes[index] = actif
	if index < _materiaux.size():
		_materiaux[index].set_shader_parameter("alarme", 1.0 if actif else 0.0)
	if index < _no_signal.size():
		_no_signal[index].visible = actif


