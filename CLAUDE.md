# souls-like — règles du dépôt

Souls-like coopératif en ligne, 4 joueurs maximum, troisième personne,
corps-à-corps. Godot 4.5, GDScript en typage statique strict. Cible Windows,
distribution Steam. Direction artistique low-poly PS1/PS2 : 400 à 1500
triangles par personnage, textures 64 à 128 px, éclairage par sommet ou absent.
Cette contrainte est une contrainte de production, pas un goût.

Équipe : une personne. **Toute complexité non justifiée est un échec.**

---

## Périmètre de la version 1

Un feu de camp, un couloir avec raccourci, trois gobelins, un boss, une
roulade. Jouable à plusieurs.

Toute idée hors de ce périmètre va dans `BACKLOG.md` et n'est jamais
implémentée, même bonne, même rapide. Le verrou ne se lève que par une
décision explicite du propriétaire du projet, écrite ici.

### AMENDEMENT — 23 août 2026, par le propriétaire du projet

Le verrou est levé sur trois points, sur demande explicite et réitérée :

1. **Quatre classes jouables** — Gardien, Mage, Soigneur, Archer — au lieu
   d'une arme unique. Ce que cela a coûté est écrit noir sur blanc ci-dessous
   dans l'invariant 5 : il a fallu ouvrir un TROISIÈME cas d'autorité.
2. **Un menu de choix de classe** avant la partie.
3. **Un tutoriel** qui enseigne les mécaniques dans l'ordre où elles servent.

Le reste du périmètre est inchangé et reste verrouillé. Notamment : toujours
pas de verrouillage de cible, pas de parade, pas de progression de
personnage, pas de second niveau.

---

## Les dix invariants, en règles opérationnelles

### 1. Le tick est la seule unité de temps
La simulation avance par pas fixes de 1/60 s, dans `_physics_process`. Un tick
est un entier partagé par toutes les machines.

- Tout événement de gameplay est daté **en ticks**. Jamais en secondes, jamais
  en `delta`.
- Un `delta` qui entre dans du code de `src/sim/` est un bug.
- Les durées réglables (fenêtres de hitbox, temps de récupération) s'expriment
  en ticks dans les ressources de `res://data/`.
- `SimConfig.TICK_RATE` et `physics/common/physics_ticks_per_second` doivent
  rester égaux.

### 2. La simulation ne connaît pas la présentation
Le code de `src/sim/` ne lit jamais l'entrée, ne touche jamais la caméra, l'UI
ni un nœud visuel.

- La simulation **émet des signaux**. La présentation **s'y abonne**. Ce sens,
  et pas l'autre.
- `Input.` n'apparaît que dans `src/presentation/`, jamais dans `src/sim/`.
- La présentation peut lire l'état de la simulation ; elle ne l'écrit jamais.

### 3. Une action de gameplay est une commande, ou n'existe pas
Toute action est un `Command` `{tick, actor_id, type, payload}` sérialisable,
appliqué par la simulation.

- Aucune entité n'appelle directement une méthode d'une autre entité.
- Ajouter une action = ajouter une valeur à `Command.Type`, **à la fin**. On ne
  réordonne jamais l'énumération, on ne recycle jamais une valeur : elles
  partent sur le réseau.
- La seule porte de sortie vers le réseau est `NetBootstrap.submit_command()`.

### 4. Hôte autoritaire, synchronisation d'état, pas de lockstep
L'hôte est un joueur et porte le peer id 1 (`SimConfig.HOST_PEER_ID`).

- Entités distantes : interpolées avec un tampon d'environ 100 ms
  (`SimConfig.INTERPOLATION_BUFFER_MSEC`).
- Personnage local : prédit, puis réconcilié.
- Les compteurs de tick des machines **ne sont pas égaux** : le client précède
  volontairement l'hôte d'un aller simple de latence, plus une marge. Ce qui
  doit être stable, c'est l'écart, pas l'égalité. Un test qui exigerait
  l'égalité exigerait du lockstep.

### 5. Autorité hybride sur les dégâts
- Dégâts **reçus par un joueur** : autorité du client-victime. L'hôte ne fait
  qu'un contrôle de plausibilité — distance, cohérence temporelle.
