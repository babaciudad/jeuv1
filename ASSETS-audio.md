# ASSETS — Sons du marais

Famille « Sons du marais » pour *Le Sel de Guérande*.
Destination : `audio/`, en quatre sous-dossiers — `ambiance/`, `eau/`, `pas/`, `gestes/`.
Tout est versé en **`.ogg` Vorbis**, rien en `.wav`.

**Mesures** (commandes réellement lancées) :

- `du -sm audio/` → **13 Mo** (budget : 35 Mo) — dont **12,29 Mo** de `.ogg`, le reste en `.import`
- `find audio -name '*.ogg' | wc -l` → **80**
- `find audio -name '*.import' | wc -l` → **80** (générés par Godot, un par asset)
- `./outils/verifier.sh` → `VERIFIER OK : 25 script(s) compilés et typés.` — l'import passe, zéro erreur.

Réparti par dossier (`du -sk --exclude='*.import'`) : `ambiance/` 7 fichiers → 8960 Ko,
`eau/` 18 → 2964 Ko, `pas/` 22 → 220 Ko, `gestes/` 33 → 604 Ko.
Les quatre cinquièmes du poids sont dans les sept nappes d'ambiance ; les 75 sons
ponctuels tiennent ensemble dans 824 Ko.

## Conventions de fabrication

