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
		_signale_pret.rpc(nom)


func envoyer_transform(id_pair: int, pos: Vector3, rot_y: float) -> void:
	if peer != null:
		_maj_transform_distant.rpc_id(id_pair, pos, rot_y)


@rpc("any_peer", "reliable")
func _signale_pret(nom: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if id > 0:
		pair_pret.emit(id, nom)


@rpc("any_peer", "unreliable_ordered")
func _maj_transform_distant(pos: Vector3, rot_y: float) -> void:
	var id := multiplayer.get_remote_sender_id()
	if id > 0:
		transform_recu.emit(id, pos, rot_y)


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