- Dégâts **infligés à un ennemi** : déclarés par l'attaquant, confirmés et
  diffusés par l'hôte.
- **Soins reçus par un joueur** : déclarés par le SOIGNEUR, confirmés par
  l'hôte. *(Troisième cas, ouvert par l'amendement sur les classes.)*
- **Comportement des ennemis** : simulé exclusivement par l'hôte.

Pourquoi le soin ne suit pas la règle des dégâts reçus : la victime a autorité
sur ce qu'elle encaisse parce qu'un coup doit être jugé sur ce qu'elle VOIT —
mourir d'une attaque qu'on a esquivée à l'écran est intolérable. Un soin n'a
pas cette urgence : cent millisecondes de retard ne tuent personne. On préfère
donc l'autorité de l'hôte, qui est plus simple et moins abusable.

Dans tous les cas, une commande ne porte que des **identifiants**, jamais des
nombres. L'hôte relit ses propres données pour les dégâts comme pour les
soins : un client ne peut ni gonfler ce qu'il inflige ni ce qu'il rend.

Ce modèle suppose l'absence de PvP. **Il n'y aura pas de PvP.** Toute
fonctionnalité qui réintroduirait du PvP invalide ce modèle entier.

### 6. Ce qui se prédit et ce qui ne se prédit pas
- **On prédit** : locomotion, roulade, déclenchement d'attaque, consommation
  d'endurance.
- **On ne prédit jamais** : dégâts, mort, ramassage, progression.

Cette liste est exhaustive dans les deux sens. Ajouter une prédiction est une
décision d'architecture, pas un détail d'implémentation.

### 7. Le combat est piloté par la donnée
Toute valeur réglable vit dans une ressource sous `res://data/` : dégâts, coût
d'endurance, fenêtres d'activation de hitbox, dégâts de poise, tracking,
fenêtre d'annulation.

- Le code **consomme** la donnée. Il ne la contient pas.
- Un nombre magique dans `src/sim/` qui décrit un réglage de combat est un bug.
- `SimConfig` est l'exception assumée : il décrit le contrat temporel du
  réseau, pas un réglage de jeu.

### 8. Les hitboxes s'activent par pistes d'animation
Exclusivement par pistes d'appel de méthode dans l'`AnimationPlayer`.

- **Jamais** de minuteur parallèle, jamais de compteur de frames à côté de
  l'animation. Une hitbox pilotée par un minuteur est un bug, même si elle
  fonctionne.

**Deux systèmes d'animation coexistent et ne doivent jamais être confondus :**

| | `src/sim/attack_runner.gd` | `src/presentation/actor_view.gd` |
|---|---|---|
| Ce qu'il anime | l'ouverture et la fermeture des hitboxes | la démarche, le geste d'arme, la pose |
| Horloge | ticks, avancés à la main par la simulation | secondes réelles, `delta` d'affichage |
| Autorité | oui : c'est lui qui décide des touches | aucune : il ne décide de rien |
| Si on le supprime | le jeu n'a plus de combat | le jeu est laid, et se joue pareil |

Le second LIT l'état du premier (`runner.hitbox_open`, `runner.attack`).
L'inverse serait une faute : une hitbox ne doit jamais dépendre de la
fréquence d'affichage. C'est pour cela que la vue anime par procédure — depuis
la position, l'état et l'attaque en cours — au lieu de jouer ses propres
`Animation`s : deux `AnimationPlayer` sur des horloges différentes finiraient
par diverger, et personne ne saurait lequel a raison.

### 9. La couche gameplay ignore le transport
ENet en développement local, `SteamMultiplayerPeer` en production.

- Tout passe par l'interface `Transport` (`src/net/transport.gd`).
- Pas de `MultiplayerAPI`, pas de RPC, pas d'annotation `@rpc`. On utilise
  l'API paquet de `MultiplayerPeer` : c'est ce qui rend le remplacement du
  transport mécanique et garde la simulation hors de l'arbre de scène.
- `LatencyPipe` décore n'importe quel `Transport` — c'est pourquoi la latence
  simulée fonctionne aussi en headless, sans droits administrateur.

### 10. Typage statique, sans exception
Annotations sur toutes les variables, tous les paramètres, tous les retours.

