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
  game_view.gd        Miroir visuel du monde et des projectiles.
  tutorial.gd         Apprend les mécaniques en observant ce que fait le joueur.
  level_view.gd       Géométrie déduite de la zone praticable.
  actor_view.gd       Vue d'un acteur, estompage des occultants.
  camera_rig.gd       Caméra troisième personne et son dégagement.
  player_input.gd     SEUL endroit autorisé à lire le clavier et la souris.
  hud.gd              Vie, endurance, boss, invites.
  debug_overlay.gd    Diagnostic réseau, touche F3.
data/               Ressources de réglage (invariant 7).
  attacks/            Calendriers et valeurs des attaques.
  classes/            Les quatre classes jouables.
  actors/             Gobelin et boss.
  level/              Géométrie et points d'intérêt de la tranche verticale.
scenes/             Scènes Godot.
tests/              Suites gdUnit4.
tools/              Scripts PowerShell de vérification, test et banc réseau.
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

**La géométrie visible est déduite de la zone praticable.** Les murs ne sont
pas décrits à la main : `LevelView` place un bloc sur chaque case pleine qui
touche une case praticable. Décrire séparément ce qu'on voit et ce contre quoi
on se cogne, c'est signer pour le jour où ils ne correspondront plus.

## Modèle de collision

Pas de physique Godot. Le monde est plat, les acteurs sont des disques, le
niveau est une union de rectangles praticables dans le plan XZ. Un déplacement
essaie le mouvement complet puis chaque axe séparément.

C'est un choix, pas un raccourci : la simulation reste testable en headless
sans arbre de scène, déterministe, et sans corps physique à tenir synchronisé
avec l'état réseau. Pour un couloir, cinq rectangles suffisent.

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
personne qui se dégage des murs, interface, banc réseau, 56 tests.

**Pas fait, et hors périmètre.** Verrouillage de cible, blocage ou parade,
montée en niveau, sauvegarde, sons, modèles et animations importés, second
niveau, PvP.

**Non éprouvé.** L'équilibrage du boss (400 points de vie) n'a jamais été
mesuré contre un joueur humain, seulement contre un bot de test. C'est une
valeur de `res://data/actors/warden.tres`, elle se règle dans l'inspecteur.
