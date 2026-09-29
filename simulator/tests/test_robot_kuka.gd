extends RefCounted
## Tests de la machine logique RobotKuka (6 axes).

const RobotKuka = preload("res://machines/robot_kuka.gd")
const IoTable = preload("res://io/io_table.gd")


func run(t) -> void:
    t.begin_suite("robot_kuka")

    var robot = RobotKuka.new()
    t.check_eq(robot.angles_deg.size(), 6, "six axes")

    # Points d'E/S : 6 angles en analogiques %IW5..%IW10
    var points = robot.create_io_points()
    t.check_eq(points.size(), 6, "6 points d'E/S")
    var io = IoTable.new()
    for point in points:
        t.check_eq(io.add_point(point), Error.OK, "point ajoutable : " + point.id)

    # Mode demo : les angles bougent, restent bornes par les amplitudes
    var seen_motion := false
    var max_abs := 0.0
    for step in range(120):
        robot.update(1.0 / 60.0)
        max_abs = maxf(max_abs, absf(float(robot.angles_deg[0])))
        if absf(float(robot.angles_deg[0])) > 1.0:
            seen_motion = true
    t.check(seen_motion, "en mode demo, A1 se deplace")
    t.check(max_abs <= 70.5, "A1 reste dans son amplitude (max " + str(max_abs) + ")")
    robot.scan_inputs(io)
    t.check(io.has_point("kuka_01.a3_deg"), "angles publies dans la table")
    t.check_eq(int(io.get_value("kuka_01.a1_deg") is float), 1, "valeurs flottantes publiees")

    # Determinisme : deux executions identiques donnent les memes angles
    var robot_b = RobotKuka.new()
    for step in range(60):
        robot_b.update(1.0 / 60.0)
    var robot_c = RobotKuka.new()
    for step in range(60):
        robot_c.update(1.0 / 60.0)
    t.check_eq(float(robot_b.angles_deg[2]), float(robot_c.angles_deg[2]), "determinisme A3")

    # Mode non-demo : le bras garde sa pose
    var quiet = RobotKuka.new()
    quiet.configure({"demo": false})
    for step in range(120):
        quiet.update(1.0 / 60.0)
    t.check_eq(float(quiet.angles_deg[0]), 0.0, "sans demo, angles figes")

    # configure refuse de toucher l'id (reserve au builder)
    t.check_eq(robot.configure({"id": "autre"}), Error.ERR_INVALID_PARAMETER, "params.id refuse")
