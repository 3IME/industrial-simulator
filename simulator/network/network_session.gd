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

## Premiere IPv4 non-boucle locale de la machine (communiquee aux eleves).
func ip_locale() -> String:
	for addr in IP.get_local_addresses():
		if ":" in addr:
			continue        # IPv6 ecartee
		if addr.begins_with("127.") or addr.begins_with("0."):
			continue
		return addr
	return "introuvable"
