extends Node
## Session reseau (autoload) : role choisi sur l'ecran de selection,
## parametres de connexion pour le futur mode multi-professeurs/eleves.

enum Role { AUCUN, PROF, ELEVE }

var role: Role = Role.AUCUN
var host_ip: String = ""
const PORT := 7777
const MAX_CLIENTS := 12

func est_hote() -> bool:
	return role == Role.PROF

func est_client() -> bool:
	return role == Role.ELEVE
