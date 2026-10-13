extends Node
## NetworkManager (autoload) : couche reseau ENet du jeu multiprof/classe.
## Modele A — serveur autoritatif : le PROF est le serveur (il parle au
## PLC Modbus et relaye l'etat), les ELEVES sont des clients afficheurs
## (ADR-013 respecte : une seule usine, une seule simulation).
##
## Les signaux du multiplayer sont connectes UNE fois dans _ready()
## (idempotent si le serveur redemarre).

signal joueur_connecte(id: int)
signal joueur_deconnecte(id: int)
signal serveur_pret()
signal connexion_echouee(raison: String)
signal pair_pret(id: int, nom: String)
signal transform_recu(id: int, pos: Vector3, rot_y: float)
signal message_recu(id_expediteur: int, nom: String, texte: String, prive: bool)
signal voix_recue(id_expediteur: int, donnees: PackedByteArray)
signal evenement_recu(type: String)

## Derniers evenements (type, ms) : un evenement peut arriver pendant
## qu'un poste construit encore son usine — il est garde ici et rejoue
## par la scene au moment de son abonnement (etat rattrape).
var derniers_evenements: Array = []
const MEMO_EVENEMENTS_MS := 120000

## Noms connus des pairs (registre de session, rempli par la scene).
var noms_pairs := {}

var peer: ENetMultiplayerPeer = null


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_down)


func demarrer_serveur(port: int, max_clients: int) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_clients)
	if err != OK:
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	print("Serveur ouvert sur le port ", port, " (", max_clients, " eleves max)")
	return OK


func demarrer_client(ip: String, port: int) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	print("Connexion vers ", ip, ":", port, "...")
	return OK


## Statut brut du peer (MultiplayerPeer.CONNECTION_*). Sondage sans
## course contrairement aux signaux : en localhost la connexion peut
## etre etablie avant meme qu'un auditeur soit branche.
func statut_connexion() -> int:
	if peer == null:
		return MultiplayerPeer.CONNECTION_DISCONNECTED
	return peer.get_connection_status()


## Fermeture propre (deconnexion, sortie de scene).
func arreter() -> void:
	if peer != null:
		peer.close()
		peer = null
	if multiplayer != null:
		multiplayer.multiplayer_peer = null


## --- Transport d'avatars : les RPC vivent sur cet autoload, PRESENT
## DES LE LANCEMENT sur tous les postes (chemin /root/NetworkManager
## identique partout). Les RPC sur la racine de scene 'Main' echouaient :
## le cache de chemins du SceneMultiplayer se desynchronise quand les
## scenes changent (menu -> splash -> usine) des deux cotes.

func annoncer_pret(nom: String) -> void:
	if peer != null:
		_signale_pret.rpc(get_node("/root/NetworkSession").PROTOCOLE, nom)


func envoyer_transform(id_pair: int, pos: Vector3, rot_y: float) -> void:
	if peer != null:
		_maj_transform_distant.rpc_id(id_pair, pos, rot_y)


