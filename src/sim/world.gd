## État du monde et règles du jeu.
##
## Invariant 2 : aucun nœud visuel, aucune caméra, aucune entrée. Le monde
## n'expose que des signaux et des données ; la présentation les lit.
##
## Invariant 1 : `step()` est appelé exactement une fois par tick. Aucune durée
## n'est mesurée autrement qu'en différences de ticks.
##
## Le monde ne parle jamais au réseau. Quand une règle produit une information
## que seule une autre machine peut trancher, il émet un signal et s'arrête là
## (invariants 3 et 5).
class_name World
extends RefCounted

enum Authority {
	## Simule les ennemis, tranche les dégâts et la progression.
	HOST = 0,
	## Simule son propre joueur, rejoue les calendriers d'attaque, ne tranche
	## rien.
	CLIENT = 1,
}

## Le joueur local a touché un ennemi. L'attaquant déclare, l'hôte confirme.
signal hit_declared(target_id: int, attack_index: int)
## Le joueur local a été touché. La victime déclare, l'hôte contrôle.
signal damage_reported(source_id: int, attack_index: int)
signal actor_died(actor_id: int)
signal bonfire_rested()
signal shortcut_opened()

## Identifiant du premier ennemi. Au-dessus des peer id, qui sont de petits
## entiers côté hôte mais peuvent être quelconques côté ENet.
const FIRST_ENEMY_ID: int = 1_000_000

## Tolérance de distance accordée aux déclarations de touche, en mètres.
## Un client déclare sur sa vue du monde, vieille d'un aller simple : exiger
## une correspondance exacte refuserait des touches légitimes.
const HIT_PLAUSIBILITY_SLACK: float = 1.75
## Ancienneté maximale d'une déclaration, en ticks.
const HIT_MAX_AGE_TICKS: int = 30

var tick: int = 0
var authority: Authority = Authority.HOST
## Acteur piloté par cette machine. 0 si aucun.
var local_actor_id: int = 0

var level: LevelData = null
var player_data: PlayerData = null
var enemy_data: Array[EnemyData] = []

var actors: Dictionary[int, Actor] = {}
var shortcut_open: bool = false

var _runner_parent: Node
var _next_enemy_id: int = FIRST_ENEMY_ID

func _init(runner_parent: Node) -> void:
	_runner_parent = runner_parent

func configure(p_level: LevelData, p_player_data: PlayerData,
		p_enemy_data: Array[EnemyData]) -> void:
	level = p_level
	player_data = p_player_data
	enemy_data = p_enemy_data

# ---------------------------------------------------------------------------
# Peuplement
# ---------------------------------------------------------------------------

func spawn_player(actor_id: int, slot: int) -> Actor:
	var actor: Actor = Actor.new()
	actor.id = actor_id
	actor.kind = Actor.Kind.PLAYER
	actor.radius = player_data.radius
	actor.max_health = player_data.max_health
	actor.health = actor.max_health
	actor.max_stamina_centi = player_data.max_stamina * Actor.CENTI
	actor.stamina_centi = actor.max_stamina_centi
	actor.max_poise = player_data.max_poise
	actor.poise = actor.max_poise
	actor.position = _player_spawn(slot)
	actor.home_position = actor.position
	actor.facing = Vector2(0.0, 1.0)
	actor.runner = _make_runner("Attack_%d" % actor_id)
	actors[actor_id] = actor
	return actor

func remove_actor(actor_id: int) -> void:
	if not actors.has(actor_id):
		return
	var actor: Actor = actors[actor_id]
	if actor.runner != null:
		actor.runner.queue_free()
	actors.erase(actor_id)

func spawn_enemies() -> void:
	if enemy_data.is_empty():
		return
	var basic: EnemyData = _first_enemy_data(false)
	if basic != null:
		for spawn: Vector2 in level.enemy_spawns:
			_spawn_enemy(basic, spawn)
	var boss: EnemyData = _first_enemy_data(true)
	if boss != null:
		_spawn_enemy(boss, level.boss_spawn)

