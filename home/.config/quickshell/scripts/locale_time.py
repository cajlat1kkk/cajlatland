#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   L O C A L E   &   T I M E                                              │
# │   system locale, timezone and NTP · read and change                      │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Read and change the system locale, timezone and NTP synchronization.

Uses timedatectl and localectl when available (falling back to reading
/etc/localtime and /etc/locale.conf), with pkexec for privileged changes.

    get                    JSON state
    set-locale <locale>    set system LANG
    set-timezone <tz>      set system timezone
    set-ntp <true|false>   toggle network time synchronization
    set-time <YYYY-MM-DD HH:MM[:SS]>  set system date and time (when NTP is off)
"""

import json
import os
import re
import shutil
import subprocess
import sys

TIMEZONES = [
    {"id": "Europe/Kaliningrad", "label": "Калининград (UTC+2)"},
    {"id": "Europe/Moscow", "label": "Москва (UTC+3)"},
    {"id": "Europe/Samara", "label": "Самара (UTC+4)"},
    {"id": "Asia/Yekaterinburg", "label": "Екатеринбург (UTC+5)"},
    {"id": "Asia/Omsk", "label": "Омск (UTC+6)"},
    {"id": "Asia/Novosibirsk", "label": "Новосибирск (UTC+7)"},
    {"id": "Asia/Krasnoyarsk", "label": "Красноярск (UTC+7)"},
    {"id": "Asia/Irkutsk", "label": "Иркутск (UTC+8)"},
    {"id": "Asia/Yakutsk", "label": "Якутск (UTC+9)"},
    {"id": "Asia/Vladivostok", "label": "Владивосток (UTC+10)"},
    {"id": "Asia/Magadan", "label": "Магадан (UTC+11)"},
    {"id": "Asia/Kamchatka", "label": "Камчатка (UTC+12)"},
    {"id": "UTC", "label": "UTC"},
    {"id": "Europe/London", "label": "Лондон (UTC+0)"},
    {"id": "Europe/Berlin", "label": "Берлин (UTC+1)"},
    {"id": "America/New_York", "label": "Нью-Йорк (UTC-5)"},
]

LOCALES = [
    {"id": "ru_RU.UTF-8", "label": "Русский (ru_RU.UTF-8)"},
    {"id": "en_US.UTF-8", "label": "English (en_US.UTF-8)"},
    {"id": "es_ES.UTF-8", "label": "Español (es_ES.UTF-8)"},
]


def get_locale():
    if os.path.exists("/etc/locale.conf"):
        try:
            with open("/etc/locale.conf", encoding="utf-8") as handle:
                for line in handle:
                    if line.startswith("LANG="):
                        return line.strip().split("=", 1)[1].strip("\"'")
        except OSError:
            pass
    return os.environ.get("LANG", "en_US.UTF-8")


def get_timezone():
    if os.path.islink("/etc/localtime"):
        try:
            target = os.readlink("/etc/localtime")
            if "zoneinfo/" in target:
                return target.split("zoneinfo/")[-1]
        except OSError:
            pass
    if os.path.exists("/etc/timezone"):
        try:
            with open("/etc/timezone", encoding="utf-8") as handle:
                tz = handle.read().strip()
                if tz:
                    return tz
        except OSError:
            pass
    return "UTC"


def get_ntp():
    if shutil.which("timedatectl"):
        try:
            result = subprocess.run(
                ["timedatectl", "show", "-p", "NTP", "--value"],
                capture_output=True, text=True, timeout=3, check=False,
            )
            if result.returncode == 0:
                return result.stdout.strip().lower() == "yes"
        except (OSError, subprocess.SubprocessError):
            pass
    return True


def state(error=""):
    return {
        "locale": get_locale(),
        "availableLocales": LOCALES,
        "timezone": get_timezone(),
        "ntp": get_ntp(),
        "timezones": TIMEZONES,
        "error": error,
    }


def run_privileged(cmd):
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=15, check=False)
        if res.returncode == 0:
            return ""
        if shutil.which("pkexec"):
            res2 = subprocess.run(["pkexec"] + cmd, capture_output=True, text=True, timeout=60, check=False)
            if res2.returncode == 0:
                return ""
            return (res2.stderr or res2.stdout or "Failed").strip()
        return (res.stderr or res.stdout or "Failed").strip()
    except (OSError, subprocess.SubprocessError) as exc:
        return str(exc)


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "get"
    error = ""

    if action == "get":
        pass
    elif action == "set-locale" and len(sys.argv) >= 3:
        loc = sys.argv[2]
        if shutil.which("localectl"):
            error = run_privileged(["localectl", "set-locale", f"LANG={loc}"])
        else:
            error = "localectl not found"
    elif action == "set-timezone" and len(sys.argv) >= 3:
        tz = sys.argv[2]
        if shutil.which("timedatectl"):
            error = run_privileged(["timedatectl", "set-timezone", tz])
        else:
            error = "timedatectl not found"
    elif action == "set-ntp" and len(sys.argv) >= 3:
        val = "true" if sys.argv[2].lower() in ("true", "1", "yes") else "false"
        if shutil.which("timedatectl"):
            error = run_privileged(["timedatectl", "set-ntp", val])
        else:
            error = "timedatectl not found"
    elif action == "set-time" and len(sys.argv) >= 3:
        stamp = sys.argv[2].strip()
        if not re.match(r"^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(:\d{2})?$", stamp):
            error = "Expected YYYY-MM-DD HH:MM:SS"
        elif shutil.which("timedatectl"):
            error = run_privileged(["timedatectl", "set-time", stamp])
        else:
            error = "timedatectl not found"
    else:
        sys.stderr.write("Usage: locale_time.py [get | set-locale <loc> | set-timezone <tz> | set-ntp <bool> | set-time <stamp>]\n")
        sys.exit(1)

    print(json.dumps(state(error)))


if __name__ == "__main__":
    main()