- `untyped_declaration`, `inferred_declaration` et les `unsafe_*` sont promus
  en **erreurs** dans `project.godot`. Un script non typé ne compile pas.
- `:=` est interdit : c'est de l'inférence, pas une annotation.
- On ne désactive jamais un avertissement pour faire passer la vérification.

---

## Arborescence

```
src/sim/            Simulation. Ignore le réseau, l'entrée et l'affichage.
  sim_config.gd       Contrat temporel : tick, avance client, nombre de joueurs.
  sim_math.gd         Géométrie XZ : collision, cônes de hitbox, rotation bornée.
  command.gd          Commande sérialisable et son format binaire.
  command_buffer.gd   Commandes en attente, abandon de celles arrivées trop tard.
  simulation.gd       Boucle à pas fixe et correction d'horloge.
  world.gd            État du monde et règles du jeu.
  actor.gd            État d'un joueur ou d'un ennemi.
  projectile.gd       Trajectoire déduite du tick de départ, jamais diffusée.
  attack_runner.gd    Calendrier d'attaque piloté par AnimationPlayer.
  enemy_brain.gd      Décisions des ennemis. Appelé par l'hôte seul.
  data/               Schémas des ressources de réglage.
src/net/            Transport, sérialisation, synchronisation.
  transport.gd        Interface. Tout passe par là (invariant 9).
  enet_transport.gd   ENet brut, sans MultiplayerAPI ni RPC.
  latency_pipe.gd     Latence et perte simulées, dans la couche transport.
  net_message.gd      Genres de messages et leur encodage.
  net_clock.gd        Estimation de l'avance du client sur l'hôte.
  world_snapshot.gd   Instantané d'état et projectiles, hôte vers clients.
  world_sync.gd       Adoption, interpolation, réconciliation.
  command_history.gd  Mémoire des commandes et positions prédites.
  net_bootstrap.gd    Point d'entrée d'une instance.
src/presentation/   Tout ce qui est visible. Lit, n'écrit jamais.
  main_menu.gd        Choix de classe, hôte ou client, tutoriel.
  actor_view.gd       Squelette de pivots habillé d'un skin, animé par procédure.
  skin_library.gd     Résout un skin par identifiant, avec cache.
  primitive_factory.gd Formes et matériaux, partagés par personnages et décor.
  vfx.gd              Effets brefs : impact, touche, soin, lancer.
  model_library.gd    Résout un modèle importé par identifiant, avec cache.
  data/               Schémas des skins et du décor : pièces primitives.
  game_view.gd        Miroir visuel du monde, des projectiles et des effets.
  tutorial.gd         Apprend les mécaniques en observant ce que fait le joueur.
  level_view.gd       Géométrie déduite de la zone praticable.
  camera_rig.gd       Caméra troisième personne et son dégagement.
  player_input.gd     SEUL endroit autorisé à lire le clavier et la souris.
  hud.gd              Vie, endurance, boss, invites.
  debug_overlay.gd    Diagnostic réseau, touche F3.
data/               Ressources de réglage (invariant 7).
  attacks/            Calendriers et valeurs des attaques.
  classes/            Les quatre classes jouables.
  skins/              Apparences, une par classe et par espèce.
  decor/              Décor d'un niveau, purement visuel : res://data/decor/<id>.tres.
                      Généré par tools/make_data.gd.
  actors/             Gobelin et boss.
  level/              Géométrie et points d'intérêt de la tranche verticale.
models/             Modèles de personnages importés. VIDE dans le dépôt ;
                    voir models/README.md. Un <id>.tres ici remplace le skin.
scenes/             Scènes Godot.
tests/              Suites gdUnit4.
tools/              Scripts PowerShell de vérification, test et banc réseau.
  make_data.gd        Génère les skins et le décor. Voir ci-dessous.
addons/             Dépendances tierces, NON versionnées, installées par test.ps1.
```

## Conventions du gameplay

Trois règles non évidentes, chacune apprise en se cognant dedans.

**Une clé d'animation destinée au tick N s'écrit à `(N - 0,5)/60` seconde.**
La simulation avance l'animation par pas de 1/60 s et le cumul en flottant ne
tombe jamais exactement sur une borne : une clé posée pile sur le tick
déclenche une fois sur deux au tick suivant.

