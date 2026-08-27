#!/usr/bin/env bash
# Installe gdUnit4 au besoin et exécute la suite de tests en headless.
#
# gdUnit4 n'est pas versionné dans le dépôt : il est récupéré à une version
# épinglée depuis les releases GitHub (la seule voie réseau qui fonctionne).
set -uo pipefail
cd "$(dirname "$0")/.."
RACINE="$PWD"
GODOT="$("$RACINE/outils/godot.sh")"
GDUNIT_VERSION="${GDUNIT_VERSION:-v6.2.1}"

if [[ ! -d "$RACINE/addons/gdUnit4" ]]; then
  echo "== Installation de gdUnit4 $GDUNIT_VERSION =="
  # Ni les tarballs d'archive ni codeload ne passent le proxy de ces machines :
  # git clone est la seule voie qui fonctionne, et un tag la rend reproductible.
  rm -rf /tmp/gdunit-src
  if ! git clone --depth 1 --branch "$GDUNIT_VERSION" -q \
       https://github.com/MikeSchulze/gdUnit4 /tmp/gdunit-src; then
    echo "TESTER KO : clone de gdUnit4 $GDUNIT_VERSION impossible."; exit 1
  fi
  mkdir -p "$RACINE/addons"
  cp -r /tmp/gdunit-src/addons/gdUnit4 "$RACINE/addons/"
  rm -rf /tmp/gdunit-src
  echo "  installé dans addons/gdUnit4"
fi

echo "== Import (enregistre les classes de gdUnit4) =="
"$GODOT" --headless --path "$RACINE" --import >/dev/null 2>&1

echo "== Suite de tests =="
# --ignoreHeadlessMode : gdUnit4 refuse le headless par défaut parce que les
# InputEvents n'y sont pas transmis. L'invariant 2 interdit à la simulation de
# lire l'entrée, donc aucun test de ce socle n'en dépend.
"$GODOT" --headless --path "$RACINE" -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests
CODE=$?
echo
[[ $CODE -eq 0 ]] && echo "TESTER OK" || echo "TESTER KO : gdUnit4 sort avec le code $CODE."
exit $CODE
