# souls-like

Souls-like coopératif en ligne. Tranche verticale jouable : un menu de choix
de classe, un tutoriel, une chapelle abandonnée, un feu de camp, un couloir
avec raccourci, trois gobelins, un boss. Quatre classes, jusqu'à quatre
joueurs.

Godot 4.5 en **Forward+**, GDScript en typage statique strict. Aucun asset
importé : personnages et décor sont assemblés en primitives, les matières sont
des bruits générés à l'exécution, et tout ce qui éclaire est une pièce qu'on
voit briller. Ombres portées, occlusion ambiante, halo, brouillard
volumétrique.

Une carte graphique compatible Vulkan est donc nécessaire pour jouer. Le repli
`gl_compatibility` reste déclaré pour le mobile, mais il perd tout l'éclairage
— ce serait un autre jeu, visuellement.

## Prérequis

| Outil | Version | Vérifier |
|---|---|---|
| Godot | 4.5.x | `godot --version` |
| PowerShell | **7 ou plus** | `pwsh --version` |
| git | quelconque | `git --version` |

**PowerShell 7, pas celui de Windows.** Windows fournit la 5.1 ; les scripts de
`tools/` déclarent `#Requires -Version 7.0` et emploient des API absentes de la
5.1. Installation : `winget install Microsoft.PowerShell`, puis utiliser la
commande `pwsh` et non `powershell`.

**Si Windows refuse d'exécuter les scripts**, c'est la politique d'exécution :
`Set-ExecutionPolicy -Scope Process Bypass` dans la session en cours.

**git est nécessaire même pour tester** : `test.ps1` et `verify.ps1` installent
gdUnit4 en clonant un tag épinglé. `addons/` n'est pas versionné.

## Lancer

Godot doit être joignable, dans cet ordre : paramètre `-GodotBin`, variable
`$env:GODOT_BIN`, puis le `PATH`.

```powershell
# Vérifier que tout compile et que le typage tient
./tools/verify.ps1

# Installer gdUnit4 au besoin et lancer la suite
./tools/test.ps1

# Deux instances locales, 120 ms de latence simulée dans chaque sens
./tools/netharness.ps1 -Instances 2 -Latency 120

# Quatre joueurs, avec perte de paquets
./tools/netharness.ps1 -Instances 4 -Latency 80 -Loss 0.02

# Tout arrêter
./tools/netharness.ps1 -Stop
```

Pour une partie normale : ouvrir le projet dans Godot et appuyer sur **F5**.
Le menu propose la classe, le mode hôte ou client, et le tutoriel.

Lancée avec des arguments réseau, l'instance saute le menu — c'est ainsi que
`netharness.ps1` démarre quatre fenêtres sans quatre clics :

```
godot --path . -- --connect <adresse> --port 45123 --class 2
godot --path . -- --host --class 0 --no-tutorial
```

## Jouer

| Touche | Effet |
|---|---|
| ZQSD / WASD / flèches | déplacement, relatif à la caméra |
| Souris | caméra, et donc visée des attaques |
| Clic gauche ou J | attaque principale |
| Clic droit ou K | attaque secondaire, soin pour le Soigneur |
| Espace | roulade, avec fenêtre d'invulnérabilité |
| E | se reposer au feu, ouvrir le raccourci |
| F3 | diagnostic réseau, coupe le tutoriel |
| Échap | libérer la souris |

Le feu de camp soigne, ressuscite et remet les ennemis en place. Le raccourci,
lui, reste ouvert : c'est de la progression. Si toute l'équipe tombe, elle se
relève au feu au bout de trois secondes.

## Les quatre classes

| Classe | En jeu |
|---|---|
| **Gardien** | 145 pv, lourd et lent. Coup lourd qui brise la garde, coup rapide en secondaire. |
| **Mage** | 78 pv. Trait à distance en principal, bâton de secours en secondaire. |
| **Soigneur** | 98 pv. Lame en principal, **soin en cône** en secondaire — alliés proches et soi-même. |
| **Archer** | 84 pv, le plus rapide. Flèche véloce et peu douloureuse, dague en secondaire. |

Un projectile ne touche jamais un allié.

## Régler le jeu

Aucune valeur de combat n'est dans le code. Tout est dans `res://data/` :

- `data/classes/*.tres` — les quatre classes : vie, endurance, vitesse, roulade
- `data/actors/gobelin.tres`, `data/actors/warden.tres` — ennemis et boss
- `data/attacks/*.tres` — dégâts, portées, angles, et le **calendrier** de
  chaque attaque sous forme de pistes d'appel de méthode
- `data/level/vertical_slice.tres` — géométrie du niveau et postes des ennemis.
  `walkable` dit où l'on marche, `ceiling_heights` la hauteur de chaque salle,
  `obstacles` ce qui bloque à l'intérieur (colonnes, autel, braseros)
- `data/decor/chapelle.tres` — le décor, et RIEN QUE ce qui se traverse : ce
  qui doit arrêter un personnage va dans `obstacles`, jamais ici
- `models/` — dépose ici un `.glb` et sa fiche `ModelData` pour remplacer un
  personnage en primitives par un vrai modèle rigué et animé. Vide dans le
  dépôt ; **`models/README.md` explique où en trouver, sous quelle licence, et
  comment le brancher.** C'est la seule façon d'avoir des personnages qui
  ressemblent à des humains
- `data/decor/chapelle.tres` et `data/skins/*.tres` sont **générés** par
  `godot --headless --path . -s tools/make_data.gd`. Les `.tres` font foi et
  se retouchent dans l'inspecteur, mais le script les réécrit entièrement :
  un réglage gardé doit être reporté dans `make_data.gd`
- `data/skins/*.tres` — apparences, en primitives assemblées sur un squelette.
  Chaque pièce déclare un `role` (tête, bras, avant-bras, cuisse, tibia) qui
  l'accroche à un pivot ; son `offset` est relatif à CE pivot, pas au sol — une
  pièce de bras a donc un `y` négatif, elle pend. Une pièce marquée « arme »
  passe au jaune quand la hitbox s'ouvre : c'est le repère de rythme du combat,
  n'en privez aucun personnage. Chaque pièce déclare aussi une matière
  (`PLAIN`, `STONE`, `WOOD`, `METAL`, `CLOTH`, `GLOW`) et, si elle brille,
  une portée de lumière — c'est le seul moyen d'éclairer quoi que ce soit
  dans ce projet : pas de lampe sans source visible.

Le rythme d'une attaque se règle dans l'éditeur d'animation, pas dans le code.
Une clé destinée au tick N se pose à `(N - 0,5)/60` seconde : voir `CLAUDE.md`.

## Architecture

Les décisions et les interdits sont dans `CLAUDE.md`. En une phrase : simulation
à pas fixe 60 Hz séparée de la présentation, toute action est une commande
sérialisable, hôte autoritaire avec synchronisation d'état, et autorité hybride
sur les dégâts.
