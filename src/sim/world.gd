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
## Le joueur local a soigné un allié. Le soigneur déclare, l'hôte confirme.
signal heal_declared(target_id: int, attack_index: int)
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
## Délai avant réapparition automatique quand toute l'équipe est morte. Sans
## lui, une équipe entièrement tombée resterait bloquée : plus personne n'est
## vivant pour aller se reposer au feu.
const WIPE_RESPAWN_DELAY_TICKS: int = 180

var tick: int = 0
var authority: Authority = Authority.HOST
## Acteur piloté par cette machine. 0 si aucun.
var local_actor_id: int = 0

var level: LevelData = null
## Classes jouables, dans l'ordre du menu. L'index d'un joueur est stocké dans
## son data_index, comme celui d'un ennemi : un acteur sait toujours de quelle
## fiche il tient ses réglages.
var player_classes: Array[PlayerData] = []
var enemy_data: Array[EnemyData] = []

var actors: Dictionary[int, Actor] = {}
var shortcut_open: bool = false

## Projectiles en vol, par identifiant. Leur position n'est jamais stockée :
## elle se recalcule depuis l'origine et le tick de départ.
var projectiles: Dictionary[int, Projectile] = {}

var _runner_parent: Node
var _next_enemy_id: int = FIRST_ENEMY_ID
var _wipe_tick: int = -1

func _init(runner_parent: Node) -> void:
	_runner_parent = runner_parent

func configure(p_level: LevelData, p_player_classes: Array[PlayerData],
		p_enemy_data: Array[EnemyData]) -> void:
	level = p_level
	player_classes = p_player_classes
	enemy_data = p_enemy_data

## Fiche de classe d'un joueur. Retombe sur la première si l'index est absurde :
## un pair distant peut annoncer n'importe quoi.
func class_for(actor: Actor) -> PlayerData:
	if player_classes.is_empty():
		return null
	var index: int = actor.data_index
	if index < 0 or index >= player_classes.size():
		index = 0
	return player_classes[index]

# ---------------------------------------------------------------------------
# Peuplement
# ---------------------------------------------------------------------------

func spawn_player(actor_id: int, slot: int, class_index: int = 0) -> Actor:
	var actor: Actor = Actor.new()
	actor.id = actor_id
	actor.kind = Actor.Kind.PLAYER
	actor.position = _player_spawn(slot)
	actor.home_position = actor.position
	actor.facing = Vector2(0.0, 1.0)
	actor.runner = _make_runner("Attack_%d" % actor_id)
	actors[actor_id] = actor
	apply_class(actor, class_index)
	return actor

## Installe une classe sur un joueur et le remet à neuf. Appelée à la
## connexion, quand le client annonce son choix.
func apply_class(actor: Actor, class_index: int) -> void:
	if actor.kind != Actor.Kind.PLAYER or player_classes.is_empty():
		return
	actor.data_index = clampi(class_index, 0, player_classes.size() - 1)
	var fiche: PlayerData = class_for(actor)
	actor.radius = fiche.radius
	actor.max_health = fiche.max_health
	actor.health = actor.max_health
	actor.max_stamina_centi = fiche.max_stamina * Actor.CENTI
	actor.stamina_centi = actor.max_stamina_centi
	actor.max_poise = fiche.max_poise
	actor.poise = actor.max_poise

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
	# Le mannequin arrive EN DERNIER : `enemies()[0]` doit rester le premier
	# gobelin, sur quoi reposent les tests et la lecture du couloir.
	var dummy: EnemyData = _training_dummy_data()
	if dummy != null and level.training_dummy_position != Vector2.ZERO:
		_spawn_enemy(dummy, level.training_dummy_position)

## Crée un ennemi dont l'hôte a annoncé l'existence. Le client ne décide ni de
## sa position ni de sa vie : il ouvre seulement la place.
func adopt_enemy(actor_id: int, index: int, spawn: Vector2) -> Actor:
	if index < 0 or index >= enemy_data.size():
		return null
	var actor: Actor = _spawn_enemy(enemy_data[index], spawn)
	actors.erase(actor.id)
	actor.id = actor_id
	actors[actor_id] = actor
	return actor

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
		# Un mannequin n'est ni un ennemi de couloir ni un boss : sans cette
		# exclusion, le premier de la liste finirait par peupler le couloir.
		if data.is_training_dummy:
			continue
		if data.is_boss == boss:
			return data
	return null

