#!/usr/bin/env python3
"""Send WM_DELETE_WINDOW to every top-level X11 window owned by PID.

Godot has no WM_CLOSE_REQUEST override in this game, so the default
auto_accept_quit path runs SceneTree.quit(); ~ENetMultiplayerPeer() then calls
close() -> peer_disconnect_now(0) + flush(), so the host sees the disconnect on
its next poll (Godot 4.5.2 modules/enet/enet_multiplayer_peer.cpp:290-311,487).
That is a graceful leave (Alt-F4 / pause-menu quit), unlike kill -9 which the
host only notices by ENet timeout (~15 s).

usage: graceful_close.py <pid> [WM_NAME-fallback e.g. P4]
"""
import sys
from Xlib import X, display, Xatom

pid = int(sys.argv[1])
name_fallback = sys.argv[2] if len(sys.argv) > 2 else None
d = display.Display()
root = d.screen().root
NET_WM_PID = d.intern_atom('_NET_WM_PID')
WM_PROTOCOLS = d.intern_atom('WM_PROTOCOLS')
WM_DELETE = d.intern_atom('WM_DELETE_WINDOW')
NET_CLIENT_LIST = d.intern_atom('_NET_CLIENT_LIST')

def wins():
    p = root.get_full_property(NET_CLIENT_LIST, Xatom.WINDOW)
    if p is not None:
        for w in p.value:
            yield d.create_resource_object('window', w)
    # fallback: walk the tree
    def walk(w):
        for c in w.query_tree().children:
            yield c
            yield from walk(c)
    yield from walk(root)

sent = 0
seen = set()
for w in wins():
    if w.id in seen:
        continue
    seen.add(w.id)
    try:
        p = w.get_full_property(NET_WM_PID, Xatom.CARDINAL)
        nm = w.get_wm_name()
    except Exception:
        continue
    match_pid = p is not None and int(p.value[0]) == pid
    match_name = name_fallback is not None and nm == name_fallback
    if not (match_pid or match_name):
        continue
    ev = __import__('Xlib.protocol.event', fromlist=['ClientMessage']).ClientMessage(
        window=w, client_type=WM_PROTOCOLS, data=(32, [WM_DELETE, X.CurrentTime, 0, 0, 0]))
    w.send_event(ev, event_mask=X.NoEventMask)
    d.flush()
    name = w.get_wm_name()
    print(f"WM_DELETE_WINDOW sent to 0x{w.id:x} name={name!r} pid={pid}")
    sent += 1
d.sync()
print(f"sent={sent}")
sys.exit(0 if sent else 1)
