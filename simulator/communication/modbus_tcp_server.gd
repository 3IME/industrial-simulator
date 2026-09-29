class_name ModbusTcpServer
extends RefCounted
## Esclave (serveur) Modbus TCP en GDScript pur, sans dependance externe (ADR-011).
##
## Le serveur expose quatre banques memoire (image d'E/S) :
##   coils             : sorties digitales ecrites par le maitre (%QX)
##   discrete_inputs   : entrees digitales lues par le maitre (%IX)
##   input_registers   : entrees analogiques/compteurs lues par le maitre (%IW)
##   holding_registers : sorties analogiques ecrites par le maitre (%QW)
##
## Les banques sont synchronisees avec la table d'E/S par ModbusPlcLink, aux
## temps 2/3 du cycle du moteur. poll() doit etre appele regulierement (le
## moteur le fait via le hook optionnel du PlcLink ; un Node Godot le fera
## aussi en Phase 5).
##
## Codes fonction supportes : 01, 02, 03, 04, 05, 06, 0F, 10.
## Exceptions : 01 (fonction inconnue), 02 (adresse), 03 (valeur).

const DEFAULT_PORT := 502
const MAX_READ_BITS := 2000
const MAX_READ_REGISTERS := 125
const MAX_WRITE_BITS := 1968
const MAX_WRITE_REGISTERS := 123

const FC_READ_COILS := 1
const FC_READ_DISCRETE_INPUTS := 2
const FC_READ_HOLDING_REGISTERS := 3
const FC_READ_INPUT_REGISTERS := 4
const FC_WRITE_SINGLE_COIL := 5
const FC_WRITE_SINGLE_REGISTER := 6
const FC_WRITE_MULTIPLE_COILS := 15
const FC_WRITE_MULTIPLE_REGISTERS := 16

const EX_ILLEGAL_FUNCTION := 1
const EX_ILLEGAL_ADDRESS := 2
const EX_ILLEGAL_VALUE := 3

var port := DEFAULT_PORT
var bind_address := "0.0.0.0"
var unit_id := 1

# Banques (image d'E/S)
var coils: Array = []                # Array[bool]
var discrete_inputs: Array = []      # Array[bool]
var input_registers: Array = []      # Array[int] 0..65535
var holding_registers: Array = []    # Array[int] 0..65535

var requests_served := 0

var _tcp := TCPServer.new()
var _peers: Array = []               # { peer: StreamPeerTCP, buffer: PackedByteArray }
var _dirty_coils := {}               # offsets ecrits par le maitre depuis le dernier take
var _dirty_holding := {}


## Dimensionne les quatre banques (les banques non referencees restent vides :
## tout acces y retourne l'exception 02).
func configure_bank_sizes(n_coils: int, n_discrete: int, n_input_regs: int, n_holding: int) -> void:
    coils.resize(maxi(n_coils, 0))
    coils.fill(false)
    discrete_inputs.resize(maxi(n_discrete, 0))
    discrete_inputs.fill(false)
    input_registers.resize(maxi(n_input_regs, 0))
    input_registers.fill(0)
    holding_registers.resize(maxi(n_holding, 0))
    holding_registers.fill(0)
    _dirty_coils = {}
    _dirty_holding = {}


## Se met a l'ecoute. Le port passe ici (si > 0) remplace le port courant ;
## l'adresse de bind peut etre precisee (defaut : toutes les interfaces).
func listen(p_port: int = -1, p_bind_address: String = "") -> Error:
    if p_port > 0:
        port = p_port
    if p_bind_address != "":
        bind_address = p_bind_address
    return _tcp.listen(port, bind_address)


func is_listening() -> bool:
    return _tcp.is_listening()


## Ferme toutes les connexions et arrete l'ecoute.
func stop() -> void:
    for p in _peers:
        (p.peer as StreamPeerTCP).disconnect_from_host()
    _peers.clear()
    _tcp.stop()


## Accepte les nouvelles connexions et traite les requetes en attente.
## A appeler regulierement (chaque cycle moteur, chaque frame en 3D).
func poll() -> void:
    if not _tcp.is_listening():
        return
    while _tcp.is_connection_available():
        var peer := _tcp.take_connection()
        peer.set_no_delay(true)
        _peers.append({ "peer": peer, "buffer": PackedByteArray() })
    var alive: Array = []
    for p in _peers:
        if _process_peer(p):
            alive.append(p)
    _peers = alive


## Sorties digitales ecrites par le maitre depuis le dernier appel
## (consomme puis remet a zero ; utilise par ModbusPlcLink).
func take_dirty_coils() -> Dictionary:
    var dirty := _dirty_coils
    _dirty_coils = {}
    return dirty


