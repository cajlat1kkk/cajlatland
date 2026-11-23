#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
[[ -f /etc/arch-release ]] && command -v pacman >/dev/null || { echo 'Нужен Arch Linux с pacman.' >&2; exit 1; }
(( EUID != 0 )) || { echo 'Запустите установку от обычного пользователя с правом sudo.' >&2; exit 1; }
exec ./setup install --full --noconfirm --skip-aur --skip-extras "$@"