func _training_dummy_data() -> EnemyData:
	for data: EnemyData in enemy_data:
		if data.is_training_dummy:
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

## Tout ce qui bloque un déplacement ou un projectile à cet instant : les
## obstacles fixes du niveau, plus la porte du raccourci tant qu'elle est
## fermée. Une seule liste, consultée par la marche comme par le vol : un
## pilier qui arrête un joueur et laisse passer une flèche serait un mensonge.
func blockers() -> Array[Rect2]:
	var out: Array[Rect2] = []
	out.append_array(level.obstacles)
	if not shortcut_open:
		out.append(level.shortcut_gate)
	return out

func data_for(actor: Actor) -> EnemyData:
	if actor.data_index < 0 or actor.data_index >= enemy_data.size():
		return null
	return enemy_data[actor.data_index]

func attacks_for(actor: Actor) -> Array[AttackData]:
	if actor.kind == Actor.Kind.PLAYER:
		var fiche: PlayerData = class_for(actor)
		return fiche.attacks if fiche != null else []
	var data: EnemyData = data_for(actor)
	return data.attacks if data != null else []

# ---------------------------------------------------------------------------
# Pas de simulation
# ---------------------------------------------------------------------------

## Avance le monde d'un tick. Le numero de tick vient de la boucle de
## simulation et n'est jamais compte ici : deux compteurs finiraient par
## diverger, et c'est exactement ce que l'invariant 1 interdit.
func step(at_tick: int, commands: Array[Command]) -> void:
	tick = at_tick
	for command: Command in commands:
		_apply_command(command)
	if authority == Authority.HOST:
		_decide_enemies()
		_revive_dummies()
		_check_wipe()
	_refresh_locks()
	_advance_attacks()
	_resolve_hitboxes()
	_advance_projectiles()
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
		Command.Type.DECLARE_HEAL:
			_command_declare_heal(actor, command)
		Command.Type.SELECT_CLASS:
			_command_select_class(actor, command)
		Command.Type.LOCK:
			_command_lock(actor, command)
		Command.Type.NONE:
			pass

func _command_move(actor: Actor, command: Command) -> void:
	if not actor.is_alive():
		return
	var direction: Vector2 = _payload_vector(command, "d")
	actor.move_intent = direction.normalized() if direction.length() > 0.001 else Vector2.ZERO

## Distance au-delà de laquelle un verrouillage se relâche tout seul, en
## mètres. Assez large pour traverser l'arène du boss sans le perdre, assez
## courte pour qu'on ne reste pas accroché à un ennemi qu'on a fui.
const LOCK_RANGE: float = 26.0
## Part de la distance et du coût d'une roulade que garde un pas arrière.
const BACKSTEP_REACH: float = 0.62
const BACKSTEP_STAMINA: float = 0.60

## Verrouille sur un adversaire. La présentation propose, la simulation
## dispose : elle vérifie que la cible existe, qu'elle est vivante, qu'elle est
## d'un autre camp et qu'elle est à portée. Zéro relâche.
func _command_lock(actor: Actor, command: Command) -> void:
	if not actor.is_alive():
		return
	var wanted: int = 0
	if command.payload.has("t"):
		var brut: Variant = command.payload["t"]
		if brut is int:
			wanted = brut
		elif brut is float:
			var f: float = brut
			wanted = int(f)
	if wanted == 0:
		actor.lock_target_id = 0
		return
	var target: Actor = actor_or_null(wanted)
	if target == null or not target.is_alive() or target.kind == actor.kind:
		return
	if actor.position.distance_to(target.position) > LOCK_RANGE:
		return
	actor.lock_target_id = wanted

