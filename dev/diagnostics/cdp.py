"""Minimal Chrome DevTools Protocol client over a raw WebSocket.

Usage:  python cdp.py <ws-url> <js-expression>
Evaluates the expression in the page and prints the JSON result.
"""

import base64
import json
import os
import socket
import struct
import sys
from urllib.parse import urlparse


def ws_connect(url, timeout=20):
    parts = urlparse(url)
    sock = socket.create_connection((parts.hostname, parts.port or 80), timeout)
    key = base64.b64encode(os.urandom(16)).decode()
    path = parts.path or "/"
    handshake = (
        f"GET {path} HTTP/1.1\r\n"
        f"Host: {parts.hostname}:{parts.port}\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\n"
        "Sec-WebSocket-Version: 13\r\n\r\n"
    )
    sock.sendall(handshake.encode())

    buf = b""
    while b"\r\n\r\n" not in buf:
        chunk = sock.recv(4096)
        if not chunk:
            raise ConnectionError("handshake failed, socket closed")
        buf += chunk
    if b"101" not in buf.split(b"\r\n", 1)[0]:
        raise ConnectionError(f"handshake rejected: {buf.split(b'\r\n', 1)[0]!r}")
    return sock


def ws_send(sock, payload):
    data = payload.encode()
    header = bytearray([0x81])
    length = len(data)
    if length < 126:
        header.append(0x80 | length)
    elif length < 65536:
        header.append(0x80 | 126)
        header += struct.pack(">H", length)
    else:
        header.append(0x80 | 127)
        header += struct.pack(">Q", length)
    mask = os.urandom(4)
    header += mask
    sock.sendall(bytes(header) + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))


def _recv_exactly(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("socket closed mid-frame")
        buf += chunk
    return buf


def ws_recv(sock):
    """Read one complete (possibly fragmented) text message."""
    message = b""
    while True:
        b0, b1 = _recv_exactly(sock, 2)
        fin = b0 & 0x80
        length = b1 & 0x7F
        if length == 126:
            length = struct.unpack(">H", _recv_exactly(sock, 2))[0]
        elif length == 127:
            length = struct.unpack(">Q", _recv_exactly(sock, 8))[0]
        message += _recv_exactly(sock, length) if length else b""
        if fin:
            return message.decode("utf-8", "replace")


def evaluate(ws_url, expression, timeout=20):
    sock = ws_connect(ws_url, timeout)
    try:
        ws_send(sock, json.dumps({
            "id": 1,
            "method": "Runtime.evaluate",
            "params": {
                "expression": expression,
                "returnByValue": True,
                "awaitPromise": True,
            },
        }))
        while True:
            msg = json.loads(ws_recv(sock))
            if msg.get("id") == 1:  # skip unsolicited events
                return msg
    finally:
        sock.close()


if __name__ == "__main__":
    result = evaluate(sys.argv[1], sys.argv[2])
    print(json.dumps(result, indent=2)[:6000])
