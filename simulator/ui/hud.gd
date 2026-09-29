extends CanvasLayer
## HUD du prototype : affiche l'etat des E/S (lecture seule, ADR-013).
## Construit programmatiquement pour rester independant de la scene.

var io = null
var link = null

var title_label: Label
var entry_label: Label
var exit_label: Label
var run_label: Label
var running_label: Label
var speed_label: Label
var position_label: Label
var encoder_label: Label
var modbus_label: Label
var hint_label: Label


func setup(p_io, p_link = null) -> void:
    io = p_io
    link = p_link


func _ready() -> void:
    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
    panel.position = Vector2(12, 12)
    panel.custom_minimum_size = Vector2(340, 0)

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.08, 0.09, 0.11, 0.85)
    style.set_corner_radius_all(8)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    panel.add_theme_stylebox_override("panel", style)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 4)
    panel.add_child(box)

    title_label = _make_label(box, "Industrial Simulator", true)
    entry_label = _make_label(box, "sensor_entry   = -")
    exit_label = _make_label(box, "sensor_exit    = -")
    run_label = _make_label(box, "run (cmd PLC)  = -")
    running_label = _make_label(box, "running        = -")
    speed_label = _make_label(box, "speed          = -")
    position_label = _make_label(box, "position       = -")
    encoder_label = _make_label(box, "encodeur       = -")
    modbus_label = _make_label(box, "modbus         = -")
    hint_label = _make_label(box, "ZQSD/WASD marcher | Maj courir | Espace saut | B boite | clic : souris | Echap : liberer", false, true)
    add_child(panel)


func _make_label(parent: Control, text: String, bold := false, dim := false) -> Label:
    var label := Label.new()
    label.text = text
    if bold:
        label.add_theme_font_size_override("font_size", 18)
    if dim:
        label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
    parent.add_child(label)
    return label


func refresh() -> void:
    if io == null:
        return
    _bool_line(entry_label, "sensor_entry")
    _bool_line(exit_label, "sensor_exit")
    _bool_line(run_label, "conveyor_01.run")
    _bool_line(running_label, "conveyor_01.running")
    speed_label.text = "speed          = %.2f m/s" % float(io.get_value("conveyor_01.speed", 0.0))
    var position_value := float(io.get_value("conveyor_01.position", -1.0))
    position_label.text = "position       = %s" % (
        "%.2f m" % position_value if position_value >= 0.0 else "aucune boite"
    )
    encoder_label.text = "encodeur       = %d impulsions" % int(io.get_value("conveyor_01.belt_encoder", 0))
    if link != null:
        modbus_label.text = "modbus         : port %d, %d requetes" % [
            link.server.port, link.server.requests_served
        ]
    else:
        modbus_label.text = "modbus         : inactif"


func _bool_line(label: Label, point_id: String) -> void:
    var on: bool = bool(io.get_value(point_id, false))
    label.text = "%-18s= %s" % [point_id, "TRUE" if on else "FALSE"]
    label.add_theme_color_override(
        "font_color", Color(0.4, 1.0, 0.4) if on else Color(0.75, 0.75, 0.75)
    )