func _spawn_enemy(data: EnemyData, spawn: Vector2) -> Actor:
	var actor: Actor = Actor.new()
	actor.id = _next_enemy_id
	_next_enemy_id += 1
	actor.kind = Actor.Kind.ENEMY
	actor.data_index = enemy_data.find(data)
	actor.radius = data.radius
	actor.max_health = data.max_health
	actor.health = actor.max_health
	actor.max_poise = data.max_poise
	actor.poise = actor.max_poise
	actor.position = spawn
	actor.home_position = spawn
	actor.facing = Vector2(0.0, -1.0)
	actor.runner = _make_runner("Attack_%d" % actor.id)
	actors[actor.id] = actor
	return actor

func _make_runner(runner_name: String) -> AttackRunner:
	var runner: AttackRunner = AttackRunner.new()
	runner.name = runner_name
	_runner_parent.add_child(runner)
	return runner

func _first_enemy_data(boss: bool) -> EnemyData:
	for data: EnemyData in enemy_data:
		if data.is_boss == boss:
			return data
	return null

func _player_spawn(slot: int) -> Vector2:
	if level.player_spawns.is_empty():
		return level.bonfire_position
	return level.player_spawns[slot % level.player_spawns.size()]

# ---------------------------------------------------------------------------
# Accès
# ---------------------------------------------------------------------------

func players() -> Array[Actor]:
	var out: Array[Actor] = []
	for actor: Actor in actors.values():
		if actor.kind == Actor.Kind.PLAYER:
			out.append(actor)
	return out

func enemies() -> Array[Actor]:
	var out: Array[Actor] = []
	for actor: Actor in actors.values():
		if actor.kind == Actor.Kind.ENEMY:
			out.append(actor)
	return out

func actor_or_null(actor_id: int) -> Actor:
	return actors.get(actor_id, null)

func local_actor() -> Actor:
	return actor_or_null(local_actor_id)

func blockers() -> Array[Rect2]:
	if shortcut_open:
		return []
	return [level.shortcut_gate]

func data_for(actor: Actor) -> EnemyData:
	if actor.data_index < 0 or actor.data_index >= enemy_data.size():
		return null
	return enemy_data[actor.data_index]

func attacks_for(actor: Actor) -> Array[AttackData]:
	if actor.kind == Actor.Kind.PLAYER:
		return player_data.attacks
	var data: EnemyData = data_for(actor)
	return data.attacks if data != null else []

# ---------------------------------------------------------------------------
# Pas de simulation
# ---------------------------------------------------------------------------

func step(commands: Array[Command]) -> void:
	tick += 1
	for command: Command in commands:
		_apply_command(command)
	if authority == Authority.HOST:
		_decide_enemies()
	_advance_attacks()
	_resolve_hitboxes()
	_integrate()
	_separate()
	_recover()

func _apply_command(command: Command) -> void:
	var actor: Actor = actor_or_null(command.actor_id)
	if actor == null:
		return
	match command.type:
		Command.Type.MOVE:
			_command_move(actor, command)
		Command.Type.DODGE:
			_command_dodge(actor, command)
		Command.Type.ATTACK:
			_command_attack(actor, command)
		Command.Type.INTERACT:
			_command_interact(actor)
		Command.Type.DECLARE_HIT:
			_command_declare_hit(actor, command)
		Command.Type.REPORT_DAMAGE:
			_command_report_damage(actor, command)
		Command.Type.NONE:
			pass

func _command_move(actor: Actor, command: Command) -> void:
	if not actor.is_alive():
		return
	var direction: Vector2 = _payload_vector(command, "d")
	actor.move_intent = direction.normalized() if direction.length() > 0.001 else Vector2.ZERO

func _command_dodge(actor: Actor, command: Command) -> void:
	if actor.kind != Actor.Kind.PLAYER or not actor.can_act():
		return
	if not actor.has_stamina(player_data.dodge_stamina_cost):
		return
	var direction: Vector2 = _payload_vector(command, "d")
	if direction.length() <= 0.001:
		direction = actor.facing
	actor.facing = direction.normalized()
	actor.velocity = actor.facing * player_data.dodge_speed
	actor.spend_stamina(player_data.dodge_stamina_cost, tick)
	actor.enter_state(Actor.State.DODGING, tick)