## Sorties analogiques ecrites par le maitre depuis le dernier appel.
func take_dirty_holding() -> Dictionary:
    var dirty := _dirty_holding
    _dirty_holding = {}
    return dirty


func _process_peer(p: Dictionary) -> bool:
    var peer: StreamPeerTCP = p.peer
    # Verifier l'etat AVANT poll() : poll() sur un pair ferme affiche une
    # erreur interne Godot ("!is_open()"). Un pair accepte est etabli ; tout
    # autre etat (remote fermé, erreur) => eviction immediate.
    if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
        return false
    if peer.poll() != Error.OK:
        return false
    var available: int = peer.get_available_bytes()
    if available == -1:
        # Socket mort pour l'OS (fermeture sale du client) alors que le
        # statut Godot est encore CONNECTED : eviction, sinon erreur
        # "!is_open()" a chaque poll.
        return false
    # NB : PackedByteArray est copy-on-write — on reconstruit le buffer local
    # puis on le restocke explicitement dans le Dictionary (jamais de mutation
    # via un simple cast, qui n'ecrirait que sur une copie temporaire).
    var buf: PackedByteArray = p["buffer"]
    if available > 0:
        var chunk = peer.get_partial_data(available)
        if chunk[0] != Error.OK:
            return false
        buf = buf + chunk[1]
    var consumed := 0
    var buf_size: int = buf.size()
    while buf_size - consumed >= 7:
        # MBAP : transaction(2) protocole(2) longueur(2) unite(1) - big-endian
        var length := _be16(buf, consumed + 4)
        if length < 2 or length > 254:
            return false    # trame absurde : connexion coupee
        var frame_size := 6 + length
        if buf_size - consumed < frame_size:
            break
        var request_unit: int = buf.decode_u8(consumed + 6)
        var pdu := buf.slice(consumed + 7, consumed + frame_size)
        var response: Variant = _handle_pdu(request_unit, pdu)
        if response != null:
            var transaction := _be16(buf, consumed)
            var err: int = peer.put_data(_encode_frame(transaction, request_unit, response))
            if err != Error.OK:
                return false
            requests_served += 1
        consumed += frame_size
    p["buffer"] = buf.slice(consumed)
    return true


func _encode_frame(transaction: int, unit: int, pdu: PackedByteArray) -> PackedByteArray:
    var length := pdu.size() + 1
    var frame := PackedByteArray([
        (transaction >> 8) & 0xFF, transaction & 0xFF,
        0, 0,
        (length >> 8) & 0xFF, length & 0xFF,
        unit & 0xFF,
    ])
    frame.append_array(pdu)
    return frame


## Traite un PDU. Retourne le PDU de reponse, ou null pour ne pas repondre
## (unit id ne correspondant pas, PDU vide).
func _handle_pdu(unit: int, pdu: PackedByteArray):
    if unit != unit_id:
        return null
    if pdu.is_empty():
        return null
    var fc: int = pdu[0]
    match fc:
        FC_READ_COILS:
            return _read_bits(coils, pdu)
        FC_READ_DISCRETE_INPUTS:
            return _read_bits(discrete_inputs, pdu)
        FC_READ_HOLDING_REGISTERS:
            return _read_registers(holding_registers, pdu)
        FC_READ_INPUT_REGISTERS:
            return _read_registers(input_registers, pdu)
        FC_WRITE_SINGLE_COIL:
            return _write_single_coil(pdu)
        FC_WRITE_SINGLE_REGISTER:
            return _write_single_register(pdu)
        FC_WRITE_MULTIPLE_COILS:
            return _write_multiple_coils(pdu)
        FC_WRITE_MULTIPLE_REGISTERS:
            return _write_multiple_registers(pdu)
        _:
            return _exception(fc, EX_ILLEGAL_FUNCTION)


func _read_bits(bank: Array, pdu: PackedByteArray) -> PackedByteArray:
    if pdu.size() != 5:
        return _exception(pdu[0], EX_ILLEGAL_VALUE)
    var offset := _be16(pdu, 1)
    var count := _be16(pdu, 3)
    if count < 1 or count > MAX_READ_BITS:
        return _exception(pdu[0], EX_ILLEGAL_VALUE)
    if offset + count > bank.size():
        return _exception(pdu[0], EX_ILLEGAL_ADDRESS)
    var byte_count := (count + 7) / 8
    var response := PackedByteArray([pdu[0], byte_count])
    for b in byte_count:
        var byte := 0
        for k in 8:
            var idx := b * 8 + k
            if idx < count and bool(bank[offset + idx]):
                byte |= 1 << k
        response.append(byte)
    return response


