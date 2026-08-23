## Décisions des ennemis.
##
## Invariant 5 : le comportement des ennemis est simulé EXCLUSIVEMENT par
## l'hôte. Ce fichier n'est appelé que là. Les clients voient le résultat dans
## les instantanés et rejouent les calendriers d'attaque pour savoir quand une
## hitbox est ouverte, mais ne décident jamais rien.
##
## L'intelligence tient en quatre états parce que le périmètre V1 demande
## « trois ennemis de base et un boss », pas un système de comportement.
class_name EnemyBrain
extends RefCounted

## Décision rendue à la simulation. Elle n'agit pas elle-même : elle propose.
class Decision extends RefCounted:
	var move_intent: Vector2 = Vector2.ZERO
	var attack_index: int = -1
	var target_id: int = 0

## Choisit le joueur vivant le plus proche dans le rayon d'aggro, ou 0.
static func pick_target(enemy: Actor, players: Array[Actor], data: EnemyData) -> int:
	var best_id: int = 0
	var best_distance: float = data.aggro_radius
	# Une cible déjà acquise se garde jusqu'au rayon de désengagement : sans
	# cela l'ennemi changerait d'avis à chaque pas d'un joueur.
	if enemy.target_id != 0:
		best_distance = data.leash_radius
	for player: Actor in players:
		if not player.is_alive():
			continue
		var distance: float = player.position.distance_to(enemy.position)
		if distance < best_distance:
			best_distance = distance
			best_id = player.id
	return best_id

static func decide(enemy: Actor, data: EnemyData, players: Array[Actor], tick: int) -> Decision:
	var decision: Decision = Decision.new()
	if not enemy.is_alive() or enemy.state == Actor.State.STAGGERED \
			or enemy.state == Actor.State.ATTACKING:
		return decision

	decision.target_id = EnemyBrain.pick_target(enemy, players, data)
	if decision.target_id == 0:
		# Sans cible, on rentre. Un ennemi qui reste où il a été attiré rend
		# le couloir injouable à la deuxième tentative.
		var to_home: Vector2 = enemy.home_position - enemy.position
		if to_home.length() > 0.5:
			decision.move_intent = to_home.normalized()
		return decision

	var target: Actor = null
	for player: Actor in players:
		if player.id == decision.target_id:
			target = player
			break
	if target == null:
		return decision

	var offset: Vector2 = target.position - enemy.position
	var distance: float = offset.length()
	if distance <= 0.05:
		return decision
	var towards: Vector2 = offset / distance
	var cooldown_ready: bool = tick - enemy.last_attack_tick >= EnemyBrain.attack_cooldown(enemy, data)

	# Reculer juste après avoir frappé. Un ennemi qui reste collé ne laisse
	# aucune fenêtre de riposte et le combat devient illisible.
	if tick - enemy.last_attack_tick < data.recover_ticks:
		decision.move_intent = -towards
		return decision

	if distance <= data.attack_range and cooldown_ready and not data.attacks.is_empty():
		decision.attack_index = EnemyBrain.pick_attack(data, distance, tick)
		return decision

	# À portée mais pas encore prêt : tourner autour plutôt que pousser. Trois
	# ennemis qui foncent tous droit se superposent et n'attaquent jamais.
	if distance <= data.attack_range * data.circle_band:
		decision.move_intent = EnemyBrain.circle_direction(enemy, towards)
		return decision

	decision.move_intent = towards
	return decision

## Sens de contournement, fixé par la parité de l'identifiant : deux ennemis
## voisins tournent en sens opposés et s'écartent au lieu de se gêner.
static func circle_direction(enemy: Actor, towards: Vector2) -> Vector2:
	var side: float = 1.0 if enemy.id % 2 == 0 else -1.0
	return (towards.orthogonal() * side + towards * 0.25).normalized()

## Cadence d'attaque. Un boss passé sous son seuil de vie enchaîne plus vite :
## c'est la seule différence de phase, et elle tient dans une division.
static func attack_cooldown(enemy: Actor, data: EnemyData) -> int:
	var cooldown: int = data.attack_cooldown_ticks
	if not data.is_boss or enemy.max_health <= 0:
		return cooldown
	var ratio: float = float(enemy.health) / float(enemy.max_health)
	if ratio >= data.phase_two_health_ratio:
		return cooldown
	var percent: int = maxi(1, data.phase_two_speed_percent)
	return maxi(1, floori(float(cooldown) * 100.0 / float(percent)))

## Choix de l'attaque. Un ennemi de base n'en a qu'une ; le boss alterne selon
## la distance, ce qui suffit à rendre ses ouvertures lisibles.
static func pick_attack(data: EnemyData, distance: float, tick: int) -> int:
	if data.attacks.size() <= 1:
		return 0
	var near: int = 0
	var far: int = data.attacks.size() - 1
	if distance < data.attack_range * 0.6:
		return near
	# Alternance déterministe plutôt qu'aléatoire : deux machines qui
	# simuleraient la même scène doivent aboutir au même résultat, et un
	# tirage non semé rendrait tout test de combat instable.
	var second: int = floori(float(tick) / float(SimConfig.TICK_RATE))
	return far if second % 2 == 0 else near
