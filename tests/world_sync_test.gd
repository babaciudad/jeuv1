## Le monde de l'hôte parvient-il au client, et les commandes du client
## parviennent-elles à l'hôte ?
##
## Deux instances complètes dans le même processus, reliées par ENet sur la
## boucle locale, avec latence simulée. Rien n'est simulé en raccourci : ce
## sont les mêmes NetBootstrap que ceux lancés par tools/netharness.ps1.
extends GdUnitTestSuite

const PORT: int = 45244
const LATENCY_MSEC: int = 60
## Assez pour que la session s'établisse, que l'horloge se cale et que
## plusieurs instantanés aient circulé.
const SETTLE_TICKS: int = 240

var _host: NetBootstrap
var _client: NetBootstrap

func before_test() -> void:
	_host = _spawn(NetOptions.Role.HOST)
	_client = _spawn(NetOptions.Role.CLIENT)

func after_test() -> void:
	# Fermeture explicite du transport : queue_free() ne rend la socket qu'a
	# la fin de l'image, et le test suivant trouverait le port encore pris.
	for instance: NetBootstrap in [_host, _client]:
		if is_instance_valid(instance):
			if instance.transport != null:
				instance.transport.close()
			instance.queue_free()
	_host = null
	_client = null
	await get_tree().physics_frame
	await get_tree().physics_frame

func _spawn(role: NetOptions.Role) -> NetBootstrap:
	var options: NetOptions = NetOptions.new()
	options.role = role
	options.port = PORT
	options.latency_msec = LATENCY_MSEC
	options.rng_seed = 1
	var instance: NetBootstrap = NetBootstrap.new()
	instance.name = "Host" if role == NetOptions.Role.HOST else "Client"
	instance.configure(options)
	add_child(instance)
	return instance

func _settle(ticks: int = SETTLE_TICKS) -> void:
	for _i: int in ticks:
		await get_tree().physics_frame

func test_le_client_adopte_le_monde_annonce_par_l_hote() -> void:
	await _settle()

	# Un joueur hôte, un joueur client, trois ennemis de base et un boss.
	assert_int(_host.world.actors.size()).is_equal(6)
	assert_int(_client.world.actors.size()).is_equal(6)
	assert_int(_client.world.enemies().size()).is_equal(4)
	assert_int(_client.world.players().size()).is_equal(2)

func test_le_client_possede_son_personnage_et_pas_les_autres() -> void:
	await _settle()

	var local: Actor = _client.world.local_actor()
	assert_object(local).is_not_null()
	assert_bool(local.simulated).is_true()
	for actor: Actor in _client.world.actors.values():
		if actor.id != local.id:
			assert_bool(actor.simulated) \
				.override_failure_message("L'acteur %d ne devrait pas etre simule par le client." % actor.id) \
				.is_false()

func test_le_client_voit_les_ennemis_ou_l_hote_les_place() -> void:
	await _settle()

	var checked: int = 0
	for enemy: Actor in _client.world.enemies():
		var reference: Actor = _host.world.actor_or_null(enemy.id)
		assert_object(reference).is_not_null()
		var gap: float = enemy.position.distance_to(reference.position)
		assert_float(gap) \
			.override_failure_message("Ennemi %d a %.2f m de sa position autoritaire." % [enemy.id, gap]) \
			.is_less(0.5)
		checked += 1
	assert_int(checked).is_equal(4)

func test_le_deplacement_du_client_parvient_a_l_hote() -> void:
	await _settle()

	var local_id: int = _client.world.local_actor_id
	var mirrored: Actor = _host.world.actor_or_null(local_id)
	assert_object(mirrored).is_not_null()
	var start_x: float = mirrored.position.x

	for _i: int in 90:
		_client.submit_command(Command.Type.MOVE, {"d": Vector2(1.0, 0.0)})
		await get_tree().physics_frame

	assert_float(mirrored.position.x) \
		.override_failure_message("L'hote n'a pas vu bouger le personnage du client.") \
		.is_greater(start_x + 1.0)

func test_la_prediction_du_client_reste_proche_de_l_autorite() -> void:
	await _settle()

	for _i: int in 90:
		_client.submit_command(Command.Type.MOVE, {"d": Vector2(1.0, 0.0)})
		await get_tree().physics_frame

	var predicted: Actor = _client.world.local_actor()
	var authoritative: Actor = _host.world.actor_or_null(_client.world.local_actor_id)
	# Le client precede l'hote : un ecart de l'ordre de l'avance est normal,
	# un ecart de plusieurs metres signifierait que la reconciliation ne
	# fonctionne pas.
	var gap: float = predicted.position.distance_to(authoritative.position)
	assert_float(gap) \
		.override_failure_message("Prediction a %.2f m de l'autorite." % gap) \
		.is_less(2.0)
