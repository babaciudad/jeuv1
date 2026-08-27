#!/usr/bin/env bash
# Rend une scène en image, en Forward+, sans écran.
#
# Ce conteneur n'a pas de carte graphique : on passe par lavapipe, le pilote
# Vulkan logiciel de Mesa, sous un serveur X virtuel. Le renderer est donc bien
# celui qu'on livrera (Forward+), et l'image est fidèle. Le temps, lui, ne l'est
# pas : ne mesurez jamais de FPS ici.
#
# Usage : outils/capture.sh res://scenes/etier.tscn /tmp/vue.png [images]
set -uo pipefail
cd "$(dirname "$0")/.."
RACINE="$PWD"
GODOT="$("$RACINE/outils/godot.sh")"

SCENE="${1:?usage: capture.sh <res://scene.tscn> <sortie.png> [images]}"
SORTIE="${2:?usage: capture.sh <res://scene.tscn> <sortie.png> [images]}"
IMAGES="${3:-30}"

if ! command -v xvfb-run >/dev/null 2>&1; then
  echo "CAPTURE KO : xvfb-run absent (apt-get install -y xvfb)."; exit 1
fi
if [[ ! -f /usr/share/vulkan/icd.d/lvp_icd.*.json ]] && ! ls /usr/share/vulkan/icd.d/lvp_icd.json >/dev/null 2>&1; then
  echo "CAPTURE : pilote Vulkan logiciel absent, installation…" >&2
  apt-get install -y -qq mesa-vulkan-drivers >/dev/null 2>&1 || true
fi

xvfb-run -a -s "-screen 0 1600x900x24" "$GODOT" \
  --path "$RACINE" --rendering-driver vulkan --resolution 1600x900 \
  --script res://outils/capture.gd -- \
  "scene=$SCENE" "sortie=$SORTIE" "images=$IMAGES" 2>&1 \
  | grep -viE 'alsa|pulse|audio driver|ERROR: Condition .status'
