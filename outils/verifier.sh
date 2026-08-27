#!/usr/bin/env bash
# Vérifie que le projet compile et que TOUT y est typé strictement.
#
# Deux étapes : un passage d'import qui enregistre les classes globales, puis
# une analyse script par script. Les avertissements sont promus en erreurs dans
# project.godot, donc un `var x = 3` sans type fait échouer ce script.
#
# Sortie binaire : 0 si tout passe, 1 sinon. Rien d'autre.
set -uo pipefail
cd "$(dirname "$0")/.."
RACINE="$PWD"
GODOT="$("$RACINE/outils/godot.sh")"

echo "Godot  : $($GODOT --headless --version)"
echo "Projet : $RACINE"
echo

echo "== Import du projet =="
if ! "$GODOT" --headless --path "$RACINE" --import >/tmp/import.log 2>&1; then
  tail -30 /tmp/import.log
  echo "VERIFIER KO : l'import a échoué."
  exit 1
fi
echo "  ok"
echo

mapfile -t SCRIPTS < <(find src outils tests -name '*.gd' 2>/dev/null | sort)
if [[ ${#SCRIPTS[@]} -eq 0 ]]; then
  echo "VERIFIER KO : aucun script trouvé, ce qui ne devrait pas arriver."
  exit 1
fi

echo "== Analyse de ${#SCRIPTS[@]} script(s) =="
ECHECS=0
for f in "${SCRIPTS[@]}"; do
  RES="res://$f"
  SORTIE="$("$GODOT" --headless --path "$RACINE" --check-only --script "$RES" 2>&1)"
  if [[ $? -ne 0 ]] || grep -qE 'Parse Error|SCRIPT ERROR|Failed to load' <<<"$SORTIE"; then
    ECHECS=$((ECHECS+1))
    echo "  ÉCHEC $RES"
    grep -E 'Parse Error|SCRIPT ERROR|Failed to load' <<<"$SORTIE" | sed 's/^/         /' | head -6
  else
    echo "  ok    $RES"
  fi
done

echo
if [[ $ECHECS -gt 0 ]]; then
  echo "VERIFIER KO : $ECHECS script(s) en échec sur ${#SCRIPTS[@]}."
  exit 1
fi
echo "VERIFIER OK : ${#SCRIPTS[@]} script(s) compilés et typés."
