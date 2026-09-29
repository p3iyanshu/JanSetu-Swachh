import json
import socket

from app.main import app  # noqa: F401 - importing the app starts the responder
from app.services.discovery import DISCOVERY_PORT, DISCOVERY_REQUEST


def test_discovery_responder_replies_with_api_port():
    # Answered either by this process's responder or by a backend that's
    # already running on the machine - both prove the protocol works.
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(3)
    try:
        sock.sendto(DISCOVERY_REQUEST, ("127.0.0.1", DISCOVERY_PORT))
        data, _ = sock.recvfrom(1024)
    finally:
        sock.close()
    payload = json.loads(data)
    assert payload["service"] == "jansetu-swachh"
    assert payload["port"] == 8000


def test_discovery_ignores_other_packets():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(1)
    try:
        sock.sendto(b"hello", ("127.0.0.1", DISCOVERY_PORT))
        try:
            sock.recvfrom(1024)
            got_reply = True
        except socket.timeout:
            got_reply = False
    finally:
        sock.close()
    assert got_reply is False
