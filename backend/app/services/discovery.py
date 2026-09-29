"""LAN auto-discovery responder.

The mobile app and the admin desktop app broadcast a small UDP packet
("JANSETU_DISCOVER") on the local network; this answers with the API port so
they can find the backend on any Wi-Fi without anyone typing an IP address.
The client learns the server's IP from the reply's source address.

Disable with JANSETU_DISCOVERY=0. If the port is already taken (e.g. a second
backend process, or the test suite importing the app while a server runs),
it quietly does nothing.
"""

import json
import os
import socket
import threading

DISCOVERY_PORT = int(os.getenv("JANSETU_DISCOVERY_PORT", "45678"))
DISCOVERY_REQUEST = b"JANSETU_DISCOVER"

_started = False


def _serve(sock: socket.socket, api_port: int) -> None:
    reply = json.dumps({"service": "jansetu-swachh", "port": api_port}).encode("utf-8")
    while True:
        try:
            data, address = sock.recvfrom(1024)
        except OSError:
            return
        if data.strip() == DISCOVERY_REQUEST:
            try:
                sock.sendto(reply, address)
            except OSError:
                pass


def start_discovery_responder() -> None:
    global _started
    if _started or os.getenv("JANSETU_DISCOVERY", "1") == "0":
        return
    api_port = int(os.getenv("JANSETU_API_PORT", "8000"))
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.bind(("0.0.0.0", DISCOVERY_PORT))
    except OSError:
        sock.close()
        return
    _started = True
    threading.Thread(target=_serve, args=(sock, api_port), name="jansetu-discovery", daemon=True).start()