func _command_attack(actor: Actor, command: Command) -> void:
	var attacks: Array[AttackData] = attacks_for(actor)
	if attacks.is_empty():
		return
	var index: int = _payload_int(command, "i", 0)
	if index < 0 or index >= attacks.size():
		return
	var can_start: bool = actor.can_act()
	if actor.state == Actor.State.ATTACKING and actor.runner != null and actor.runner.can_cancel:
		can_start = true
	if not can_start or not actor.is_alive():
		return
	var attack: AttackData = attacks[index]
	if actor.kind == Actor.Kind.PLAYER and not actor.has_stamina(attack.stamina_cost):
		return
	if not actor.runner.start(attack):
		return
	if actor.kind == Actor.Kind.PLAYER:
		actor.spend_stamina(attack.stamina_cost, tick)
	else:
		actor.last_attack_tick = tick
	actor.attack_index = index
	actor.enter_state(Actor.State.ATTACKING, tick)

## Repos au feu et ouverture du raccourci : de la progression, donc de
## l'autorité de l'hôte, et jamais prédite (invariant 6).
func _command_interact(actor: Actor) -> void:
	if authority != Authority.HOST or actor.kind != Actor.Kind.PLAYER:
		return
	if not actor.is_alive():
		return
	if not shortcut_open \
			and actor.position.distance_to(level.shortcut_switch_position) <= level.shortcut_switch_radius:
		shortcut_open = true
		shortcut_opened.emit()
		return
	if actor.position.distance_to(level.bonfire_position) <= level.bonfire_radius:
		rest_at_bonfire()

func _command_declare_hit(attacker: Actor, command: Command) -> void:
	if authority != Authority.HOST:
		return
	var target: Actor = actor_or_null(_payload_int(command, "t", 0))
	if target == null or not target.is_alive() or target.kind != Actor.Kind.ENEMY:
		return
	if not attacker.is_alive():
		return
	if tick - command.tick > HIT_MAX_AGE_TICKS or command.tick > tick + 5:
		return
	var attacks: Array[AttackData] = attacks_for(attacker)
	var index: int = _payload_int(command, "a", -1)
	if index < 0 or index >= attacks.size():
		return
	# L'hôte relit SES propres données : la charge utile ne porte que des
	# identifiants, jamais un nombre de dégâts. Un client ne peut donc pas
	# gonfler ce qu'il inflige.
	var attack: AttackData = attacks[index]
	var reach: float = attack.range_meters + target.radius + HIT_PLAUSIBILITY_SLACK
	if attacker.position.distance_to(target.position) > reach:
		return
	apply_damage(target, attack.damage, attack.poise_damage)

func _command_report_damage(victim: Actor, command: Command) -> void:
	if authority != Authority.HOST or victim.kind != Actor.Kind.PLAYER:
		return
	if not victim.is_alive():
		return
	if tick - command.tick > HIT_MAX_AGE_TICKS or command.tick > tick + 5:
		return
	var source: Actor = actor_or_null(_payload_int(command, "s", 0))
	if source == null or source.kind != Actor.Kind.ENEMY:
		return
	var attacks: Array[AttackData] = attacks_for(source)
	var index: int = _payload_int(command, "a", -1)
	if index < 0 or index >= attacks.size():
		return
	var attack: AttackData = attacks[index]
	var reach: float = attack.range_meters + victim.radius + HIT_PLAUSIBILITY_SLACK
	if source.position.distance_to(victim.position) > reach:
		return
	apply_damage(victim, attack.damage, attack.poise_damage)

# ---------------------------------------------------------------------------
# Ennemis (hôte uniquement)
# ---------------------------------------------------------------------------