**La visée voyage dans la commande d'attaque.** Le personnage ne tourne que
lorsqu'il se déplace ; à l'arrêt, sans direction visée, il frapperait toujours
vers son dernier pas. La présentation joint donc la direction de la caméra à
la commande `ATTACK`, parce qu'elle seule connaît la caméra (invariant 2).

**Un skin ne change rien au jeu.** Ni hitbox, ni portée, ni rayon de
collision : il habille un cylindre de simulation, il ne le remplace pas. C'est
pourquoi il vit dans `res://data/skins/<id>.tres` et non dans la fiche de
classe — et pourquoi `PlayerData` ignore que le type `SkinData` existe. Le skin
se résout par l'identifiant de la fiche ; ajouter une classe et son apparence
ne demande de toucher à aucun `.gd`.

Une pièce marquée `is_weapon` passe au jaune quand la hitbox est ouverte. Ce
n'est pas décoratif : **c'est le seul repère de rythme du jeu**, le tutoriel
l'enseigne explicitement. Un skin sans pièce d'arme rend son porteur illisible
en combat.

**Un personnage peut venir d'un modèle importé.** Si `res://models/<id>.tres`
existe (une ressource `ModelData` pointant sur un `.glb`), il remplace le skin
en primitives. Sinon la vue retombe sur les primitives, et le jeu tourne
exactement pareil : `models/` est vide dans le dépôt, et le jeu est jouable.

C'est la seule façon d'avoir des personnages qui ressemblent à des humains —
aucun greffon ne fabrique cela, dans aucun moteur. `models/README.md` donne
les sources, les licences et la marche à suivre.

Point à ne jamais perdre de vue : **l'animation d'attaque d'un modèle importé
est décorative.** Elle n'ouvre aucune hitbox — celles-ci viennent
d'`AttackRunner`, en ticks (invariant 8). L'animation est simplement étirée
pour durer exactement le temps de l'attaque simulée, afin que le geste tombe
au bon moment. Un modèle qui apporterait ses propres pistes de hitbox doit
les perdre, pas les brancher.

**Un personnage est articulé, pas empilé.** Chaque pièce déclare un `role`
(`SkinPart.Role`) qui l'accroche à un pivot : tête, bras, avant-bras, cuisse,
tibia — gauche et droite. `SkinData` décrit le squelette en six mesures
(`shoulder`, `elbow_drop`, `hip`, `knee_drop`, `neck`, plus `stride_degrees`
et `idle_bob`) et `ActorView` en construit la hiérarchie de `Node3D`.

Conséquence à ne pas oublier : **l'`offset` d'une pièce est relatif à SON
pivot**, pas au sol. Une pièce de bras a donc un `y` négatif — elle pend. Seule
une pièce `STATIC` se mesure depuis le sol. `tests/skin_test.gd` verrouille les
deux règles, plus un plancher de huit pièces articulées par skin : sans lui, un
skin peut redevenir un tas de caisses sans que rien ne le signale, puisque tout
resterait affiché — simplement plus rien ne bougerait.

**Un effet visuel naît d'un écart déjà constaté, jamais d'un événement.**
`Vfx` (impact, touche, soin, lancer) est déclenché par `GameView` qui compare
l'état à celui de l'image précédente : des points de vie qui ont baissé, un
projectile qui a disparu. La simulation n'émet aucun signal pour cela, et c'est
volontaire — un client qui rejoue ses commandes repasserait deux fois sur le
même signal.

## Rendu

Le projet tourne en **Forward+** (`renderer/rendering_method` dans
`project.godot`). Ce n'est pas un détail de confort : c'est ce qui donne les
ombres portées, l'occlusion ambiante, le halo et le brouillard volumétrique.

Il a tourné en `gl_compatibility` pendant toute sa première moitié, et cela
donnait exactement l'aspect qu'on lui reprochait : aplats gris, pas d'ombre,
pas de relief. **En `gl_compatibility` tout le bloc `_build_atmosphere()` est
ignoré en silence** — aucune erreur, aucun avertissement, seulement une
chapelle en carton. Si un jour le rendu redevient plat sans qu'on ait touché
au décor, c'est la première chose à vérifier.

Trois règles tiennent l'aspect :

