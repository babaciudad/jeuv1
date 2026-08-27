# Modèles 3D du marais — végétation, props de métier, oiseaux

Tout est versé dans `models/marais/` et nulle part ailleurs :

| dossier | contenu | fichiers modèles |
|---|---|---|
| `models/marais/vegetation/` | herbe, roseaux, joncs, buissons, souches, arbres morts, bois flotté, billboards | 43 `.glb` + 2 `.obj` + 4 `.png` |
| `models/marais/props/` | outils du paludier, futaille, bois d'œuvre, charroi, appentis | 52 `.glb` |
| `models/marais/faune/` | oiseaux, 12 d'entre eux animés | 26 `.glb` |
| `models/marais/licences/` | les textes de licence recopiés depuis chaque source | 27 fichiers |

**123 modèles, 28 Mo** (`du -sm models/marais` → `28`, textures extraites par l'import Godot
comprises ; les modèles seuls pèsent 18 Mo). Budget annoncé : 90 Mo.

**Import Godot : `./outils/verifier.sh` → `VERIFIER OK : 20 script(s) compilés et typés.`**
L'import passe, aucun fichier n'a été rejeté à ce stade, chaque fichier a son `.import`.

---

## Provenance et licences — une ligne par source

| fichiers versés | provenance (dépôt + chemin d'origine) | auteur | licence | preuve (chemin du fichier de licence) |
|---|---|---|---|---|
| 26 modèles de végétation : `arbre_maigre*`, `bois_flotte_03/04`, `buisson_bas_01..06`, `herbe_plate_*`, `herbe_pousse_01/02`, `herbe_rase_01/02`, `herbe_touffe_01/02`, `jonc_bas/haut`, `roseau_grand/jeune`, `souche_*` | ETdoFresh/kenney.nl (miroir CC0) — `/tmp/hunt/vegetation/kenneymirror/kenney_natureKit_2.1/Models/GLTF format/` | Kenney (Nature Kit 2.1) | CC0 1.0 | `/tmp/hunt/vegetation/kenneymirror/kenney_natureKit_2.1/License.txt` → copié en `models/marais/licences/kenney_naturekit_CC0.txt` |
| 23 modèles : props `appentis_*`, `barriere*`, `caisse`, `caisse_grande`, `caisse_ouverte`, `houe`, `panneau_bois`, `pelle_courte`, `seau`, `tonneau`, `tonneau_ouvert` ; végétation `bois_flotte_01/02`, `herbe_rase_03/04/05`, `herbe_touffe_03`, `tronc_mort` | binhbb2204/map-editor — `/tmp/hunt/props-bois/mapeditor-meta/public/models/kenney_survival-kit/Models/GLB format/` | Kenney (Survival Kit) | CC0 1.0 | `/tmp/hunt/props-bois/mapeditor-meta/public/models/kenney_survival-kit/License.txt` → `licences/kenney_survivalkit_CC0.txt` |
| 11 modèles : props `charrette`, `charrette_haute`, `etal_bois`, `perches`, `pieux`, `planches`, `planches_demi`, `portillon`, `roue_charrette` ; végétation `arbre_tordu_01/02` | binhbb2204/map-editor — `/tmp/hunt/props-bois/mapeditor-meta/public/models/kenney_fantasy-town-kit_2.0/Models/GLB format/` | Kenney (Fantasy Town Kit 2.0) | CC0 1.0 | `.../kenney_fantasy-town-kit_2.0/License.txt` → `licences/kenney_fantasytownkit_CC0.txt` |
| 4 props : `pelle_plate`, `cloture_basse`, `cloture_cassee`, `bois_debris` | `/tmp/hunt/registres/kenney-meta/kenney_graveyardkit_3/Models/GLTF format/` | Kenney (Graveyard Kit 3) | CC0 1.0 | `/tmp/hunt/registres/kenney-meta/kenney_graveyardkit_3/License.txt` → `licences/kenney_graveyardkit_CC0.txt` |
| 10 props : `ballot_toile`, `bois_tas`, `caisse_bois`, `panier_01`, `panier_02`, `planche`, `planches_tas`, `poutre`, `sac_farine`, `sac_toile` | `/tmp/hunt/props-bois/tilecontrols-meta/assets/threeDimensionalResources/KayKit_ResourceBits_1.0_SOURCE/Assets/gltf/` | Kay Lousberg (KayKit Resource Bits 1.0) | CC0 1.0 | `.../KayKit_ResourceBits_1.0_SOURCE/License.txt` → `licences/kaykit_resourcebits_CC0.txt` |
| 10 props : `rateau`, `rateau_a_main`, `pelle`, `tonneau_bois`, `panier_osier`, `seau_bois`, `pieu`, `poteau`, `echelle`, `fagot` | m3-org/base-meshes — `/tmp/hunt/registres/base-meshes/models/<nom>/<nom>.glb` | thebasemesh.com, converti par m3-org | CC0 1.0 | `/tmp/hunt/registres/base-meshes/LICENSE` → `licences/thebasemesh_CC0.txt` |
| 3 props : `brouette`, `brouette_vide`, `fourche` | `/tmp/hunt/props-bois/kayfa-meta/media/3D_Assets/KayKit_Mystery_Series6/12 - June 2026 - Farmers/gltf/` | Kay Lousberg (KayKit Mystery Monthly S6, Farmers) | CC0 1.0 | `.../KayKit_Mystery_Series6/LICENSE.txt` → `licences/kaykit_farmers_CC0.txt` |
| 3 arbres morts : `arbre_mort_petit/moyen/grand` | `/tmp/hunt/props-bois/KayKit-Halloween-Bits-1.0/addons/kaykit_halloween_bits/Assets/gltf/` | Kay Lousberg (KayKit Halloween Bits 1.0) | CC0 1.0 | `.../kaykit_halloween_bits/Assets/LICENSE.txt` → `licences/kaykit_halloweenbits_CC0.txt` |
| 5 modèles : `roseau_touffe`, `herbe_billboard_01..04` | ToxSam/cc0-models-Polygonal-Mind, copies locales dans `/tmp/hunt/vegetation/keep/pm-veg/` (`tomb-chaser-2__Reed_Art.glb`, `tomb-chaser-2__Grass01/02_Art.glb`, `MomusPark__Grass_01_a/b.glb`) | Polygonal Mind | CC0 1.0 | `/tmp/hunt/vegetation/toxsam/LICENSE` + champ `"license": "CC0"` des projets `pm-tomb-chaser-2` et `pm-momuspark` dans `/tmp/hunt/vegetation/toxsam/data/projects.json` → `licences/polygonalmind_registre_CC0.txt` et `licences/polygonalmind_projets_CC0.json` |
| 2 brins d'herbe pour MultiMesh : `brin_herbe_haut.obj`, `brin_herbe_bas.obj` | `/tmp/hunt/vegetation/godotgrass/assets/grass/grass_high.obj`, `grass_low.obj` | Ethan Truong | MIT | `/tmp/hunt/vegetation/godotgrass/LICENSE` → `licences/godotgrass_MIT.txt` |
| 4 textures de billboard d'herbe : `billboard_herbe_01/02/03.png`, `billboard_herbe_buisson.png` | `/tmp/hunt/vegetation/nobiax/grass01.png`, `grass02.png`, `grass03.png`, `grassbush.png` | Nobiax / Yughues | CC0 1.0 | `/tmp/hunt/vegetation/nobiax/readme.txt` → `licences/nobiax_CC0.txt` |
| 1 oiseau animé : `echassier_vol` (cigogne) | `/tmp/hunt/oiseaux/threejs_birds/Stork.glb` (dépôt three.js, `examples/models/gltf/`) | three.js authors | MIT | `/tmp/hunt/oiseaux/threejs_LICENSE.txt` → `licences/threejs_MIT.txt` |
| 1 oiseau animé : `oie_nage` | `/tmp/hunt/oiseaux/keep_jam83/SK_goose.glb` (Godot Wild Jam 83) | Team Happy Cat | MIT | `/tmp/hunt/oiseaux/keep_jam83/LICENSE` → `licences/jam83_oie_MIT.txt` |
| 1 oiseau animé : `oiseau_marche` | `/tmp/hunt/oiseaux/localagents_birds/bird.glb` | Kenney (Cube Pets), redistribué par le projet local-agents | CC0 1.0 (modèle) / MIT (dépôt) | `/tmp/hunt/oiseaux/localagents_birds/ATTRIBUTION.md` (« Kenney — Cube Pets … License: CC0 ») + `LICENSE_MIT_local-agents.txt` → `licences/localagents_ATTRIBUTION.md`, `licences/localagents_MIT.txt` |
| 14 oiseaux statiques : `aigrette`, `busard_des_roseaux`, `canard`, `canard_colvert`, `corbeau`, `echasse`, `goeland`, `goeland_planeur`, `grande_aigrette`, `heron`, `heron_gris`, `mouette_planeur`, `mouette_posee`, `oie_posee` | `/tmp/hunt/oiseaux/poly_birds/` (archive Poly by Google via poly.pizza) | Poly by Google | CC-BY 3.0 | `/tmp/hunt/oiseaux/poly_birds/LICENSE_CC-BY-3.0.md` + crédit par modèle dans `ATTRIBUTION.txt` → `licences/poly_CC-BY-3.0.md`, `licences/poly_ATTRIBUTION.txt` |
| 1 oiseau animé : `mouette_vol` | `/tmp/hunt/oiseaux/sketchfab_seagull/scene.gltf` — « Low-Poly Seagull (with Animation & Rigged) » | simonaskLDE (Sketchfab) | CC-BY 4.0 | `/tmp/hunt/oiseaux/sketchfab_seagull/license.txt` → `licences/sketchfab_seagull_simonaskLDE_CC-BY-4.0.txt` |
| 1 oiseau animé : `pigeon_vol` | `/tmp/hunt/oiseaux/sketchfab_birds/pigeon/scene.gltf` — « Animated Bird, Pigeon » | dudecon (Sketchfab) | CC-BY 4.0 | `.../pigeon/license.txt` → `licences/sketchfab_pigeon_CC-BY-4.0.txt` |
| 1 vol animé : `mouettes_troupe` | `/tmp/hunt/oiseaux/sketchfab_birds/seagulls_flock/scene.gltf` — « Seagulls animated » | vicente betoret ferrero / deathcow (Sketchfab) | CC-BY 4.0 | `.../seagulls_flock/license.txt` → `licences/sketchfab_seagulls_flock_CC-BY-4.0.txt` |
| 1 oiseau animé : `mouette_detaillee` | `/tmp/hunt/oiseaux/sketchfab_birds/dayvable_seagull/seagull.gltf` — « Seagull » | Dayvable (Sketchfab) | CC-BY 4.0 | `.../dayvable_seagull/license.txt` → `licences/sketchfab_dayvable_seagull_CC-BY-4.0.txt` |
| 1 oiseau animé : `oiseau_vol_leger` | `/tmp/hunt/oiseaux/sketchfab_birds/illupo_bird/scene.gltf` — « Bird Flying » | illupo (Sketchfab) | CC-BY 4.0 | `.../illupo_bird/license.txt` → `licences/sketchfab_illupo_bird_CC-BY-4.0.txt` |
| 1 oiseau animé : `oiseau_vol_moyen` | `/tmp/hunt/oiseaux/sketchfab_birds/rukh3d_bird/scene.gltf` — « Bird Flying Animation » | Rukh3D (Sketchfab) | CC-BY 4.0 | `.../rukh3d_bird/license.txt` → `licences/sketchfab_rukh3d_bird_CC-BY-4.0.txt` |
| 1 oiseau animé : `oiseau_vol_simple` | `/tmp/hunt/oiseaux/sketchfab_birds/simple_bird/scene.gltf` — « Simple_Bird » | Nagovandera (Sketchfab) | CC-BY 4.0 | `.../simple_bird/license.txt` → `licences/sketchfab_simple_bird_CC-BY-4.0.txt` |
| 1 oiseau animé : `oiseau_vol_petit` | `/tmp/hunt/oiseaux/sketchfab_birds/sandeep_bird/scene.gltf` — « Flying Bird » | sandeep.s (Sketchfab) | CC-BY 4.0 | `.../sandeep_bird/license.txt` → `licences/sketchfab_sandeep_bird_CC-BY-4.0.txt` |
| 1 oiseau animé : `oiseau_bas_poly` | `/tmp/hunt/oiseaux/sketchfab_birds/tnkii_bird/scene.gltf` — « Low Poly Bird (Animated) » | Charlie Tinley / Tnkii (Sketchfab) | CC-BY 4.0 | `.../tnkii_bird/license.txt` → `licences/sketchfab_tnkii_bird_CC-BY-4.0.txt` |

### Crédits à afficher (obligation CC-BY)

Le CC0 n'exige rien. Les quinze oiseaux CC-BY, si : il faut nommer l'auteur et la licence
quelque part dans le jeu. Le texte exact à recopier est dans `licences/poly_ATTRIBUTION.txt`
(une ligne par modèle Poly) et dans les huit `licences/sketchfab_*.txt`.

---

## Transformation appliquée aux fichiers

Rien n'a été remodélisé. Deux opérations mécaniques, faites par script :

1. **Empaquetage en `.glb` autonome.** Les sources en `.gltf` + `.bin` + textures externes
   (Sketchfab, KayKit, farmers) et les `.glb` Kenney qui pointaient vers un
   `Textures/colormap.png` voisin ont été réécrits en un seul `.glb` avec les images
   embarquées dans le buffer. Plus aucun fichier versé ne dépend d'un chemin relatif.
2. **Nettoyage des noms d'images internes** (minuscules, sans espace ni accent), sinon
   l'importeur Godot recrachait des fichiers comme `mouette_planeur_Gull tex2.png`.

Les `.png` qu'on trouve à côté des `.glb` dans `vegetation/`, `props/` et `faune/` ne sont
pas des copies faites à la main : c'est l'importeur glTF de Godot qui extrait les textures
embarquées. Ils font partie du projet et doivent être commités avec les `.glb`.

---

## Ce qu'il y a dedans, mesuré

Triangles comptés par lecture du chunk JSON de chaque `.glb` ; encombrement mesuré en
appliquant les transformations de nœuds de la scène glTF (pas seulement les `min`/`max`
des accesseurs, qui donnent des chiffres faux sur les exports Sketchfab).

### `vegetation/` — 45 modèles, tous sous 800 triangles

| ce que c'est | fichiers | triangles | hauteur mesurée |
|---|---|---|---|
| herbe rase | `herbe_rase_01..05` | 33 à 144 | 0,14 m (`04`/`05` sont des décalques plats de 1,2 m de côté, hauteur nulle) |
| touffes d'herbe | `herbe_touffe_01..03` | 132 / 224 / 144 | 0,14 – 0,25 m |
| herbe plate, pousses | `herbe_plate_basse/haute`, `herbe_pousse_01/02` | 32 à 84 | 0,24 – 0,68 m |
| **roseaux** | `roseau_touffe`, `roseau_grand`, `roseau_jeune` | 45 / 564 / 276 | **1,79 m** / 0,89 m / 0,55 m |
| joncs | `jonc_haut`, `jonc_bas` | 720 / 360 | 0,33 / 0,53 m |
| buissons bas | `buisson_bas_01..06` | 16 à 104 | 0,17 – 0,36 m |
| souches | `souche_ronde/vieille/haute/carree` | 44 à 120 | 0,20 – 0,67 m |
| arbres tordus par le vent | `arbre_tordu_01/02`, `arbre_maigre`, `arbre_maigre_roux` | 178 / 210 / 228 / 228 | 2,41 / 2,97 / 1,49 m |
| arbres morts | `arbre_mort_petit/moyen/grand` | 184 / 216 / 256 | 2,99 / 4,19 / 5,07 m |
| bois flotté, tronc | `bois_flotte_01..04`, `tronc_mort` | 52 à 200 | couchés, 0,55 à 1,00 m de long |
| billboards texturés | `herbe_billboard_01..04` | 4 / 4 / 4 / 16 | plans de 0,85 à 6,0 m — à redimensionner |
| brins pour MultiMesh | `brin_herbe_haut.obj` (9 tri), `brin_herbe_bas.obj` (**1 tri**) | 9 / 1 | brin de 10 cm |
| textures de billboard | `billboard_herbe_01/02/03.png`, `billboard_herbe_buisson.png` | — | PNG à canal alpha, prêtes pour un quad + `billboard = y-billboard` |

Le plus lourd de toute la végétation est `jonc_haut` à **720 triangles** : la contrainte des
800 tient partout. `brin_herbe_bas.obj` à un seul triangle est le candidat évident pour la
nappe d'herbe rase instanciée sur des kilomètres.

**Échelle.** Les kits Kenney sont bâtis sur une trame de 0,5 m : leurs touffes d'herbe
(0,14–0,25 m) sont déjà à la bonne taille pour une lande rase, mais `roseau_grand` à 0,89 m
demande un `scale` de 2 à 3 pour ressembler à un vrai roseau du bord d'étier.
`roseau_touffe`, lui, sort à 1,79 m : bon du premier coup.

### `props/` — 52 modèles

| priorité demandée | fichiers versés | triangles | taille mesurée |
|---|---|---|---|
| **1. râteau / raclette à long manche (le *las*)** | **`rateau.glb`** | 2 092 | **0,71 × 1,76 × 0,10 m** — manche long, tête large, à l'échelle réelle |
| | `rateau_a_main.glb` | 632 | 0,22 m, râteau à main |
| | `fourche.glb` | 532 | 2,06 m, fourche à long manche |
| **2. pelle plate (la *lousse*)** | **`pelle.glb`** | 2 050 | **0,28 × 0,95 × 0,10 m**, échelle réelle |
| | `pelle_plate.glb` | 134 | lame plate à 0,63 m |
| | `pelle_courte.glb`, `houe.glb` | 124 / 58 | outils Kenney, trame 0,5 m |
| 3. futaille | `tonneau`, `tonneau_ouvert`, `tonneau_bois`, `caisse`, `caisse_grande`, `caisse_ouverte`, `caisse_bois`, `panier_01`, `panier_02`, `panier_osier`, `sac_toile`, `sac_farine`, `ballot_toile`, `seau`, `seau_bois` | 68 à 2 484 | 0,19 à 1,62 m |
| 4. bois d'œuvre | `planche`, `planches`, `planches_demi`, `planches_tas`, `poutre`, `bois_tas`, `pieu`, `pieux`, `perches`, `poteau`, `barriere`, `barriere_haute`, `barriere_passage`, `cloture_basse`, `cloture_cassee`, `portillon`, `echelle`, `fagot`, `bois_debris` | 20 à 3 576 | `echelle` 3,00 m, `planche` 1,50 m, `pieu` 1,24 m |
| 5. charroi | `charrette`, `charrette_haute`, `roue_charrette`, `brouette`, `brouette_vide` | 192 à 1 028 | brouette 2,23 m de long, charrette 1,34 m |
| 6. cabane / appentis (le *salorge* en réduction) | `appentis_ossature`, `appentis_toit`, `appentis_plancher`, `appentis_bache`, `etal_bois` | 80 à 188 | modules de 0,50 m à assembler ; `etal_bois` est un étal couvert d'un seul tenant (1,00 m) |

**Le râteau et la pelle existent, tu n'as pas à les modéliser.** Les deux viennent de
thebasemesh (CC0), sont à l'échelle du monde réel et n'ont pas de texture : matériau
`DefaultMaterial` gris uni, un seul mesh, prêt à recevoir la peinture du jeu. Le manche de
la vraie lousse fait quatre à cinq mètres ; ici il en fait un. C'est un allongement de
manche à faire, pas une modélisation.

**Échelle des props.** Trois familles cohabitent :
thebasemesh à l'échelle réelle (râteau 1,76 m, échelle 3,00 m) ;
Kenney sur trame 0,5 m, à multiplier par ~2 (le tonneau fait 0,34 m de haut) ;
KayKit Resource Bits légèrement surdimensionné, à multiplier par ~0,6 (le sac fait 1,62 m).

### `faune/` — 26 oiseaux, dont 12 animés

Animations lues dans le chunk JSON de chaque `.glb`.

| fichier | triangles | animations mesurées |
|---|---|---|
| **`pigeon_vol.glb`** | 710 | **`BirdRig\|Flapping`, `BirdRig\|Gliding`, `BirdRig\|Landing`, `BirdRig\|Standing Idle`, `BirdRig\|Takeoff`** |
| `oiseau_marche.glb` | 530 | `static`, `idle`, `walk`, `run`, `eat`, `dance`, `gesture-positive`, `gesture-negative` |
| `oie_nage.glb` | 2 224 | `attack`, `default-loop`, `swim-loop` |
| `oiseau_vol_simple.glb` | 1 442 | `Flying_GLTF_created_0`, `Flying` |
| `mouette_vol.glb` | 580 | `ArmatureAction` (battement d'ailes) |
| `mouette_detaillee.glb` | 4 352 | `ArmatureAction.006` |
| `mouettes_troupe.glb` | 796 | `Take 001` — quatre mouettes, 4 squelettes dans un seul fichier |
| `echassier_vol.glb` | 542 | `storkFly_B_` (cigogne, vol par morph/nœuds, sans squelette) |
| `oiseau_vol_leger.glb` | 210 | `ArmatureAction` |
| `oiseau_vol_moyen.glb` | 1 178 | `Armature\|ArmatureAction` |
| `oiseau_vol_petit.glb` | 342 | `Take 001` |
| `oiseau_bas_poly.glb` | 2 268 | `Take 001` |
| 14 statiques : `heron`, `heron_gris`, `aigrette`, `grande_aigrette`, `echasse`, `canard`, `canard_colvert`, `oie_posee`, `mouette_posee`, `goeland`, `mouette_planeur`, `goeland_planeur`, `corbeau`, `busard_des_roseaux` | 296 à 1 026 | aucune |

`pigeon_vol.glb` est la pièce maîtresse : c'est le seul modèle du lot qui porte le cycle
complet *décollage → battement → plané → posé → immobile*. C'est un pigeon, pas une
mouette ; le rig est générique, une mouette peut être greffée dessus. `mouette_planeur` et
`goeland_planeur` sont statiques mais figés **ailes déployées** : parfaits pour un vol
lointain animé par un simple `Node3D` qui tourne.

**Échelles à appliquer.** Aucun de ces oiseaux n'est à l'échelle. Voici la plus grande
dimension mesurée et le facteur pour l'amener à une taille d'oiseau réel :

| fichier | dim. max mesurée (m) | `scale` conseillé |
|---|---|---|
| `aigrette` | 10,02 | 0,065 |
| `busard_des_roseaux` | 3,69 | 0,30 |
| `canard` | 2,58 | 0,23 |
| `canard_colvert` | 2,55 | 0,24 |
| `corbeau` | 50,08 | 0,010 |
| `echasse` | 9,99 | 0,040 |
| `echassier_vol` | 196,80 | 0,0091 |
| `goeland` | 65,38 | 0,0092 |
| `goeland_planeur` | 88,47 | 0,016 |
| `grande_aigrette` | 4,63 | 0,22 |
| `heron` | 13,30 | 0,075 |
| `heron_gris` | 176,98 | 0,0057 |
| `mouette_detaillee` | 2,03 | 0,69 |
| `mouette_planeur` | 88,47 | 0,015 |
| `mouette_posee` | 67,23 | 0,0089 |
| `mouette_vol` | 29,39 | 0,048 |
| `mouettes_troupe` | 15,24 | 0,39 (la volée entière) |
| `oie_nage` | 1,11 | 0,72 |
| `oie_posee` | 76,94 | 0,010 |
| `oiseau_bas_poly` | 9,31 | 0,064 |
| `oiseau_marche` | 2,20 | 0,14 |
| `oiseau_vol_leger` | 5,49 | 0,11 |
| `oiseau_vol_moyen` | 0,54 | 1,1 |
| `oiseau_vol_petit` | 0,56 | 1,1 |
| `oiseau_vol_simple` | 1,05 | 0,57 |
| `pigeon_vol` | 4,37 | 0,15 |

---

## Ce qui a été écarté, et pourquoi

| écarté | pourquoi |
|---|---|
| `/tmp/hunt/oiseaux/Flying-Bird/seagull-2.glb` — mouette animée, 1 182 tri, animations `flap`, `planer`, `planer 2` | **Aucun fichier de licence.** Le `README.md` du dépôt contient une seule ligne, « # Flying-Bird ». C'était le meilleur candidat du lot : une mouette avec un clip de plané déjà nommé en français. Licence absente = pas versé. |
| `/tmp/hunt/oiseaux/misc_birds/httyd_seagull.glb`, `jeanmilost_seagull.glb` | Le dossier `misc_birds/` n'a aucun fichier de licence. `httyd_` renvoie de surcroît à une licence de film. |
| `/tmp/hunt/vegetation/re-vegetation/` (bush01, arbres, textures) | `cc-by-sa.txt` à la racine : CC-BY-SA, contaminant, exclu par la consigne. |
| `/tmp/hunt/vegetation/kiwiograss/graas_shader/objs/grass.obj` (7 tri) | Aucun `LICENSE` dans le dépôt. |
| `/tmp/hunt/vegetation/m3retro/Nature/`, `/tmp/hunt/registres/retro3d/Tools/shovel.blend` | Uniquement des `.blend`. Blender n'est pas installé, et la consigne interdit de verser un `.blend` seul. |
| `/tmp/hunt/props-bois/LowPolyMedievalAssetsPack/` | `.blend` et `.fbx` seulement, pas de fichier de licence. |
| `/tmp/hunt/vegetation/nobiax/` : les modèles `.obj` (shrub, parviflora, bush_06, tiny_weed) | CC0 vérifié, mais les `.obj` n'ont **pas de `.mtl`** — la texture ne se rattacherait pas à l'import. Seules les quatre textures de billboard, elles utilisables telles quelles, ont été versées. Écarté aussi parce que `trop_shrub_04` et `palm_*` sont tropicaux. |
| `/tmp/hunt/oiseaux/sketchfab_birds/water_bird/` (« Ice Bird ») | 6 888 triangles et 5 Mo de textures pour un oiseau de glace : mauvais rapport. |
| `/tmp/hunt/oiseaux/sketchfab_birds/low_poly_bird/` | 1 932 tri et **aucune animation** : les 14 statiques Poly font mieux pour moins cher. |
| Tout le tropical et le conifère de montagne du Nature Kit : `tree_palm*`, `tree_pine*`, `cactus_*`, `crop_melon`, `crop_pumpkin`, `hanging_moss`, `lily_*` | Hors sujet sur une lande salée bretonne. |
| Les packs entiers : Nature Kit (329 modèles), Fantasy Town Kit (167), Survival Kit (80), base-meshes (901), poly_birds (87) | Seuls les modèles utiles ont été copiés, jamais le pack. 123 fichiers retenus sur environ 1 900 examinés. |
| `/tmp/hunt/vegetation/toxsam/` | Registre JSON, zéro `.glb` (`find … -name '*.glb' \| wc -l` → `0`). Sert de preuve de licence pour les modèles Polygonal Mind, pas de source de fichiers. |

---

## Ce qui manque encore et qu'il faudra fabriquer

1. **Un vrai roseau de bord d'étier, en plusieurs variantes.** Un seul modèle du lot est
   nommé « reed » par son auteur : `roseau_touffe.glb` (Polygonal Mind, 45 tri, 1,79 m).
   `roseau_grand` et `roseau_jeune` sont en réalité les **bambous** du Nature Kit de Kenney
   (`crops_bambooStageA/B`) et `jonc_haut` / `jonc_bas` sont son **blé**
   (`crops_wheatStageA/B`). La silhouette tient — tiges verticales, épis — mais ce ne sont
   pas des roseaux, et c'est la plante la plus importante du décor. Trois ou quatre
   variantes de *Phragmites* à faire.
2. **Le manche de la lousse.** `pelle.glb` fait 0,95 m ; la vraie lousse en fait quatre à
   cinq. Étirer le manche, ou en rebâtir un.
3. **Une mouette animée qui soit une mouette.** Le cycle complet vol/plané/posé n'existe
   que sur `pigeon_vol.glb`. Les mouettes versées ont soit un seul clip de battement
   (`mouette_vol`, `mouette_detaillee`), soit rien. Le rig du pigeon est générique et peut
   accueillir un maillage de goéland argenté.
4. **Un salorge.** `appentis_*` sont quatre modules Kenney de 0,50 m et `etal_bois` un étal
   de marché. On peut monter un abri crédible avec, mais ce n'est pas un salorge.
5. **Un sac de sel.** `sac_toile` est un sac à gemmes KayKit et `sac_farine` un sac de
   farine ; il n'existe nulle part dans `/tmp/hunt/` de sac de sel, ni de mulon.
6. **Aucune texture propre au jeu.** Les modèles thebasemesh (râteau, pelle, tonneau,
   échelle, panier, seau, pieu, poteau, fagot) sont en gris uni sur un unique
   `DefaultMaterial`. Les modèles Kenney et KayKit partagent chacun un atlas de couleurs
   qui n'a rien de breton. Une passe de matériaux est à prévoir, et elle est facile : un
   seul matériau par famille.
7. **Aucun LOD, aucun collider.** Tout est en maillage brut.
