"""Convert text by matching the physical keys of standard US and Russian XKB."""
import sys

US = (
    "1234567890-=\x60qwertyuiop[]\\asdfghjkl;'zxcvbnm,./"
    '~QWERTYUIOP{}|ASDFGHJKL:"ZXCVBNM<>?!@#$%^&*()_+'
)
RU = (
    "1234567890-=ёйцукенгшщзхъ\\фывапролджэячсмитьбю."
    'ЁЙЦУКЕНГШЩЗХЪ/ФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,!"№;%:?*()_+'
)
TO_RU = str.maketrans(US, RU)
TO_US = str.maketrans(RU, US)
US_ONLY = set(US) - set(RU)
RU_ONLY = set(RU) - set(US)


def convert(text, source=None):
    ru_letters = sum(ch.isalpha() and ch in RU_ONLY for ch in text)
    us_letters = sum(ch.isalpha() and ch in US_ONLY for ch in text)
    if ru_letters != us_letters:
        source = "ru" if ru_letters > us_letters else "us"
    else:
        ru_signs = sum(ch in RU_ONLY for ch in text)
        us_signs = sum(ch in US_ONLY for ch in text)
        if ru_signs != us_signs:
            source = "ru" if ru_signs > us_signs else "us"
    return text.translate(TO_US if source == "ru" else TO_RU)


def previous_layout(keyboards):
    main = next((item for item in keyboards if item.get("main")), {})
    layouts = main.get("layout", "").split(",")
    index = main.get("active_layout_index", 0)
    # The first Shift has already advanced the layout when both layouts are loaded.
    return layouts[(index - 1) % len(layouts)]


if __name__ == "__main__":
    source = None
    if len(sys.argv) > 1:
        import subprocess
        from app_scope import query
        try:
            source = previous_layout(query("devices")["keyboards"])
        except (OSError, ValueError, KeyError, subprocess.SubprocessError):
            pass
    sys.stdout.write(convert(sys.stdin.read(), source))
