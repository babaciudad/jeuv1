## Les vitesses au sol des clips de locomotion, en mètres par seconde.
##
## MESURÉES, pas estimées. `outils/mesurer_pas.gd` joue chaque clip pas à pas,
## regarde à chaque instant lequel des deux pieds est le plus bas — c'est celui
## qui porte — et cumule la distance dont il recule dans le repère du corps. Un
## pied qui porte ne glisse pas : c'est le sol qui défile sous lui, et cette
## distance est exactement celle dont le corps aurait dû avancer.
##
## Relancer la mesure :
##   $(outils/godot.sh) --headless --path . --script res://outils/mesurer_pas.gd
class_name Allures
extends RefCounted

const MARCHE: float = 0.67
const TROT: float = 2.04
const COURSE: float = 2.85
const ARRIERE: float = 0.90
const COTE: float = 0.745
const CRISTALLISE: float = 0.80

## Nom du clip de chaque point du mélange au sol.
const CLIP_ATTENTE: StringName = &"Idle_A"
const CLIP_MARCHE: StringName = &"Walk"
const CLIP_TROT: StringName = &"Jog"
const CLIP_COURSE: StringName = &"Sprint"
const CLIP_ARRIERE: StringName = &"plus/Walk_Backwards"
const CLIP_COTE_GAUCHE: StringName = &"plus/Strafe_left"
const CLIP_COTE_DROIT: StringName = &"plus/Strafe_right"

## Les gestes, et leur durée mesurée dans le fichier, en secondes. L'arbre
## d'animation les ÉTIRE pour tomber sur les fenêtres de coup exprimées en
## ticks — jamais l'inverse (invariant 8).
const CLIP_LAS: StringName = &"Farm_Harvest"
const DUREE_LAS: float = 2.33
const CLIP_CUEILLIR: StringName = &"Farm_PlantSeed"
const DUREE_CUEILLIR: float = 2.79
const CLIP_VANNE: StringName = &"Interact"
const DUREE_VANNE: float = 2.50
const CLIP_ESQUIVE_ARRIERE: StringName = &"plus/Dodge_back_RM"
const CLIP_ESQUIVE_GAUCHE: StringName = &"plus/Dodge_left_RM"
const CLIP_ESQUIVE_DROITE: StringName = &"plus/Dodge_right_RM"
const CLIP_ROULADE: StringName = &"Roll"
const CLIP_DOULEUR: StringName = &"Hit_Chest"
const CLIP_MORT: StringName = &"Death_D"
const CLIP_ASSIS_ENTREE: StringName = &"Sitting_Enter"
const CLIP_ASSIS: StringName = &"Sitting_Idle"
const CLIP_ASSIS_SORTIE: StringName = &"Sitting_Exit"

## Les cristallisés : ce ne sont pas des zombies, ce sont des gestes qui
## continuent. Leur attente et leur marche viennent du répertoire mort-vivant,
## mais leur ATTAQUE est le geste du las — le même clip que le joueur. C'est
## par là qu'on comprend, sans une ligne de dialogue, qu'ils faisaient le même
## métier.
const CLIP_CRISTALLISE_ATTENTE: StringName = &"Zombie_Idle"
const CLIP_CRISTALLISE_MARCHE: StringName = &"Zombie_Walk"
const CLIP_CRISTALLISE_LEVEE: StringName = &"plus/Zombie_Rise"
const DUREE_CRISTALLISE_LEVEE: float = 3.38
