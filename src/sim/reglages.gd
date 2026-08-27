## Les constantes de la simulation, en un seul endroit.
##
## Tout est en unités du monde : mètres, secondes, mètres par seconde. Le tick
## est la seule unité de temps (invariant 1) ; les durées exprimées ici en
## secondes ne servent qu'à dériver des ticks au démarrage, jamais à l'exécution.
class_name Reglages
extends RefCounted

## Fréquence de simulation. Doit correspondre à physics_ticks_per_second.
const TICKS_PAR_SECONDE: int = 60
const DUREE_TICK: float = 1.0 / float(TICKS_PAR_SECONDE)

# --- Déplacement ------------------------------------------------------------
## Le paludier ne court pas : il travaille. La marche est la vitesse normale,
## et la course est une dépense, pas un mode de déplacement.
##
## Ces deux valeurs ne sont pas choisies au goût : elles sont calées sur les
## clips, mesurés par outils/mesurer_pas.gd, qui rend la vitesse au sol réelle
## de chaque animation en suivant le pied qui porte. Jog vaut 2,04 m/s et
## Sprint 2,85 m/s. Marcher à 2,0 fait donc tourner Jog à sa cadence naturelle,
## et courir à 3,7 n'étire Sprint que d'un quart. Au-delà, les pieds patinent —
## c'est le défaut d'animation le plus visible d'un jeu à la troisième personne,
## et il ne se voit sur aucune capture d'écran.
const VITESSE_MARCHE: float = 2.00
const VITESSE_COURSE: float = 3.70
## Endurance dépensée par seconde de course.
##
## ENDURANCE_COURSE existait déjà et n'était LUE NULLE PART : on sprintait
## indéfiniment, 85 % plus vite, gratuitement. Il n'y avait aucune raison de
## marcher, ce qui vide de son sens la moitié du vocabulaire souls-like.
const ENDURANCE_PAR_SECONDE_DE_COURSE: float = 18.0
## Accélération et freinage, en mètres par seconde carrée. Un corps qui porte
## un las de cinq mètres ne pivote pas sur place.
const ACCELERATION: float = 26.0
const FREINAGE: float = 34.0
## Vitesse de rotation du buste, en radians par seconde.
const VITESSE_CAP: float = 9.0

# --- Terrain ----------------------------------------------------------------
## Largeur d'un talus, en mètres. Le lore dit soixante-dix centimètres, et
## c'est cette valeur-là qui fait tout le sel du terrain : un pas de côté mal
## placé et on tombe.
const LARGEUR_TALUS: float = 0.70
## Hauteur du talus au-dessus du fond d'un bassin.
const HAUTEUR_TALUS: float = 0.45
## Au-delà de cette profondeur d'eau, on ne marche plus : on patauge.
const EAU_GENANTE: float = 0.12
## Facteur de vitesse dans l'eau peu profonde. « On ne meurt pas de tomber d'un
## talus, on devient lent, bruyant et exposé. »
const FACTEUR_EAU: float = 0.45

## Au-delà de cette hauteur d'eau, en mètres, on ne patauge plus : on coule.
##
## Le lore distingue deux eaux et le jeu doit les distinguer aussi. Un bassin
## fait trois à sept centimètres : on y tombe, on s'y traîne, on s'en relève.
## L'étier fait UN MÈTRE TRENTE : c'est un chenal de mer, et un paludier chargé
## d'un las de cinq mètres n'y nage pas.
##
## Sans cette règle, le joueur marchait au FOND du chenal, immergé jusqu'au
## torse, la caméra sous la nappe — et comme le shader d'eau ne s'affiche que
## par-dessus, il voyait le ciel à travers l'eau. C'était le défaut le plus
## visible du jeu.
const EAU_MORTELLE: float = 0.55
## Ticks passés sous l'eau avant que le sel ne reprenne son dû. Une seconde et
## trois dixièmes : le temps de comprendre qu'on coule et de faire demi-tour —
## à quarante-deux ticks, un pas de côté depuis la première digue du tutoriel
## tuait en neuf dixièmes de seconde, ce qui se lit comme un bug et non comme
## une règle.
const TICKS_DE_NOYADE: int = 78

## Rayon d'encombrement d'un corps, en mètres. Deux corps ne s'interpénètrent
## pas : on se cale contre un cristallisé, on ne le traverse pas comme du
## brouillard. C'est aussi ce qui rend l'espacement au combat réel — reculer
## contre un corps, c'est être coincé.
const RAYON_CORPS: float = 0.30