@rpc("any_peer", "reliable")
func _signale_pret(proto: int, nom: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if id <= 0:
		return
	var proto_local: int = get_node("/root/NetworkSession").PROTOCOLE
	if proto != proto_local:
		push_error("Version reseau differente chez le pair %d (proto %d, local %d) : METTEZ A JOUR LES DEUX POSTES" % [id, proto, proto_local])
		pair_pret.emit(-id, nom)   # id negatif : signal d'incompatibilite
		return
	pair_pret.emit(id, nom)


@rpc("any_peer", "unreliable_ordered")
func _maj_transform_distant(pos: Vector3, rot_y: float) -> void:
	var id := multiplayer.get_remote_sender_id()
	if id > 0:
		transform_recu.emit(id, pos, rot_y)


## --- Chat : tout passe par le serveur (topologie en etoile).
## destinataire 0 = diffusion generale, sinon id du pair vise.
## L'emetteur affiche son propre message localement (pas d'echo).

func envoyer_message(texte: String, destinataire: int) -> void:
	if peer == null:
		return
	var nom := NetworkSession.nom_joueur
	if nom == "":
		nom = "PROF" if NetworkSession.est_hote() else "ELEVE"
	if multiplayer.is_server():
		# le prof EST le pair 1 : router localement, sans aller-retour
		# RPC vers soi-meme (source de la latence constatee)
		_router_message(1, nom, texte, destinataire)
	else:
		_message_chat.rpc_id(1, nom, texte, destinataire)


func _router_message(id_expediteur: int, nom: String, texte: String,
		destinataire: int) -> void:
	# cote serveur uniquement : relais vers la/les cibles
	if destinataire == 0:
		for id_pair in multiplayer.get_peers():
			if id_pair != id_expediteur:
				_diffuser_chat.rpc_id(id_pair, id_expediteur, nom, texte, false)
		# pas d'emit vers soi-meme : l'UI du prof a deja fait son echo
		# local (sinon doublon cote prof)
		if id_expediteur != 1:
			message_recu.emit(id_expediteur, nom, texte, false)
	else:
		var prive := true
		if destinataire == 1 and id_expediteur != 1:
			message_recu.emit(id_expediteur, nom, texte, prive)
		elif multiplayer.get_peers().has(destinataire):
			_diffuser_chat.rpc_id(destinataire, id_expediteur, nom, texte, prive)


@rpc("any_peer", "reliable")
func _message_chat(nom: String, texte: String, destinataire: int) -> void:
	if not multiplayer.is_server():
		return   # un client ne route pas : il adresse le serveur (pair 1)
	var id_e := multiplayer.get_remote_sender_id()
	if id_e <= 0:
		id_e = 1   # envoi du serveur lui-meme
	_router_message(id_e, nom, texte, destinataire)


@rpc("any_peer", "reliable")
func _diffuser_chat(id_expediteur: int, nom: String, texte: String,
		prive: bool) -> void:
	message_recu.emit(id_expediteur, nom, texte, prive)


## --- Voix (PTT) : PCM 16 kHz mono 16 bits par paquets ~50 ms.
## Diffusion a tous (un any_peer broadcast est relaye par le serveur) ;
## le lecteur de chaque poste spatialise la voix sur l'avatar.

func envoyer_voix(donnees: PackedByteArray) -> void:
	if peer != null and not donnees.is_empty():
		_paquet_voix.rpc(donnees)


@rpc("any_peer", "unreliable_ordered")
func _paquet_voix(donnees: PackedByteArray) -> void:
	var id := multiplayer.get_remote_sender_id()
	if id > 0:
		voix_recue.emit(id, donnees)


## --- Evenements de scenario (chantier 6) : incendie, confinement,
## evacuation, sprinklers, coupure. Autorite SERVEUR uniquement (le
## prof est maitre du jeu) ; chaque client rejoue l'evenement localement.

func diffuser_evenement(type: String) -> void:
	if peer != null and multiplayer.is_server():
		_evenement.rpc(type)


@rpc("authority", "reliable")
func _evenement(type: String) -> void:
	print("EVENEMENT recu : ", type)
	derniers_evenements.append([type, Time.get_ticks_msec()])
	evenement_recu.emit(type)


func _exit_tree() -> void:
	arreter()


func _on_peer_connected(id: int) -> void:
	joueur_connecte.emit(id)
	print("Joueur connecte : ", id)


func _on_peer_disconnected(id: int) -> void:
	joueur_deconnecte.emit(id)
	print("Joueur deconnecte : ", id)


func _on_connected() -> void:
	serveur_pret.emit()
	print("Connecte au serveur du professeur")


func _on_failed() -> void:
	connexion_echouee.emit("Connexion refusee")
	print("Echec de connexion")


func _on_server_down() -> void:
	connexion_echouee.emit("Serveur deconnecte")
	print("Le serveur du professeur s'est arrete")
