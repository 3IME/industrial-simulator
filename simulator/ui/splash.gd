extends Control
## Ecran de demarrage : logo 3IME, son d'accueil, lien vers le site.
## Bascule vers la scene principale apres quelques secondes, ou au clic/touche.

const MAIN_SCENE := "res://scenes/main.tscn"
const LOGO_PATH := "res://assets/branding/logo2.svg"
const SOUND_PATH := "res://assets/branding/access_granted.mp3"
const SITE_URL := "https://www.3ime.fr/"
const DUREE_AFFICHAGE := 3.5    # repli si le son est absent
const MARGE_APRES_MUSIQUE := 1.5
const FONDU := 0.4

var finished := false


func _ready() -> void:
    # Fond sombre plein ecran
    var bg := ColorRect.new()
    bg.color = Color(0.04, 0.05, 0.08)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    # Colonne centree : conteneur plein ecran, enfants centres en largeur
    # (SIZE_SHRINK_CENTER) et bloc centre en hauteur (ALIGNMENT_CENTER).
    var column := VBoxContainer.new()
    column.set_anchors_preset(Control.PRESET_FULL_RECT)
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 12)
    add_child(column)

    var logo := TextureRect.new()
    var texture = load(LOGO_PATH)
    if texture != null:
        # Rond blanc derriere le logo. L'artwork du SVG n'occupe qu'une partie
        # de son canvas, decalee vers le bas-droit (mesure pixel) : on compense
        # en positionnant le rect de texture pour que le VISIBLE soit centre.
        var holder := Control.new()
        holder.custom_minimum_size = Vector2(340, 340)
        var circle := Panel.new()
        var circle_style := StyleBoxFlat.new()
        circle_style.bg_color = Color.WHITE
        circle_style.set_corner_radius_all(170)
        circle.add_theme_stylebox_override("panel", circle_style)
        circle.position = Vector2.ZERO
        circle.size = Vector2(340, 340)
        holder.add_child(circle)
        # Artwork reel du SVG (canvas 612x792, mesure alpha via Godot) :
        # bbox (80,122)-(545,650), centre (312.5, 386.0), taille 466x529.
        # Cible : artwork a ~62 % du diametre du cercle.
        # PIEGE Godot : expand_mode AVANT size — sinon la taille est ecrasee
        # par la taille native de la texture (min size par defaut).
        var k := 315.0 / 792.0
        var logo_size := Vector2(612.0 * k, 792.0 * k)
        logo.texture = texture
        logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        # -8 px : le haut de la bbox est clairseme (ombre douce de l'engrenage),
        # la masse optique reelle est ~8 px sous le centre geometrique.
        logo.position = Vector2(170.0 - k * 312.5, 170.0 - k * 386.0 - 8.0)
        logo.size = logo_size
        holder.add_child(logo)
        logo.size = logo_size
        column.add_child(holder)

    var title := Label.new()
    title.text = "3IME"
    title.add_theme_font_size_override("font_size", 64)
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

    # Tous les enfants de la colonne centres horizontalement
    for child in column.get_children():
        child.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

    # Son d'accueil
    var player := AudioStreamPlayer.new()
    var sound = load(SOUND_PATH)
    if sound != null:
        player.stream = sound
        add_child(player)
        player.play()

    # Fondu d'entree puis minuterie : duree de la musique + 1,5 s
    modulate.a = 0.0
    var tween := create_tween()
    tween.tween_property(self, "modulate:a", 1.0, FONDU)
    var duree := DUREE_AFFICHAGE
    if sound != null and sound is AudioStream:
        duree = sound.get_length() + MARGE_APRES_MUSIQUE
    await get_tree().create_timer(duree).timeout
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
    _start_async_load()


## Chargement de la scene principale EN ARRIERE-PLAN : change_scene_to_file
## bloque le thread principal (ecran gris fige ~3 s avec notre usine).
## Ici le splash reste visible et anime pendant le chargement threade.
var _loading := false
var _load_bar: ProgressBar


func _start_async_load() -> void:
    var err := ResourceLoader.load_threaded_request(MAIN_SCENE)
    if err != Error.OK:
        push_warning("chargement differe indisponible, repli synchrone")
        get_tree().change_scene_to_file(MAIN_SCENE)
        return
    _loading = true

    var label := Label.new()
    label.text = "Chargement de l'usine..."
    label.add_theme_font_size_override("font_size", 20)
    label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
    label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    label.offset_bottom = -96.0
    label.offset_top = -124.0
    add_child(label)

    _load_bar = ProgressBar.new()
    _load_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    _load_bar.custom_minimum_size = Vector2(320, 12)
    _load_bar.show_percentage = false
    _load_bar.offset_bottom = -70.0
    _load_bar.offset_top = -58.0
    add_child(_load_bar)


func _process(_delta: float) -> void:
    if not _loading:
        return
    var progress: Array = []
    var status := ResourceLoader.load_threaded_get_status(MAIN_SCENE, progress)
    if _load_bar != null and progress.size() > 0:
        _load_bar.value = float(progress[0]) * 100.0
    if status == ResourceLoader.THREAD_LOAD_LOADED:
        _loading = false
        var packed = ResourceLoader.load_threaded_get(MAIN_SCENE)
        var tween := create_tween()
        tween.tween_property(self, "modulate:a", 0.0, 0.2)
        tween.tween_callback(func() -> void:
            get_tree().change_scene_to_packed(packed))
    elif status == ResourceLoader.THREAD_LOAD_FAILED \
            or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
        _loading = false
        push_warning("chargement differe echoue, repli synchrone")
        get_tree().change_scene_to_file(MAIN_SCENE)