## Relâche un verrouillage devenu caduc : cible morte, disparue, ou trop loin.
## Appelé chaque tick — un verrou qui survit à sa cible est un personnage qui
## regarde un cadavre en reculant.
func _refresh_locks() -> void:
	for actor: Actor in actors.values():
		if actor.lock_target_id == 0:
			continue
		var target: Actor = actor_or_null(actor.lock_target_id)
		if target == null or not target.is_alive() \
				or actor.position.distance_to(target.position) > LOCK_RANGE:
			actor.lock_target_id = 0

func _command_dodge(actor: Actor, command: Command) -> void:
	if actor.kind != Actor.Kind.PLAYER or not actor.can_act():
		return
	var fiche: PlayerData = class_for(actor)
	if fiche == null or not actor.has_stamina(fiche.dodge_stamina_cost):
		return
	var direction: Vector2 = _payload_vector(command, "d")
	# PAS D'ESQUIVE ARRIÈRE. Sans direction, on ne roule pas en avant : on
	# saute en arrière SANS SE RETOURNER. C'est le geste de garde du genre —
	# celui qu'on fait quand on ne sait pas encore ce qui arrive — et il n'a
	# aucun équivalent quand toute esquive part vers l'avant. Il coûte moins,
	# va moins loin, et laisse le personnage face à ce qu'il fuit.
	actor.dodge_backstep = direction.length() <= 0.001
	if actor.dodge_backstep:
		actor.dodge_heading = -actor.facing
		actor.spend_stamina(
			maxi(1, int(float(fiche.dodge_stamina_cost) * BACKSTEP_STAMINA)),
			tick)
	else:
		actor.facing = direction.normalized()
		actor.dodge_heading = actor.facing
		actor.spend_stamina(fiche.dodge_stamina_cost, tick)
	actor.velocity = actor.dodge_heading * fiche.dodge_speed
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
	# Pivot immédiat vers la visée, puis tracking limité par la donnée. C'est
	# le compromis du genre : on choisit où l'on frappe au moment de frapper,
	# et plus après.
	var aim: Vector2 = _payload_vector(command, "d")
	if aim.length() > 0.001:
		actor.aim = aim.normalized()
		actor.facing = actor.aim
	else:
		actor.aim = actor.facing
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

## Le soigneur déclare, l'hôte confirme. Amendement assumé de l'invariant 5 :
## le troisième cas d'autorité, celui d'un joueur qui modifie favorablement
## l'état d'un autre. Il revient à l'hôte et non à la cible, parce qu'un soin
## n'a pas besoin d'être instantané pour rester juste.
func _command_declare_heal(healer: Actor, command: Command) -> void:
	if authority != Authority.HOST or healer.kind != Actor.Kind.PLAYER:
		return
	if not healer.is_alive():
		return
	if tick - command.tick > HIT_MAX_AGE_TICKS or command.tick > tick + 5:
		return
	var target: Actor = actor_or_null(_payload_int(command, "t", 0))
	if target == null or target.kind != Actor.Kind.PLAYER or not target.is_alive():
		return
	var attacks: Array[AttackData] = attacks_for(healer)
	var index: int = _payload_int(command, "a", -1)
	if index < 0 or index >= attacks.size():
		return
	var attack: AttackData = attacks[index]
	if attack.heal <= 0:
		return
	var reach: float = attack.range_meters + target.radius + HIT_PLAUSIBILITY_SLACK
	if healer.position.distance_to(target.position) > reach:
		return
	target.health = mini(target.max_health, target.health + attack.heal)

## Un joueur annonce sa classe en arrivant. L'hôte seul décide, et seulement
## avant que le joueur n'ait commencé à se battre.
func _command_select_class(actor: Actor, command: Command) -> void:
	if authority != Authority.HOST or actor.kind != Actor.Kind.PLAYER:
		return
	apply_class(actor, _payload_int(command, "c", 0))
	actor.position = actor.home_position
	actor.velocity = Vector2.ZERO
	actor.enter_state(Actor.State.IDLE, tick)

# ---------------------------------------------------------------------------
# Projectiles
# ---------------------------------------------------------------------------

