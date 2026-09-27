class_name NullPlcLink
extends RefCounted
## Lien PLC vide (Phase 0) : le cycle tourne sans automate connecte.
## Remplace par le serveur Modbus TCP en Phase 2 ; les tests utilisent
## leurs propres fakes implementant le meme contrat.


func publish_inputs(_io) -> void:
    pass


func pull_outputs(_io) -> void:
    pass
