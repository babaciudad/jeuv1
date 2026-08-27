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
const VITESSE_MARCHE: float = 2.6
const VITESSE_COURSE: float = 5.2
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
## Facteur de vitesse dans l'eau. On n'y meurt pas — le marais n'est pas
## profond — mais on y est lent, bruyant et vulnérable.
const FACTEUR_EAU: float = 0.45

# --- Endurance --------------------------------------------------------------
const ENDURANCE_MAX: float = 100.0
const ENDURANCE_COURSE: float = 18.0
const ENDURANCE_ESQUIVE: float = 22.0
const ENDURANCE_COUP_LAS: float = 28.0
## Régénération par seconde, et délai avant qu'elle reprenne, en secondes.
const ENDURANCE_REGEN: float = 34.0
const ENDURANCE_DELAI: float = 0.55

# --- Vie --------------------------------------------------------------------
const VIE_JOUEUR: float = 100.0
const VIE_CRISTALLISE: float = 62.0

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