Aucun fichier n'est une copie brute : tout a été redécodé et réencodé avec
**libsndfile 1.2.2** via `soundfile` 0.14 (installé pour l'occasion, `pip install soundfile`),
selon deux régimes.

- **Nappes et boucles** (`*_boucle.ogg`, `eau_vanne*.ogg`) : **stéréo conservée**
  (sauf les deux `eau_vanne*` qui sont mono, voir plus bas), segment découpé dans la
  source, **bouclage par fondu croisé** de 0,8 à 2,5 s (la queue est remixée sur la
  tête, donc le fichier boucle sans clic), crête normalisée à −3 dBFS,
  `compression_level` 0,45. Durées entre **36 et 94 s**, comme demandé.
- **Sons ponctuels** (pas, gestes, gouttes, éclaboussures) : **repliés en mono** —
  c'est ce que réclame `AudioStreamPlayer3D` pour se spatialiser correctement —
  silences de tête et de queue rognés, crête normalisée à −2 ou −3 dBFS avec un
  **gain plafonné à +20 dB** (les sons d'OpenClonk sont masterisés très bas ; sans
  plafond on remonterait aussi leur plancher de bruit), micro-fondus de 4 ms aux
  deux bouts, `compression_level` 0,4. Aucun ne dépasse **3,7 s ni 55 Ko**.

Les treize fichiers de boucle ont `loop=true` dans leur `.import` (les autres restent
à `loop=false`). Rien d'autre n'a été touché dans le dépôt.

Deux fichiers sont des **dérivés** et pas de simples extraits, c'est dit ici pour que
personne ne s'y trompe :

- `ambiance/vent_herbes_boucle.ogg` — segment 100–164 s de la source, **filtré
  passe-haut à 700 Hz** (FFT, pente d'ordre 2) pour ne garder que le sifflement et le
  froissement, et laisser la place au grave de `vent_plaine_boucle.ogg` en dessous.
- `ambiance/vent_souffle_bas_boucle.ogg` — la source ne fait que 14,8 s ; elle est
  **répétée 3 fois** avec fondus croisés de 1,2 s pour atteindre les 41 s exigées.

Vérifications faites sur les fichiers **de sortie**, pas sur les sources : durée,
taille, fréquence d'échantillonnage, nombre de canaux, crête, RMS, centroïde
spectral et variation d'enveloppe. C'est ce dernier couple qui a servi à nommer les
vents : `vent_plaine` est grave et régulier (centroïde 753 Hz, cv d'enveloppe 0,22),
`vent_rafale` souffle par à-coups (2371 Hz, cv 0,71), `vent_herbes` est le seul aigu
(3943 Hz, 53 % de son énergie entre 400 et 2000 Hz).

---

## Le tableau des sources

| fichiers versés | provenance (dépôt + chemin d'origine) | auteur | licence | preuve (chemin du fichier de licence) |
|---|---|---|---|---|
| `ambiance/vent_plaine_boucle.ogg`, `ambiance/oiseaux_marais_boucle.ogg`, `eau/chute_bassin_01..03.ogg`, `eau/goutte_01..02.ogg`, `pas/pas_terre_seche_01..05.ogg`, `gestes/pelletage_01..05.ogg`, `gestes/grincement_bois_04..06.ogg`, `gestes/choc_sourd_03..04.ogg`, `gestes/impact_mat_01..04.ogg`, `gestes/souffle_01.ogg` (**27 fichiers**) | `openclonk/openclonk` — `planet/Sound.ocg/` : `Environment.ocg/WindLoop.ogg`, `Environment.ocg/BirdsLoop.ogg`, `Liquids.ocg/Splash1..3.wav`, `Liquids.ocg/Waterdrop1..2.wav`, `Clonk.ocg/Movement.ocg/StepHard1..5.ogg`, `Clonk.ocg/Action.ocg/Dig.ocg/Dig1..5.wav`, `Hits.ocg/Materials.ocg/Wood.ocg/WoodCreak1..3.ogg` + `DullWoodHit1..2.ogg`, `Hits.ocg/SoftHit1..2.ogg` + `OrganicHit1..2.ogg`, `Clonk.ocg/Action.ocg/Breathing.wav` | The OpenClonk Team — son et musique : David Oerther (ala), Martin Strohmeier (K-Pone) ; crédits complets dans `Credits.txt` | **CC BY** (Creative Commons Attribution, texte intégral, sans clause ShareAlike : `grep -c ShareAlike` → 0) — couvre le dossier `planet/`, c'est-à-dire les données du jeu ; le code est en ISC | `/tmp/hunt/audio/openclonk-sounds/planet/COPYING` (copie aussi en `/tmp/hunt/audio/oc_planet_COPYING.txt`) ; auteurs dans `/tmp/hunt/audio/openclonk-sounds/Credits.txt` l. 24-26 |
| `ambiance/vent_rafale_boucle.ogg`, `ambiance/vent_herbes_boucle.ogg` | `Muges/ambientsounds` — `wind.ogg` (à l'origine freesound.org/people/felix.blume/sounds/139337/) | felix.blume | **CC0** | `/tmp/hunt/audio/ambientsounds/readme.md` — « Wind by felix.blume (CC0) » ; confirmé par les tags Vorbis du fichier lui-même : `copyright=CC0`, `artist=felix.blume` |
| `eau/eau_vanne.ogg`, `eau/eau_vanne_filet.ogg` | `Muges/ambientsounds` — `stream.ogg` (à l'origine freesound.org/people/mystiscool/sounds/7138/) | mystiscool | **CC BY** | `/tmp/hunt/audio/ambientsounds/readme.md` — « Stream by mystiscool (CC BY) » ; confirmé par les tags Vorbis : `copyright=CC BY`, `artist=mystiscool` |
| `ambiance/vent_souffle_bas_boucle.ogg` | `rafaelmardojai/blanket` — `data/resources/sounds/wind.ogg` (freesound.org/people/felix.blume/sounds/217506/) | felix.blume, montage Porrumentzio | **CC0** | `/tmp/hunt/audio/blanket/SOUNDS_LICENSING.md` — ligne « Wind \| felix.blume \| Porrumentzio \| CC0 » |
| `ambiance/bord_de_mer_lointain_boucle.ogg` | `rafaelmardojai/blanket` — `data/resources/sounds/waves.ogg` (freesound.org/people/Luftrum/sounds/48412/) | Luftrum, montage Porrumentzio | **CC BY** | `/tmp/hunt/audio/blanket/SOUNDS_LICENSING.md` — ligne « Waves \| Luftrum \| Porrumentzio \| CC BY » |
| `ambiance/oiseaux_lointains_boucle.ogg` | `rafaelmardojai/blanket` — `data/resources/sounds/birds.ogg` (freesound.org/people/kvgarlic/sounds/156826/) | kvgarlic, montage Porrumentzio | **CC0** | `/tmp/hunt/audio/blanket/SOUNDS_LICENSING.md` — ligne « Birds \| kvgarlic \| Porrumentzio \| CC0 » |
| `eau/clapot_leger_boucle.ogg` | `rafaelmardojai/blanket` — `data/resources/sounds/boat.ogg` (freesound.org/people/Falcet/sounds/439365/) | Falcet, montage Porrumentzio | **CC0** | `/tmp/hunt/audio/blanket/SOUNDS_LICENSING.md` — ligne « Boat \| Falcet \| Porrumentzio \| CC0 » |
| `eau/ruissellement_fin_boucle.ogg` | `rafaelmardojai/blanket` — `data/resources/sounds/stream.ogg` (freesound.org/people/gluckose/sounds/333987/) | gluckose | **CC0** | `/tmp/hunt/audio/blanket/SOUNDS_LICENSING.md` — ligne « Stream \| gluckose \| - \| CC0 » |
| `eau/ruissellement_boucle.ogg`, `eau/eclaboussure_01..05.ogg`, `pas/pas_eau_04..06.ogg` (**9 fichiers**) | `lavenderdotpet/CC0-Public-Domain-Sounds` — `40-cc0-water-splash-slime-sfx/` : `loop_water_02.ogg`, `splash_02/03/06/08/15.ogg`, `splash_09/10/14.ogg` | non nommé dans le dépôt (pack agrégé, versé sous CC0 par le dépôt) | **CC0 1.0 Universal** | `/tmp/hunt/audio/CC0-Public-Domain-Sounds/LICENSE` |
| `eau/eau_peu_profonde_boucle.ogg`, `pas/pas_eau_01..03.ogg` | `lavenderdotpet/CC0-Public-Domain-Sounds` — `100-cc0-sfx-2/` : `sfx100v2_loop_water_02.ogg`, `sfx100v2_footstep_wet_01..03.ogg` | idem | **CC0 1.0 Universal** | `/tmp/hunt/audio/CC0-Public-Domain-Sounds/LICENSE` |
| `pas/pas_boue_01..06.ogg` | `lavenderdotpet/CC0-Public-Domain-Sounds` — `25-CC0-mud-sfx/` : `mud_02/04/12/17/18/20.ogg` | idem | **CC0 1.0 Universal** | `/tmp/hunt/audio/CC0-Public-Domain-Sounds/LICENSE` |
| `gestes/effort_01..04.ogg` | `lavenderdotpet/CC0-Public-Domain-Sounds` — `80-CC0-creature-sfx-2/human_01..04.ogg` | idem | **CC0 1.0 Universal** | `/tmp/hunt/audio/CC0-Public-Domain-Sounds/LICENSE` |
| `gestes/souffle_02.ogg` | `lavenderdotpet/CC0-Public-Domain-Sounds` — `80-CC0-creature-SFX/breath.ogg` | idem | **CC0 1.0 Universal** | `/tmp/hunt/audio/CC0-Public-Domain-Sounds/LICENSE` |
| `pas/pas_terre_herbe_01..05.ogg` | `lavenderdotpet/CC0-Public-Domain-Sounds` — `kenney_impactsounds/Audio/footstep_grass_000..004.ogg` | Kenney (kenney.nl) | **CC0** | `/tmp/hunt/audio/CC0-Public-Domain-Sounds/kenney_impactsounds/License.txt` — « License: (Creative Commons Zero, CC0) » |
| `gestes/grincement_bois_01..03.ogg` | `lavenderdotpet/CC0-Public-Domain-Sounds` — `kenney_rpgaudio/Audio/creak1..3.ogg` | Kenney Vleugels (kenney.nl) | **CC0** | `/tmp/hunt/audio/CC0-Public-Domain-Sounds/kenney_rpgaudio/License.txt` — « License (Creative Commons Zero, CC0) » |
| `gestes/raclage_01..02.ogg` | `lavenderdotpet/CC0-Public-Domain-Sounds` — `bb - Japanese Pull Saw (Oct 2021)/Scrape 01.wav`, `Scrape 02.wav` | Ben Burnes (Abstraction) | **CC0** | `/tmp/hunt/audio/CC0-Public-Domain-Sounds/bb - Japanese Pull Saw (Oct 2021)/_README.txt` — « These sounds are public domain (Creative Commons 0) » |
| `gestes/raclage_03..05.ogg`, `gestes/frottement_bois_01..03.ogg`, `gestes/choc_sourd_01..02.ogg` (**8 fichiers**) | `lavenderdotpet/CC0-Public-Domain-Sounds` — `bb - Toolbox Rummaging (Sept 2021)/` : `Big Metal Brush 1..3.wav`, `Drawer Move.wav`, `Close Drawer 1..2.wav`, `Big Thump.wav`, `Good Thunk.wav` | Ben Burnes (Abstraction) | **CC0** | `/tmp/hunt/audio/CC0-Public-Domain-Sounds/bb - Toolbox Rummaging (Sept 2021)/_README.txt` — même phrase |
| `eau/goutte_03..04.ogg` | `lavenderdotpet/CC0-Public-Domain-Sounds` — `bb - Bottle Plops (Apr 2021)/Plop - Airy 1.wav`, `Plop - Airy 2.wav` (rognés à 1,0 et 1,2 s) | Ben Burnes (Abstraction) | **CC0** | `/tmp/hunt/audio/CC0-Public-Domain-Sounds/bb - Bottle Plops (Apr 2021)/_README.txt` — même phrase |

Deux licences seulement, et les deux sont acceptées : **CC0** pour 50 fichiers,
**CC BY** pour 30 — les 27 d'OpenClonk, `bord_de_mer_lointain_boucle.ogg` (Luftrum)
et les deux `eau_vanne*.ogg` (mystiscool).
Les fichiers CC BY imposent une mention dans les crédits du jeu : *OpenClonk Team
(David Oerther, Martin Strohmeier)*, *Luftrum*, *mystiscool*.

---

## Ce qu'il y a, son par son

### `audio/ambiance/` — les nappes à superposer

| fichier | durée | poids | ce que c'est | pour quoi dans le jeu |
|---|---|---|---|---|
| `vent_plaine_boucle.ogg` | 50,6 s | 837 Ko | souffle grave et régulier, 60 % d'énergie sous 400 Hz | le lit permanent. Se joue en continu, volume bas |
| `vent_rafale_boucle.ogg` | 88,0 s | 1538 Ko | vent large qui souffle par à-coups | la couche qui donne le mouvement. À moduler selon l'heure |
| `vent_herbes_boucle.ogg` | 62,0 s | 1156 Ko | sifflement aigu (dérivé, passe-haut 700 Hz) | le froissement dans les salicornes des talus |
| `vent_souffle_bas_boucle.ogg` | 40,9 s | 706 Ko | bourdon grave, plus proche du micro | quatrième couche, pour les moments où le vent tombe |
| `bord_de_mer_lointain_boucle.ogg` | 93,5 s | 1941 Ko | ressac lointain, respiration lente | l'océan derrière la digue, côté étier |
| `oiseaux_lointains_boucle.ogg` | 93,5 s | 2030 Ko | oiseaux épars, très aigus, silences longs | le fond d'été. Un cri toutes les quelques secondes |
| `oiseaux_marais_boucle.ogg` | 36,5 s | 735 Ko | boucle d'oiseaux plus dense | à jouer par bouffées, pas en continu |

### `audio/eau/` — dont le son du premier geste

| fichier | durée | poids | ce que c'est | pour quoi dans le jeu |
|---|---|---|---|---|
| **`eau_vanne.ogg`** | **48,0 s** | **611 Ko** | **filet d'eau qui coule, régulier (cv d'enveloppe 0,10), mono** | **★ le son de la vanne ouverte — le premier geste du tutoriel, et tous les raccourcis ensuite. Mono exprès : il doit se placer dans l'espace, à la vanne** |
| `eau_vanne_filet.ogg` | 54,0 s | 707 Ko | même ruisseau, autre segment, mono | la seconde vanne, pour que deux vannes ouvertes ne soient pas le même son |
| `ruissellement_fin_boucle.ogg` | 42,5 s | 799 Ko | ruissellement fin et aigu | l'eau qui suinte entre deux œillets |
| `ruissellement_boucle.ogg` | 6,2 s | 81 Ko | boucle courte de ruissellement | à empiler sur un point d'eau localisé |
| `clapot_leger_boucle.ogg` | 38,5 s | 474 Ko | clapot contre une coque | le bord des bassins, la vasière |
| `eau_peu_profonde_boucle.ogg` | 7,9 s | 95 Ko | remous d'eau basse | sous les pieds quand on marche dans un œillet |
| `goutte_01..04.ogg` | 0,13–1,20 s | 6–20 Ko | 4 gouttes (2 sèches, 2 avec queue) | égouttement du las, d'un bord de talus |
| `eclaboussure_01..05.ogg` | 0,38–0,57 s | 11–12 Ko | 5 éclaboussures courtes | impacts dans l'eau, coups qui touchent la surface |
| `chute_bassin_01..03.ogg` | 1,20–1,86 s | 18–25 Ko | 3 grosses chutes dans l'eau | le pas de côté raté sur le talus. C'est la punition du terrain |

### `audio/pas/` — quatre surfaces, cinq ou six variantes chacune

| fichiers | durée | poids | ce que c'est | pour quoi dans le jeu |
|---|---|---|---|---|
| `pas_terre_seche_01..05.ogg` | 0,18 s | 6–7 Ko | 5 pas secs sur sol dur | l'argile compactée du talus, en plein été |
| `pas_terre_herbe_01..05.ogg` | 0,10–0,15 s | 5–6 Ko | 5 pas sur végétation rase | les bords enherbés, la salicorne |
| `pas_boue_01..06.ogg` | 0,36–0,57 s | 9–13 Ko | 6 pas dans la boue, bien gluants | la vasière, le fond des bassins vidés |
| `pas_eau_01..06.ogg` | 0,20–0,46 s | 7–11 Ko | 6 pas mouillés (3 pas humides + 3 petites gerbes) | l'eau peu profonde des œillets |

Vingt-deux échantillons pour quatre surfaces : de quoi tirer au sort sans que
la marche cliquette.

### `audio/gestes/` — le travail, qui est aussi le combat

| fichiers | durée | poids | ce que c'est | pour quoi dans le jeu |
|---|---|---|---|---|
| `raclage_01..05.ogg` | 2,39–3,67 s | 38–55 Ko | 5 raclages longs (scie japonaise, brosse métallique) | **le las** : le geste large et lent qui tire le gros sel vers la ladure. Attaque lourde du Saunier, et attaque du cristallisé |
| `frottement_bois_01..03.ogg` | 0,97–2,29 s | 15–30 Ko | 3 frottements bois sur bois, dont un qui finit en butée | le manche qu'on traîne, la lousse qui effleure |
| `pelletage_01..05.ogg` | 0,18–0,45 s | 6–10 Ko | 5 coups de fouille dans la terre | curer un bassin, refaire un talus, la lousse qui charge |
| `grincement_bois_01..06.ogg` | 0,28–1,09 s | 7–21 Ko | 6 grincements (3 francs, 3 très ténus) | la vanne de bois qu'on force, le salorge |
| `choc_sourd_01..04.ogg` | 0,24–1,29 s | 7–17 Ko | 4 chocs mats, sans résonance | la barre à vanne qui cale, un corps qui tombe sur l'argile |
| `impact_mat_01..04.ogg` | 0,17–0,44 s | 6–9 Ko | 4 impacts mous | le las qui touche un cristallisé — pas un choc d'arme, un choc d'outil |
| `effort_01..04.ogg` | 0,51–0,63 s | 10–11 Ko | 4 efforts humains courts | l'attaque lourde, l'esquive, le portage |
| `souffle_01..02.ogg` | 0,47–0,55 s | 9–10 Ko | 2 souffles / reprises de respiration | endurance à zéro, sortie d'esquive |

---

## Ce qui a été écarté, et pourquoi

| écarté | raison |
|---|---|
| `/tmp/hunt/audio/re-sounds/` (Red Eclipse, 239 Mo) — dont `ambience/water.ogg` et `ambience/wind.ogg` | **CC-BY-SA**. `readme.txt` : « In the absence of an explicit license, content is considered to be covered by the CC-BY-SA license » ; `ambience/readme.txt` confirme fichier par fichier (`License: CC-BY-SA4`, `CC-BY-SA3`). Exclu par la règle |
| `/tmp/hunt/audio/CDDA-Soundpacks/` (24 Mo) — `sound/CC-Sounds/plmove/walk_dirt_*`, `walk_grass_*`, `walk_t_gravel_*`, `tool/shovel_1.ogg` | **CC-BY-SA 4.0** (`LICENSE.txt`, première ligne : « Attribution-ShareAlike 4.0 International »). C'était pourtant le meilleur gisement de pas par surface. Exclu quand même |
| `/tmp/hunt/audio/Game-Sound-Effects/` (17 Mo) | **Aucune licence.** Le `README.md` dit seulement « As far as I know, all of these sounds are royalty free and open source ». « As far as I know » n'est pas une licence |
| `/tmp/hunt/audio/CC0-Public-Domain-Sounds/warfork-cc0/` (114 Mo) — `world/ft_step1..3.ogg`, `world/water_in.ogg`, `players/male/gasp.ogg` | Écarté **par prudence**, pas par certitude : le dépôt hôte est bien CC0 (`LICENSE`), mais l'arborescence contient des doublons préfixés `cc0-` (`items/cat/cc0-health_25.ogg`, `misc/cat/cc0-kill.wav`) — ce qui suggère que certains fichiers *non* préfixés viennent du Warsow d'origine et ont été remplacés depuis. Comme j'avais des équivalents sûrs ailleurs, je n'ai rien pris ici |
| `/tmp/hunt/audio/game_sounds/` | Ce ne sont pas des sons mais des fichiers `.bfxrsound` (définitions de synthèse bfxr). Rien à verser |
| `/tmp/hunt/audio/CC0-1.0-Music-subset/` (230 Mo), `BB_2HTC Samples Vol 4` (597 Mo annoncés), `Maximiliano-Stradex-Ambient` | CC0 et donc utilisables, mais c'est de la **musique** et des nappes de synthé, pas des sons du marais. Hors famille |
| `openclonk .../Structures.ocg/HingeCreak1..3.ogg` | CC BY, très bons grincements, mais échantillonnés à **96 kHz** et je n'avais pas de rééchantillonneur propre sous la main. Remplacés par `WoodCreak1..3` (44,1 kHz) |
| tout le pack `kenney_impactsounds` sauf 5 fichiers, tout `25-CC0-mud-sfx` sauf 6, tout `40-cc0-water-splash-slime-sfx` sauf 9 | Règle du poids : on copie les fichiers utilisés, pas les paquets |

## Ce qui manque encore

- **Les cris de mouettes et d'échassiers.** Rien dans `/tmp/hunt/audio/` : la seule
  recherche par nom (`gull|seagull|heron|wader|crane|duck`) ne renvoie aucun fichier
  audio. `oiseaux_lointains_boucle.ogg` et `oiseaux_marais_boucle.ogg` sont des
  passereaux — c'est joli, c'est estival, mais ce n'est pas le marais salant.
  Il faut aller chercher un enregistrement CC0 de *Larus* et d'échassiers, ou
  l'enregistrer.
- **Une vraie ambiance de marais**, c'est-à-dire un fond unique où l'eau, le vent et
  les oiseaux sont déjà mêlés. Les sept nappes de `ambiance/` sont là pour être
  empilées et dosées en jeu ; c'est plus souple, mais ça reporte le mixage sur le code.
- **Le son de la vanne qu'on ouvre**, l'instant du geste : le bois qui force puis
  l'eau qui part. On a les deux moitiés (`gestes/grincement_bois_*`,
  `eau/eau_vanne.ogg`) mais pas le raccord. À enchaîner en jeu ou à fabriquer.
- **Des pas sur talus mouillé** (argile détrempée mais pas immergée), entre
  `pas_boue_*` et `pas_eau_*`. Le tutoriel se joue à marée montante, cette surface-là
  existe.