**Le métal reste peu métallique.** `Surface.METAL` est à 0,38 de métallicité,
pas 0,9. À 0,9 un métal ne tire sa couleur que de ce qu'il reflète — et cette
scène n'a ni ciel ni sonde de réflexion, donc il reflète du noir : les heaumes
devenaient des billes de plastique noir. Si un jour une sonde de réflexion
apparaît, cette valeur pourra remonter.

**Les matières sont déclarées, pas réglées pièce par pièce.**
`SkinPart.Surface` — `PLAIN`, `STONE`, `WOOD`, `METAL`, `CLOTH`, `GLOW` —
décide de la rugosité, de la métallicité et du grain. Deux pièces d'acier
brillent pareil sans qu'on ait à s'en souvenir.

**Les textures sont fabriquées, jamais chargées.** Le dépôt ne contient aucune
image. `PrimitiveFactory` génère un bruit de Perlin par matière et le projette
en triplanaire : le grain suit le monde et non la boîte, donc une colonne de
six mètres et un pavé de un mètre ont le même grain. Le contraste du bruit
reste faible — à pleine amplitude, un bruit ne fait pas de la pierre, il fait
du camouflage.

**Ce qui brille éclaire, et rien n'éclaire sans qu'on voie quoi.** Il n'y a
aucune liste de lampes dans ce projet. Une lumière naît toujours d'une pièce
`GLOW` dont le champ `light_range` est non nul, et ce seul nombre décide à la
fois de sa portée, de son énergie et de l'intensité de sa lueur. Une lampe
sans source visible, ou une flamme qui n'éclaire pas, c'est l'incohérence
qu'on ne remarque pas en la posant et qu'on ne s'explique plus six mois après.

Corollaire appris en se cognant dedans : **la lumière prend la teinte de la
pièce, mais désaturée de moitié.** Une flamme est rouge orangé ; ce qu'elle
éclaire ne l'est pas. Seize torches à leur couleur pleine transforment un
couloir en chambre noire de photographe, et plus rien n'a de couleur propre.

**La géométrie visible est déduite de la zone praticable.** Les murs ne sont
pas décrits à la main : `LevelView` place un bloc sur chaque case pleine qui
touche une case praticable. Décrire séparément ce qu'on voit et ce contre quoi
on se cogne, c'est signer pour le jour où ils ne correspondront plus.

La hauteur suit la même règle. `LevelData.ceiling_heights` donne une hauteur
sous plafond par rectangle praticable ; un mur monte à la hauteur de la case
la plus haute qu'il borde. C'est ce qui fait qu'une nef à 7,6 m et un boyau à
3,6 m ne se ressemblent pas, sans qu'on ait à le dire deux fois.

Là où une salle basse touche une salle haute, `LevelView` bouche la bande de
vide entre les deux plafonds. Sans ce pan, on voit à travers le décor — et la
première version l'oubliait, ce qui ouvrait un trou sur le néant au-dessus de
l'arcade du chœur.

Le dallage se pose en deux passes : un lit sombre pleine largeur, puis les
dalles rétrécies de quatre centimètres. Ce sont ces quatre centimètres qui
font le joint de mortier. Quarante mètres de sol sans joint sont une seule
surface lisse, et aucune texture ne rattrape ça.

## Modèle de collision

Pas de physique Godot. Le monde est plat, les acteurs sont des disques, le
niveau est une union de rectangles praticables dans le plan XZ. Un déplacement
essaie le mouvement complet puis chaque axe séparément.

C'est un choix, pas un raccourci : la simulation reste testable en headless
sans arbre de scène, déterministe, et sans corps physique à tenir synchronisé
avec l'état réseau. Pour un couloir, cinq rectangles suffisent.

Ce qui bloque est déclaré une seule fois, dans `LevelData` :

- `walkable` — l'union des rectangles où un acteur peut se trouver ;
- `obstacles` — les rectangles pleins À L'INTÉRIEUR du praticable (colonnes,
  autel, braseros). Ils arrêtent les déplacements ET les projectiles, par la
  même liste : `World.blockers()` ;
- `shortcut_gate` — la porte du raccourci, qui rejoint `blockers()` tant
  qu'elle est fermée.