# --- Endurance --------------------------------------------------------------
const ENDURANCE_MAX: float = 100.0
const ENDURANCE_COURSE: float = 18.0
const ENDURANCE_ESQUIVE: float = 18.0
const ENDURANCE_COUP_LAS: float = 24.0
## Régénération par seconde, et délai avant qu'elle reprenne, en secondes.
const ENDURANCE_REGEN: float = 34.0
const ENDURANCE_DELAI: float = 0.55

# --- Vie --------------------------------------------------------------------
const VIE_JOUEUR: float = 100.0
const VIE_CRISTALLISE: float = 62.0

## Répit d'un cristallisé entre deux gestes, en ticks. « Il ne poursuit jamais
## très loin. » Ce silence-là est ce qui rend le combat lisible : c'est dans ce
## trou que le joueur place son propre geste.
const REPIT_CRISTALLISE: int = 54

# --- Hydraulique ------------------------------------------------------------
## Débit d'une vanne ouverte, en mètres cubes par seconde et par mètre de
## charge. Tout descend par gravité : le débit suit la différence de niveau,
## et rien ne remonte jamais.
##
## Un vrai marais met des heures ; celui-ci met une dizaine de secondes, et
## c'est délibéré. Ouvrir une vanne est le premier geste du jeu et le geste
## des raccourcis : il doit se VOIR. À cette valeur, deux œillets de soixante
## -dix mètres carrés s'égalisent en une dizaine de secondes — assez lent pour
## qu'on voie l'eau descendre, assez court pour qu'on ne s'ennuie pas devant.
## Le test de convergence tient cette promesse-là, pas seulement la physique.
const DEBIT_VANNE: float = 3.5
## En dessous de cette différence de niveau, en mètres, on considère que les
## deux bassins sont à l'équilibre et le débit s'arrête. Sans ce seuil, deux
## bassins échangent éternellement des millilitres.
const CHARGE_MINIMALE: float = 0.004

# --- La fleur -------------------------------------------------------------
## Salinité en deçà de laquelle rien ne cristallise en surface.
const FLEUR_SALINITE: float = 0.90
## La fleur ne prend que sur une lame d'eau : trop peu, l'œillet est sec ;
## trop, la pellicule coule et rejoint le gros sel au fond.
const FLEUR_EAU_MIN: float = 0.006
const FLEUR_EAU_MAX: float = 0.120
## Au-delà de cette hauteur d'eau, une pellicule déjà prise coule et rejoint le
## gros sel au fond. C'est la SEULE façon de perdre une fleur formée.
const FLEUR_NOYEE: float = 0.250
## Vent d'est minimal. « Un souffle d'est en fin de journée, pas de pluie, pas
## trop de vent — sinon elle coule. »
const FLEUR_VENT_MIN: float = 0.18
const FLEUR_VENT_MAX: float = 0.86
## Vitesse de formation et de dissolution, par seconde.
const FLEUR_POUSSE: float = 0.085
const FLEUR_FONTE: float = 0.055
## Ce qu'une cueillette prend à la pellicule.
const FLEUR_PRISE: float = 0.34

# --- Le gros sel ----------------------------------------------------------
## Un œillet ne rend du gros sel que mûr et presque sec : c'est le fond qui a
## cristallisé contre l'argile, et c'est pour ça qu'il est gris.
const SEL_SALINITE: float = 0.92
const SEL_EAU_MAX: float = 0.022

## Portée d'une interaction, en mètres. On ouvre une vanne à bout de bras.
const PORTEE_GESTE: float = 2.1

## Durées des gestes de travail, en ticks. Le corps s'arrête pour les faire :
## on n'ouvre pas une vanne en marchant, on ne cueille pas en courant.
const TICKS_TRAVAIL_VANNE: int = 66
const TICKS_TRAVAIL_CUEILLETTE: int = 72
## La levée d'un cristallisé : le temps du clip, à sa cadence naturelle.
const TICKS_LEVEE: int = 203

## Ticks entre la mort et le dépôt à la ladure.
##
## « Le sel garde ce qui s'y dissout. Sa mort ne l'efface pas, elle le dépose. »
## Ce n'est donc pas un écran de défaite : c'est un transport. Le monde, lui, ne
## se remet pas à zéro — l'eau qu'on a fait descendre est toujours descendue.
const REPOS_APRES_MORT: int = 156
