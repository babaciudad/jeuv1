## L'état complet du marais à un tick donné : le terrain, l'eau, les corps.
##
## Le monde ne s'avance pas lui-même — c'est Simulation qui le fait. Cette
## séparation existe pour qu'on puisse copier un monde, le rejouer, en comparer
## deux, et un jour en envoyer un sur un réseau.
class_name Monde
extends RefCounted

var tick: int = 0
var marais: Marais = Marais.new()
var acteurs: Array[Acteur] = []
## Les gestes disponibles, par nom.
var gestes: Dictionary[StringName, Geste] = {}
## Vitesse d'évaporation courante, en mètres d'eau par seconde. Le vent d'est
## de fin de tutoriel la fait monter : c'est lui qui fait naître la fleur.
var evaporation: float = 0.0
## Force du vent d'est, de 0 à 1. Zéro tant que le ciel n'a pas tourné.
var vent_est: float = 0.0

func ajouter(acteur: Acteur) -> Acteur:
	acteur.id = acteurs.size() + 1
	acteurs.append(acteur)
	return acteur

func acteur_par_id(cherche: int) -> Acteur:
	for a: Acteur in acteurs:
		if a.id == cherche:
			return a
	return null

func joueur() -> Acteur:
	for a: Acteur in acteurs:
		if a.camp == Acteur.Camp.PALUDIER:
			return a
	return null

## Les cristallisés encore debout.
func ennemis_vivants() -> Array[Acteur]:
	var vivants: Array[Acteur] = []
	for a: Acteur in acteurs:
		if a.camp == Acteur.Camp.CRISTALLISE and a.vivant():
			vivants.append(a)
	return vivants

## Accès typé à un geste. `Dictionary.get` rend un Variant même sur un
## dictionnaire typé, et un transtypage depuis Variant est refusé par
## l'invariant 10 : ce détour est la façon propre de le contourner.
func geste_nomme(nom: StringName) -> Geste:
	if not gestes.has(nom):
		return null
	return gestes[nom]