func _decide_enemies() -> void:
	var living_players: Array[Actor] = []
	for player: Actor in players():
		if player.is_alive():
			living_players.append(player)
	for enemy: Actor in enemies():
		if not enemy.is_alive():
			continue
		var data: EnemyData = data_for(enemy)
		if data == null:
			continue
		var decision: EnemyBrain.Decision = EnemyBrain.decide(enemy, data, living_players, tick)
		enemy.target_id = decision.target_id
		enemy.move_intent = decision.move_intent
		if decision.attack_index >= 0:
			var command: Command = Command.new(tick, enemy.id, Command.Type.ATTACK,
				{"i": decision.attack_index})
			_command_attack(enemy, command)

# ---------------------------------------------------------------------------
# Attaques
# ---------------------------------------------------------------------------

func _advance_attacks() -> void:
	for actor: Actor in actors.values():
		if actor.runner == null or actor.runner.finished:
			continue
		actor.runner.advance_tick()
		if actor.runner.finished and actor.state == Actor.State.ATTACKING:
			actor.attack_index = -1
			actor.enter_state(Actor.State.IDLE, tick)

func _resolve_hitboxes() -> void:
	var local: Actor = local_actor()
	for attacker: Actor in actors.values():
		if attacker.runner == null or not attacker.runner.hitbox_open:
			continue
		var attack: AttackData = attacker.runner.attack
		if attack == null:
			continue
		if attacker.kind == Actor.Kind.PLAYER and attacker.id == local_actor_id:
			_resolve_player_hitbox(attacker, attack)
		elif attacker.kind == Actor.Kind.ENEMY and local != null:
			_resolve_enemy_hitbox(attacker, attack, local)

## L'attaquant déclare ce qu'il touche (invariant 5).
func _resolve_player_hitbox(attacker: Actor, attack: AttackData) -> void:
	for target: Actor in enemies():
		if not target.is_alive():
			continue
		if not SimMath.cone_contains(attacker.position, attacker.facing,
				attack.range_meters, attack.half_angle_degrees, target.position, target.radius):
			continue
		if not attacker.runner.try_register_hit(target.id):
			continue
		hit_declared.emit(target.id, attacker.attack_index)

## La victime déclare ce qu'elle encaisse (invariant 5). Elle ne l'applique
## pas : les dégâts ne se prédisent jamais (invariant 6).
func _resolve_enemy_hitbox(attacker: Actor, attack: AttackData, victim: Actor) -> void:
	if not victim.is_alive() or is_invulnerable(victim):
		return
	if not SimMath.cone_contains(attacker.position, attacker.facing,
			attack.range_meters, attack.half_angle_degrees, victim.position, victim.radius):
		return
	if not attacker.runner.try_register_hit(victim.id):
		return
	damage_reported.emit(attacker.id, attacker.attack_index)

func is_invulnerable(actor: Actor) -> bool:
	if actor.state != Actor.State.DODGING:
		return false
	var elapsed: int = actor.ticks_in_state(tick)
	return elapsed >= player_data.dodge_invulnerable_from_tick \
		and elapsed <= player_data.dodge_invulnerable_to_tick

# ---------------------------------------------------------------------------
# Dégâts et progression (hôte uniquement)
# ---------------------------------------------------------------------------

func apply_damage(target: Actor, damage: int, poise_damage: int) -> void:
	if not target.is_alive():
		return
	target.health = maxi(0, target.health - damage)
	if target.health == 0:
		if target.runner != null:
			target.runner.interrupt()
		target.velocity = Vector2.ZERO
		target.enter_state(Actor.State.DEAD, tick)
		actor_died.emit(target.id)
		return
	target.poise = maxi(0, target.poise - poise_damage)
	if target.poise > 0:
		return
	target.last_poise_break_tick = tick
	if target.runner != null:
		target.runner.interrupt()
	target.attack_index = -1
	target.velocity = Vector2.ZERO
	target.enter_state(Actor.State.STAGGERED, tick)

