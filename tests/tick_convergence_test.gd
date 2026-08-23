## Test d'acceptation du socle réseau.
##
## Deux instances dans le même processus, reliées par ENet sur la boucle
## locale, avec 120 ms de latence simulée dans chaque sens. Après 600 ticks,
## le client doit précéder l'hôte d'un décalage constant.
##
## On ne teste pas l'égalité des compteurs : l'hôte étant autoritaire et la
## synchronisation d'état n'étant pas du lockstep (décision 4), le client
## simule volontairement en avance. Ce qui doit converger, c'est l'écart —
## il doit se stabiliser, ne plus dériver, et valoir la bonne chose.
##
## Valeur attendue de l'écart. Avec L la latence d'un aller simple, le client
## vise « tick estampillé par l'hôte + aller-retour + marge », soit H + 2L + m.
## Mais l'hôte a lui-même avancé de L depuis qu'il a estampillé. L'écart
## observable entre les deux compteurs au même instant vaut donc L + m, et non
## 2L + m : le client précède l'hôte d'exactement un aller simple, ce qui est
## précisément ce qu'il faut pour qu'une commande émise maintenant arrive à
## temps.
extends GdUnitTestSuite

const PORT: int = 45231
const LATENCY_MSEC: int = 120
const TOTAL_TICKS: int = 600
## On ignore la phase d'accrochage : la première sonde ne peut pas revenir
## avant un aller-retour, et la resynchronisation initiale suit.
const SETTLED_AFTER_TICK: int = 300
## Écart toléré entre le plus grand et le plus petit décalage observé une fois
## stabilisé. La zone morte de Simulation vaut 1 tick, donc l'écart oscille au
## plus entre -1 et +1 autour de la cible.
const MAX_SPREAD_TICKS: int = 2
## Dérive tolérée entre la première et la seconde moitié de la mesure.
const MAX_DRIFT_TICKS: int = 1
## Tolérance autour de l'écart théorique. Absorbe l'arrondi en ticks et la
## gigue d'ordonnancement de la machine, sans laisser passer une avance
## effondrée ou aberrante.
const LEAD_TOLERANCE_TICKS: int = 3

var _host: NetBootstrap
var _client: NetBootstrap

func before_test() -> void:
	_host = _spawn(NetOptions.Role.HOST)
	_client = _spawn(NetOptions.Role.CLIENT)

func after_test() -> void:
	for instance: NetBootstrap in [_host, _client]:
		if is_instance_valid(instance):
			instance.queue_free()
	_host = null
	_client = null

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

func test_le_decalage_de_tick_se_stabilise_sans_deriver() -> void:
	var offsets: PackedInt32Array = PackedInt32Array()
	for _frame: int in TOTAL_TICKS:
		await get_tree().physics_frame
		if _host.simulation.current_tick >= SETTLED_AFTER_TICK:
			offsets.append(_client.simulation.current_tick - _host.simulation.current_tick)

	assert_int(_host.simulation.current_tick) \
		.override_failure_message("L'hôte n'a pas simulé les 600 ticks attendus.") \
		.is_greater_equal(TOTAL_TICKS - 5)
	assert_bool(_client.clock.has_estimate()) \
		.override_failure_message("Le client n'a jamais reçu de réponse à ses sondes d'horloge.") \
		.is_true()
	assert_int(offsets.size()).is_greater(100)

	var lowest: int = offsets[0]
	var highest: int = offsets[0]
	for offset: int in offsets:
		lowest = mini(lowest, offset)
		highest = maxi(highest, offset)

	assert_int(lowest) \
		.override_failure_message("Le client doit précéder l'hôte, pas le suivre (décalage %d)." % lowest) \
		.is_greater(0)
	assert_int(highest - lowest) \
		.override_failure_message("Le décalage oscille de %d ticks : l'horloge n'est pas stable." % (highest - lowest)) \
		.is_less_equal(MAX_SPREAD_TICKS)

	var half: int = offsets.size() >> 1
	var drift: int = absi(_mean(offsets.slice(half)) - _mean(offsets.slice(0, half)))
	assert_int(drift) \
		.override_failure_message("Le décalage dérive de %d ticks entre les deux moitiés de la mesure." % drift) \
		.is_less_equal(MAX_DRIFT_TICKS)

	var expected_lead: int = SimConfig.usec_to_ticks(LATENCY_MSEC * 1000) \
		+ SimConfig.CLIENT_LEAD_SAFETY_TICKS
	var observed_lead: int = _mean(offsets)
	prints("écart observé : [%d, %d] ticks, attendu %d ± %d"
		% [lowest, highest, expected_lead, LEAD_TOLERANCE_TICKS])
	assert_int(absi(observed_lead - expected_lead)) \
		.override_failure_message(
			"Avance du client de %d ticks au lieu de %d : la compensation de latence est fausse."
			% [observed_lead, expected_lead]) \
		.is_less_equal(LEAD_TOLERANCE_TICKS)

func _mean(values: PackedInt32Array) -> int:
	if values.is_empty():
		return 0
	var total: int = 0
	for value: int in values:
		total += value
	return roundi(float(total) / float(values.size()))
