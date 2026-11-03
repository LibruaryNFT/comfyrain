#!/usr/bin/env python3
"""Send one obs-websocket v5 request to a local OBS and print the response.

    python3 -I tools/obs_ws.py StartRecord
    python3 -I tools/obs_ws.py GetVideoSettings
    python3 -I tools/obs_ws.py GetSourceScreenshot '{"sourceName":"Screen","imageFormat":"png"}' --out /tmp/s.png

Standard library only, so it runs on a fresh box with nothing installed. The
password is read from OBS's own websocket config, so it never goes on a
command line or into shell history. Exits 1 if OBS refuses the request.
"""
import base64
import hashlib
import json
import os
import socket
import struct
import sys
import uuid

CONFIG = os.path.expanduser("~/.config/obs-studio/plugin_config/obs-websocket/config.json")


def send_frame(sock, text):
    payload = text.encode()
    mask = os.urandom(4)
    head = bytes([0x81])
    n = len(payload)
    if n < 126:
        head += bytes([0x80 | n])
    elif n < 65536:
        head += bytes([0x80 | 126]) + struct.pack(">H", n)
    else:
        head += bytes([0x80 | 127]) + struct.pack(">Q", n)
    sock.sendall(head + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(payload)))


def recv_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("OBS closed the connection")
        buf += chunk
    return buf


def recv_message(sock):
    while True:
        b0, b1 = recv_exact(sock, 2)
        n = b1 & 0x7F
        if n == 126:
            n = struct.unpack(">H", recv_exact(sock, 2))[0]
        elif n == 127:
            n = struct.unpack(">Q", recv_exact(sock, 8))[0]
        payload = recv_exact(sock, n)
        op = b0 & 0x0F
        if op == 8:
            code = struct.unpack(">H", payload[:2])[0] if len(payload) >= 2 else 0
            raise ConnectionError(f"OBS closed the connection: {code} {payload[2:].decode(errors='replace')}")
        if op == 9:
            sock.sendall(bytes([0x8A, 0x80]) + os.urandom(4))
            continue
        if op == 1:
            return json.loads(payload)


def connect(cfg):
    sock = socket.create_connection(("127.0.0.1", cfg.get("server_port", 4455)), timeout=30)
    key = base64.b64encode(os.urandom(16)).decode()
    sock.sendall((
        "GET / HTTP/1.1\r\nHost: 127.0.0.1\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n"
        "Sec-WebSocket-Protocol: obswebsocket.json\r\n\r\n").encode())
    head = b""
    while b"\r\n\r\n" not in head:
        head += recv_exact(sock, 1)
    if b" 101 " not in head.split(b"\r\n")[0]:
        raise ConnectionError(head.decode(errors="replace"))

    hello = recv_message(sock)["d"]
    ident = {"rpcVersion": 1, "eventSubscriptions": 0}
    if "authentication" in hello:
        a = hello["authentication"]
        secret = base64.b64encode(hashlib.sha256((cfg["server_password"] + a["salt"]).encode()).digest())
        ident["authentication"] = base64.b64encode(
            hashlib.sha256(secret + a["challenge"].encode()).digest()).decode()
    send_frame(sock, json.dumps({"op": 1, "d": ident}))
    if recv_message(sock)["op"] != 2:
        raise ConnectionError("OBS did not accept the Identify")
    return sock


def main(argv):
    out = None
    if "--out" in argv:
        i = argv.index("--out")
        out = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    if not argv:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    req_type = argv[0]
    data = json.loads(argv[1]) if len(argv) > 1 else {}

    with open(CONFIG) as f:
        cfg = json.load(f)
    sock = connect(cfg)
    rid = str(uuid.uuid4())
    send_frame(sock, json.dumps({"op": 6, "d": {
        "requestType": req_type, "requestId": rid, "requestData": data}}))
    while True:
        msg = recv_message(sock)
        if msg["op"] == 7 and msg["d"]["requestId"] == rid:
            break
    sock.close()

    status = msg["d"]["requestStatus"]
    resp = msg["d"].get("responseData") or {}
    if out and "imageData" in resp:
        with open(out, "wb") as f:
            f.write(base64.b64decode(resp["imageData"].split(",", 1)[1]))
        resp["imageData"] = f"(written to {out})"
    if not status["result"]:
        print(json.dumps(status), file=sys.stderr)
        return 1
    print(json.dumps(resp, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