## Fait avancer les projectiles et résout ce qu'ils rencontrent.
##
## Chaque machine simule le vol : la trajectoire étant entièrement déterminée
## par l'origine et le tick de départ, elles obtiennent le même résultat. Seule
## la DÉCLARATION de la touche suit l'autorité (invariant 5).
func _advance_projectiles() -> void:
	if projectiles.is_empty():
		return
	var expired: Array[int] = []
	for projectile: Projectile in projectiles.values():
		var attack: AttackData = projectile_attack(projectile)
		if attack == null or attack.projectile == null or projectile.spent:
			expired.append(projectile.id)
			continue
		if projectile.age(tick) > attack.projectile.lifetime_ticks:
			expired.append(projectile.id)
			continue
		var at: Vector2 = projectile.position_at(tick, attack.projectile.speed)
		if not SimMath.point_is_free(at, level.walkable, blockers()):
			expired.append(projectile.id)
			continue
		var victim: Actor = _projectile_victim(projectile, at, attack)
		if victim != null:
			projectile.spent = true
			_declare_projectile_hit(projectile, victim)
			expired.append(projectile.id)
	for projectile_id: int in expired:
		projectiles.erase(projectile_id)

func projectile_attack(projectile: Projectile) -> AttackData:
	var shooter: Actor = actor_or_null(projectile.owner_id)
	if shooter == null:
		return null
	var attacks: Array[AttackData] = attacks_for(shooter)
	if projectile.attack_index < 0 or projectile.attack_index >= attacks.size():
		return null
	return attacks[projectile.attack_index]

## Position visible d'un projectile. Utilisée par la présentation.
func projectile_position(projectile: Projectile) -> Vector2:
	var attack: AttackData = projectile_attack(projectile)
	if attack == null or attack.projectile == null:
		return projectile.origin
	return projectile.position_at(tick, attack.projectile.speed)

func _projectile_victim(projectile: Projectile, at: Vector2, attack: AttackData) -> Actor:
	var shooter: Actor = actor_or_null(projectile.owner_id)
	if shooter == null:
		return null
	for actor: Actor in actors.values():
		if actor.id == projectile.owner_id or not actor.is_alive():
			continue
		# Pas de tir allié : un projectile ne touche que le camp d'en face.
		if actor.kind == shooter.kind:
			continue
		if at.distance_to(actor.position) <= attack.projectile.radius + actor.radius:
			return actor
	return null

func _declare_projectile_hit(projectile: Projectile, victim: Actor) -> void:
	var shooter: Actor = actor_or_null(projectile.owner_id)
	if shooter == null:
		return
	if shooter.id == local_actor_id and victim.kind == Actor.Kind.ENEMY:
		hit_declared.emit(victim.id, projectile.attack_index)
	elif shooter.kind == Actor.Kind.ENEMY and victim.id == local_actor_id \
			and not is_invulnerable(victim):
		damage_reported.emit(shooter.id, projectile.attack_index)

func spawn_projectile(shooter: Actor, attack_index: int) -> Projectile:
	var projectile: Projectile = Projectile.new()
	projectile.owner_id = shooter.id
	projectile.spawn_tick = tick
	projectile.id = Projectile.make_id(shooter.id, tick)
	projectile.attack_index = attack_index
	projectile.direction = shooter.facing
	projectile.origin = shooter.position + shooter.facing * (shooter.radius + 0.35)
	projectiles[projectile.id] = projectile
	return projectile

# ---------------------------------------------------------------------------
# Ennemis (hôte uniquement)
# ---------------------------------------------------------------------------

## Relève l'équipe si elle est entièrement tombée.
func _check_wipe() -> void:
	var roster: Array[Actor] = players()
	if roster.is_empty():
		_wipe_tick = -1
		return
	for player: Actor in roster:
		if player.is_alive():
			_wipe_tick = -1
			return
	if _wipe_tick < 0:
		_wipe_tick = tick
	elif tick - _wipe_tick >= WIPE_RESPAWN_DELAY_TICKS:
		_wipe_tick = -1
		rest_at_bonfire()

