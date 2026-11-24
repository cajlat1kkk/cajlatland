"""Import a local file selected by the Cajlatland wallpaper dialog."""
import itertools
import os
from pathlib import Path
import shutil
import sys
import tempfile
from urllib.parse import unquote, urlsplit

from theme_manager import IMAGE_EXTENSIONS, WALLPAPERS_DIR


def import_picture(url):
    selected = urlsplit(url)
    if selected.scheme != "file" or selected.netloc not in ("", "localhost"):
        raise ValueError("Выберите локальный файл")
    source = Path(unquote(selected.path)).resolve(strict=True)
    if source.suffix.lower() not in IMAGE_EXTENSIONS or not source.is_file():
        raise ValueError("Выберите изображение PNG, JPEG или WebP")
    library = Path(WALLPAPERS_DIR).resolve()
    if source.is_relative_to(library):
        return source
    folder = library / "Мои обои"
    folder.mkdir(parents=True, exist_ok=True)
    name = source.stem.lstrip(".") or "Обои"
    with tempfile.NamedTemporaryFile(dir=folder, prefix=".import-") as temp:
        with source.open("rb") as src:
            shutil.copyfileobj(src, temp)
        temp.flush()
        for number in itertools.count(1):
            suffix = "" if number == 1 else f" ({number})"
            target = folder / f"{name}{suffix}{source.suffix}"
            try:
                os.link(temp.name, target)
                return target
            except FileExistsError:
                continue


if __name__ == "__main__":
    try:
        print(import_picture(sys.argv[1]))
    except (ValueError, OSError) as error:
        print(f"Не удалось добавить обои. {error}", file=sys.stderr)
        sys.exit(1)
