## L'intention d'un joueur pour un tick, et rien d'autre.
##
## Invariant 3 : une action de gameplay est une commande, ou n'existe pas. La
## simulation ne lit jamais le clavier ; elle lit ceci. C'est ce qui la rend
## rejouable à l'identique, testable sans fenêtre, et transportable sur un
## réseau le jour où on en voudra un.
class_name Commande
extends RefCounted

## Direction voulue, dans le repère du monde, normalisée ou nulle.
var direction: Vector2 = Vector2.ZERO
## Cap voulu (là où regarde la caméra), en radians.
var cap: float = 0.0
var court: bool = false
var esquive: bool = false
var frappe: bool = false
var interagit: bool = false

func dupliquer() -> Commande:
	var copie: Commande = Commande.new()
	copie.direction = direction
	copie.cap = cap
	copie.court = court
	copie.esquive = esquive
	copie.frappe = frappe
	copie.interagit = interagit
	return copie

## Deux commandes identiques doivent produire deux ticks identiques : cette
## égalité-là est ce que vérifient les tests de convergence.
func identique_a(autre: Commande) -> bool:
	return direction.is_equal_approx(autre.direction) \
		and is_equal_approx(cap, autre.cap) \
		and court == autre.court and esquive == autre.esquive \
		and frappe == autre.frappe and interagit == autre.interagit