## Repos au feu : soigne les joueurs, ressuscite les morts, remet les ennemis
## en place. Le raccourci, lui, reste ouvert — c'est de la progression.
func rest_at_bonfire() -> void:
	for player: Actor in players():
		player.health = player.max_health
		player.stamina_centi = player.max_stamina_centi
		player.poise = player.max_poise
		player.velocity = Vector2.ZERO
		player.move_intent = Vector2.ZERO
		player.attack_index = -1
		if player.runner != null:
			player.runner.interrupt()
		player.enter_state(Actor.State.IDLE, tick)
	for enemy: Actor in enemies():
		enemy.health = enemy.max_health
		enemy.poise = enemy.max_poise
		enemy.position = enemy.home_position
		enemy.velocity = Vector2.ZERO
		enemy.move_intent = Vector2.ZERO
		enemy.target_id = 0
		enemy.attack_index = -1
		enemy.last_attack_tick = -10000
		if enemy.runner != null:
			enemy.runner.interrupt()
		enemy.enter_state(Actor.State.IDLE, tick)
	bonfire_rested.emit()

# ---------------------------------------------------------------------------
# Mouvement
# ---------------------------------------------------------------------------

func _integrate() -> void:
	var walkable: Array[Rect2] = level.walkable
	var active_blockers: Array[Rect2] = blockers()
	for actor: Actor in actors.values():
		_update_velocity(actor)
		if actor.velocity.is_zero_approx():
			continue
		var target: Vector2 = actor.position + actor.velocity * SimConfig.TICK_DURATION_SEC
		actor.position = SimMath.slide(actor.position, target, actor.radius,
			walkable, active_blockers)

func _update_velocity(actor: Actor) -> void:
	match actor.state:
		Actor.State.DEAD, Actor.State.STAGGERED:
			actor.velocity = actor.velocity.move_toward(Vector2.ZERO,
				player_data.deceleration * SimConfig.TICK_DURATION_SEC)
		Actor.State.DODGING:
			# Vitesse imposée par la roulade : ni accélération ni contrôle.
			pass
		Actor.State.ATTACKING:
			_update_attack_movement(actor)
		_:
			_update_walk(actor)

func _update_walk(actor: Actor) -> void:
	var speed: float = player_data.move_speed
	var acceleration: float = player_data.acceleration
	var deceleration: float = player_data.deceleration
	var turn: float = player_data.turn_degrees_per_tick
	if actor.kind == Actor.Kind.ENEMY:
		var data: EnemyData = data_for(actor)
		if data != null:
			speed = data.move_speed
			acceleration = data.acceleration
			deceleration = data.acceleration
			turn = data.turn_degrees_per_tick
	if actor.move_intent.is_zero_approx():
		actor.velocity = actor.velocity.move_toward(Vector2.ZERO,
			deceleration * SimConfig.TICK_DURATION_SEC)
		if actor.state == Actor.State.MOVING and actor.velocity.is_zero_approx():
			actor.enter_state(Actor.State.IDLE, tick)
		return
	actor.facing = SimMath.rotate_towards(actor.facing, actor.move_intent, turn)
	actor.velocity = actor.velocity.move_toward(actor.move_intent * speed,
		acceleration * SimConfig.TICK_DURATION_SEC)
	if actor.state == Actor.State.IDLE:
		actor.enter_state(Actor.State.MOVING, tick)

func _update_attack_movement(actor: Actor) -> void:
	var attack: AttackData = actor.runner.attack if actor.runner != null else null
	if attack == null:
		actor.velocity = Vector2.ZERO
		return
	# Le tracking ne vaut que tant que la hitbox est fermée : une fois le coup
	# parti, il ne suit plus sa cible.
	if not actor.runner.hitbox_open:
		var desired: Vector2 = actor.move_intent
		if actor.kind == Actor.Kind.ENEMY:
			var target: Actor = actor_or_null(actor.target_id)
			if target != null:
				desired = target.position - actor.position
		actor.facing = SimMath.rotate_towards(actor.facing, desired,
			attack.tracking_degrees_per_tick)
		actor.velocity = actor.facing * attack.forward_speed
	else:
		actor.velocity = actor.velocity.move_toward(Vector2.ZERO,
			player_data.deceleration * SimConfig.TICK_DURATION_SEC)

