extends Control
## Ecran de demarrage : logo 3IME, son d'accueil, lien vers le site.
## Bascule vers la scene principale apres quelques secondes, ou au clic/touche.

const MAIN_SCENE := "res://scenes/main.tscn"
const LOGO_PATH := "res://assets/branding/logo2.svg"
const SOUND_PATH := "res://assets/branding/access_granted.mp3"
const SITE_URL := "https://www.3ime.fr/"
const DUREE_AFFICHAGE := 3.5
const FONDU := 0.4

var finished := false


func _ready() -> void:
    # Fond sombre plein ecran
    var bg := ColorRect.new()
    bg.color = Color(0.04, 0.05, 0.08)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    # Colonne centree : logo, 3IME, sous-titre, lien
    var column := VBoxContainer.new()
    column.set_anchors_preset(Control.PRESET_CENTER)
    column.add_theme_constant_override("separation", 18)
    add_child(column)

    var logo := TextureRect.new()
    var texture = load(LOGO_PATH)
    if texture != null:
        logo.texture = texture
        # SVG au format portrait (612 x 792) : affichage ~300 px de large
        logo.custom_minimum_size = Vector2(300, 388)
        logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        column.add_child(logo)

    var title := Label.new()
    title.text = "3IME"
    title.add_theme_font_size_override("font_size", 72)
    title.add_theme_color_override("font_color", Color(0.92, 0.93, 0.95))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Industrial Simulator"
    subtitle.add_theme_font_size_override("font_size", 22)
    subtitle.add_theme_color_override("font_color", Color(0.55, 0.6, 0.65))
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(subtitle)

    var link := Button.new()
    link.text = SITE_URL
    link.flat = true
    link.add_theme_font_size_override("font_size", 18)
    link.add_theme_color_override("font_color", Color(0.35, 0.65, 0.95))
    link.pressed.connect(func() -> void: OS.shell_open(SITE_URL))
    column.add_child(link)

    var hint := Label.new()
    hint.text = "Cliquez ou appuyez sur une touche pour continuer"
    hint.add_theme_font_size_override("font_size", 13)
    hint.add_theme_color_override("font_color", Color(0.45, 0.47, 0.5))
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(hint)

    # Son d'accueil
    var player := AudioStreamPlayer.new()
    var sound = load(SOUND_PATH)
    if sound != null:
        player.stream = sound
        add_child(player)
        player.play()

    # Fondu d'entree puis minuterie
    modulate.a = 0.0
    var tween := create_tween()
    tween.tween_property(self, "modulate:a", 1.0, FONDU)
    await get_tree().create_timer(DUREE_AFFICHAGE).timeout
    _finish()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        _finish()
    elif event is InputEventMouseButton and event.pressed:
        _finish()


func _finish() -> void:
    if finished:
        return
    finished = true
    # Preuve visuelle optionnelle : capturer le splash avant de basculer
    if "--capture" in OS.get_cmdline_user_args():
        var image := get_viewport().get_texture().get_image()
        image.save_png("res://capture_splash.png")
        print("Capture ecrite : res://capture_splash.png")
    var tween := create_tween()
    tween.tween_property(self, "modulate:a", 0.0, FONDU)
    await tween.finished
    get_tree().change_scene_to_file(MAIN_SCENE)
