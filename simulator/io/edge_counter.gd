class_name EdgeCounter
extends RefCounted
## Compteur d'evenements generique : compte les fronts montants d'un signal
## booleen (capteur, commande...). Utilise par les machines pour leurs points
## COUNTER et pour detecter les fronts de commandes.


var previous := false
var count := 0


## Observe l'etat courant du signal. Retourne true sur front montant
## (transition false -> true), false sinon. Le compteur s'incremente
## sur chaque front montant.
func observe(state: bool) -> bool:
    var rising := state and not previous
    if rising:
        count += 1
    previous = state
    return rising


## Remise a zero du compteur seule : l'etat du signal est conserve, un signal
## deja haut ne produira pas de nouveau front apres remise a zero (comportement
## d'un compteur industriel reel).
func reset() -> void:
    count = 0


## Remise a zero complete, y compris l'etat du signal observe.
func reset_all() -> void:
    count = 0
    previous = false
