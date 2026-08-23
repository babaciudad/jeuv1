## État d'un acteur simulé : joueur ou ennemi.
##
## Données pures, sans nœud, sauf le dérouleur d'attaque qui doit être dans
## l'arbre pour que ses pistes d'animation se résolvent (invariant 8).
##
## L'endurance est stockée en centièmes de point. Une valeur qui doit être
## identique sur toutes les machines n'a pas à transiter par un flottant
## accumulé tick après tick.
class_name Actor
extends RefCounted

enum Kind {
	PLAYER = 0,
	ENEMY = 1,
}

enum State {
	IDLE = 0,
	MOVING = 1,
	DODGING = 2,
	ATTACKING = 3,
	STAGGERED = 4,
	DEAD = 5,
}

const CENTI: int = 100

var id: int = 0
var kind: Kind = Kind.PLAYER
var state: State = State.IDLE
## Tick auquel l'état courant a été pris. Toutes les durées se mesurent
## par rapport à lui, jamais avec un compteur séparé.
var state_entered_tick: int = 0

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2(0.0, 1.0)
var radius: float = 0.45

var health: int = 100
var max_health: int = 100
var stamina_centi: int = 10000
var max_stamina_centi: int = 10000
var poise: int = 40
var max_poise: int = 40

var last_stamina_spend_tick: int = -10000
var last_poise_break_tick: int = -10000

## Direction de déplacement demandée au dernier tick, déjà normalisée.
var move_intent: Vector2 = Vector2.ZERO
## Index de l'attaque en cours dans les données de l'acteur, -1 si aucune.
var attack_index: int = -1
## Direction visée par l'attaque en cours. Fixée au déclenchement, elle sert
## de cible au tracking tant que la hitbox n'est pas ouverte.
var aim: Vector2 = Vector2(0.0, 1.0)
var runner: AttackRunner = null

## Réservé aux ennemis : cible poursuivie, et tick de la dernière attaque.
var target_id: int = 0
var last_attack_tick: int = -10000
## Position d'origine, pour le retour en cas de désengagement.
var home_position: Vector2 = Vector2.ZERO
## Index dans le tableau des données d'ennemis. -1 pour un joueur.
var data_index: int = -1

## Vrai si cette machine calcule elle-même le mouvement de cet acteur. Sur
## l'hôte, tout le monde. Sur un client, son seul personnage : les autres sont
## interpolés depuis les instantanés (invariant 4), et les intégrer localement
## les ferait dériver de ce que l'hôte affirme.
var simulated: bool = true

func is_alive() -> bool:
	return state != State.DEAD

## Vrai si l'acteur peut entamer une nouvelle action.
func can_act() -> bool:
	return state == State.IDLE or state == State.MOVING

func stamina_points() -> int:
	return floori(float(stamina_centi) / float(CENTI))

func has_stamina(points: int) -> bool:
	return stamina_centi >= points * CENTI

func spend_stamina(points: int, tick: int) -> void:
	stamina_centi = maxi(0, stamina_centi - points * CENTI)
	last_stamina_spend_tick = tick

func enter_state(new_state: State, tick: int) -> void:
	state = new_state
	state_entered_tick = tick

func ticks_in_state(tick: int) -> int:
	return tick - state_entered_tick
