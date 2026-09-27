extends SceneTree
## Runner headless des tests du simulateur.
##
## Utilisation :
##   godot --headless --path simulator --script res://tests/run_tests.gd
## (ou scripts/run_tests.bat / scripts/run_tests.sh depuis la racine du depot)
##
## Code de sortie 0 si tous les tests passent, 1 sinon.

const TestFramework = preload("res://tests/test_framework.gd")
const SUITES = [
    preload("res://tests/test_io_point.gd"),
    preload("res://tests/test_io_table.gd"),
    preload("res://tests/test_io_mapping.gd"),
    preload("res://tests/test_quality.gd"),
    preload("res://tests/test_conveyor.gd"),
    preload("res://tests/test_simulation_engine.gd"),
    preload("res://tests/test_machine_contract.gd"),
    preload("res://tests/test_factory_builder.gd"),
]


func _initialize() -> void:
    var t := TestFramework.new()
    print("=== Industrial Simulator - tests Phases 0-1 ===")
    for suite in SUITES:
        suite.new().run(t)
    print("")
    print(t.summary())
    quit(0 if t.failures == 0 else 1)