## Un mannequin abattu se relève. C'est le seul endroit du jeu où la mort ne
## coûte rien — et il le faut : on apprend le rythme d'une arme en se
## trompant, pas en lisant une consigne.
##
## Hôte uniquement, comme toute décision sur un ennemi (invariant 5).
func _revive_dummies() -> void:
	for enemy: Actor in enemies():
		if enemy.is_alive():
			continue
		var data: EnemyData = data_for(enemy)
		if data == null or not data.is_training_dummy:
			continue
		if enemy.ticks_in_state(tick) < data.dummy_revive_ticks:
			continue
		enemy.health = enemy.max_health
		enemy.poise = enemy.max_poise
		enemy.position = enemy.home_position
		enemy.enter_state(Actor.State.IDLE, tick)

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
		if not actor.simulated:
			continue
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
		# Un tir part sur TOUTES les machines, avec le même identifiant : sa
		# trajectoire est déterministe, seule la touche demande une autorité.
		if attack.projectile != null:
			if attacker.runner.try_fire_once():
				spawn_projectile(attacker, attacker.attack_index)
			continue
		if attacker.kind == Actor.Kind.PLAYER and attacker.id == local_actor_id:
			_resolve_player_hitbox(attacker, attack)
		elif attacker.kind == Actor.Kind.ENEMY and local != null:
			_resolve_enemy_hitbox(attacker, attack, local)

## L'attaquant déclare ce qu'il touche (invariant 5).
func _resolve_player_hitbox(attacker: Actor, attack: AttackData) -> void:
	if attack.heal > 0:
		_resolve_heal(attacker, attack)
		return
	for target: Actor in enemies():
		if not target.is_alive():
			continue
		if not SimMath.cone_contains(attacker.position, attacker.facing,
				attack.range_meters, attack.half_angle_degrees, target.position, target.radius):
			continue
		if not attacker.runner.try_register_hit(target.id):
			continue
		hit_declared.emit(target.id, attacker.attack_index)

## Un soin cherche des alliés, pas des ennemis. Le soigneur est toujours dans
## son propre cône : il se soigne aussi.
func _resolve_heal(healer: Actor, attack: AttackData) -> void:
	for ally: Actor in players():
		if not ally.is_alive():
			continue
		if ally.id != healer.id and not SimMath.cone_contains(healer.position,
				healer.facing, attack.range_meters, attack.half_angle_degrees,
				ally.position, ally.radius):
			continue
		if not healer.runner.try_register_hit(ally.id):
			continue
		heal_declared.emit(ally.id, healer.attack_index)

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

## Avancement de la roulade, de 0 à 1. Zéro si l'acteur ne roule pas.
##
## Lecture seule, offerte à la présentation : la vue a besoin de savoir OÙ en
## est la roulade pour la dessiner, et il vaut mieux qu'elle le demande à la
## simulation que de le recompter avec ses propres horloges — deux compteurs
## séparés finissent toujours par diverger.
func dodge_progress(actor: Actor) -> float:
	if actor.state != Actor.State.DODGING:
		return 0.0
	var fiche: PlayerData = class_for(actor)
	if fiche == null:
		return 0.0
	var duration: int = maxi(1, fiche.dodge_duration_ticks)
	return clampf(float(actor.ticks_in_state(tick)) / float(duration), 0.0, 1.0)

func is_invulnerable(actor: Actor) -> bool:
	if actor.state != Actor.State.DODGING:
		return false
	var fiche: PlayerData = class_for(actor)
	if fiche == null:
		return false
	var elapsed: int = actor.ticks_in_state(tick)
	return elapsed >= fiche.dodge_invulnerable_from_tick \
		and elapsed <= fiche.dodge_invulnerable_to_tick

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
		player.position = player.home_position
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
	projectiles.clear()
	bonfire_rested.emit()

# ---------------------------------------------------------------------------
# Mouvement
# ---------------------------------------------------------------------------

func _integrate() -> void:
	var walkable: Array[Rect2] = level.walkable
	var active_blockers: Array[Rect2] = blockers()
	for actor: Actor in actors.values():
		if not actor.simulated:
			continue
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
				_deceleration(actor) * SimConfig.TICK_DURATION_SEC)
		Actor.State.DODGING:
			# Vitesse imposée par la roulade : ni accélération ni contrôle,
			# mais un profil, pas un plateau.
			_update_dodge_velocity(actor)
		Actor.State.ATTACKING:
			_update_attack_movement(actor)
		_:
			_update_walk(actor)

