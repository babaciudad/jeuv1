## La correction d'horloge est le seul mécanisme autorisé à modifier le
## compteur de tick. Ces tests fixent son comportement sans réseau.
extends GdUnitTestSuite

var _created: Array[Simulation] = []

func after_test() -> void:
	for sim: Simulation in _created:
		sim.free()
	_created.clear()

func _make() -> Simulation:
	var sim: Simulation = Simulation.new()
	_created.append(sim)
	return sim

func test_avance_d_un_tick_sans_cible() -> void:
	var sim: Simulation = _make()
	sim.advance()
	sim.advance()
	assert_int(sim.current_tick).is_equal(2)

func test_zone_morte_pas_de_correction() -> void:
	var sim: Simulation = _make()
	sim.advance()
	# Cible à un tick d'avance : dans la zone morte, on avance normalement.
	sim.set_target_tick(sim.current_tick + 1)
	sim.advance()
	assert_int(sim.current_tick).is_equal(2)

func test_rattrape_un_tick_quand_en_retard() -> void:
	var sim: Simulation = _make()
	sim.set_target_tick(5)
	sim.advance()
	assert_int(sim.current_tick).is_equal(2)

func test_cale_un_tick_quand_en_avance() -> void:
	var sim: Simulation = _make()
	sim.advance()
	sim.advance()
	sim.advance()
	sim.set_target_tick(0)
	sim.advance()
	assert_int(sim.current_tick).is_equal(3)

func test_resynchronisation_au_dela_du_seuil() -> void:
	var sim: Simulation = _make()
	var snapped_to: Array[int] = []
	sim.tick_snapped.connect(func(_from: int, to: int) -> void: snapped_to.append(to))
	sim.set_target_tick(Simulation.SNAP_THRESHOLD_TICKS + 50)
	sim.advance()
	assert_int(sim.current_tick).is_equal(Simulation.SNAP_THRESHOLD_TICKS + 50)
	assert_int(snapped_to.size()).is_equal(1)

func test_les_commandes_sont_appliquees_a_leur_tick() -> void:
	var sim: Simulation = _make()
	var applied: Array[int] = []
	sim.command_applied.connect(func(command: Command) -> void: applied.append(command.tick))
	sim.buffer.push(Command.new(3, 1))
	for _i: int in 5:
		sim.advance()
	assert_array(applied).is_equal([3])
