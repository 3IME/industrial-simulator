extends RefCounted
## Tests du serveur Modbus TCP : protocole sur boucle locale + chaine complete
## capteur virtuel -> moteur d'E/S -> Modbus TCP -> client (PLC) -> moteur virtuel.
##
## Ces tests utilisent de vraies sockets TCP sur 127.0.0.1 (ports 15020/15021) :
## ils ne sont pas deterministes au sens strict du cycle, mais les valeurs
## echangees le sont.

const ModbusTcpServer = preload("res://communication/modbus_tcp_server.gd")
const ModbusPlcLink = preload("res://communication/modbus_plc_link.gd")
const IoMapping = preload("res://io/io_mapping.gd")
const IoTable = preload("res://io/io_table.gd")
const Conveyor = preload("res://machines/conveyor.gd")
const SimulationEngine = preload("res://simulation/simulation_engine.gd")


## Client Modbus de test : construit les trames, attend les reponses en
## pollant le serveur via un rappel (le simulateur est mono-thread).
class TestClient extends RefCounted:
    var peer := StreamPeerTCP.new()
    var transaction := 0
    var server_poll: Callable = Callable()

    func connect_to(port: int) -> bool:
        peer.connect_to_host("127.0.0.1", port)
        for i in range(400):
            peer.poll()
            if server_poll.is_valid():
                server_poll.call()
            var status := peer.get_status()
            if status == StreamPeerTCP.STATUS_CONNECTED:
                return true
            if status == StreamPeerTCP.STATUS_ERROR:
                return false
            OS.delay_usec(500)
        return false

    func _wait_available(n: int) -> bool:
        for i in range(400):
            peer.poll()
            if server_poll.is_valid():
                server_poll.call()
            if peer.get_available_bytes() >= n:
                return true
            OS.delay_usec(500)
        return false

    ## Envoie un PDU et retourne le PDU de reponse (vide si aucune reponse).
    ## Modbus est big-endian : les u16 sont construits octet par octet
    ## (encode_u16/decode_u16 de Godot sont little-endian).
    func transact(pdu: PackedByteArray, unit: int = 1) -> PackedByteArray:
        transaction += 1
        var length := pdu.size() + 1
        var frame := PackedByteArray([
            (transaction >> 8) & 0xFF, transaction & 0xFF,
            0, 0,
            (length >> 8) & 0xFF, length & 0xFF,
            unit & 0xFF,
        ])
        frame.append_array(pdu)
        if peer.put_data(frame) != Error.OK:
            return PackedByteArray()
        if not _wait_available(7):
            return PackedByteArray()
        var header = peer.get_partial_data(7)[1]
        var resp_length: int = (header[4] << 8) | header[5]
        var rest_n: int = resp_length - 1
        if rest_n > 0 and not _wait_available(rest_n):
            return PackedByteArray()
        if rest_n <= 0:
            return PackedByteArray()
        return peer.get_partial_data(rest_n)[1]

    ## Retourne { ok, exception, values } pour une lecture de bits.
    func read_bits(fc: int, offset: int, count: int) -> Dictionary:
        var pdu := PackedByteArray([fc])
        pdu.append_array(_u16(offset))
        pdu.append_array(_u16(count))
        var resp := transact(pdu)
        if resp.size() < 2 or (resp[0] & 0x80) != 0:
            return _fail(resp)
        var values: Array = []
        for i in count:
            values.append((resp[2 + i / 8] >> (i % 8) & 1) == 1)
        return { "ok": true, "exception": 0, "values": values }

    ## Retourne { ok, exception, values } pour une lecture de registres.
    func read_registers(fc: int, offset: int, count: int) -> Dictionary:
        var pdu := PackedByteArray([fc])
        pdu.append_array(_u16(offset))
        pdu.append_array(_u16(count))
        var resp := transact(pdu)
        if resp.size() < 2 or (resp[0] & 0x80) != 0:
            return _fail(resp)
        var values: Array = []
        for i in count:
            values.append((resp[2 + i * 2] << 8) | resp[3 + i * 2])
        return { "ok": true, "exception": 0, "values": values }

    func write_coil(offset: int, on: bool) -> Dictionary:
        var pdu := PackedByteArray([5])
        pdu.append_array(_u16(offset))
        pdu.append_array(_u16(0xFF00 if on else 0x0000))
        var resp := transact(pdu)
        if resp.size() < 5 or (resp[0] & 0x80) != 0:
            return _fail(resp)
        return { "ok": true, "exception": 0, "values": [] }

    func write_register(offset: int, value: int) -> Dictionary:
        var pdu := PackedByteArray([6])
        pdu.append_array(_u16(offset))
        pdu.append_array(_u16(value))
        var resp := transact(pdu)
        if resp.size() < 5 or (resp[0] & 0x80) != 0:
            return _fail(resp)
        return { "ok": true, "exception": 0, "values": [] }

    func _fail(resp: PackedByteArray) -> Dictionary:
        var code: int = resp[1] if resp.size() >= 2 else -1
        return { "ok": false, "exception": code, "values": [] }

    func _u16(value: int) -> PackedByteArray:
        return PackedByteArray([(value >> 8) & 0xFF, value & 0xFF])


