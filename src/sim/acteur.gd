## Un corps dans le marais : le joueur, ou un cristallisé.
##
## Rien ici n'est un nœud Godot. Un acteur est un état pur, avançable par
## ticks et comparable à un autre — c'est ce qui rend la simulation testable
## sans fenêtre et rejouable à l'identique (invariants 1 et 2).
class_name Acteur
extends RefCounted

enum Etat {
	## Debout, libre de ses gestes.
	LIBRE,
	## Roulade ou pas de côté : invulnérable sur une fenêtre, immobilisé après.
	ESQUIVE,
	## Un geste de travail en cours. Le las est lent, large, et ne s'annule pas.
	FRAPPE,
	## Encaissement. Court, mais on ne fait rien pendant.
	DOULEUR,
	## Un geste de travail sans coup : ouvrir une vanne, cueillir, se relever.
	## Il immobilise — on n'ouvre pas une vanne en marchant — et c'est lui qui
	## donne un corps aux gestes du métier : ils avaient leurs clips chargés
	## dans le rig et rien ne les jouait jamais.
	TRAVAIL,
	## Fin.
	MORT,
}

enum Camp { PALUDIER, CRISTALLISE }

var id: int = 0
var camp: Camp = Camp.PALUDIER
var etat: Etat = Etat.LIBRE

## Position au sol, dans le plan du marais. La hauteur est déduite du terrain :
## on ne saute pas dans un marais salant.
var position: Vector2 = Vector2.ZERO
var vitesse: Vector2 = Vector2.ZERO
## Cap du corps, en radians.
var cap: float = 0.0

var vie: float = Reglages.VIE_JOUEUR
var vie_max: float = Reglages.VIE_JOUEUR
var endurance: float = Reglages.ENDURANCE_MAX
## Ticks restants avant que l'endurance reprenne.
var repos_avant_regen: int = 0

## Ticks restants dans l'état courant. Zéro quand l'état est LIBRE.
var ticks_etat: int = 0
## Identifiant du geste en cours (nom de l'attaque jouée), pour que la
## présentation sache quel clip étirer.
var geste: StringName = &""
## Ticks écoulés dans le geste courant : c'est là-dessus que se lisent les
## fenêtres de coup (invariant 8).
var ticks_geste: int = 0
## Vrai pendant la fenêtre d'invulnérabilité d'une esquive.
var intouchable: bool = false
## Cibles déjà touchées pendant le geste en cours. Vidée à chaque nouveau
## geste. C'est elle qui permet à la fenêtre de coup d'être une vraie fenêtre :
## chaque tick de la fenêtre peut toucher, mais jamais deux fois le même corps.
var touches: PackedInt32Array = PackedInt32Array()
## Profondeur d'eau sous les pieds au dernier tick, en mètres. Recopiée par la
## simulation pour que la présentation n'ait pas à réinterroger le marais.
var eau_sous_les_pieds: float = 0.0
## Ticks passés dans une eau où l'on ne marche plus.
var ticks_immerge: int = 0
## Ticks écoulés depuis la mort. Sert au délai avant d'être redéposé.
var ticks_mort: int = 0
## Ticks d'attente avant qu'un cristallisé reprenne son geste.
##
## Sans ce répit, il enchaîne le las sans jamais s'arrêter et le combat devient
## une salve continue : le joueur n'a plus qu'à esquiver, il ne peut plus jamais
## frapper, et l'endurance des deux camps s'effondre. Un cristallisé est LENT —
## c'est un geste qui continue, pas un fauve.
var attente: int = 0
## Vrai si l'acteur est tombé du talus depuis le dernier tick. La présentation
## s'en sert pour l'éclaboussure, le jeu pour un éventuel dégât de chute.
var vient_de_tomber: bool = false

func vivant() -> bool:
	return etat != Etat.MORT

func peut_agir() -> bool:
	return etat == Etat.LIBRE

## Consomme de l'endurance et arme le délai avant régénération. Renvoie faux si
## l'acteur n'en a pas assez : c'est la simulation qui décide, pas l'entrée.
func depenser(cout: float) -> bool:
	if endurance < cout:
		return false
	endurance -= cout
	repos_avant_regen = int(Reglages.ENDURANCE_DELAI * float(Reglages.TICKS_PAR_SECONDE))
	return true

func blesser(degats: float) -> void:
	if etat == Etat.MORT or intouchable:
		return
	vie = maxf(0.0, vie - degats)
	if vie <= 0.0:
		etat = Etat.MORT
		ticks_mort = 0
		ticks_etat = 0
		geste = &"mort"
		ticks_geste = 0
		vitesse = Vector2.ZERO

func copier() -> Acteur:
	var a: Acteur = Acteur.new()
	a.id = id
	a.camp = camp
	a.etat = etat
	a.position = position
	a.vitesse = vitesse
	a.cap = cap
	a.vie = vie
	a.vie_max = vie_max
	a.endurance = endurance
	a.repos_avant_regen = repos_avant_regen
	a.ticks_etat = ticks_etat
	a.geste = geste
	a.ticks_geste = ticks_geste
	a.intouchable = intouchable
	a.touches = touches.duplicate()
	a.ticks_immerge = ticks_immerge
	a.ticks_mort = ticks_mort
	a.attente = attente
	a.eau_sous_les_pieds = eau_sous_les_pieds
	a.vient_de_tomber = vient_de_tomber
	return a