func _read_registers(bank: Array, pdu: PackedByteArray) -> PackedByteArray:
    if pdu.size() != 5:
        return _exception(pdu[0], EX_ILLEGAL_VALUE)
    var offset := _be16(pdu, 1)
    var count := _be16(pdu, 3)
    if count < 1 or count > MAX_READ_REGISTERS:
        return _exception(pdu[0], EX_ILLEGAL_VALUE)
    if offset + count > bank.size():
        return _exception(pdu[0], EX_ILLEGAL_ADDRESS)
    var response := PackedByteArray([pdu[0], count * 2])
    for i in count:
        var value: int = int(bank[offset + i]) & 0xFFFF
        response.append((value >> 8) & 0xFF)
        response.append(value & 0xFF)
    return response


func _write_single_coil(pdu: PackedByteArray) -> PackedByteArray:
    if pdu.size() != 5:
        return _exception(pdu[0], EX_ILLEGAL_VALUE)
    var offset := _be16(pdu, 1)
    var value := _be16(pdu, 3)
    if value != 0x0000 and value != 0xFF00:
        return _exception(pdu[0], EX_ILLEGAL_VALUE)
    if offset >= coils.size():
        return _exception(pdu[0], EX_ILLEGAL_ADDRESS)
    coils[offset] = value == 0xFF00
    _dirty_coils[offset] = true
    return pdu.duplicate()


func _write_single_register(pdu: PackedByteArray) -> PackedByteArray:
    if pdu.size() != 5:
        return _exception(pdu[0], EX_ILLEGAL_VALUE)
    var offset := _be16(pdu, 1)
    var value := _be16(pdu, 3)
    if offset >= holding_registers.size():
        return _exception(pdu[0], EX_ILLEGAL_ADDRESS)
    holding_registers[offset] = value
    _dirty_holding[offset] = true
    return pdu.duplicate()


func _write_multiple_coils(pdu: PackedByteArray) -> PackedByteArray:
    if pdu.size() < 6:
        return _exception(pdu[0], EX_ILLEGAL_VALUE)
    var offset := _be16(pdu, 1)
    var count := _be16(pdu, 3)
    var byte_count: int = pdu[5]
    if count < 1 or count > MAX_WRITE_BITS or byte_count != (count + 7) / 8 or pdu.size() != 6 + byte_count:
        return _exception(pdu[0], EX_ILLEGAL_VALUE)
    if offset + count > coils.size():
        return _exception(pdu[0], EX_ILLEGAL_ADDRESS)
    for i in count:
        var byte: int = pdu[6 + i / 8]
        var on := (byte >> (i % 8)) & 1 == 1
        coils[offset + i] = on
        _dirty_coils[offset + i] = true
    var response := PackedByteArray([pdu[0]])
    response.append_array(_u16_bytes(offset))
    response.append_array(_u16_bytes(count))
    return response


func _write_multiple_registers(pdu: PackedByteArray) -> PackedByteArray:
    if pdu.size() < 6:
        return _exception(pdu[0], EX_ILLEGAL_VALUE)
    var offset := _be16(pdu, 1)
    var count := _be16(pdu, 3)
    var byte_count: int = pdu[5]
    if count < 1 or count > MAX_WRITE_REGISTERS or byte_count != count * 2 or pdu.size() != 6 + byte_count:
        return _exception(pdu[0], EX_ILLEGAL_VALUE)
    if offset + count > holding_registers.size():
        return _exception(pdu[0], EX_ILLEGAL_ADDRESS)
    for i in count:
        var value := _be16(pdu, 6 + i * 2)
        holding_registers[offset + i] = value
        _dirty_holding[offset + i] = true
    var response := PackedByteArray([pdu[0]])
    response.append_array(_u16_bytes(offset))
    response.append_array(_u16_bytes(count))
    return response


func _exception(fc: int, code: int) -> PackedByteArray:
    return PackedByteArray([(fc | 0x80) & 0xFF, code])


## Lecture big-endian d'un u16 (Modbus est big-endian ; les encode_u16/decode_u16
## de PackedByteArray sont little-endian, on n'y touche pas).
static func _be16(b: PackedByteArray, offset: int) -> int:
    return (b[offset] << 8) | b[offset + 1]


static func _u16_bytes(value: int) -> PackedByteArray:
    return PackedByteArray([(value >> 8) & 0xFF, value & 0xFF])
