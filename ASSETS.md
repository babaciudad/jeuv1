# Provenance des assets

Tout ce que porte ce dépôt et que nous n'avons pas fabriqué est listé ici, avec
sa source, son auteur, sa licence, et le chemin du fichier de licence qui le
prouve. Aucune exception : un asset dont on ne sait pas dire la licence ne doit
pas entrer, et n'est pas entré.

Le jeu vise une sortie commerciale. Les licences acceptées sont donc **CC0**,
**CC-BY** (avec attribution), **MIT**, **Apache-2.0** et **Unlicense**. Ont été
refusés — et le détail figure dans les manifestes — CC-BY-NC, CC-BY-SA, les
dépôts sans fichier de licence, et les formats inexploitables (`.blend` seul,
Blender n'étant pas installé dans la chaîne de vérification).

## Les manifestes

| domaine | manifeste | contenu |
|---|---|---|
| modèles 3D | [ASSETS-modeles.md](ASSETS-modeles.md) | végétation, props de métier, oiseaux |
| textures | [ASSETS-textures.md](ASSETS-textures.md) | argile, boue, sel, bois, herbe, ciels |
| audio | [ASSETS-audio.md](ASSETS-audio.md) | vent, eau, pas, gestes, ambiances |

## Le corps humain

`models/humain/` porte un mannequin gréé de 66 os et 162 animations, sous
**CC0 1.0** (voir `models/humain/LICENCE-CC0.md`). C'est lui qui joue le
paludier et les cristallisés. Les vitesses au sol de ses clips de locomotion
sont mesurées, pas estimées : voir `src/presentation/animation/allures.gd` et
`outils/mesurer_pas.gd`.

## Ce qui reste à fabriquer

Les agents de collecte ont signalé ce qu'ils n'ont pas trouvé, et c'est utile :

- **Les roseaux.** C'est la plante du bord d'étier, et c'est le trou du lot. Un
  seul modèle libre porte réellement ce nom. Ce qui est versé sous
  `roseau_grand` / `roseau_jeune` / `jonc_*` est en fait du bambou et du blé
  stylisés : la silhouette tient, l'espèce non.
- **Le manche de la lousse.** La pelle versée fait 95 cm ; une vraie lousse en
  fait quatre à cinq. C'est un étirement, pas une modélisation.
- **Une mouette animée qui soit une mouette.** Le cycle complet vol → plané →
  se poser n'existe que sur un pigeon. Son squelette est générique : y greffer
  un maillage de goéland est le raccourci le plus rentable du lot.
- **Un salorge.** Les modules d'appentis versés font 50 cm ; la grange à sel du
  lore est haute, sombre et sèche, et reste à bâtir.
