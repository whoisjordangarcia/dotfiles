#!/usr/bin/python3 -I
"""Expose kudu-opah Rex hosts as local unix sockets for the Rex app.

Rex Beta resolves host names itself and ignores HTTPS_PROXY, so it cannot reach hosts on a
tailnet that the system Tailscale is not on. Rex host endpoints may list a unix socket
first; devices without that path skip it. Each connection is dialled with `tailscale nc`
through the ts-rex node's private LocalAPI socket, then TLS-wrapped here, so the remote still
sees a normal HTTPS client with the real SNI and certificate check. No TCP port is opened.

Usage: rex-bridge.py HOST [HOST...]   -> /tmp/rex-bridge/<HOST>.sock
"""
import os
import socket
import ssl
import subprocess
import sys
import threading

TS_SOCKET = os.path.expanduser("~/.local/share/ts-rex/tailscaled.sock")
SOCK_DIR = "/tmp/rex-bridge"


def tailnet_connect(host, port):
    ours, theirs = socket.socketpair()
    subprocess.Popen(
        ["/opt/homebrew/bin/tailscale", "--socket=" + TS_SOCKET, "nc", host, str(port)],
        stdin=theirs, stdout=theirs, stderr=subprocess.DEVNULL, close_fds=True,
    )
    theirs.close()
    return ours


def pipe(src, dst):
    try:
        while True:
            data = src.recv(65536)
            if not data:
                break
            dst.sendall(data)
    except OSError:
        pass
    finally:
        for s in (src, dst):
            try:
                s.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass


def handle(client, host, ctx):
    try:
        upstream = ctx.wrap_socket(tailnet_connect(host, 443), server_hostname=host)
    except (OSError, ssl.SSLError) as e:
        print("%s: %s" % (host, e), file=sys.stderr, flush=True)
        client.close()
        return
    threading.Thread(target=pipe, args=(upstream, client), daemon=True).start()
    pipe(client, upstream)


def serve(host, ctx):
    path = os.path.join(SOCK_DIR, host + ".sock")
    if os.path.exists(path):
        os.unlink(path)
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(path)
    os.chmod(path, 0o600)
    srv.listen(64)
    print("listening %s -> %s:443" % (path, host), flush=True)
    while True:
        conn, _ = srv.accept()
        threading.Thread(target=handle, args=(conn, host, ctx), daemon=True).start()


def main():
    hosts = sys.argv[1:]
    if not hosts:
        sys.exit(__doc__)
    os.makedirs(SOCK_DIR, mode=0o700, exist_ok=True)
    ctx = ssl.create_default_context()
    for h in hosts:
        threading.Thread(target=serve, args=(h, ctx), daemon=True).start()
    threading.Event().wait()


if __name__ == "__main__":
    main()
