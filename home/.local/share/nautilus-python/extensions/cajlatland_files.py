"""Cajlatland's liquid surface and 7-Zip actions for Nautilus."""

import json
import os
from pathlib import Path
import shutil
import subprocess

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gdk, Gio, GLib, GObject, Gtk, Nautilus

EXTENSION_DIR = Path(__file__).resolve().parent
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "quickshell"
SETTINGS_FILE = STATE_DIR / "settings.json"
GROUNDS = {
    "classic": ((0, 0, 0), "none", 0),
    "glass": ((32, 39, 50), "blur(16px)", 0.08),
    "liquid": ((15, 18, 23), "blur(24px)", 0.14),
}


def appearance(settings):
    style = settings.get("fileManagerGround", "liquid")
    if not isinstance(style, str) or style not in GROUNDS:
        style = "liquid"
    opacity = settings.get("fileManagerOpacity", 72)
    if type(opacity) is not int:
        opacity = 72
    return style, max(50, min(95, opacity)), settings.get("fileManagerSidebarShade") is not False


def build_css(template, style, opacity, shade_sidebar):
    (red, green, blue), blur, edge = GROUNDS[style]
    classic = style == "classic"
    opacity = 1.0 if classic else opacity / 100
    sidebar = "rgba(38, 42, 48, 0.55)" if classic else "rgba(10, 13, 18, 0.32)"
    return (template.replace("CAJLATLAND_GROUND", f"rgba({red}, {green}, {blue}, {opacity})")
            .replace("CAJLATLAND_SIDEBAR", sidebar if shade_sidebar else "transparent")
            .replace("CAJLATLAND_BLUR", blur)
            .replace("CAJLATLAND_EDGE", str(edge)))


class CajlatlandFiles(GObject.GObject, Nautilus.MenuProvider):
    def __init__(self):
        super().__init__()
        display = Gdk.Display.get_default()
        if display is not None:
            Adw.StyleManager.get_for_display(display).set_color_scheme(Adw.ColorScheme.FORCE_DARK)
            self.css = Gtk.CssProvider()
            self.template = (EXTENSION_DIR / "cajlatland-liquid.css").read_text(encoding="utf-8")
            self.applied = None
            self.refresh_id = 0
            Gtk.StyleContext.add_provider_for_display(display, self.css, Gtk.STYLE_PROVIDER_PRIORITY_USER + 1)
            self.reload_appearance()
            try:
                self.monitor = Gio.File.new_for_path(str(STATE_DIR)).monitor_directory(
                    Gio.FileMonitorFlags.WATCH_MOVES, None
                )
                self.monitor.connect("changed", self.settings_changed)
            except GLib.Error:
                self.monitor = None

    def settings_changed(self, _monitor, file, other_file, _event):
        if not any(path and path.get_basename() == SETTINGS_FILE.name for path in (file, other_file)):
            return
        if not self.refresh_id:
            self.refresh_id = GLib.timeout_add(80, self.reload_appearance)

    def reload_appearance(self):
        self.refresh_id = 0
        try:
            settings = json.loads(SETTINGS_FILE.read_text(encoding="utf-8"))
        except FileNotFoundError:
            settings = {}
        except (OSError, ValueError):
            return GLib.SOURCE_REMOVE
        current = appearance(settings if isinstance(settings, dict) else {})
        if current != self.applied:
            self.css.load_from_string(build_css(self.template, *current))
            self.applied = current
        return GLib.SOURCE_REMOVE

    def get_background_items(self, _folder):
        if not shutil.which("qs"):
            return []
        russian = any(lang.startswith("ru") for lang in GLib.get_language_names())
        entry = Nautilus.MenuItem(
            name="CajlatlandFiles::Appearance",
            label="Параметры оформления…" if russian else "Appearance settings…",
        )
        entry.connect("activate", self.open_appearance)
        return [entry]

    def open_appearance(self, _entry):
        subprocess.Popen(["qs", "ipc", "call", "settings", "fileManager"], start_new_session=True)

    def get_file_items(self, files):
        paths = [file.get_location().get_path() for file in files]
        if not paths or not all(paths) or not shutil.which("7z"):
            return []
        parents = {Path(path).parent for path in paths}
        if len(parents) != 1 or any(not Path(path).name for path in paths):
            return []

        menu = Nautilus.Menu()
        root = Nautilus.MenuItem(name="CajlatlandFiles::7Zip", label="7-Zip")
        root.set_submenu(menu)
        for kind in ("7z", "zip"):
            entry = Nautilus.MenuItem(
                name=f"CajlatlandFiles::{kind}", label=f"Сжать в .{kind}"
            )
            entry.connect("activate", self.archive, kind, paths)
            menu.append_item(entry)
        return [root]

    def archive(self, _entry, kind, paths):
        subprocess.Popen(
            ["/usr/bin/python3", str(EXTENSION_DIR / "cajlatland-archive"), kind, *paths],
            start_new_session=True,
        )
