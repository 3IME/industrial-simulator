extends Node
## Voix push-to-talk (option B, 100% GDScript).
## Toucher V maintenue = parler : le micro alimente un bus PRIVÉ muet
## muni d'un AudioEffectCapture ; chaque ~50 ms on tire les frames,
## on convertit en mono 16 kHz 16 bits et on diffuse par RPC.
## Indicateur 'micro' affiché pendant l'émission.

const TAUX_VOX := 16000          # qualité téléphone, ~32 ko/s en émission
const MS_TRAME := 50             # granularité d'envoi
const RAPPORT := 48000.0 / float(TAUX_VOX)   # 3 (recalcule au demarrage)

var _capture: AudioEffectCapture = null
var _lecteur_micro: AudioStreamPlayer = null
var _manager: Node = null
var _accumulateur: PackedFloat32Array = PackedFloat32Array()
var _reste_a_envoyer := 0
var _indice_voix: Label = null


func _ready() -> void:
	_manager = get_node_or_null("/root/NetworkManager")
	if _manager == null:
		queue_free()
		return
	_construire_indicateur()
	if not _configurer_micro():
		print("Voix : aucun micro detecte — PTT desactive")


func _configurer_micro() -> bool:
	if AudioServer.get_input_device_list().is_empty():
		return false
	var indice := AudioServer.bus_count
	AudioServer.add_bus(indice)
	AudioServer.set_bus_name(indice, "Voix")
	AudioServer.set_bus_mute(indice, true)   # jamais d'echo local
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 0.5   # tampon de capture (secondes)
	AudioServer.add_bus_effect(indice, _capture)
	_lecteur_micro = AudioStreamPlayer.new()
	_lecteur_micro.stream = AudioStreamMicrophone.new()
	_lecteur_micro.bus = "Voix"
	add_child(_lecteur_micro)
	_lecteur_micro.play()
	return true


func _process(delta: float) -> void:
	if _capture == null:
		return
	# Pendant une saisie GUI (chat), V fait partie du texte : ne pas
	# transmettre (lecon de la barre d'espace)
	var saisie_active := get_viewport().gui_get_focus_owner() is LineEdit
	var parle := Input.is_physical_key_pressed(KEY_V) and not saisie_active
	_indice_voix.visible = parle
	if not parle and _accumulateur.is_empty():
		_vider_capture()
		return
	_tirer_et_convertire()
	var seuil := int(TAUX_VOX * MS_TRAME / 1000.0)
	if _accumulateur.size() >= seuil:
		# plafond anti-retard : si le _process a ete affame (rafale),
		# ne pas laisser le retard s'accumuler — garder les 250 ms
		# les plus recentes
		if _accumulateur.size() > TAUX_VOX / 4:
			_accumulateur = _accumulateur.slice(
				_accumulateur.size() - int(TAUX_VOX / 4))
		_envoyer_bloc(_accumulateur.size())


## Tire les frames du bus, moyenne les canaux, sous-echantillonne
## au taux voix et accumule.
func _tirer_et_convertire() -> void:
	while _capture.get_frames_available() > 0:
		var bloc: PackedVector2Array = _capture.get_buffer(
			_capture.get_frames_available())
		var pas := int(round(AudioServer.get_mix_rate() / float(TAUX_VOX)))
		var i := 0
		while i + pas <= bloc.size():
			var total := 0.0
			for k in range(pas):
				total += (bloc[i + k].x + bloc[i + k].y) * 0.5
			_accumulateur.append(total / pas)
			i += pas
		if i < bloc.size():
			_capture.discard_buffer()   # reste incomplet : jete, ~2 ms
			break


## Vide le tampon de capture quand on ne parle pas (evite le retard).
func _vider_capture() -> void:
	if _capture.get_frames_available() > 0:
		_capture.get_buffer(_capture.get_frames_available())


var _premier_bloc := true


func _envoyer_bloc(taille: int) -> void:
	if _premier_bloc:
		_premier_bloc = false
		var somme := 0.0
		for v in _accumulateur.slice(0, taille):
			somme += v * v
		var rms := sqrt(somme / taille)
		print("Voix : premier bloc emis (", taille * 2, " octets, niveau RMS ",
			"%.4f" % rms, ")", " — SILENCE ? verifier le micro" if rms < 0.001 else "")
	var donnees := PackedByteArray()
	donnees.resize(taille * 2)
	for i in range(taille):
		var v := int(clampf(_accumulateur[i], -1.0, 1.0) * 32767.0)
		donnees.encode_s16(i * 2, v)
	_manager.envoyer_voix(donnees)
	# retire les samples emis
	_accumulateur = _accumulateur.slice(taille)


func _construire_indicateur() -> void:
	var couche := CanvasLayer.new()
	couche.layer = 6
	add_child(couche)
	_indice_voix = Label.new()
	_indice_voix.text = "● MICRO"
	_indice_voix.anchor_left = 1.0
	_indice_voix.anchor_right = 1.0
	_indice_voix.offset_left = -120
	_indice_voix.offset_top = 14
	_indice_voix.offset_right = -16
	_indice_voix.offset_bottom = 40
	_indice_voix.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_indice_voix.add_theme_font_size_override("font_size", 18)
	_indice_voix.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	_indice_voix.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04))
	_indice_voix.add_theme_constant_override("outline_size", 8)
	_indice_voix.visible = false
	couche.add_child(_indice_voix)
