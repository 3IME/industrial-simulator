extends RefCounted
## Mini framework d'assertions pour les tests headless (ADR-002 : aucune
## dependance externe). Le runner est run_tests.gd.


var checks := 0
var failures := 0
var _suite := ""


func begin_suite(suite_name: String) -> void:
    _suite = suite_name
    print("")
    print("== " + suite_name + " ==")


func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("  ECHEC [" + _suite + "] " + message)


func check_eq(got: Variant, expected: Variant, message: String) -> void:
    check(
        got == expected,
        message + " (obtenu: " + str(got) + ", attendu: " + str(expected) + ")"
    )


func check_almost_eq(got: float, expected: float, epsilon: float, message: String) -> void:
    check(
        absf(got - expected) <= epsilon,
        message + " (obtenu: " + str(got) + ", attendu: ~" + str(expected) + ")"
    )


func check_not_null(value: Variant, message: String) -> void:
    check(value != null, message)


func check_is_null(value: Variant, message: String) -> void:
    check(value == null, message)


func summary() -> String:
    var verdict := "OK" if failures == 0 else "ECHEC"
    return "Tests: %d assertions, %d echecs -> %s" % [checks, failures, verdict]
