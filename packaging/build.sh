#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
mkdir -p dist
work=$(mktemp -d dist/.build.XXXXXXXX)
trap 'rm -rf -- "$work"' EXIT
tar --exclude=__pycache__ --exclude='*.pyc' --exclude=target -czf "$work/data" LICENSE README.md install.sh setup home packages system
digest=$(sha256sum "$work/data")
sed "s/PAYLOAD_SHA256/${digest%% *}/" packaging/launcher.sh > "$work/cajlatland.run"
cat "$work/data" >> "$work/cajlatland.run"
chmod 755 "$work/cajlatland.run"
mv -f -- "$work/cajlatland.run" dist/cajlatland.run
