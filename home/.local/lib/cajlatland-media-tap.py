#!/usr/bin/python3
import fcntl
import struct
import subprocess

from pathlib import Path

def find_touchpad():
    for device in sorted(Path("/dev/input").glob("event*")):
        properties = subprocess.run(["udevadm", "info", "--query=property", str(device)],
                                    capture_output=True, text=True)
        if "ID_INPUT_TOUCHPAD=1" in properties.stdout.splitlines():
            return device
    return None

DEVICE = find_touchpad()
if DEVICE is None:
    raise SystemExit(0)
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
            four = peak <= 4 and (len(active) == 4 or four_down)
            if four and active and all(None not in coords.get(i, [None]) for i in active):
                x, y = [sum(coords[i][axis] for i in active) / len(active)
                        / (limits[axis] / 3) for axis in (0, 1)]
                if tracking != fingers:
                    tracking = fingers
                    anchor_x, anchor_y = x, y
                dy = anchor_y - y
                if not sliding and abs(dy) >= 3 and abs(dy) > abs(x - anchor_x):
                    sliding = moved = True
                if sliding and abs(dy) >= 1 and now - last_update >= 0.035:
                    percent = min(100, int(abs(dy) * 2))
                    if dy > 0:
                        subprocess.run(["wpctl", "set-mute", sink, "0"], check=False)
                    subprocess.run(["wpctl", "set-volume", "-l", "1.0", sink,
                                    f"{percent}%{'+' if dy > 0 else '-'}"], check=False)
                    anchor_y -= (1 if dy > 0 else -1) * percent / 2
                    last_update = now
            else:
                tracking = None
            if not active and start is not None:
                sliding = False
                if peak == 4 and not moved and 0.025 <= now-start <= 0.38:
                    subprocess.run(["playerctl", "play-pause"], check=False)
                peak, start, moved = 0, None, False