**Un obstacle est DESSINÉ à partir de son emprise, jamais posé à côté.**
`LevelView` en tire base, fût et chapiteau ; `obstacle_heights` décide s'il
monte jusqu'au plafond (un pilier) ou s'arrête (un meuble). Un obstacle
dessiné ailleurs que là où il bloque est le pire des bugs : on cherche du côté
du réseau pendant des heures.

Symétriquement, `res://data/decor/<id>.tres` ne contient QUE ce qui se
traverse. Une pièce de décor ne bloque rien, jamais.

## Commandes du jeu

| Touche | Effet |
|---|---|
| ZQSD / WASD / flèches | déplacement, relatif à la caméra |
| Souris | orientation de la caméra, et donc visée |
| Clic gauche ou J | attaque principale |
| Clic droit ou K | attaque secondaire, soin pour le Soigneur |
| Espace | roulade |
| E | interagir : se reposer au feu, ouvrir le raccourci |
| F3 | diagnostic réseau, coupe le tutoriel |
| Échap | libérer la souris |

### Les quatre classes

L'ordre de `NetBootstrap.CLASS_PATHS` est celui du menu ET celui qui voyage
sur le réseau. On n'en réordonne jamais, on n'en retire jamais, on n'en ajoute
qu'à la fin — un index de classe périmé désignerait un autre personnage.

| Classe | Rôle | Particularité technique |
|---|---|---|
| Gardien | encaisse et brise la garde | rien de spécial, mêlée pure |
| Mage | frappe de loin | attaque principale à projectile |
| Soigneur | rend des points de vie | attaque secondaire à `heal > 0`, cherche des alliés |
| Archer | rapide et léger | projectile rapide, dégâts faibles |

## Commandes de vérification

Prérequis : Godot 4.5, **PowerShell 7 ou plus** (`pwsh`, pas `powershell` :
les scripts déclarent `#Requires -Version 7.0`), et git, dont `test.ps1` et
`verify.ps1` se servent pour installer gdUnit4.

Godot est résolu dans cet ordre : paramètre `-GodotBin`, puis `$env:GODOT_BIN`,
puis le `PATH`.

```powershell
./tools/verify.ps1                                  # parsing + typage + lint
./tools/test.ps1                                    # installe gdUnit4 et teste
./tools/test.ps1 -Suite res://tests/tick_convergence_test.gd
./tools/netharness.ps1 -Instances 2 -Latency 120    # deux fenêtres synchronisées
./tools/netharness.ps1 -Instances 4 -Latency 80 -Loss 0.02
./tools/netharness.ps1 -Stop                        # arrête les instances
```

`verify.ps1` et `test.ps1` ont un code de sortie binaire : 0 ou 1.
`-Latency` est une latence d'**aller simple** appliquée dans chaque sens :
`-Latency 120` signifie 240 ms d'aller-retour.

Les deux doivent passer avant tout commit.

## Le générateur de données

`godot --headless --path . -s tools/make_data.gd` réécrit `data/skins/*.tres`,
`data/decor/chapelle.tres` et `data/level/vertical_slice.tres`.

Il existe parce qu'un personnage fait une trentaine de pièces et la chapelle
sept cents : les poser une par une dans l'inspecteur est faisable, les tenir
cohérentes ne l'est pas. Huit colonnes doivent partager leur profil, six skins
doivent partager leur ossature, seize torches doivent se ressembler.

**Lequel fait foi : les `.tres`.** Ce sont eux que le jeu charge, eux qui sont
versionnés, eux qu'on peut retoucher dans l'inspecteur pour essayer une
valeur. Mais le script les réécrit INTÉGRALEMENT : un réglage trouvé à la main
et jugé bon doit être reporté dans `make_data.gd`, sinon la prochaine
exécution l'écrase. C'est le seul piège de ce fichier ; il n'y en a pas
d'autre.

## Conventions

- **Code** : identifiants en anglais, commentaires et documentation en
  français.
- **Commits** : en français, à l'impératif, atomiques. Un livrable, un commit.
- **gdUnit4** n'est pas versionné et n'est pas activé comme greffon dans
  `project.godot` : l'activer rendrait le projet impossible à ouvrir sur un
  clone neuf tant que `test.ps1` n'a pas tourné. Pour obtenir le panneau dans
  l'éditeur, activez-le à la main après une première exécution de `test.ps1`.
