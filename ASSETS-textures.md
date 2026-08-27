# ASSETS — Textures de sol et ciels

Famille « Textures de sol et ciels » pour *Le Sel de Guérande*.
Destination : `textures/`. Tout est versé en PNG (albédo / normale / rugosité),
sauf le ciel en `.hdr`.

**Mesures** (commandes réellement lancées) :

- `du -sm textures/` → **42 Mo** (budget : 45 Mo)
- `find textures -name '*.png' | wc -l` → **27**
- `find textures -name '*.hdr' | wc -l` → **1**
- `find textures -name '*.import' | wc -l` → **28** (générés par Godot, un par asset)
- `./outils/verifier.sh` → `VERIFIER OK : 20 script(s) compilés et typés.` — l'import passe, zéro erreur.

Toutes les images sont **1024×1024**, sauf `sable_fin_*` qui est **512×512**
(résolution native de la source, non ré-agrandie). Redimensionnement fait avec
Pillow 12.3.0 (LANCZOS), installé pour l'occasion via `pip3 install Pillow`.

Les normales sont en convention **OpenGL** (+Y vers le haut), celle de Godot.
Les rugosités sont versées en niveaux de gris 8 bits (mode `L`) pour le poids.

---

## Le tableau des sources

| fichiers versés | provenance (dépôt + chemin d'origine) | auteur | licence | preuve (chemin du fichier de licence) |
|---|---|---|---|---|
| `argile_albedo.png`, `argile_normale.png`, `argile_rugosite.png` | `spimort/TerraBrush` — `demo/Assets/cc0_textures/dirt_ground_0013_1k_zW2rzw/` (`ground_0013_color_1k.jpg`, `ground_0013_normal_opengl_1k.png`, `ground_0013_roughness_1k.jpg`) | spimort (dépôt) ; texture d'origine ambientCG / cgbookcase | MIT (dépôt) + CC0 (dossier `cc0_textures/`) | `/tmp/hunt/textures-ciel/meta_spimort_TerraBrush/LICENSE` |
| `boue_craquelee_albedo.png`, `boue_craquelee_normale.png`, `boue_craquelee_rugosite.png` | `TokisanGames/Terrain3D` — `project/demo/assets/textures/rock023_alb_ht.png` + `rock023_nrm_rgh.png` (ambientCG **Rock023**) | ambientCG | CC0 1.0 Universal | `/tmp/hunt/eau-shaders/TokisanGames_Terrain3D/project/demo/assets/textures/asset_licenses.txt` — « All ambientCG assets are provided under the Creative Commons CC0 1.0 Universal License » + `https://ambientcg.com/view?id=Rock023` |
| `vase_albedo.png`, `vase_normale.png`, `vase_rugosite.png`, `herbe_rase_albedo.png`, `herbe_rase_normale.png`, `herbe_rase_rugosite.png` | `Zylann/godot_hterrain_demo` — `addons/zylann.hterrain_demo/textures/ground/src/sand/` et `.../src/grass/` | cc0textures.com (ambientCG) ; dépôt de Marc Gilleron (Zylann) | CC0 (textures) ; MIT (code du greffon) | `/tmp/hunt/textures-ciel/hterrain-demo/README.md` ligne 10 — « Textures are from http://cc0textures.com/home » ; `/tmp/hunt/textures-ciel/hterrain-demo/addons/zylann.hterrain/LICENSE.md` |
| `sel_croute_*`, `sel_grains_*`, `planches_grises_*`, `bois_use_*` (12 fichiers) | `Calinou/godot-cmvalley` — `ambientcg/Concrete035_2K_*`, `Gravel011_2K_*`, `Planks012_2K_*`, `Planks014_2K_*` (canaux `Color`, `Normal`, `Roughness`) | ambientCG ; dépôt de Hugo Locurcio | CC0 (ambientCG) ; MIT (dépôt) | `/tmp/hunt/textures-ciel/meta_Calinou_godot-cmvalley/LICENSE.md` + `README.md` l. 49-52 (le MIT s'applique par défaut ; la réserve « licences propriétaires » ne vise que le dossier `cmvalley/`, pas `ambientcg/`) |
| `sable_fin_albedo.png`, `sable_fin_normale.png`, `sable_fin_rugosite.png` | `Brandt-J/WaterShader` — `Textures/Sand_512.jpg`, `Sand_normal_512.jpg`, `Sand_rough_ao_512.jpg` (canal R = rugosité) | Josef Brandt | MIT | `/tmp/hunt/eau-shaders/Brandt-J_WaterShader/LICENSE` |
| `ciel_couchant.hdr` | `godotengine/godot-demo-projects` — `compute/texture/assets/polyhaven/industrial_sunset_puresky_2k.hdr` | Poly Haven | CC0 1.0 Universal | `/tmp/hunt/eau-shaders/godot-demo-projects/compute/texture/README.md` l. 33-34 — « Files in the `polyhaven/` folder are downloaded from https://polyhaven.com/a/industrial_sunset_puresky and are licensed under CC0 1.0 Universal » |

---

## Ce qu'il y a, matière par matière

| matière | fichier | ce que c'est | pour quoi dans le jeu |
|---|---|---|---|
| **argile** | `argile_*` | argile brun-gris humide, grumeleuse | le sol de tout le jeu : talus de 80 cm, fond des bassins |
| **boue craquelée** | `boue_craquelee_*` | croûte fendillée couleur argile sèche | œillets et adernes qui sèchent |
| **vase** | `vase_*` | limon olive-gris très fin, presque lisse | fond de la vasière et du cobier, sous l'eau |
| **sel (croûte)** | `sel_croute_*` | croûte blanche marbrée, grenue | la cristallisation dans l'œillet, les bords de bassin |
| **sel (grains)** | `sel_grains_*` | granulat gris pâle serré | les tas de sel gris, la ladure |
| **herbe rase** | `herbe_rase_*` | herbe pelée sur terre nue, plaques | la lande autour du marais, les chemins |
| **planches grises** | `planches_grises_*` | planches grises usées, mousse dans les joints | passerelles, ponts sur les étiers |
| **bois usé** | `bois_use_*` | planches brunes délavées, algue verte dans les joints | vannes, trappes, bois au contact de l'eau |
| **sable fin** | `sable_fin_*` | sable ridé par le vent (512 natif) | les bords sableux, l'entrée de l'étier |
| **ciel** | `ciel_couchant.hdr` | ciel pur au soleil bas, nuages, horizon plat — 2048×1024, 4,3 Mo | l'été breton au couchant ; à mettre en `PanoramaSkyMaterial` |

### Retouches colorimétriques — à savoir

Deux albédos ont été **recolorés** (dérivés autorisés : sources CC0). Les normales
et rugosités sont intactes.

- `argile_albedo.png` : la source `ground_0013` est une argile **rouille/latérite**,
  franchement orange. Désaturée à 50 %, refroidie et assombrie (gain 0,88) pour
  donner une argile brun-gris humide de marais breton.
- `boue_craquelee_albedo.png` : la source est **ambientCG Rock023**, une dalle de
  pierre **grise** fissurée. Teintée chaud (×1,10 / 0,97 / 0,80) pour lire comme
  de la terre sèche fendillée. **Honnêteté :** ce n'est pas un scan de vraies
  fentes de dessiccation polygonales — la fissuration est plutôt stratifiée,
  linéaire. C'est ce qui se rapprochait le plus dans tout `/tmp/hunt`. Si la
  boue craquelée compte vraiment, il faudra la fabriquer.

Deux textures ont aussi été **remises au carré** depuis un ratio bâtard de la
source, pour être posables avec un UV carré par défaut :
`sel_croute_*` (2048×1024 → 1024×1024) et `herbe_rase_*` (1024×957 → 1024×1024,
étirement de 7 %, invisible).

---

## Rejets, et pourquoi

**Licence :**

- `Feeflak/4Form` (`/tmp/hunt/textures-ciel/meta_Feeflak_4Form/`) — jolies textures
  `SurfaceGround`, `Moss`, `SurfaceRock`, mais **GPL-3.0** sur les assets.
  Preuve : `/tmp/hunt/textures-ciel/meta_Feeflak_4Form/LICENSE`. Écarté.
- `gdquest-demos/godot-shaders` — contient pourtant les vraies ambientCG
  `Ground039_1K` et `Snow004_1K`, mais le dépôt déclare ses assets d'art en
  **CC-BY-NC-SA 4.0**. Preuve : `/tmp/hunt/eau-shaders/gdquest-demos_godot-shaders/LICENSE`
  (« Art assets (image textures and 3D models) are CC-BY-NC-SA 4.0 »). Écarté.
- `registres/retro3d` — `Ground/Materials/` a pourtant exactement ce qui manque :
  `dirt_muddy_1.jpg`, `dirt_0.png`, `grass_dead_01..03.png`. Mais **aucun fichier
  de licence**, seulement une phrase du README (« no attribution, share-alike, or
  such required ») et une liste de sources itch.io qui **ne couvre pas** la section
  Ground. Doute → écarté.
- `Calinou/godot-cmvalley` dossier `cmvalley/` — « various proprietary licenses »
  d'après le README. Seul `ambientcg/` a été pris.

**Poids :**

- `Flarkk/Godot-Water-Shader-Prototype` — `textures/sky/evening_01.hdr`, un vrai
  ciel du soir, mais **25 Mo** (`ls -la`), au-dessus de la limite de 8 Mo. Écarté.

**Contenu (licence pourtant bonne) :**

- `pmndrs/assets` (CC0) — `sunset.hdr` et `dawn.hdr`, 1,5 Mo chacun, bien dans le
  budget. Mais après décodage et rendu : `sunset` est la **place Saint-Marc à
  Venise** (palais, campanile), `dawn` est une **montagne désertique**. Inutilisables
  pour un marais plat et ouvert. Écartés — d'où **un seul ciel** et non deux.
- ambientCG `Ground041` / `Ground042` (litière de feuilles de forêt), `Snow002`
  (blanc bleuté quasi vide), `WoodFloor030` (canevas orange cartoon),
  TerraBrush `sand_ground_0043` (aplat orange, normale en gros blobs sans grain) —
  écartés sur le rendu, pas sur la licence.

---

## Notes d'intégration Godot

- Les 28 `.import` sont générés et l'import passe. Aucun fichier n'a dû être retiré.
- `compress/normal_map=0` (= *détecter*) sur toutes les images : Godot bascule
  automatiquement en compression normale quand la texture est branchée sur le
  slot **Normal Map** d'un `StandardMaterial3D`. Rien à régler à la main.
- Pour le ciel : `Sky` → `PanoramaSkyMaterial` → `Panorama` = `res://textures/ciel_couchant.hdr`.
  Godot 4 sait aussi faire un `ProceduralSkyMaterial` correct ; l'HDRI est un bonus.
- Aucun autre dossier du dépôt n'a été touché. Rien n'a été commité.
