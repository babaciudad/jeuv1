# Modèles de personnages

Ce dossier est vide, et c'est normal : le dépôt ne contient aucun modèle 3D.
Le jeu tourne sans, avec les personnages en primitives de `data/skins/`.

**Dès qu'un fichier `<id>.tres` apparaît ici, il remplace le skin en
primitives du personnage correspondant.** Rien à changer dans le code.

---

## La vérité sur l'aspect des personnages

Aucun greffon Godot ne fabrique des personnages qui ressemblent à des
humains. Ce n'est pas une limite de Godot : ça n'existe dans aucun moteur.
Ce qui fait un personnage crédible, c'est un **modèle 3D maillé, texturé et
rigué**, avec ses animations — fait dans Blender, ou acheté, ou téléchargé.
Godot les importe nativement au format glTF (`.glb`), sans greffon.

Les personnages en primitives de ce projet ont un plafond, et il est atteint :
des volumes assemblés restent des volumes assemblés. Pour aller plus loin il
faut des modèles.

## Où en prendre

| Source | Licence | Ce que ça vaut |
|---|---|---|
| **KayKit Adventurers / Skeletons** (kaylousberg.itch.io) | CC0 | Fantasy stylisé, rigué, animé. Le meilleur rapport effort/résultat pour ce projet. Gratuit, y compris commercialement. |
| **Quaternius** (quaternius.com) | CC0 | Packs low-poly animés, très complets. Gratuit. |
| **Mixamo** (mixamo.com, compte Adobe gratuit) | gratuite, usage commercial autorisé | Humanoïdes réalistes + des centaines d'animations réutilisables. C'est ce qu'utilisent la plupart des prototypes. |
| **Synty POLYGON** (syntystore.com) | payante, ~30-60 € | Qualité commerciale. « Fantasy Kingdom » et « Dungeon Realms » sont proches de la direction visée. |

Vérifie toujours la licence avant de publier sur Steam. CC0 ne demande rien ;
Mixamo interdit la redistribution des modèles bruts mais autorise le jeu ;
Synty demande une licence par siège.

## Comment brancher un modèle

1. Dépose le `.glb` ici, par exemple `models/gardien.glb`. Godot l'importe
   tout seul à l'ouverture du projet.
2. Crée une ressource `ModelData` à côté : `models/gardien.tres`, avec
   `Nouvelle ressource → ModelData` dans l'inspecteur.
3. Remplis-la :
   - `scene` : le `.glb` importé ;
   - `scale`, `yaw_degrees`, `lift` : pour le mettre à la bonne taille et le
     faire regarder vers l'avant (l'avant du projet est **-Z**) ;
   - les sept noms d'animations, **tels qu'ils sont dans le modèle** :
     `idle`, `walk`, `run`, `attack`, `dodge`, `hurt`, `death`. Un nom laissé
     vide, ou absent du modèle, retombe sur l'animation de repos.
4. Lance le jeu. C'est tout.

L'identifiant du fichier est celui de la classe ou de l'espèce :
`gardien`, `mage`, `soigneur`, `archer`, `gobelin`, `warden`. Le même que
pour `data/skins/`.

## Le point à ne jamais oublier

**L'animation d'attaque du modèle est purement décorative.**

Ce n'est jamais elle qui ouvre une hitbox. Les hitboxes viennent
d'`AttackRunner`, en ticks, par des pistes d'appel de méthode
(invariant 8 de `CLAUDE.md`). L'animation importée est simplement **étirée**
pour durer exactement le temps de l'attaque simulée, afin que le geste tombe
au bon moment.

Concrètement : si tu changes la durée d'une attaque dans
`data/attacks/*.tres`, l'animation du modèle suit toute seule. Et si un
modèle arrivait avec ses propres pistes de hitbox, il faudrait les
supprimer — pas les brancher.

## Ce qui a été vérifié

Le pipeline a été testé de bout en bout avec un modèle rigué et animé
importé en `.glb` : instanciation, mise à l'échelle, enchaînement des
animations selon l'état simulé, marche et course selon la vitesse réelle.
Le modèle de test n'est pas versionné — c'était un personnage tiers, sans
rapport avec ce jeu.
