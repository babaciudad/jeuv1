## Photographie d'un acteur à un tick donné, telle qu'elle voyage sur le fil.
##
## Volontairement plate et sans logique : c'est un format d'échange, pas un
## acteur. Les valeurs que le client n'a pas le droit de prédire — vie, poise,
## mort — n'existent que dans ce sens, de l'hôte vers les clients.
class_name ActorState
extends RefCounted

var id: int = 0
var kind: int = 0
var state: int = 0
var state_entered_tick: int = 0
var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2(0.0, 1.0)
var health: int = 0
var poise: int = 0
var stamina_points: int = 0
## Index de l'attaque en cours, -1 si aucune.
var attack_index: int = -1
## Ticks écoulés depuis le début de l'attaque en cours.
var attack_elapsed: int = 0
## Index des données d'ennemi, -1 pour un joueur.
var data_index: int = -1

static func from_actor(actor: Actor) -> ActorState:
	var out: ActorState = ActorState.new()
	out.id = actor.id
	out.kind = int(actor.kind)
	out.state = int(actor.state)
	out.state_entered_tick = actor.state_entered_tick
	out.position = actor.position
	out.velocity = actor.velocity
	out.facing = actor.facing
	out.health = actor.health
	out.poise = actor.poise
	out.stamina_points = actor.stamina_points()
	out.attack_index = actor.attack_index
	out.attack_elapsed = actor.runner.elapsed_ticks if actor.runner != null else 0
	out.data_index = actor.data_index
	return out
