"""Read a selection from the active application's focused editable field."""
import sys

import gi

gi.require_version("Atspi", "2.0")
from gi.repository import Atspi, GLib


def state(node, wanted):
    return node.get_state_set().contains(wanted)


def walk(root):
    stack = [root]
    while stack:
        node = stack.pop()
        if node.get_role() == Atspi.Role.PASSWORD_TEXT:
            continue
        yield node
        for index in reversed(range(node.get_child_count())):
            child = node.get_child_at_index(index)
            if child:
                stack.append(child)


def selected_text(pid):
    desktop = Atspi.get_desktop(0)
    for index in range(desktop.get_child_count()):
        app = desktop.get_child_at_index(index)
        if not app or app.get_process_id() != pid:
            continue
        focused = next((node for node in walk(app) if state(node, Atspi.StateType.FOCUSED)), None)
        if not focused:
            continue
        # Chromium can expose focus on a paragraph and the selection on its
        # editable parent, or expose the range on a text child of that parent.
        field = focused
        while field and not state(field, Atspi.StateType.EDITABLE):
            field = field.get_parent()
            if field and field.get_role() in (Atspi.Role.PASSWORD_TEXT, Atspi.Role.DOCUMENT_WEB):
                field = None
        if not field:
            continue
        for node in walk(field):
            if not node.is_text() or Atspi.Text.get_n_selections(node) != 1:
                continue
            selection = Atspi.Text.get_selection(node, 0)
            if selection:
                start, end = sorted((selection.start_offset, selection.end_offset))
                if 0 < end - start <= 2000:
                    return Atspi.Text.get_text(node, start, end)
    return ""


if __name__ == "__main__":
    try:
        sys.stdout.write(selected_text(int(sys.argv[1])))
    except (GLib.Error, RuntimeError):
        pass