## Écarte les acteurs qui se chevauchent. Sans cela, trois ennemis convergeant
## vers le même joueur occuperaient la même case.
func _separate() -> void:
	var list: Array[Actor] = []
	for actor: Actor in actors.values():
		if actor.is_alive():
			list.append(actor)
	var walkable: Array[Rect2] = level.walkable
	var active_blockers: Array[Rect2] = blockers()
	for i: int in list.size():
		for j: int in range(i + 1, list.size()):
			var a: Actor = list[i]
			var b: Actor = list[j]
			var offset: Vector2 = b.position - a.position
			var distance: float = offset.length()
			var minimum: float = a.radius + b.radius
			if distance >= minimum:
				continue
			var push: Vector2 = Vector2(1.0, 0.0) if distance < 0.0001 else offset / distance
			var correction: Vector2 = push * (minimum - distance) * 0.5
			a.position = SimMath.slide(a.position, a.position - correction, a.radius,
				walkable, active_blockers)
			b.position = SimMath.slide(b.position, b.position + correction, b.radius,
				walkable, active_blockers)

# ---------------------------------------------------------------------------
# Récupération et fins d'état
# ---------------------------------------------------------------------------

func _recover() -> void:
	for actor: Actor in actors.values():
		_recover_state(actor)
		_recover_stamina(actor)
		_recover_poise(actor)

func _recover_state(actor: Actor) -> void:
	match actor.state:
		Actor.State.DODGING:
			if actor.ticks_in_state(tick) >= player_data.dodge_duration_ticks:
				actor.velocity = Vector2.ZERO
				actor.enter_state(Actor.State.IDLE, tick)
		Actor.State.STAGGERED:
			var duration: int = player_data.stagger_duration_ticks
			if actor.kind == Actor.Kind.ENEMY:
				var data: EnemyData = data_for(actor)
				if data != null:
					duration = data.stagger_duration_ticks
			if actor.ticks_in_state(tick) >= duration:
				actor.enter_state(Actor.State.IDLE, tick)
		_:
			pass

func _recover_stamina(actor: Actor) -> void:
	if actor.kind != Actor.Kind.PLAYER or not actor.is_alive():
		return
	if tick - actor.last_stamina_spend_tick < player_data.stamina_regen_delay_ticks:
		return
	actor.stamina_centi = mini(actor.max_stamina_centi,
		actor.stamina_centi + player_data.stamina_regen_per_tick_centi)

func _recover_poise(actor: Actor) -> void:
	if not actor.is_alive() or actor.poise >= actor.max_poise:
		return
	var recovery_ticks: int = player_data.poise_recovery_ticks
	if actor.kind == Actor.Kind.ENEMY:
		var data: EnemyData = data_for(actor)
		if data != null:
			recovery_ticks = data.poise_recovery_ticks
	var period: int = maxi(1, floori(float(recovery_ticks) / float(maxi(1, actor.max_poise))))
	var elapsed: int = tick - actor.last_poise_break_tick
	if elapsed > 0 and elapsed % period == 0:
		actor.poise = mini(actor.max_poise, actor.poise + 1)

# ---------------------------------------------------------------------------
# Lecture de charge utile. Un pair distant peut envoyer n'importe quoi.
# ---------------------------------------------------------------------------

func _payload_vector(command: Command, key: String) -> Vector2:
	var raw: Variant = command.payload.get(key, null)
	if typeof(raw) != TYPE_VECTOR2:
		return Vector2.ZERO
	var value: Vector2 = raw
	if not is_finite(value.x) or not is_finite(value.y):
		return Vector2.ZERO
	return value

func _payload_int(command: Command, key: String, fallback: int) -> int:
	var raw: Variant = command.payload.get(key, null)
	if typeof(raw) != TYPE_INT:
		return fallback
	var value: int = raw
	return value
