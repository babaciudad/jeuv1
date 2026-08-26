# Modèles de personnages

Tous les personnages du jeu partagent **un seul corps** et **une seule
bibliothèque de mouvements**. Ce qui les distingue est le costume, bâti en
primitives par `SaltBody`, et le choix des clips.

| Fichier | Ce que c'est |
|---|---|
| `humain/corps.glb` | Maillage skinné seul, 66 os, 13 757 triangles |
| `humain/gestes_base.glb` | Le même corps + 87 clips. **C'est la scène utilisée.** |
| `humain/gestes_plus.glb` | 75 clips de plus, greffés au montage sous `plus/` |
| `<id>.tres` | La fiche `ModelData` d'un personnage : quels clips, quel costume |

Onze mégaoctets pour six personnages, contre vingt-quatre auparavant pour six
squelettes identiques.

## Licence et attribution

**Mesh2Motion** (Scott Petrovic) — modèles, rigs et animations en **CC0 1.0**.
Le code de leur application est MIT, mais on n'en utilise rien. Texte de la
licence : `humain/LICENCE-CC0.md`. Source :
<https://github.com/Mesh2Motion/mesh2motion-app>

## Pourquoi ce corps-là, et pourquoi ce n'est pas un asset flip

Ce qui est importé, c'est un **mannequin nu et sa bibliothèque de gestes** —
l'équivalent libre de ce que fait Mixamo. Tout ce qu'on voit à l'écran par
dessus — la toile huilée, le chapeau de saunier, les lunettes de verre, la
croûte de sel, le rabot, le râtelier de lampes — est fabriqué dans
`src/presentation/salt_body.gd`. Un mannequin de couture n'est pas une robe.

La version précédente assemblait le personnage ENTIER en primitives collées
sur des os. Ça ne pouvait pas marcher : un empilement de volumes reste un
mannequin articulé, on voit les jonctions, les épaules ne se raccordent pas.
Le corps est maintenant une surface continue déformée par le squelette, et le
code ne fait plus que l'habiller.

## Proportions

Mesurées sur le rig, pas estimées : personnage de **1,83 m**, bassin à
**50,1 %** de la hauteur, épaules à **78,7 %**. Ce sont les proportions
humaines de manuel. Le rig précédent était chibi et il avait fallu rallonger
les os de 2,1× pour y remédier — ce qui cassait tous les cycles de marche,
animés pour des jambes deux fois plus courtes. Ce bricolage a disparu.

## Les clips qui comptent

162 en tout. Ceux que la simulation sait produire :

- **Locomotion** : `Walk`, `Walk_Large`, `Walk_Formal`, `Jog`, `Sprint`,
  `plus/Walk_Backwards`, `plus/Strafe_left`, `plus/Strafe_right`
- **Esquive** : `Roll` — une **vraie roulade**, plus une bascule du
  porte-pièces. Aussi `plus/Dodge_back/left/right`.
- **Coups** : `Sword_Regular_A/B/C`, `Spell_Simple_Shoot`,
  `plus/Bow Release`, `plus/Two-hand Blast`, `plus/Attack_Ground_Pound`
- **Réactions** : `Hit_Chest`, `Hit_Head`, `Hit_Knockback`, quatre morts
- **Mort-vivant** : `Zombie_Idle`, `Zombie_Walk`, `plus/Zombie_Walk_2`,
  `Zombie_Scratch`. C'est ce qui donne aux cristallisés une démarche qui
  n'est pas celle des joueurs, et ça se lit de loin.

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

Lancé et observé, pas seulement compilé :

- les six `.glb` s'importent et s'instancient sans erreur de script ;
- chacun porte un `Skeleton3D` de **41 os** et de **76 à 95 animations** ;
- `Idle` s'enchaîne bien tout seul au démarrage sur le joueur comme sur les
  quatre ennemis de la partie ;
- le sommet du crâne est à environ **1,5 m** à `scale = 1.0`, ce qui cadre
  correctement avec la caméra existante (recul 6 m, hauteur d'épaule 1,7 m) ;
- rendu en jeu dans la nef, le couloir et l'arène, passe de gravure comprise.

Reste à faire, et c'est l'étape suivante : régler les racines de mouvement,
les mélanges d'enchaînement et la synchronisation exacte du geste d'attaque
sur la fenêtre de hitbox.