## Profil de vitesse de la roulade, fonction pure du nombre de ticks écoulés :
## elle donne donc le même résultat sur l'hôte, sur le client qui prédit et
## dans un rejeu de réconciliation.
##
## La courbe reste haute au début puis tombe — c'est ce qui fait qu'une
## roulade se sent comme une impulsion et non comme un déplacement à vitesse
## constante, qui était le vrai défaut de sensation du jeu.
func _update_dodge_velocity(actor: Actor) -> void:
	var fiche: PlayerData = class_for(actor)
	if fiche == null:
		return
	var duration: int = maxi(1, fiche.dodge_duration_ticks)
	var progress: float = clampf(
		float(actor.ticks_in_state(tick)) / float(duration), 0.0, 1.0)
	var shape: float = pow(1.0 - progress, 2.4)
	var factor: float = fiche.dodge_tail \
		+ (fiche.dodge_burst - fiche.dodge_tail) * shape
	if actor.dodge_backstep:
		factor *= BACKSTEP_REACH
	# On suit le CAP pris au départ, pas `facing` : un pas arrière laisse le
	# personnage tourné vers ce qu'il fuit, et suivre `facing` le ferait
	# repartir en avant.
	actor.velocity = actor.dodge_heading * (fiche.dodge_speed * factor)

## Freinage propre à l'acteur : une classe lourde ne s'arrête pas comme un
## archer, et un ennemi encore moins.
func _deceleration(actor: Actor) -> float:
	if actor.kind == Actor.Kind.ENEMY:
		var data: EnemyData = data_for(actor)
		return data.acceleration if data != null else 25.0
	var fiche: PlayerData = class_for(actor)
	return fiche.deceleration if fiche != null else 45.0

func _update_walk(actor: Actor) -> void:
	var speed: float = 5.0
	var acceleration: float = 60.0
	var deceleration: float = 45.0
	var turn: float = 12.0
	if actor.kind == Actor.Kind.ENEMY:
		var data: EnemyData = data_for(actor)
		if data != null:
			speed = data.move_speed
			acceleration = data.acceleration
			deceleration = data.acceleration
			turn = data.turn_degrees_per_tick
	else:
		var fiche: PlayerData = class_for(actor)
		if fiche != null:
			speed = fiche.move_speed
			acceleration = fiche.acceleration
			deceleration = fiche.deceleration
			turn = fiche.turn_degrees_per_tick
	# Verrouillé, on reste FACE à la cible, qu'on avance, qu'on recule ou qu'on
	# tourne autour. C'est toute la différence de démarche entre un souls-like
	# et un jeu d'action : sans ça le personnage regarde toujours là où il va,
	# et il n'y a ni pas chassé ni marche arrière.
	var locked: Actor = actor_or_null(actor.lock_target_id)
	if locked != null and locked.is_alive():
		var toward: Vector2 = locked.position - actor.position
		if toward.length() > 0.01:
			actor.facing = SimMath.rotate_towards(actor.facing, toward,
				turn * 1.6)
	if actor.move_intent.is_zero_approx():
		actor.velocity = actor.velocity.move_toward(Vector2.ZERO,
			deceleration * SimConfig.TICK_DURATION_SEC)
		if actor.state == Actor.State.MOVING and actor.velocity.is_zero_approx():
			actor.enter_state(Actor.State.IDLE, tick)
		return
	if locked == null or not locked.is_alive():
		actor.facing = SimMath.rotate_towards(actor.facing, actor.move_intent,
			turn)
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
		var desired: Vector2 = actor.aim
		if actor.kind == Actor.Kind.ENEMY:
			var target: Actor = actor_or_null(actor.target_id)
			if target != null:
				desired = target.position - actor.position
		actor.facing = SimMath.rotate_towards(actor.facing, desired,
			attack.tracking_degrees_per_tick)
		actor.velocity = actor.facing * attack.forward_speed
	else:
		actor.velocity = actor.velocity.move_toward(Vector2.ZERO,
			_deceleration(actor) * SimConfig.TICK_DURATION_SEC)