- **`export_presets.cfg`** est ignoré par git : il portera la clé de signature
  et l'AppID Steam. Il doit être recréé sur chaque machine de build.

---

## INTERDITS

Les points suivants ne se discutent pas et ne se contournent pas.

1. **Écrire du gameplay hors périmètre V1.** Le périmètre est verrouillé. Une
   idée hors périmètre va dans `BACKLOG.md`, point.
2. **Utiliser `delta` ou des secondes dans `src/sim/`.** Le temps se compte en
   ticks.
3. **Lire l'entrée, toucher la caméra, l'UI ou un nœud visuel depuis
   `src/sim/`.**
4. **Appeler directement une méthode d'entité pour une action de gameplay.**
   Cela passe par une commande, ou cela n'existe pas.
5. **Utiliser `@rpc`, `MultiplayerAPI` ou tout appel réseau hors de
   l'interface `Transport`.**
6. **Prédire les dégâts, la mort, le ramassage ou la progression.**
7. **Mettre une valeur de réglage de combat en dur dans le code.** Elle va dans
   `res://data/`.
8. **Activer une hitbox par un minuteur** plutôt que par une piste d'animation.
9. **Écrire `:=` ou une variable, un paramètre ou un retour sans annotation.**
10. **Désactiver un avertissement, commenter un test, ou ajouter
    `@warning_ignore` pour faire passer `verify.ps1`.** Si la vérification
    échoue, on corrige la cause.
11. **Ajouter une dépendance externe sans accord explicite préalable.**
12. **Introduire du PvP.** Le modèle d'autorité sur les dégâts s'effondrerait.
13. **Refactoriser ce qui n'a pas été demandé**, même si c'est évident, même
    « pendant qu'on y est ».
14. **Affirmer qu'un code fonctionne sans l'avoir exécuté.**

---

## État du jeu

**Fait.** Boucle à tick fixe et correction d'horloge. Commandes sérialisables.
Instantanés d'état, interpolation des acteurs distants, prédiction et
réconciliation du personnage local. Autorité hybride sur les dégâts et les
soins. Quatre classes, dont deux à projectiles et une soigneuse. Menu de choix
de classe et de session. Tutoriel en neuf étapes qui se valident en agissant.
Feu de camp avec repos, soin, réapparition et remise en place des ennemis.
Couloir et raccourci à grille. Trois gobelins et un boss à deux phases.
Roulade avec fenêtre d'invulnérabilité, endurance, poise. Caméra troisième
personne qui se dégage des murs, interface, banc réseau, 64 tests.

**Le niveau est une chapelle abandonnée** (`data/level/vertical_slice.tres`,
identifiant `chapelle`) : nef à 7,6 m sous plafond avec deux rangs de colonnes
qui bloquent pour de vrai, vitraux, bancs renversés et poutres tombées ; chœur
à 5,8 m avec autel, croix, cierges et braseros, autour du feu de camp ; boyau
à 3,6 m vers l'arène du boss ; raccourci parallèle fermé par une grille. Le
décor purement visuel vit dans `data/decor/chapelle.tres`.

**Le rendu est en Forward+**, avec ombres portées, occlusion ambiante, halo,
brouillard volumétrique et tonemapping ACES ; matières PBR et grain
procédural, sans aucun fichier image dans le dépôt.

**Les personnages sont articulés.** Six skins humanoïdes — quatre classes, le
gobelin, le warden — bâtis sur un squelette de pivots et animés par procédure :
foulée calée sur la distance parcourue, coude et genou qui plient, geste d'arme
distinct pour la préparation, la frappe, le lancer et le soin. Quatre effets
brefs : impact de projectile, touche, soin, lancer.

**Pas fait, et hors périmètre.** Verrouillage de cible, blocage ou parade,
montée en niveau, sauvegarde, sons, modèles et animations importés, second
niveau, PvP.

**Non éprouvé.** L'équilibrage du boss (400 points de vie) n'a jamais été
mesuré contre un joueur humain, seulement contre un bot de test. C'est une
valeur de `res://data/actors/warden.tres`, elle se règle dans l'inspecteur.
