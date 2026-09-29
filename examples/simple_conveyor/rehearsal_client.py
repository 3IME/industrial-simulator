#!/usr/bin/env python3
"""Répétition générale : rejoue exactement la logique du programme OpenPLC
(plc/openplc/conveyor.st) en client Modbus, sans OpenPLC.

Utile pour valider la chaîne simulateur <-> Modbus avant de brancher le vrai
automate, ou pour dépanner : si ce script fait tourner le convoyeur mais pas
OpenPLC, le problème est dans la configuration OpenPLC (voir le guide).

Usage :
    python rehearsal_client.py [hote] [port]      # defauts : 127.0.0.1 1502

Logique (identique au ST) :
    SI sensor_entry ALORS run := VRAI
    SI sensor_exit  ALORS run := FAUX
Scrutation toutes les 100 ms, comme OpenPLC par defaut. Ctrl+C pour arreter.
Aucune dependance : client Modbus TCP sur socket brut.
"""

import socket
import struct
import sys
import time

HOST = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 1502
UNIT_ID = 1


class MiniModbusClient:
    """Le strict minimum : FC2 (lire DI), FC5 (ecrire coil)."""

    def __init__(self, host, port):
        self.sock = socket.create_connection((host, port), timeout=3)
        self.tid = 0

    def _transact(self, pdu):
        self.tid = (self.tid + 1) & 0xFFFF
        frame = struct.pack(">HHHB", self.tid, 0, len(pdu) + 1, UNIT_ID) + pdu
        self.sock.sendall(frame)
        header = b""
        while len(header) < 7:
            chunk = self.sock.recv(7 - len(header))
            if not chunk:
                raise ConnectionError("connexion fermee par le simulateur")
            header += chunk
        length = struct.unpack(">H", header[4:6])[0]
        body = b""
        while len(body) < length - 1:
            body += self.sock.recv(length - 1 - len(body))
        if body[0] & 0x80:
            raise IOError("exception Modbus %d (fc %d)" % (body[1], body[0] & 0x7F))
        return body

    def read_discrete(self, offset, count):
        body = self._transact(bytes([2]) + struct.pack(">HH", offset, count))
        return [(body[2 + i // 8] >> (i % 8)) & 1 == 1 for i in range(count)]

    def write_coil(self, offset, on):
        value = 0xFF00 if on else 0x0000
        self._transact(bytes([5]) + struct.pack(">HH", offset, value))

    def close(self):
        self.sock.close()


def main():
    client = MiniModbusClient(HOST, PORT)
    run = False
    print("Client 'PLC de repetition' connecte sur %s:%d" % (HOST, PORT))
    print("Logique : sensor_entry -> marche ; sensor_exit -> arret. Ctrl+C pour quitter.")
    try:
        while True:
            entry, exit_ = client.read_discrete(0, 2)
            if entry:
                run = True
            if exit_:
                run = False
            client.write_coil(0, run)
            print("\rentry=%d exit=%d | run=%d" % (entry, exit_, run), end="", flush=True)
            time.sleep(0.1)
    except KeyboardInterrupt:
        pass
    finally:
        client.write_coil(0, False)
        client.close()
        print("\nArret, coil remise a 0.")


if __name__ == "__main__":
    main()