## Écarte les acteurs qui se chevauchent. Sans cela, trois ennemis convergeant
## vers le même joueur occuperaient la même case.
func _separate() -> void:
	var list: Array[Actor] = []
	for actor: Actor in actors.values():
		if actor.is_alive() and actor.simulated:
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

## Rejoue le mouvement du personnage local depuis un tick corrigé par l'hôte.
##
## Ne rejoue que MOVE et DODGE. Les calendriers d'attaque ne sont jamais
## rembobinés : leurs pistes d'appel de méthode retomberaient, et une touche
## déjà déclarée le serait une seconde fois. La conséquence assumée est qu'une
## correction pendant une attaque replace le personnage sans replacer son
## avancée d'attaque, ce qui se voit à peine et coûte cent lignes de moins.
func replay_local(actor: Actor, history: CommandHistory, from_tick: int, to_tick: int) -> void:
	var restore_tick: int = tick
	var walkable: Array[Rect2] = level.walkable
	var active_blockers: Array[Rect2] = blockers()
	for replay_tick: int in range(from_tick, to_tick + 1):
		tick = replay_tick
		for command: Command in history.commands_at(replay_tick):
			match command.type:
				Command.Type.MOVE:
					_command_move(actor, command)
				Command.Type.DODGE:
					_command_dodge(actor, command)
				_:
					pass
		_update_velocity(actor)
		if not actor.velocity.is_zero_approx():
			var target: Vector2 = actor.position + actor.velocity * SimConfig.TICK_DURATION_SEC
			actor.position = SimMath.slide(actor.position, target, actor.radius,
				walkable, active_blockers)
		_recover_state(actor)
		history.record_position(replay_tick, actor.position)
	tick = restore_tick

# ---------------------------------------------------------------------------
# Récupération et fins d'état
# ---------------------------------------------------------------------------

func _recover() -> void:
	for actor: Actor in actors.values():
		if not actor.simulated:
			continue
		_recover_state(actor)
		_recover_stamina(actor)
		_recover_poise(actor)

func _recover_state(actor: Actor) -> void:
	match actor.state:
		Actor.State.DODGING:
			var fiche: PlayerData = class_for(actor)
			var dodge_ticks: int = fiche.dodge_duration_ticks if fiche != null else 24
			if actor.ticks_in_state(tick) >= dodge_ticks:
				# On ne coupe pas à zéro : le personnage sort de sa roulade
				# en marchant, ce qui rend l'enchaînement lisible.
				var exit_speed: float = fiche.dodge_exit_speed if fiche != null else 2.4
				actor.velocity = actor.facing * exit_speed
				actor.enter_state(Actor.State.IDLE, tick)
		Actor.State.STAGGERED:
			var duration: int = 30
			if actor.kind == Actor.Kind.ENEMY:
				var data: EnemyData = data_for(actor)
				if data != null:
					duration = data.stagger_duration_ticks
			else:
				var player_fiche: PlayerData = class_for(actor)
				if player_fiche != null:
					duration = player_fiche.stagger_duration_ticks
			if actor.ticks_in_state(tick) >= duration:
				actor.enter_state(Actor.State.IDLE, tick)
		_:
			pass

func _recover_stamina(actor: Actor) -> void:
	if actor.kind != Actor.Kind.PLAYER or not actor.is_alive() or not actor.simulated:
		return
	var fiche: PlayerData = class_for(actor)
	if fiche == null or tick - actor.last_stamina_spend_tick < fiche.stamina_regen_delay_ticks:
		return
	actor.stamina_centi = mini(actor.max_stamina_centi,
		actor.stamina_centi + fiche.stamina_regen_per_tick_centi)

func _recover_poise(actor: Actor) -> void:
	if not actor.is_alive() or actor.poise >= actor.max_poise:
		return
	var recovery_ticks: int = 180
	if actor.kind == Actor.Kind.ENEMY:
		var data: EnemyData = data_for(actor)
		if data != null:
			recovery_ticks = data.poise_recovery_ticks
	else:
		var fiche: PlayerData = class_for(actor)
		if fiche != null:
			recovery_ticks = fiche.poise_recovery_ticks
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
