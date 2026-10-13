extends Node
## Session reseau (autoload) : role choisi sur l'ecran de selection,
## parametres de connexion pour le futur mode multi-professeurs/eleves.

enum Role { AUCUN, PROF, ELEVE }

var role: Role = Role.AUCUN
var host_ip: String = ""
var nom_joueur: String = ""
## Version du protocole reseau : incremente a chaque changement de
## signature des RPC — deux versions differentes ne peuvent PAS se
## voir (avions silencieux). Le menu l'affiche explicitement.
const PROTOCOLE := 2
const PORT := 7777
const MAX_CLIENTS := 12

func est_hote() -> bool:
	return role == Role.PROF

func est_client() -> bool:
	return role == Role.ELEVE

## Toutes les IPv4 utilisables de la machine : boucle locale et APIPA
## (169.254.x.x = carte sans DHCP, ping impossible) ecartees.
func ips_locales() -> Array[String]:
	var candidates: Array[String] = []
	for addr in IP.get_local_addresses():
		if ":" in addr:
			continue        # IPv6 ecartee
		if addr.begins_with("127.") or addr.begins_with("0."):
			continue
		if addr.begins_with("169.254."):
			continue    # lien local auto-attribue : pas sur le reseau réel
		candidates.append(addr)
	return candidates


## Premiere IPv4 utilisable (communiquee aux eleves).
func ip_locale() -> String:
	var candidates := ips_locales()
	return candidates[0] if not candidates.is_empty() else "introuvable"
