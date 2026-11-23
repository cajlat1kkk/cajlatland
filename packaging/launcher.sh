#!/usr/bin/env bash
set -euo pipefail
digest=PAYLOAD_SHA256
offset=$(awk '/^__CAJLATLAND_ARCHIVE__$/ {print NR + 1; exit}' "$0")
payload() { tail -n +"$offset" -- "$0"; }
actual=$(payload | sha256sum)
[[ ${actual%% *} == "$digest" ]] || { echo 'Ошибка контрольной суммы установщика.' >&2; exit 1; }
if [[ ${1:-} == --check ]]; then payload | tar -tzf - >/dev/null; echo 'Архив cajlatland проверен.'; exit 0; fi
base=${XDG_DATA_HOME:-$HOME/.local/share}/cajlatland-installer
mkdir -p -- "$base"
dest="$base/$digest"
if [[ ! -d $dest ]]; then
    work=$(mktemp -d -- "$base/.unpack.XXXXXXXX")
    trap 'rm -rf -- "$work"' EXIT
    payload | tar -xzf - -C "$work"
    mv -T -- "$work" "$dest" || [[ -d $dest ]]
fi
exec bash "$dest/install.sh" "$@"
__CAJLATLAND_ARCHIVE__