func run(t) -> void:
    t.begin_suite("modbus_tcp")
    _test_protocol(t)
    _test_full_chain(t)


func _test_protocol(t) -> void:
    var server = ModbusTcpServer.new()
    server.configure_bank_sizes(10, 10, 10, 10)
    server.discrete_inputs[0] = true
    server.discrete_inputs[3] = true
    server.input_registers[2] = 12345
    t.check_eq(server.listen(15020), Error.OK, "serveur a l'ecoute sur 15020")
    t.check(server.is_listening(), "is_listening")

    var client := TestClient.new()
    client.server_poll = server.poll
    t.check(client.connect_to(15020), "client connecte sur 127.0.0.1:15020")

    # FC 02 : lecture des discrete inputs
    var bits = client.read_bits(2, 0, 5)
    t.check(bits.ok, "FC02 reussie")
    t.check_eq(bits.values[0], true, "DI0 = true")
    t.check_eq(bits.values[1], false, "DI1 = false")
    t.check_eq(bits.values[3], true, "DI3 = true")

    # FC 01 : lecture des coils (vide au depart)
    var coils0 = client.read_bits(1, 0, 10)
    t.check(coils0.ok, "FC01 reussie")
    t.check(coils0.values.all(func(v): return not v), "tous les coils a false")

    # FC 04 : lecture des input registers
    var regs = client.read_registers(4, 0, 3)
    t.check(regs.ok, "FC04 reussie")
    t.check_eq(regs.values[2], 12345, "IR2 = 12345")

    # FC 05 : ecriture d'un coil puis relecture
    var w = client.write_coil(3, true)
    t.check(w.ok, "FC05 reussie")
    var coils1 = client.read_bits(1, 0, 5)
    t.check_eq(coils1.values[3], true, "coil 3 ecrit et relu")

    # FC 06 : ecriture d'un holding register puis relecture (FC 03)
    var wr = client.write_register(2, 4242)
    t.check(wr.ok, "FC06 reussie")
    var holding = client.read_registers(3, 0, 3)
    t.check(holding.ok, "FC03 reussie")
    t.check_eq(holding.values[2], 4242, "HR2 = 4242")

    # FC 0F : ecriture de plusieurs coils
    var pdu15 := PackedByteArray([15])
    pdu15.append_array(PackedByteArray([0, 4, 0, 5, 1, 0x1F]))
    var resp15 := client.transact(pdu15)
    t.check(resp15.size() >= 5 and resp15[0] == 15, "FC0F acceptee")
    var coils2 = client.read_bits(1, 4, 5)
    t.check(coils2.values[0] and coils2.values[1] and coils2.values[2] and coils2.values[3] and coils2.values[4], "5 coils ecrits en lot (0x1F)")

    # FC 10 : ecriture de plusieurs registres
    var pdu16 := PackedByteArray([16])
    pdu16.append_array(PackedByteArray([0, 5, 0, 2, 4, 0x01, 0x00, 0xFF, 0xFF]))
    var resp16 := client.transact(pdu16)
    t.check(resp16.size() >= 5 and resp16[0] == 16, "FC10 acceptee")
    var holding2 = client.read_registers(3, 5, 2)
    t.check_eq(holding2.values[0], 256, "HR5 = 0x0100")
    t.check_eq(holding2.values[1], 65535, "HR6 = 0xFFFF")

    # Exceptions
    var ex_fn = client.transact(PackedByteArray([0x63, 0, 0, 0, 1]))
    t.check(ex_fn.size() == 2 and ex_fn[0] == 0xE3 and ex_fn[1] == 1, "code fonction inconnu -> exception 01")
    var ex_addr = client.read_bits(2, 8, 5)
    t.check(not ex_addr.ok and ex_addr.exception == 2, "adresse hors banque (10 bits, offset 8 + 5) -> exception 02")
    var ex_val = client.read_bits(2, 0, 0)
    t.check(not ex_val.ok and ex_val.exception == 3, "quantite nulle -> exception 03")
    var ex_coil = client.transact(PackedByteArray([5, 0, 99, 0xFF, 0x00]))
    t.check(ex_coil.size() == 2 and ex_coil[1] == 2, "ecriture coil hors banque -> exception 02")
    var ex_coil_val = client.transact(PackedByteArray([5, 0, 1, 0x12, 0x34]))
    t.check(ex_coil_val.size() == 2 and ex_coil_val[1] == 3, "valeur de coil invalide -> exception 03")

    # Unit id different : aucune reponse attendue
    var noresp := client.transact(PackedByteArray([1, 0, 0, 0, 1]), 9)
    t.check(noresp.is_empty(), "unit id different : pas de reponse")

    t.check(server.requests_served > 0, "requetes comptabilisees")
    server.stop()


