#!/usr/bin/python3
import fcntl
import struct
import subprocess
import json
import os
from pathlib import Path

SETTINGS = Path(os.environ.get("XDG_STATE_HOME", Path.home()/".local/state"))/"quickshell/settings.json"
def action(fingers, direction):
    try:
        value = json.loads(SETTINGS.read_text()).get("touchpadGestures", {}).get(f"{fingers}_{direction}", "default")
    except (OSError, ValueError):
        value = "default"
    if value == "default":
        return {(4,"up"):"volumeUp",(4,"down"):"volumeDown",(4,"tap"):"play"}.get((fingers,direction),"none")
    return value

def perform(value):
    commands = {
        "volumeUp":["wpctl","set-volume","-l","1.0","@DEFAULT_AUDIO_SINK@","10%+"],
        "volumeDown":["wpctl","set-volume","@DEFAULT_AUDIO_SINK@","10%-"],
        "play":["playerctl","play-pause"],
        "next":["playerctl","next"],
    }
    if value in commands:
        subprocess.run(commands[value],check=False)

DEVICE = "/dev/input/by-path/pci-0000:00:15.0-platform-i2c_designware.0-event-mouse"
EVENT = struct.Struct("@llHHi")
with open(DEVICE, "rb", buffering=0) as pad:
    def resolution(axis):
        info = fcntl.ioctl(pad, 0x80184540 + axis, bytes(24))
        return max(1, struct.unpack("6i", info)[5])

    limits = [resolution(axis) * 3 for axis in (53, 54)]
    active, origin, coords = set(), {}, {}
    slot = peak = 0
    start = None
    moved = False
    four_down = False
    tracking = None
    sliding = False
    sink = "@DEFAULT_AUDIO_SINK@"
    last_update = 0.0
    gesture_anchor = None
    gesture_count = 0
    while True:
        seconds, micros, kind, code, value = EVENT.unpack(pad.read(EVENT.size))
        now = seconds + micros / 1e6
        if kind == 3:
            if code == 47:
                slot = value
            elif code == 57:
                if value < 0:
                    active.discard(slot)
                else:
                    active.add(slot)
                    origin.pop(slot, None)
                    if start is None:
                        start = now
            elif code in (53, 54):
                coords.setdefault(slot, [None, None])[code - 53] = value
        elif kind == 1 and code == 335:
            four_down = bool(value)
            if four_down:
                peak = max(peak, 4)
        elif kind == 1 and value and code == 328:
            peak = 5
        elif kind == 0 and code == 3:
            raise SystemExit(1)
        elif kind == 0 and code == 0:
            peak = max(peak, len(active))
            for finger in active:
                pos = coords.get(finger, [None, None])
                if None not in pos:
                    base = origin.setdefault(finger, tuple(pos))
                    moved |= any(abs(a-b) > limit for a,b,limit in zip(pos,base,limits))
            fingers = frozenset(active)
            if len(active) in (2,3,4) and all(None not in coords.get(i,[None]) for i in active):
                count=len(active)
                x,y=[sum(coords[i][axis] for i in active)/count/(limits[axis]/3) for axis in (0,1)]
                if gesture_count!=count or gesture_anchor is None:
                    gesture_anchor=(x,y)
                    gesture_count=count
                dx,dy=x-gesture_anchor[0],y-gesture_anchor[1]
                if max(abs(dx),abs(dy))>=8 and now-last_update>=0.035:
                    direction=("right" if dx>0 else "left") if abs(dx)>abs(dy) else ("down" if dy>0 else "up")
                    perform(action(count,direction))
                    gesture_anchor=(x,y)
                    last_update=now
                    moved=True
            else:
                gesture_anchor=None
                gesture_count=0
            if not active and start is not None:
                sliding = False
                if peak in (2,3,4) and not moved and 0.025 <= now-start <= 0.38:
                    perform(action(peak,"tap"))
                peak, start, moved = 0, None, False
