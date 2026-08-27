#!/usr/bin/env bash
# Résout le binaire Godot, en le téléchargeant au besoin.
#
# Les sites de Godot sont injoignables depuis les conteneurs de développement,
# mais les « release assets » de GitHub passent. C'est la seule voie qui marche,
# et elle est épinglée sur une version précise : un moteur qui glisse d'une
# version à l'autre entre deux vérifications ne vérifie rien.
set -euo pipefail

VERSION="${GODOT_VERSION:-4.7.2-stable}"
CACHE="${GODOT_CACHE:-/tmp/godot-$VERSION}"
BIN="$CACHE/Godot_v${VERSION}_linux.x86_64"

if [[ -n "${GODOT_BIN:-}" && -x "${GODOT_BIN}" ]]; then echo "$GODOT_BIN"; exit 0; fi
if [[ -x "$BIN" ]]; then echo "$BIN"; exit 0; fi
if command -v godot >/dev/null 2>&1; then command -v godot; exit 0; fi

mkdir -p "$CACHE"
URL="https://github.com/godotengine/godot-builds/releases/download/${VERSION}/Godot_v${VERSION}_linux.x86_64.zip"
echo "Téléchargement de Godot $VERSION…" >&2
curl -sL --fail --max-time 600 -o "$CACHE/godot.zip" "$URL"
python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$CACHE/godot.zip" "$CACHE"
chmod +x "$BIN"
rm -f "$CACHE/godot.zip"
echo "$BIN"