func _test_full_chain(t) -> void:
    # Chaine complete exige par le cahier des charges :
    # capteur virtuel -> moteur d'E/S -> Modbus TCP -> PLC (client de test)
    #   -> Modbus TCP -> moteur virtuel
    var dt := 1.0 / 60.0
    var mapping = IoMapping.from_file("res://config/conveyor_io_map.json")
    var conveyor = Conveyor.new()
    var io = IoTable.new()
    for point in conveyor.create_io_points():
        io.add_point(point)
    var link = ModbusPlcLink.new(io, mapping, 15021, 1)
    t.check(link.address_map.errors.is_empty(), "projection sans erreur")
    t.check_eq(link.server.discrete_inputs.size(), 9, "banque discrete dimensionnee")
    t.check_eq(link.server.holding_registers.size(), 1, "banque holding dimensionnee")
    t.check_eq(link.listen(), Error.OK, "lien Modbus a l'ecoute sur 15021")

    var engine = SimulationEngine.new(io, link)
    engine.add_machine(conveyor)

    var plc := TestClient.new()
    plc.server_poll = link.poll
    t.check(plc.connect_to(15021), "PLC de test connecte")

    # 1. La boite posee sur le capteur d'entree est visible via Modbus
    conveyor.spawn_box()
    engine.advance(0.1, dt)    # cycle : capteurs rafraichis puis publies dans les banques
    var inputs = plc.read_bits(2, 0, 2)
    t.check(inputs.ok, "lecture des entrees par le PLC")
    t.check_eq(inputs.values[0], true, "le PLC lit sensor_entry = 1 (%IX0.0)")
    t.check_eq(inputs.values[1], false, "le PLC lit sensor_exit = 0 (%IX0.1)")

    # 2. Le PLC commande la marche (%QX0.0) : le convoyeur demarre
    var w = plc.write_coil(0, true)
    t.check(w.ok, "le PLC ecrit conveyor_01.run = 1")
    engine.advance(0.2, dt)    # poll reseau + pull outputs + apply + update
    t.check(conveyor.running, "le convoyeur demarre, commande via Modbus")

    # 3. Le PLC lit la vitesse reelle (%IW0) : 0.5 m/s -> 50 (echelle x100)
    var regs = plc.read_registers(4, 0, 2)
    t.check(regs.ok, "lecture des registres d'entree")
    t.check_eq(regs.values[0], 50, "vitesse 0.5 m/s lue = 50 (x100)")
    t.check(regs.values[1] > 30, "position de la boite croissante (x100)")

    # 4. Le PLC reduit la consigne (%QW0) : 25 % -> 2500 brut
    var wr = plc.write_register(0, 2500)
    t.check(wr.ok, "le PLC ecrit la consigne de vitesse = 25 %")
    engine.advance(0.1, dt)
    t.check_almost_eq(conveyor.speed, 0.125, 0.0001, "consigne 25 % appliquee -> 0.125 m/s")
    var regs2 = plc.read_registers(4, 0, 1)
    t.check_eq(regs2.values[0], 13, "vitesse 0.125 m/s lue = 13 (round(12.5))")

    # 5. Compteur d'entree lisible (%IW2, echelle 1)
    var counters = plc.read_registers(4, 2, 1)
    t.check_eq(counters.values[0], 1, "compteur d'entree = 1 passage")

    # 6. Le PLC coupe la marche : le convoyeur s'arrete
    plc.write_coil(0, false)
    engine.advance(0.1, dt)
    t.check(not conveyor.running, "le convoyeur s'arrete sur ordre du PLC")

    link.stop()
